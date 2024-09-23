#!/usr/bin/python3

# Copyright © 2024 Kiri Jolly

# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the “Software”), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import socket
import threading
import time
import sys
import enum

class PacketSocket:
    """Socket wrapper that encapsulates its own packet protocol and
    manages its own threads. Polling-style interface.

    Packets are simply binary blobs with a little-endian 32-bit
    unsigned integer size prepended to them. Input data will be split
    into individual packets based on these.

    TCP/IP only.

    Main public API:

    - start_client(address) - Connect to an open port.

    - start_server(address) - Start a server with an open port. This
      will start receiving connections, which much be accepted with
      get_next_server_connection().

    - get_next_server_connection() - Get the next incoming connection
      (returns None if nothing is currently connecting, or a new
      PacketSocket that can actually receive packets, otherwise).
      Polling interface.

    - send_packet(b) - Sends a byte array (b) as a packet. This adds
      it to a queue which is send in its own thread.

    - get_next_packet() - Gets the next complete incoming packet as a
      byte array or None if no packet yet (polling interface).

    - get_last_error() - Gets the last error as a string.

    - is_disconnected_or_error() - True if we've had a problem (use
      get_last_error() to see what the problem was).

    - stop() - Shutdown server or disconnect client (undoes
      start_client/start_server). Also must be used on the
      PacketSocket objects returned by get_next_server_connection().

    Internal packet format:

    - size: 4-byte little-endian unsigned integer indicating the
      number of bytes to follow for the next packet.

    - data: As many bytes of data that were specified in the 'size'.

    Note: 'size' does not include the space needed for the 'size'
    value itself.

    Example packet (bytes):
      [ 0x03, 0x00, 0x00, 0x00, 0x41, 0x42, 0x43 ]

    The first four bytes, [ 0x03, 0x00, 0x00, 0x00 ], indicate the
    size of the data, in a little endian unsigned integer. In this
    case that decodes to three. The next three bytes, [ 0x41, 0x42,
    0x43 ] are the packet data. In this case they represent the ASCII
    string "ABC".

    To send this example packet, one would use send_packet(b'ABC').

    On the receiving side, the return value of get_next_packet() would
    be b'ABC'.

    This class exists in KiriPacketSocket.gd, ported to GDScript. Any
    functional changes to this should be reflected in that
    implementation as well.
    """

    class PacketBuffer:
        """Receiving buffer for packets. Accumulates bytes until
        complete packets are formed.
        """

        def __init__(self):
            self._receive_buffer = b''
            self._packet_buffer = []

        def _grab_complete_packets(self):

            while len(self._receive_buffer) >= 4:

                next_packet_size = int.from_bytes(
                    self._receive_buffer[0:4],
                    "little")

                if len(self._receive_buffer) >= 4 + next_packet_size:

                    next_packet = self._receive_buffer[4 : 4 + next_packet_size]
                    self._receive_buffer = self._receive_buffer[4 + len(next_packet):]
                    self._packet_buffer.append(next_packet)

                else:

                    break

        def _have_complete_packet(self):
            self._grab_complete_packets()
            return len(self._packet_buffer) > 0

        def get_next_packet(self):
            if not self._have_complete_packet():
                return None
            return self._packet_buffer.pop(0)

        def add_bytes(self, incoming_bytes):
            self._receive_buffer += incoming_bytes

    class SocketState(enum.Enum):
        DISCONNECTED     = 0
        CONNECTING       = 1
        CONNECTED        = 2
        SERVER_STARTING  = 3
        SERVER_LISTENING = 4
        ERROR            = 5

    def __init__(self):
        self._should_quit = False
        self._packet_buffer = self.PacketBuffer()
        self._state = self.SocketState.DISCONNECTED
        self._outgoing_packet_queue = []

        self._state_lock = threading.Lock()
        self._worker_thread = None

        self._new_connections_to_server = []
        self._error_string = None

    def __del__(self):
        # WE BETTER NOT HAVE ZOMBIE THREADS SITTING AROUND.
        assert(not self._worker_thread)

    def send_packet(self, packet_bytes):
        """Add a binary blob to the send queue."""
        assert(packet_bytes)
        with self._state_lock:

            assert(packet_bytes)
            self._outgoing_packet_queue.append(packet_bytes)

    def get_next_packet(self):
        """Get a binary blob from the receive queue."""
        with self._state_lock:
            ret = self._packet_buffer.get_next_packet()

        return ret

    def get_send_queue_size(self):
        """Get the number of things waiting to send."""
        with self._state_lock:
            ret = len(self._outgoing_packet_queue)

        return ret

    def get_next_server_connection(self):
        """For servers: Get the next incoming connection as a PacketSocket instance.

        Returns None if there are no incoming connections.

        """
        with self._state_lock:
            ret = None
            if len(self._new_connections_to_server):
                ret = self._new_connections_to_server.pop(0)
        return ret

    def get_last_error(self):
        """Get the last error, as a string. (From the thrown exception.)

        Returns None if there has not been an error.

        """
        with self._state_lock:
            return self._error_string

    def is_disconnected_or_error(self):
        """Returns True if this socket has disconnected, or thrown an
        error. (One way or another, the connection is gone and
        resources may be cleaned up.)

        Note: May still have un-processed packets queued.

        """
        with self._state_lock:

            bad_states = [
                    self.SocketState.DISCONNECTED,
                    self.SocketState.ERROR
            ]

            if self._state in bad_states:
                return True

        return False

    def get_state(self):
        """Returns the current SocketState of this object."""

        with self._state_lock:
            return self._state

    def start_server(self, address):
        """For servers: Start a listening server. (And start worker
        thread.)

        Address is a tuple with a host IP (string) and a port number
        (int). Use "0.0.0.0" to open on every interface.

        """

        self._set_state(self.SocketState.SERVER_STARTING)

        assert(not self._worker_thread)
        self._worker_thread = threading.Thread(
            target=self._server_thread_func,
            args=[address],
            daemon=True)

        self._worker_thread.start()

    def start_client(self, address):
        """For clients: Attempt to connect to a listening server. (And
        start worker thread.)

        Address is a tuple with a host IP (string) and a port number
        (int).

        """

        self._set_state(self.SocketState.CONNECTING)

        assert(not self._worker_thread)

        self._worker_thread = threading.Thread(
            target=self._client_thread_func,
            args=[address],
            daemon=True)

        self._worker_thread.start()

    def stop(self):
        """Disconnect and shutdown the thread.

        For servers: Note that this does not disconnect PacketSocket
        instances that were established from this server.

        """

        assert(self._worker_thread)
        self._should_quit = True
        self._worker_thread.join()
        self._worker_thread = None
        self._should_quit = False

    def is_running(self):
        return not (self._worker_thread == None)

    def _normal_communication_loop(self, sock, address):
        """Shared communication loop between clients and servers."""

        # Packet wranging timeout. Should be low so we can send and
        # receive packets fast.
        sock.settimeout(0.0001)

        while not self._should_quit:

            # Get new data.
            try:
                incoming_bytes = sock.recv(1024)
                if not incoming_bytes:
                    break
                with self._state_lock:
                    self._packet_buffer.add_bytes(incoming_bytes)
            except TimeoutError:
                pass

            # Send all packets from queue.
            with self._state_lock:

                while len(self._outgoing_packet_queue):
                    next_outgoing_packet = self._outgoing_packet_queue.pop(0)
                    sock.send(len(next_outgoing_packet).to_bytes(4, "little"))
                    sock.send(next_outgoing_packet)

    def _client_thread_func(self, address):
        """Client startup thread function. Attempts to establishes connection."""

        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:

            try:
                # Connect to the server.
                self._set_state(self.SocketState.CONNECTING)
                sock.connect(address)

                self._set_state(self.SocketState.CONNECTED)

                self._normal_communication_loop(sock, address)

                # We are now disconnected.
                self._set_state(self.SocketState.DISCONNECTED)
                sock.close()

            except ConnectionError as ex:
                self._set_state(self.SocketState.ERROR, str(ex))

    def _set_state(self, state, error_string=None):
        with self._state_lock:

            self._state = state

            if self._state == self.SocketState.ERROR:
                assert(error_string)
                self._error_string = error_string
            else:
                assert(not error_string)
                self._error_string = None


    def _server_to_client_thread_func(self, connection, address):
        """Server connection startup thread function. Initiated
        internally from a server listening for connections.

        """

        self._set_state(self.SocketState.CONNECTED)

        try:
            self._normal_communication_loop(connection, address)
        except ConnectionError as ex:
            self._set_state(self.SocketState.ERROR, str(ex))

        # Only switch to "disconnected" if we were most recently
        # connected, otherwise we could mask an error.
        if self.get_state() == self.SocketState.CONNECTED:
            self._set_state(self.SocketState.DISCONNECTED)

    def _server_thread_func(self, address):
        """Server thread function. Attempts to bind to an address and
        listen for incoming connections, in a loop.

        """

        while not self._should_quit:

            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:

                # Timeout for waiting on incoming connections. This
                # can be "large". We aren't doing any message
                # wrangling besides getting these in. Worst case we
                # add latency to shutdown with this.
                sock.settimeout(0.01)

                try:

                    # FXIME: This seems to be for UDP ports?
                    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

                    sock.bind(address)
                    sock.listen()

                except Exception as ex:

                    # FIXME: I wonder if we should do this in the main
                    # thread so we can get the exceptions back up to
                    # the start_server function and up from there.
                    self._set_state(self.SocketState.ERROR, str(ex))
                    break


                self._set_state(self.SocketState.SERVER_LISTENING)

                while not self._should_quit:

                    try:
                        connection, address = sock.accept()

                        new_client = PacketSocket()
                        new_client._start_client_connection_from_server(connection, address)

                        with self._state_lock:
                            self._new_connections_to_server.append(new_client)

                    except TimeoutError:
                        pass

    def _start_client_connection_from_server(self, connection, address):
        """Entrypoint for PacketSocket instances created by servers
        accepting connections.

        """

        assert(not self._worker_thread)
        self._worker_thread = threading.Thread(
            target=self._server_to_client_thread_func,
            args=(connection, address),
            daemon=True)
        self._worker_thread.start()
