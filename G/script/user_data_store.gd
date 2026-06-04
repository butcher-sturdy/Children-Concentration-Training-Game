extends RefCounted
class_name UserDataStore

const PROJECT_DATA_FILE_PATH: String = "res://data/users.json"
const SAVE_FILE_PATH: String = "user://users.json"
const DEFAULT_FOCUS_BASELINE: float = 50.0

var users: Dictionary = {}
var current_username: String = ""

func _init() -> void:
	load_users()

func load_users() -> bool:
	users.clear()

	var raw_content: String = _read_text(SAVE_FILE_PATH)
	if raw_content.is_empty():
		raw_content = _read_text(PROJECT_DATA_FILE_PATH)

	if raw_content.is_empty():
		return save_users()

	var parsed: Variant = JSON.parse_string(raw_content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("User data is not valid JSON. A fresh user data file will be written.")
		users.clear()
		return save_users()

	var parsed_users: Variant = parsed.get("users", {})
	if typeof(parsed_users) != TYPE_DICTIONARY:
		push_warning("User data does not contain a users dictionary. A fresh user data file will be written.")
		users.clear()
		return save_users()

	users = parsed_users as Dictionary
	_normalize_loaded_users()
	return save_users()

func save_users() -> bool:
	var data: Dictionary = {
		"schema_version": 1,
		"users": users
	}
	var json_text: String = JSON.stringify(data, "\t")
	var saved_runtime_file: bool = _write_text(SAVE_FILE_PATH, json_text, true)

	# Keep the project data file visible while developing in the editor.
	_write_text(PROJECT_DATA_FILE_PATH, json_text, false)
	return saved_runtime_file

func get_save_file_path() -> String:
	return ProjectSettings.globalize_path(SAVE_FILE_PATH)

func get_project_data_file_path() -> String:
	return ProjectSettings.globalize_path(PROJECT_DATA_FILE_PATH)

func has_user(username: String) -> bool:
	return users.has(username.strip_edges())

func validate_login(username: String, password: String) -> bool:
	var clean_username: String = username.strip_edges()
	if not users.has(clean_username):
		return false

	var user: Dictionary = users[clean_username] as Dictionary
	return str(user.get("password", "")) == password

func set_current_user(username: String) -> bool:
	var clean_username: String = username.strip_edges()
	if not users.has(clean_username):
		return false

	current_username = clean_username
	return true

func create_user(username: String, password: String, focus_baseline: float = DEFAULT_FOCUS_BASELINE) -> Dictionary:
	var clean_username: String = username.strip_edges()
	if clean_username.is_empty():
		return {"ok": false, "message": "用户名不能为空"}
	if password.is_empty():
		return {"ok": false, "message": "密码不能为空"}
	if users.has(clean_username):
		return {"ok": false, "message": "用户已存在"}

	users[clean_username] = _create_empty_user(clean_username, password, focus_baseline)
	save_users()
	current_username = clean_username
	return {"ok": true, "message": "用户已创建"}

func get_user(username: String = "") -> Dictionary:
	var target_username: String = _resolve_username(username)
	if target_username.is_empty() or not users.has(target_username):
		return {}

	var user: Dictionary = users[target_username] as Dictionary
	return user.duplicate(true)

func set_focus_baseline(value: float, username: String = "") -> bool:
	var target_username: String = _resolve_username(username)
	if target_username.is_empty() or not users.has(target_username):
		return false

	var user: Dictionary = users[target_username] as Dictionary
	user["focus_baseline"] = clampf(value, 0.0, 100.0)
	users[target_username] = user
	return save_users()

func record_level_success(level_id: String, attempts: int, username: String = "") -> bool:
	var target_username: String = _resolve_username(username)
	if target_username.is_empty() or level_id.strip_edges().is_empty() or not users.has(target_username):
		return false

	var user: Dictionary = users[target_username] as Dictionary
	var level_success_attempts: Dictionary = {}
	var saved_attempts: Variant = user.get("level_success_attempts", {})
	if typeof(saved_attempts) == TYPE_DICTIONARY:
		level_success_attempts = saved_attempts as Dictionary
	level_success_attempts[level_id.strip_edges()] = max(attempts, 1)
	user["level_success_attempts"] = level_success_attempts
	users[target_username] = user
	return save_users()

func add_play_time(seconds: float, username: String = "") -> bool:
	var target_username: String = _resolve_username(username)
	if target_username.is_empty() or not users.has(target_username):
		return false

	var user: Dictionary = users[target_username] as Dictionary
	var current_total: float = float(user.get("total_play_time_seconds", 0.0))
	user["total_play_time_seconds"] = max(current_total + seconds, 0.0)
	users[target_username] = user
	return save_users()

func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""

	var content: String = file.get_as_text()
	file.close()
	return content

func _write_text(path: String, content: String, report_error: bool) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		if report_error:
			push_error("Could not open user data file: %s" % path)
		return false

	file.store_string(content)
	file.close()
	return true

func _normalize_loaded_users() -> void:
	var normalized_users: Dictionary = {}
	for username in users.keys():
		var clean_username: String = str(username).strip_edges()
		if clean_username.is_empty():
			continue

		var user: Dictionary = {}
		if typeof(users[username]) == TYPE_DICTIONARY:
			user = users[username] as Dictionary
		if not user.has("username"):
			user["username"] = clean_username
		if not user.has("password"):
			user["password"] = ""
		if not user.has("focus_baseline"):
			user["focus_baseline"] = DEFAULT_FOCUS_BASELINE
		if not user.has("level_success_attempts") or typeof(user["level_success_attempts"]) != TYPE_DICTIONARY:
			user["level_success_attempts"] = {}
		if not user.has("total_play_time_seconds"):
			user["total_play_time_seconds"] = 0.0

		normalized_users[clean_username] = user

	users = normalized_users

func _create_empty_user(username: String, password: String, focus_baseline: float) -> Dictionary:
	return {
		"username": username,
		"password": password,
		"focus_baseline": clampf(focus_baseline, 0.0, 100.0),
		"level_success_attempts": {},
		"total_play_time_seconds": 0.0
	}

func _resolve_username(username: String) -> String:
	var clean_username: String = username.strip_edges()
	if clean_username.is_empty():
		return current_username
	return clean_username
