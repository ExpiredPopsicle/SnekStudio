## An HTTP request received by the server
class_name HttpRequest
extends RefCounted


## A dictionary of the headers of the request
var headers: Dictionary

## The received raw body
var body: String

## A match object of the regular expression that matches the path
var query_match: RegExMatch

## The path that matches the router path
var path: String

## The method
var method: String

## A dictionary of request (aka. routing) parameters
var parameters: Dictionary

## A dictionary of request query parameters
var query: Dictionary

## Returns the body object based on the raw body and the content type of the request
func get_body_parsed() -> Variant:
	var content_type: String = ""

	if(headers.has("content-type")):
		content_type = headers["content-type"]
	elif(headers.has("Content-Type")):
		content_type = headers["Content-Type"]

	if(content_type == "application/json"):
		return JSON.parse_string(body)

	if(content_type == "application/x-www-form-urlencoded"):
		var data = {}

		for body_part in  body.split("&"):
			var key_and_value = body_part.split("=")
			data[key_and_value[0]] = key_and_value[1]

		return data

	# Not supported contenty type parsing... for now
	return null

## Override `str()` method, automatically called in `print()` function
func _to_string() -> String:
	return JSON.stringify({headers=headers, method=method, path=path})
