extends Node

var channel_id : String
var channel_info : Dictionary


func _ready():
	await OAuth2.token_recieved
	get_channel_info(OAuth2.token)


func get_channel_info(token):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var request_url := "https://www.patreon.com/api/oauth2/v2/identity?include=memberships.campaign&fields%5Bmember%5D=patron_status"
	var headers := [
		"Authorization: Bearer %s" % token,
		"Accept: application/json"
	]
	
	var error = http_request.request(request_url, PackedStringArray(headers))
	if error != OK:
		push_error("ERROR OCCURED @ FUNC get_LiveBroadcastResource() : %s" % error)
		http_request.queue_free()
	
	var response = await http_request.request_completed
	var test_json_conv = JSON.new()
	test_json_conv.parse(response[3].get_string_from_utf8())
	var response_body = test_json_conv.get_data()
	
	return response_body
