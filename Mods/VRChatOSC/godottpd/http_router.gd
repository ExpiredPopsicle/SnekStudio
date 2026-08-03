## A base class for all HTTP routers
##
## This router handles all the requests that the client sends to the server.
## [br]NOTE: This class is meant to be expanded upon instead of used directly.
## [br]Usage:
## [codeblock]
## class_name MyCustomRouter
## extends HttpRouter
##
## func handle_get(request: HttpRequest, response: HttpResponse) -> void:
##     response.send(200, "Hello World")
## [/codeblock]
class_name HttpRouter
extends RefCounted


## Handle a GET request
## [br]
## [br][param request] - The request from the client
## [br][param response] - The node to send the response back to the client
@warning_ignore("unused_parameter")
func handle_get(request: HttpRequest, response: HttpResponse) -> void:
	response.send(405, "GET not allowed")


## Handle a POST request
## [br]
## [br][param request] - The request from the client
## [br][param response] - The node to send the response back to the client
@warning_ignore("unused_parameter")
func handle_post(request: HttpRequest, response: HttpResponse) -> void:
	response.send(405, "POST not allowed")


## Handle a HEAD request
## [br]
## [br][param request] - The request from the client
## [br][param response] - The node to send the response back to the client
@warning_ignore("unused_parameter")
func handle_head(request: HttpRequest, response: HttpResponse) -> void:
	response.send(405, "HEAD not allowed")


## Handle a PUT request
## [br]
## [br][param request] - The request from the client
## [br][param response] - The node to send the response back to the client
@warning_ignore("unused_parameter")
func handle_put(request: HttpRequest, response: HttpResponse) -> void:
	response.send(405, "PUT not allowed")


## Handle a PATCH request
## [br]
## [br][param request] - The request from the client
## [br][param response] - The node to send the response back to the client
@warning_ignore("unused_parameter")
func handle_patch(request: HttpRequest, response: HttpResponse) -> void:
	response.send(405, "PATCH not allowed")


## Handle a DELETE request
## [br]
## [br][param request] - The request from the client
## [br][param response] - The node to send the response back to the client
@warning_ignore("unused_parameter")
func handle_delete(request: HttpRequest, response: HttpResponse) -> void:
	response.send(405, "DELETE not allowed")


## Handle an OPTIONS request
## [br]
## [br][param request] - The request from the client
## [br][param response] - The node to send the response back to the client
@warning_ignore("unused_parameter")
func handle_options(request: HttpRequest, response: HttpResponse) -> void:
	response.send(405, "OPTIONS not allowed")
