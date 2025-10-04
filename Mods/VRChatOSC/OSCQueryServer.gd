extends Node
class_name OSCQueryServer

# TODO: Export required?
@export var osc_server : KiriOSCServer
@export var app_name : String
@export var osc_paths : Dictionary = {}
@export var osc_server_ip : String = "127.0.0.1"
@export var osc_server_port : int = 9001
@export var osc_query_server_port : int = 61613

var running : bool = false
signal on_host_info_requested
signal on_root_requested
signal on_osc_server_message_received(address : String, args)

@export var http_server : HttpServer
func _ready():
	start()

func start() -> void:
	running = true
	osc_server.change_port_and_ip(osc_server_port, osc_server_ip)
	if len(osc_server.message_received.get_connections()) == 0:
		osc_server.message_received.connect(_message_received)
	osc_server.start_server()

	var host_info_router = OSCQueryHostInfoRouter.new()
	host_info_router.query_server = self
	var address_router = OSCQueryAddressRouter.new()
	address_router.query_server = self

	# Add if not already added.
	if http_server == null:
		http_server = HttpServer.new()
		http_server.bind_address = "127.0.0.1"
		http_server.port = osc_query_server_port
		add_child(http_server)
		http_server.register_router("^/HOST_INFO", host_info_router)
		http_server.register_router("^/", address_router)

	http_server.start()

func stop() -> void:
	http_server.stop()
	osc_server.stop_server()
	running = false

func set_osc_server_port(new_port : int) -> void:
	if new_port != osc_server_port:
		osc_server_port = new_port
		stop()
		start()
	else:
		osc_server_port = new_port
		
func set_osc_query_server_port(new_port : int) -> void:
	if new_port != osc_query_server_port:
		osc_query_server_port = new_port
		stop()
		start()
	else:
		osc_query_server_port = new_port
		
func _message_received(address : String, args) -> void:
	on_osc_server_message_received.emit(address, args)
	
class OSCQueryHostInfoRouter:
	extends HttpRouter
	var query_server : OSCQueryServer
	
	func handle_get(request: HttpRequest, response: HttpResponse):
		query_server.on_host_info_requested.emit()
		var data = {
			"NAME": query_server.app_name,
			"OSC_IP": query_server.osc_server_ip,
			"OSC_PORT": query_server.osc_server_port,
			"OSC_TRANSPORT": "UDP",
			"EXTENSIONS": {
				"ACCESS": true,
				"CLIPMODE": false,
				"RANGE": true,
				"TYPE": true,
				"VALUE": true
			}
		}
		var host_info_json = JSON.stringify(data)
		response.send(200, host_info_json, "application/json")

class OSCQueryAddressRouter:
	extends HttpRouter
	var query_server : OSCQueryServer
	
	func handle_get(request: HttpRequest, response: HttpResponse):
		query_server.on_root_requested.emit()
		var data = {
			"DESCRIPTION": "Root",
			"FULL_PATH": "/",
			"ACCESS": 0,
			"CONTENTS": query_server.osc_paths,
		}
		var root_json = JSON.stringify(data)
		response.send(200, root_json, "application/json")
