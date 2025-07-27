extends Node
class_name OSCQueryServer

# TODO: Export required?
@export var osc_server : KiriOSCServer
@export var app_name : String
var osc_server_ip : String = "127.0.0.1"
var osc_server_port : int = 9001

signal on_host_info_requested

var http_server : HttpServer
func _ready():
	
	osc_server.change_port_and_ip(osc_server_port, osc_server_ip)
	osc_server.start()
	
	var host_info_router = OSCQueryHostInfoRouter.new()
	host_info_router.query_server = self
	var address_router = OSCQueryAddressRouter.new()
	address_router.query_server = self
	
	http_server = HttpServer.new()
	http_server.port = 61613 # TODO: Make random port. This is advertised on mDNS to apps.
	add_child(http_server)
	http_server.register_router(".*HOST_INFO.*", host_info_router)
	http_server.register_router("/", host_info_router)
	http_server.start()
	
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
		var data = {
			"DESCRIPTION": "",
			"FULL_PATH": "/",
			"ACCESS": 0,
			"TYPE": null,
			"CONTENTS": {
				"/"
			},
			"VALUE": {}
		}
		var host_info_json = JSON.stringify(data)
		response.send(200, host_info_json, "application/json")
