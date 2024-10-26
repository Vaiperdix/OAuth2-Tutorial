extends Control


const client_secret := ""
const client_ID := ""
const auth_server := "https://www.patreon.com/oauth2/authorize"
const token_req := "https://www.patreon.com/api/oauth2/token"

const PORT := 31419
const BINDING := "127.0.0.1"
var redirect_server := TCPServer.new() # 
var redirect_uri := "http://%s:%s" % [BINDING, PORT]
var token
var refresh_token

signal token_recieved


func _ready():
	set_process(false)


func authorize():
	#load_tokens()
	
	if !await is_token_valid():
		if !await refresh_tokens():
			get_auth_code()


func _process(_delta):
	if redirect_server.is_connection_available():
		var connection = redirect_server.take_connection()
		var request = connection.get_string(connection.get_available_bytes())
		if request:
			set_process(false)
			var auth_code = request.split("&scope")[0].split("=")[1]
			get_token_from_auth(auth_code)
			
			connection.put_data(("HTTP/1.1 %d\r\n" % 200).to_ascii_buffer())
			connection.put_data(load_HTML("res://OAuth2/display_page.html").to_ascii_buffer())
			redirect_server.stop()

func get_auth_code():
	set_process(true)
# warning-ignore:unused_variable
	var redir_err = redirect_server.listen(PORT, BINDING)
	
	var body_parts = [
		"response_type=code",
		"client_id=%s" % client_ID,
		"redirect_uri=%s" % redirect_uri,
		"scope=identity%20identity.memberships",
		"allow_signup=false",
	]
	var url = auth_server + "?" + "&".join(PackedStringArray(body_parts))
	print(redirect_uri)
# warning-ignore:return_value_discarded
	OS.shell_open(url) # Opens window for user authentication


func get_token_from_auth(auth_code):
	
	var headers = [
		"Content-Type: application/x-www-form-urlencoded",
		"accept: application/json"
	]
	headers = PackedStringArray(headers)
	
	var body_parts = [
		"code=%s" % auth_code, 
		"client_id=%s" % client_ID,
		"client_secret=%s" % client_secret,
		"redirect_uri=%s" % redirect_uri,
		"grant_type=authorization_code"
	]
	
	var body = "&".join(PackedStringArray(body_parts))
	
# warning-ignore:return_value_discarded
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var error = http_request.request(token_req, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred in the HTTP request with ERR Code: %s" % error)
	
	var response = await http_request.request_completed
	var test_json_conv = JSON.new()
	test_json_conv.parse(response[3].get_string_from_utf8())
	var response_body = test_json_conv.get_data()

	token = response_body["access_token"]
	refresh_token = response_body["refresh_token"]
	
	#save_tokens()
	
	get_channel_info(token)
	emit_signal("token_recieved")

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
	
	print(response_body)

func refresh_tokens():
	print("refreshing")
	var headers = [
		"Content-Type: application/x-www-form-urlencoded"
	]
	
	var body_parts = [
		"client_id=%s" % client_ID,
		"client_secret=%s" % client_secret,
		"refresh_token=%s" % refresh_token,
		"grant_type=refresh_token"
	]
	var body = "&".join(PackedStringArray(body_parts))
	
# warning-ignore:return_value_discarded
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var error = http_request.request(token_req, headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		push_error("An error occurred in the HTTP request with ERR Code: %s" % error)
	
	var response = await http_request.request_completed
	
	var test_json_conv = JSON.new()
	test_json_conv.parse(response[3].get_string_from_utf8())
	var response_body = test_json_conv.get_data()
	
	if response_body.get("access_token"):
		token = response_body["access_token"]
		#save_tokens()
		print("token refreshed")
		emit_signal("token_recieved")
		return true
	else:
		return false


func is_token_valid() -> bool:
	if !token:
		await get_tree().create_timer(0.001).timeout
		return false
	
	var headers = [
		"Content-Type: application/x-www-form-urlencoded"
	]
	
	var body = "access_token=%s" % token
# warning-ignore:return_value_discarded
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var error = http_request.request(token_req + "info", headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred in the HTTP request with ERR Code: %s" % error)
	
	var response = await http_request.request_completed
	
	var test_json_conv = JSON.new()
	test_json_conv.parse(response[3].get_string_from_utf8())
	var expiration = test_json_conv.get_data()
	
	if expiration and int(expiration) > 0:
		print(expiration)
		print("token is valid")
		emit_signal("token_recieved")
		return true
	else:
		return false


# SAVE/LOAD
const SAVE_DIR = 'user://token/'
var save_path = SAVE_DIR + 'token.dat'


func save_tokens():
	var createDir = DirAccess.make_dir_absolute(SAVE_DIR)
	var dir = DirAccess.open(SAVE_DIR)
	if !dir:
		dir.make_dir_recursive(SAVE_DIR)
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	var error = file.open_encrypted_with_pass(save_path, FileAccess.WRITE, 'abigail')
	if error != null:
		var tokens = {
			"token" : token,
			"refresh_token" : refresh_token
		}
		file.store_var(tokens)
		file.close()


func load_tokens():
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var error = file.open_encrypted_with_pass(save_path, FileAccess.READ, 'abigail')
		if error != null:
			var tokens = file.get_var()
			token = tokens.get("token")
			refresh_token = tokens.get("refresh_token")
			file.close()
			print("token loaded successfully")


func load_HTML(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		file.open(path, FileAccess.READ)
		var HTML = file.get_as_text().replace("    ", "\t").insert(0, "\n")
		file.close()
		return HTML
