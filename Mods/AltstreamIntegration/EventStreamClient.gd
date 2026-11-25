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
var headers: Dictionary[String, String] = {
	"Accept" = "text/event-stream",
	"User-Agent" = "SnekStudio/" + ProjectSettings.get_setting("application/config/version"),
}

var reconnect := true
var reconnect_attempts := 20
var reconnect_delay_min :=  2.0 # seconds
var reconnect_delay_max := 30.0 # seconds

var is_reconnecting: bool:
	get: return _reconnect_at > 0.0
var reconnection_attempt: int:
	get: return _reconnect_counter
var reconnection_delay: float: ## Seconds until next reconnection attempt.
	get: return maxf(0.0, _reconnect_at - Time.get_ticks_msec() / 1000.0)

@warning_ignore("shadowed_variable")
func connect_to_host(host: String, endpoint: String) -> void:
	self.host     = host
	self.endpoint = endpoint

	close() # in case we were already connected
	status = Status.CONNECTING
	var err := _http.connect_to_host(host)
	if err: return _on_disconnected("error during connect: " + error_string(err))

	_reconnect_at = 0.0
	_reconnect_counter = 0

func close() -> void:
	_on_disconnected()


var _http := HTTPClient.new()
var _request_sent := false
var _buffer: PackedByteArray

var _reconnect_at := 0.0
var _reconnect_counter := 0

func poll() -> void:
	if status == Status.DISCONNECTED: return

	if is_reconnecting and (_http.get_status() == HTTPClient.STATUS_DISCONNECTED):
		if reconnection_delay > 0.0: return # wait before reconnecting
		var err := _http.connect_to_host(host)
		if err: return _on_disconnected("error during reconnect: " + error_string(err))

	_http.poll() # ignore error, handle via status
	match _http.get_status():
		# Clean disconnect by server, but we probably still want to reconnect?
		# If the server wants to reject our connection, it'll send a non-OK status code.
		HTTPClient.STATUS_DISCONNECTED: return _on_disconnected("", true)
		HTTPClient.STATUS_RESOLVING: pass
		HTTPClient.STATUS_CANT_RESOLVE: return _on_disconnected("cant resolve", true)
		HTTPClient.STATUS_CANT_CONNECT: return _on_disconnected("cant connect", true)
		HTTPClient.STATUS_CONNECTION_ERROR: return _on_disconnected("connection error", true)
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR: return _on_disconnected("tls handshake error", true)

		HTTPClient.STATUS_CONNECTED:
			# After we send our request we should enter `STATUS_REQUESTING` and then stay
			# in `STATUS_BODY` for the remainder of the session, receiving event messages.
			if _request_sent: return _on_disconnected("unexpectedly entered STATUS_CONNECTED again")

			var headers_list: PackedStringArray
			for name in headers: headers_list.append(name + ": " + headers[name])
			var err := _http.request(HTTPClient.METHOD_GET, endpoint, headers_list)
			if err: return _on_disconnected("error during request: " + error_string(err))
			_request_sent = true

		HTTPClient.STATUS_REQUESTING:
			pass

		HTTPClient.STATUS_BODY:
			var code := _http.get_response_code()
			if code != 200: return _on_disconnected("status code: " + str(code)) # don't attempt to reconnect?

			# Successfully established an event stream, so consider ourselves connected now!
			if status != Status.CONNECTED:
				status = Status.CONNECTED
				connected.emit() # at this point, `is_reconnecting` may still return true
				_reconnect_at = 0.0
				_reconnect_counter = 0

			var chunk := _http.read_response_body_chunk()
			if chunk.is_empty(): return
			_buffer += chunk

			while true:
				var i := _find_double_newline(_buffer)
				if i == -1: return
				var message := _buffer.slice(0, i).get_string_from_utf8()
				_buffer = _buffer.slice(i + 2)
				_process_message(message)

func _on_disconnected(error_message := "", attempt_reconnect := false) -> void:
	if status == Status.DISCONNECTED: return
	var was_connected := (status == Status.CONNECTED)

	_http.close()
	_request_sent = false
	_buffer.clear()

	if attempt_reconnect and (_reconnect_counter < reconnect_attempts):
		status = Status.CONNECTING
		var current_time   := Time.get_ticks_msec() / 1000.0
		var delay_uncapped := reconnect_delay_min * pow(2, _reconnect_counter)
		var delay_capped   := minf(reconnect_delay_max, delay_uncapped)
		_reconnect_at = current_time + delay_capped
		_reconnect_counter += 1
	else:
		status = Status.DISCONNECTED
		_reconnect_at = 0.0
		_reconnect_counter = 0

	if was_connected: disconnected.emit(error_message)
	else: connection_failed.emit(error_message)

func _process_message(message: String) -> void:
	var event := ""
	var data  := ""

	for line in message.split("\n"):
		assert(not line.is_empty())
		var split := line.split(":", true, 1)
		var field := split[0]
		var value := split[1].trim_prefix(" ") if (split.size() > 1) else ""

		match field:
			""      : pass # this is a comment
			"event" : event = value
			"data"  : data += value + "\n"

	if event or data:
		event_received.emit(event, data.trim_suffix("\n"))

const NEWLINE := ord("\n")
static func _find_double_newline(buffer: PackedByteArray) -> int:
	var i := 0
	while true:
		i = buffer.find(NEWLINE, i)
		if (i == -1) or (i == buffer.size() - 1): break
		if buffer[i + 1] == NEWLINE: return i
		i += 2
	return -1
