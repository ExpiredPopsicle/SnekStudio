#!/usr/bin/python3

import importlib.util
import sys
import argparse
import time
import json
import traceback
import os

import KiriPacketSocket

packet_socket = None

def exception_to_string(e):
    exception_string_generator = traceback.TracebackException.from_exception(e)
    exception_string = "".join(exception_string_generator.format())
    return exception_string


# This whole thing being in a try/except is just so we can catch
# errors and see them before the terminal window closes.
try:
# if True:

    # Parse arguments
    arg_parser = argparse.ArgumentParser(
        prog="KiriPythonRPCWrapper",
        description="Wrapper for Python modules to RPCs from Godot.",
        epilog="")

    arg_parser.add_argument("--script", type=str, required=True)
    arg_parser.add_argument("--port", type=int, required=True)

    args = arg_parser.parse_args()

    # Connect to server.
    packet_socket =  KiriPacketSocket.PacketSocket()
    packet_socket.start_client(("127.0.0.1", args.port))
    while packet_socket.get_state() == packet_socket.SocketState.CONNECTING:
        time.sleep(0.001)

    if packet_socket.get_state() != packet_socket.SocketState.CONNECTED:
        packet_socket.stop()
        raise Exception("Failed to connect to RPC host.")


    # module_path = "../KiriPacketSocket/__init__.py"
    # module_name = "KiriPacketSocket"

    module_path = args.script
    module_name = ""

    # Make it so the script can load local modules.
    sys.path.append(os.path.dirname(args.script))


    # Attempt to load the module.
    module_spec = importlib.util.spec_from_file_location(
        module_name, module_path)
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)

    # This will be all the functions we find in the module that don't
    # start with "_".
    known_entrypoints = {}

    # Scan the module for "public" functions.
    for entrypoint in dir(module):

        # Skip anything starting with "_". Probably not meant to be
        # exposed.
        if entrypoint.startswith("_"):
            continue

        attr = getattr(module, entrypoint)

        # if hasattr(attr, "__call__"):
        if callable(attr):
            known_entrypoints[entrypoint] = attr

    print("Starting packet processing.")

    def send_error_response(code, message, request_id):
        ret_dict = {
            "jsonrpc" : "2.0",
            "error" : {
                "code" : code,
                "message" : message
            },
            "id" : request_id
        }
        ret_dict_json = json.dumps(ret_dict)
        packet_socket.send_packet(ret_dict_json.encode("utf-8"))

        # Also spam the console.
        try:
            sys.stderr.write("RPC Error: " + message + "\n")
        except Exception as e:
            sys.stderr.write("RPC Error: Unknown. Unable to decode error.\n")

    def send_response(result, request_id):
        try:
            ret_dict = {
                "jsonrpc" : "2.0",
                "result" : ret,
                "id" : request_id
            }
            ret_dict_json = json.dumps(ret_dict)
            packet_socket.send_packet(ret_dict_json.encode("utf-8"))
        except Exception as e:
            send_error_response(-32603, "Error sending result: " + str(e), request_id)

    # Start processing packets.
    while True:

        # Shutdown when we lose connection to host.
        if packet_socket.get_state() != packet_socket.SocketState.CONNECTED:
            packet_socket.stop()
            raise Exception("Disconnected from RPC host.")

        next_packet = packet_socket.get_next_packet()
        while next_packet:
            this_packet = next_packet
            next_packet = packet_socket.get_next_packet()

            # FIXME: Handle batches.

            # Parse the incoming dict.
            try:
                request_dict_json = this_packet.decode("utf-8")
                request_dict = json.loads(request_dict_json)
            except Exception as e:
                send_error_response(-32700, "Error parsing packet: " + str(e), request_id)
                continue

            # Make sure all the fields are there.
            try:
                method = request_dict["method"]
                func_args = request_dict["params"]
                request_id = request_dict["id"]
            except Exception as e:
                send_error_response(-32602, "Missing field: " + str(e), request_id)
                continue

            # Make sure the method is something we scanned earlier.
            try:
                func = known_entrypoints[method]
            except Exception as e:
                send_error_response(-32601, "Method not found: " + str(e), request_id)
                continue

            # Call the dang function.
            try:
                ret = func(*func_args)
            except Exception as e:
                send_error_response(
                    -32603,
                    "Call failed:\n" + exception_to_string(e),
                    request_id)
                continue

            send_response(ret, request_id)

        time.sleep(0.0001)

except Exception as e:

    # FIXME: Do we need the extra exception handler inside the
    # exception handler?
    try:
        if packet_socket != None:

            exception_string = exception_to_string(e)

            error_report_dict = {
                "kirijsonrpcerror" : "Exception occurred:\n" + exception_string
            }
            error_report_dict_json = json.dumps(error_report_dict)
            packet_socket.send_packet(error_report_dict_json.encode("utf-8"))

            # Wait until the error is sent.
            while packet_socket.get_send_queue_size():
                if packet_socket.get_state() != packet_socket.SocketState.CONNECTED:
                    print("Disconnected. Can't send error state.")
                    break

                time.sleep(0.001)

    except Exception as e2:
        print(e2)

    # FIXME: Do we really need this now that we have "proper" error
    # handling that sends stuff back to the Godot app?
    time.sleep(1)
    raise e
