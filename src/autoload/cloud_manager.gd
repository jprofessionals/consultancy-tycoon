extends Node

const AUTH_PATH = "user://cloud_auth.json"
const DEFAULT_BASE_URL = "https://tycoon.jpro.dev"

var base_url: String = DEFAULT_BASE_URL
var player_id: String = ""
var auth_token: String = ""
var passphrase: String = ""
var _syncing: bool = false

signal player_created(player_id: String, passphrase: String)
signal player_recovered(player_id: String)
signal sync_completed(success: bool)
signal leaderboard_fetched(data: Dictionary)

func _ready():
	_load_auth()

# ── Auth persistence ──

func _load_auth():
	if not FileAccess.file_exists(AUTH_PATH):
		return
	var file = FileAccess.open(AUTH_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		player_id = str(json.data.get("player_id", ""))
		auth_token = str(json.data.get("auth_token", ""))
		passphrase = str(json.data.get("passphrase", ""))

func _save_auth():
	var data = {
		"player_id": player_id,
		"auth_token": auth_token,
		"passphrase": passphrase,
	}
	var file = FileAccess.open(AUTH_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if(window.Module&&Module.FS&&Module.FS.syncfs)Module.FS.syncfs(false,function(e){});")

func is_authenticated() -> bool:
	return player_id != "" and auth_token != ""

# ── Player creation ──

func create_player(display_name: String) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"display_name": display_name})
	http.request(base_url + "/api/players", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	var result = await http.request_completed
	http.queue_free()
	var response_code = result[1]
	if response_code == 200 or response_code == 201:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			player_id = str(json.data.get("id", ""))
			auth_token = str(json.data.get("token", ""))
			passphrase = str(json.data.get("passphrase", ""))
			_save_auth()
			player_created.emit(player_id, passphrase)

func recover_player(input_passphrase: String) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"passphrase": input_passphrase})
	http.request(base_url + "/api/players/recover", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	var result = await http.request_completed
	http.queue_free()
	var response_code = result[1]
	if response_code == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			player_id = str(json.data.get("id", ""))
			auth_token = str(json.data.get("token", ""))
			_save_auth()
			player_recovered.emit(player_id)

# ── Score submission ──

func submit_scores(components: Dictionary) -> void:
	if not is_authenticated():
		return
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify(components)
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/scores", headers, HTTPClient.METHOD_PUT, body)
	var result = await http.request_completed
	http.queue_free()

# ── Cloud save ──

func upload_save(save_data: Dictionary) -> void:
	if not is_authenticated():
		return
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"save_data": save_data, "version": 1})
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/saves", headers, HTTPClient.METHOD_PUT, body)
	var result = await http.request_completed
	http.queue_free()

func download_save() -> Dictionary:
	if not is_authenticated():
		return {}
	var http = HTTPRequest.new()
	add_child(http)
	var headers = ["Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/saves/me", headers, HTTPClient.METHOD_GET)
	var result = await http.request_completed
	http.queue_free()
	if result[1] == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			return json.data
	return {}

# ── Leaderboard ──

func fetch_leaderboard() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	var headers = []
	if is_authenticated():
		headers = ["Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/leaderboard", headers, HTTPClient.METHOD_GET)
	var result = await http.request_completed
	http.queue_free()
	if result[1] == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			leaderboard_fetched.emit(json.data)

# ── Profile update ──

func update_display_name(new_name: String) -> void:
	if not is_authenticated():
		return
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"display_name": new_name})
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/players/me", headers, HTTPClient.METHOD_PATCH, body)
	var result = await http.request_completed
	http.queue_free()

func set_leaderboard_visibility(visible: bool) -> void:
	if not is_authenticated():
		return
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"show_on_leaderboard": visible})
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/players/me", headers, HTTPClient.METHOD_PATCH, body)
	var result = await http.request_completed
	http.queue_free()

# ── Account upgrade ──

func register_account(username: String, password: String) -> bool:
	if not is_authenticated():
		return false
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"username": username, "password": password})
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + auth_token]
	http.request(base_url + "/api/players/register", headers, HTTPClient.METHOD_POST, body)
	var result = await http.request_completed
	http.queue_free()
	return result[1] == 200

func login(username: String, password: String) -> bool:
	var http = HTTPRequest.new()
	add_child(http)
	var body = JSON.stringify({"username": username, "password": password})
	http.request(base_url + "/api/players/login", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	var result = await http.request_completed
	http.queue_free()
	if result[1] == 200:
		var json = JSON.new()
		if json.parse(result[3].get_string_from_utf8()) == OK:
			player_id = str(json.data.get("id", ""))
			auth_token = str(json.data.get("token", ""))
			_save_auth()
			return true
	return false
