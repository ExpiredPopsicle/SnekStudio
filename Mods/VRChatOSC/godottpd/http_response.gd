## A response object useful to send out responses
class_name HttpResponse
extends RefCounted


## The client currently talking to the server
var client: StreamPeer

## The server identifier to use on responses [GodotTPD]
var server_identifier: String = "GodotTPD"

## A dictionary of headers
## [br] Headers can be set using the `set(name, value)` function
var headers: Dictionary = {}

## An array of cookies
## [br] Cookies can be set using the `cookie(name, value, options)` function
## [br] Cookies will be automatically sent via "Set-Cookie" headers to clients
var cookies: Array = []

## Origins allowed to call this resource
var access_control_origin = "*"

## Comma separed methods for the access control
var access_control_allowed_methods = "POST, GET, OPTIONS"

## Comma separed headers for the access control
var access_control_allowed_headers = "content-type"

## Send out a raw (Bytes) response to the client
## [br]Useful to send files faster or raw data which will be converted by the client
## [br][param status] - The HTTP Status code to send
## [br][param data] - The body data to send
## [br][param content_type] - The type of content to send.
func send_raw(status_code: int, data: PackedByteArray = PackedByteArray([]), content_type: String = "application/octet-stream", extra_header: String = "") -> void:
	client.put_data(("HTTP/1.1 %d %s\r\n" % [status_code, _match_status_code(status_code)]).to_ascii_buffer())
	client.put_data(("Server: %s\r\n" % server_identifier).to_ascii_buffer())
	for header in headers.keys():
		client.put_data(("%s: %s\r\n" % [header, headers[header]]).to_ascii_buffer())
	for cookie in cookies:
		client.put_data(("Set-Cookie: %s\r\n" % cookie).to_ascii_buffer())
	client.put_data(("Content-Length: %d\r\n" % data.size()).to_ascii_buffer())
	client.put_data("Connection: close\r\n".to_ascii_buffer())
	client.put_data(("Access-Control-Allow-Origin: %s\r\n" % access_control_origin).to_ascii_buffer())
	client.put_data(("Access-Control-Allow-Methods: %s\r\n" % access_control_allowed_methods).to_ascii_buffer())
	client.put_data(("Access-Control-Allow-Headers: %s\r\n" % access_control_allowed_headers).to_ascii_buffer())
	client.put_data("Accept-Ranges: bytes\r\n".to_ascii_buffer())
	client.put_data(extra_header.to_ascii_buffer())
	client.put_data(("Content-Type: %s\r\n\r\n" % content_type).to_ascii_buffer())
	
	client.put_data(data)
	
## For sending parts of data
## [br]TODO: http_file_router.gd - use this to send small parts of large files at a time to avoid smashing the ram of the server
## [br]TODO: This will probably be used for range header?
func send_partial(status_code: int, data: PackedByteArray = PackedByteArray([]), content_type: String = "application/octet-stream", extra_header: String = "") -> void:
	client.put_data(data)

## Send out a response to the client
## [br]
## [br][param status_code] - The HTTP status code to send
## [br][param data] - The body to send
## [br][param content_type] - The type of the content to send
func send(status_code: int, data: String = "", content_type = "text/html") -> void:
	send_raw(status_code, data.to_ascii_buffer(), content_type)

## Send out a JSON response to the client
## [br] This function will internally call the [method send]
## [br]
## [br][param status_code] - The HTTP status code to send
## [br][param data] - The body to send
func json(status_code: int, data) -> void:
	send(status_code, JSON.stringify(data), "application/json")


## Sets the response’s header "field" to "value"
## [br]
## [br][param field] - The name of the header. i.e. [code]Accept-Type[/code]
## [br][param value] - The value of this header. i.e. [code]application/json[/code]
func set(field: StringName, value: Variant) -> void:
	headers[field] = value


## Sets cookie "name" to "value"
## [br]
## [br][param name] - The name of the cookie. i.e. [code]user-id[/code]
## [br][param value] - The value of this cookie. i.e. [code]abcdef[/code]
## [br][param options] - A Dictionary of [url=https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#attributes]cookie attributes[/url]
## for this specific cokkie in the [code]{ "secure" : "true"}[/code] format.
func cookie(name: String, value: String, options: Dictionary = {}) -> void:
	var cookie: String = name+"="+value
	if options.has("domain"): cookie+="; Domain="+options["domain"]
	if options.has("max-age"): cookie+="; Max-Age="+options["max-age"]
	if options.has("expires"): cookie+="; Expires="+options["expires"]
	if options.has("path"): cookie+="; Path="+options["path"]
	if options.has("secure"): cookie+="; Secure="+options["secure"]
	if options.has("httpOnly"): cookie+="; HttpOnly="+options["httpOnly"]
	if options.has("sameSite"):
		match (options["sameSite"]):
			true: cookie += "; SameSite=Strict"
			"lax": cookie += "; SameSite=Lax"
			"strict": cookie += "; SameSite=Strict"
			"none": cookie += "; SameSite=None"
			_: pass
	cookies.append(cookie)


## Automatically matches a "status_code" to an RFC 7231 compliant "status_text"
## [br]
## [br][param code] - The HTTP Status code to be matched
## [br]Returns: the matched [code]status_text[/code]
func _match_status_code(code: int) -> String:
	var text: String = "OK"
	match(code):
		# 1xx - Informational Responses
		100: text="Continue"
		101: text="Switching protocols"
		102: text="Processing"
		103: text="Early Hints"
		# 2xx - Successful Responses
		200: text="OK"
		201: text="Created"
		202: text="Accepted"
		203: text="Non-Authoritative Information"
		204: text="No Content"
		205: text="Reset Content"
		206: text="Partial Content"
		207: text="Multi-Status"
		208: text="Already Reported"
		226: text="IM Used"
		# 3xx - Redirection Messages
		300: text="Multiple Choices"
		301: text="Moved Permanently"
		302: text="Found (Previously 'Moved Temporarily')"
		303: text="See Other"
		304: text="Not Modified"
		305: text="Use Proxy"
		306: text="Switch Proxy"
		307: text="Temporary Redirect"
		308: text="Permanent Redirect"
		# 4xx - Client Error Responses
		400: text="Bad Request"
		401: text="Unauthorized"
		402: text="Payment Required"
		403: text="Forbidden"
		404: text="Not Found"
		405: text="Method Not Allowed"
		406: text="Not Acceptable"
		407: text="Proxy Authentication Required"
		408: text="Request Timeout"
		409: text="Conflict"
		410: text="Gone"
		411: text="Length Required"
		412: text="Precondition Failed"
		413: text="Payload Too Large"
		414: text="URI Too Long"
		415: text="Unsupported Media Type"
		416: text="Range Not Satisfiable"
		417: text="Expectation Failed"
		418: text="I'm a Teapot"
		421: text="Misdirected Request"
		422: text="Unprocessable Entity"
		423: text="Locked"
		424: text="Failed Dependency"
		425: text="Too Early"
		426: text="Upgrade Required"
		428: text="Precondition Required"
		429: text="Too Many Requests"
		431: text="Request Header Fields Too Large"
		451: text="Unavailable For Legal Reasons"
		# 5xx - Server Error Responses
		500: text="Internal Server Error"
		501: text="Not Implemented"
		502: text="Bad Gateway"
		503: text="Service Unavailable"
		504: text="Gateway Timeout"
		505: text="HTTP Version Not Supported"
		506: text="Variant Also Negotiates"
		507: text="Insufficient Storage"
		508: text="Loop Detected"
		510: text="Not Extended"
		511: text="Network Authentication Required"
	return text
