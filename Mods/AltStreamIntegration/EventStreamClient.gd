# https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events#event_stream_format
class_name EventStreamClient
extends RefCounted

enum Status { DISCONNECTED, CONNECTING, CONNECTED }

signal connected
signal connection_failed(error: String)
signal disconnected(error: String)

## Message is received. Named events will have `event` set, while
## for data-only messages, `event` will be empty and can be ignored.
signal event_received(event: String, data: String)

var status := Status.DISCONNECTED
var host: String
var endpoint: String

@warning_ignore("shadowed_variable")
func connect_to_host(host: String, endpoint: String) -> void:
	self.host     = host
	self.endpoint = endpoint

	close() # in case we were already connected
	status = Status.CONNECTING
	var err := _http.connect_to_host(host)
	if err: return _on_disconnected("error during connect: " + error_string(err))
	# TODO: Automatically attempt to reconnect?

func close() -> void:
	_on_disconnected()


const NEWLINE := ord("\n")
var _http := HTTPClient.new()
var _request_sent := false
var _buffer: PackedByteArray

func poll() -> void:
	if status == Status.DISCONNECTED: return
	_http.poll() # ignore error, handle via status
	match _http.get_status():
		HTTPClient.STATUS_DISCONNECTED: return _on_disconnected()
		HTTPClient.STATUS_RESOLVING: pass
		HTTPClient.STATUS_CANT_RESOLVE: return _on_disconnected("cant resolve")
		HTTPClient.STATUS_CANT_CONNECT: return _on_disconnected("cant connect")
		HTTPClient.STATUS_CONNECTION_ERROR: return _on_disconnected("connection error")
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR: return _on_disconnected("tls handshake error")

		HTTPClient.STATUS_CONNECTED:
			# After we send our request we should enter `STATUS_REQUESTING` and then stay
			# in `STATUS_BODY` for the remainder of the session, receiving event messages.
			if _request_sent: return _on_disconnected("unexpectedly entered STATUS_CONNECTED again")

			var err := _http.request(HTTPClient.METHOD_GET, endpoint, [ "Accept: text/event-stream" ])
			if err: return _on_disconnected("error during request: " + error_string(err))
			_request_sent = true

		HTTPClient.STATUS_REQUESTING:
			pass

		HTTPClient.STATUS_BODY:
			var code := _http.get_response_code()
			if code != 200: return _on_disconnected("status code: " + str(code))

			# Successfully established an event stream, so consider ourselves connected now!
			if status != Status.CONNECTED: status = Status.CONNECTED; connected.emit()

			var chunk := _http.read_response_body_chunk()
			if chunk.is_empty(): return
			_buffer += chunk

			# Look for a "\n\n" sequence in the buffer.
			var i := _buffer.size() - 1
			while true:
				i = _buffer.rfind(NEWLINE, i) - 1
				if i < 0: return # not found anywhere
				if _buffer[i] == NEWLINE: break

			var message := _buffer.slice(0, i).get_string_from_utf8()
			_buffer = _buffer.slice(i + 2)
			_on_message(message)

func _on_disconnected(error_message := "") -> void:
	if status == Status.DISCONNECTED: return
	var was_connected := (status == Status.CONNECTED)

	status = Status.DISCONNECTED
	_http.close()
	_request_sent = false
	_buffer.clear()

	if was_connected: disconnected.emit(error_message)
	else: connection_failed.emit(error_message)

func _on_message(message: String) -> void:
	var event := ""
	var data  := ""

	for line in message.split("\n"):
		var split := line.split(":", true, 1)
		var field := split[0]
		var value := split[1].trim_prefix(" ") if (split.size() > 1) else ""

		match field:
			"": pass # this is a comment
			"event" : event = value
			"data"  : data += value + "\n"

	if event or data:
		event_received.emit(event, data.trim_suffix("\n"))
