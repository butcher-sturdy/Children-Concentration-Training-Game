extends RefCounted
class_name UserDataStore

const PROJECT_DATA_FILE_PATH: String = "res://data/users.json"
const SAVE_FILE_PATH: String = "user://users.json"
const DEFAULT_FOCUS_BASELINE: float = 50.0
const DEBUG_USERNAME := "debug"
const DEBUG_PASSWORD := "debug"

const DEBUG_UNLOCKED_LEVELS: Array[String] = [
	"res://main_scene/bridgebuildgrass1.tscn",
	"res://main_scene/bridgebuildgrass2.tscn",
	"res://main_scene/bridgebuildgrass3.tscn",
	"res://main_scene/bridgebuildgrass4.tscn",
	"res://main_scene/bridgebuildgrass5.tscn",
	"res://main_scene/bridgebuildgrass6.tscn",
	"res://main_scene/bridgebuildgrass7.tscn",
	"res://main_scene/bridgebuildgrass8.tscn",
	"res://main_scene/bridgebuildgrass9.tscn",
	"res://main_scene/bridgebuildgrass10.tscn",
	"res://main_scene/bridgebuildsnow1.tscn",
	"res://main_scene/bridgebuildsnow2.tscn",
	"res://main_scene/bridgebuildsnow3.tscn",
	"res://main_scene/bridgebuildsnow4.tscn",
	"res://main_scene/bridgebuildsnow5.tscn",
	"res://main_scene/bridgebuildsnow6.tscn",
	"res://main_scene/bridgebuildsnow7.tscn",
	"res://main_scene/bridgebuildsnow8.tscn",
	"res://main_scene/bridgebuildsnow9.tscn",
	"res://main_scene/bridgebuildsnow10.tscn",
	"res://main_scene/bridgebuildsnow11.tscn",
	"res://main_scene/bridgebuildsnow12.tscn",
	"res://main_scene/bridgebuildsnow13.tscn",
	"res://main_scene/bridgebuildsnow14.tscn",
	"res://main_scene/bridgebuildvolcano1.tscn",
	"res://main_scene/bridgebuildvolcano2.tscn",
	"res://main_scene/bridgebuildvolcano3.tscn",
	"res://main_scene/bridgebuildvolcano4.tscn",
	"res://main_scene/bridgebuildvolcano5.tscn",
	"res://main_scene/bridgebuildvolcano6.tscn",
	"res://main_scene/bridgebuildvolcano7.tscn",
	"res://main_scene/bridgebuildvolcano8.tscn",
	"res://main_scene/bridgebuildvolcano9.tscn",
	"res://main_scene/bridgebuildvolcano10.tscn",
	"res://main_scene/bridgebuildvolcano11.tscn",
	"res://main_scene/bridgebuildvolcano12.tscn",
	"res://main_scene/bridgebuildvolcano13.tscn",
	"res://main_scene/bridgebuildvolcano14.tscn",
	"res://main_scene/bridgebuildvolcano15.tscn",
	"res://main_scene/bridgebuildvolcano16.tscn",
	"res://main_scene/bridgebuildvolcano17.tscn",
	"res://main_scene/bridgebuildvolcano18.tscn",
	"res://main_scene/bridgebuildvolcano19.tscn",
	"res://main_scene/bridgebuildvolcano20.tscn",
	"res://main_scene/bridgebuildvolcano21.tscn",
	"res://main_scene/bridge_build_city_1.tscn",
	"res://main_scene/bridge_build_city_2.tscn",
	"res://main_scene/bridge_build_city_3.tscn",
	"res://main_scene/bridge_build_city_4.tscn",
	"res://main_scene/bridge_build_city_5.tscn",
	"res://main_scene/bridge_build_city_6.tscn",
	"res://main_scene/bridge_build_city_7.tscn",
	"res://main_scene/bridge_build_city_8.tscn",
	"res://main_scene/bridge_build_city_9.tscn",
	"res://main_scene/bridge_build_city_10.tscn",
]

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
		_ensure_debug_user()
		return save_users()

	var parsed: Variant = JSON.parse_string(raw_content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("User data is not valid JSON. A fresh user data file will be written.")
		users.clear()
		_ensure_debug_user()
		return save_users()

	var parsed_users: Variant = parsed.get("users", {})
	if typeof(parsed_users) != TYPE_DICTIONARY:
		push_warning("User data does not contain a users dictionary. A fresh user data file will be written.")
		users.clear()
		_ensure_debug_user()
		return save_users()

	users = parsed_users as Dictionary
	_normalize_loaded_users()
	_ensure_debug_user()
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
		return {"ok": false, "message": "\u7528\u6237\u540d\u4e0d\u80fd\u4e3a\u7a7a"}
	if password.is_empty():
		return {"ok": false, "message": "\u5bc6\u7801\u4e0d\u80fd\u4e3a\u7a7a"}
	if users.has(clean_username):
		return {"ok": false, "message": "\u7528\u6237\u5df2\u5b58\u5728"}

	users[clean_username] = _create_empty_user(clean_username, password, focus_baseline)
	save_users()
	current_username = clean_username
	return {"ok": true, "message": "\u7528\u6237\u5df2\u521b\u5efa"}


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


func record_level_success(level_id: String, attempts: int, elapsed_seconds: float = -1.0, username: String = "") -> bool:
	var target_username: String = _resolve_username(username)
	var clean_level_id := level_id.strip_edges()
	if target_username.is_empty() or clean_level_id.is_empty() or not users.has(target_username):
		return false

	var user: Dictionary = users[target_username] as Dictionary
	var level_success_attempts: Dictionary = _dictionary_from(user.get("level_success_attempts", {}))
	level_success_attempts[clean_level_id] = max(attempts, 1)
	user["level_success_attempts"] = level_success_attempts

	var level_completion: Dictionary = _dictionary_from(user.get("level_completion", {}))
	level_completion[clean_level_id] = true
	user["level_completion"] = level_completion

	if elapsed_seconds >= 0.0:
		var level_times: Dictionary = _dictionary_from(user.get("level_times", {}))
		var old_record: Dictionary = _dictionary_from(level_times.get(clean_level_id, {}))
		var best_seconds := elapsed_seconds
		if old_record.has("best_seconds"):
			best_seconds = minf(float(old_record.get("best_seconds", elapsed_seconds)), elapsed_seconds)

		level_times[clean_level_id] = {
			"last_seconds": elapsed_seconds,
			"best_seconds": best_seconds
		}
		user["level_times"] = level_times

	users[target_username] = user
	return save_users()


func is_level_completed(level_id: String, username: String = "") -> bool:
	var target_username: String = _resolve_username(username)
	var clean_level_id := level_id.strip_edges()
	if target_username.is_empty() or clean_level_id.is_empty() or not users.has(target_username):
		return false

	var user: Dictionary = users[target_username] as Dictionary
	var completion_data: Dictionary = _dictionary_from(user.get("level_completion", {}))
	if bool(completion_data.get(clean_level_id, false)):
		return true

	# Older saves only had success attempts; treat those as completed too.
	var attempts_data: Dictionary = _dictionary_from(user.get("level_success_attempts", {}))
	return attempts_data.has(clean_level_id)


func get_level_best_time_seconds(level_id: String, username: String = "") -> float:
	var target_username: String = _resolve_username(username)
	var clean_level_id := level_id.strip_edges()
	if target_username.is_empty() or clean_level_id.is_empty() or not users.has(target_username):
		return 0.0

	var user: Dictionary = users[target_username] as Dictionary
	var times_data: Dictionary = _dictionary_from(user.get("level_times", {}))
	var level_record: Dictionary = _dictionary_from(times_data.get(clean_level_id, {}))
	return float(level_record.get("best_seconds", 0.0))


func add_play_time(seconds: float, username: String = "") -> bool:
	var target_username: String = _resolve_username(username)
	if target_username.is_empty() or not users.has(target_username):
		return false

	var user: Dictionary = users[target_username] as Dictionary
	var current_total: float = float(user.get("total_play_time_seconds", 0.0))
	user["total_play_time_seconds"] = maxf(current_total + seconds, 0.0)
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

		var user: Dictionary = _dictionary_from(users[username])
		if not user.has("username"):
			user["username"] = clean_username
		if not user.has("password"):
			user["password"] = ""
		if not user.has("focus_baseline"):
			user["focus_baseline"] = DEFAULT_FOCUS_BASELINE
		if not user.has("level_success_attempts") or typeof(user["level_success_attempts"]) != TYPE_DICTIONARY:
			user["level_success_attempts"] = {}
		if not user.has("level_completion") or typeof(user["level_completion"]) != TYPE_DICTIONARY:
			user["level_completion"] = {}
		if not user.has("level_times") or typeof(user["level_times"]) != TYPE_DICTIONARY:
			user["level_times"] = {}
		if not user.has("total_play_time_seconds"):
			user["total_play_time_seconds"] = 0.0

		normalized_users[clean_username] = user

	users = normalized_users


func _ensure_debug_user() -> void:
	var user: Dictionary = _dictionary_from(users.get(DEBUG_USERNAME, {}))
	user["username"] = DEBUG_USERNAME
	user["password"] = DEBUG_PASSWORD
	user["focus_baseline"] = float(user.get("focus_baseline", DEFAULT_FOCUS_BASELINE))
	user["total_play_time_seconds"] = float(user.get("total_play_time_seconds", 0.0))

	var level_completion: Dictionary = _dictionary_from(user.get("level_completion", {}))
	var level_success_attempts: Dictionary = _dictionary_from(user.get("level_success_attempts", {}))
	for level_path in DEBUG_UNLOCKED_LEVELS:
		level_completion[level_path] = true
		if not level_success_attempts.has(level_path):
			level_success_attempts[level_path] = 1

	user["level_completion"] = level_completion
	user["level_success_attempts"] = level_success_attempts
	user["level_times"] = _dictionary_from(user.get("level_times", {}))
	users[DEBUG_USERNAME] = user


func _create_empty_user(username: String, password: String, focus_baseline: float) -> Dictionary:
	return {
		"username": username,
		"password": password,
		"focus_baseline": clampf(focus_baseline, 0.0, 100.0),
		"level_success_attempts": {},
		"level_completion": {},
		"level_times": {},
		"total_play_time_seconds": 0.0
	}


func _resolve_username(username: String) -> String:
	var clean_username: String = username.strip_edges()
	if clean_username.is_empty():
		return current_username
	return clean_username


func _dictionary_from(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}
