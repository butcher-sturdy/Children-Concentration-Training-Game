extends Node

const UserDataStoreScript = preload("res://script/user_data_store.gd")

const TITLE_SCENE_PATH := "res://main_scene/title.tscn"
const LOGIN_SCENE_PATH := "res://main_scene/login.tscn"
const LEVEL_SELECT_SCENE_PATH := "res://main_scene/subtitle.tscn"
const PARKOUR_SCENE_PATH := "res://main_scene/parkour.tscn"
const BRIDGE_RESULT_SCENE_PATH := "res://main_scene/bridge_result.tscn"
const PARKOUR_RESULT_SCENE_PATH := "res://main_scene/parkour_result.tscn"
const COLLECTOR_UDP_HOST := "127.0.0.1"
const COLLECTOR_UDP_PORT := 8765

const GROUP_BLANK_CONTROL := "blank_control"
const GROUP_EEG := "eeg"
const GROUP_GESTURE := "gesture"
const GROUP_GESTURE_EEG := "gesture_eeg"
const EXPERIMENTAL_GROUPS: Array = [
	{"code": GROUP_BLANK_CONTROL, "label": "\u7a7a\u767d\u5bf9\u7167\u7ec4"},
	{"code": GROUP_EEG, "label": "\u8111\u7535\u7ec4"},
	{"code": GROUP_GESTURE, "label": "\u624b\u52bf\u7ec4"},
	{"code": GROUP_GESTURE_EEG, "label": "\u8111\u7535+\u624b\u52bf\u7ec4"},
]

const LEVEL_SCENE_PATHS: Array[String] = [
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

signal bridge_level_started(level_path: String, failure_count: int)
signal bridge_failure_recorded(failure_count: int)
signal bridge_level_completed(result: Dictionary)

var user_data_store
var current_username: String = ""

var active_bridge_level_path: String = ""
var active_bridge_level_index: int = -1
var active_bridge_scene_instance_id: int = 0
var bridge_failure_count: int = 0
var bridge_started_msec: int = 0

var parkour_started_msec: int = 0
var parkour_level_path: String = ""
var parkour_level_index: int = -1

var last_bridge_result: Dictionary = {}
var last_parkour_result: Dictionary = {}
var collector_udp := PacketPeerUDP.new()
var gameplay_mode: String = ""
var gameplay_scene_path: String = ""


func _ready() -> void:
	user_data_store = UserDataStoreScript.new()
	process_mode = Node.PROCESS_MODE_ALWAYS
	collector_udp.connect_to_host(COLLECTOR_UDP_HOST, COLLECTOR_UDP_PORT)


func _process(_delta: float) -> void:
	_sync_gameplay_capture_scope()


func _input(event: InputEvent) -> void:
	if not is_logged_in():
		return

	var key_event := event as InputEventKey
	if key_event == null:
		return

	var keycode := key_event.keycode
	if keycode == KEY_NONE:
		keycode = key_event.physical_keycode
	var key_name := OS.get_keycode_string(keycode)
	if key_name.is_empty():
		key_name = "KEY_%d" % keycode

	send_game_event("PLAYER_INPUT", {
		"block_id": gameplay_scene_path,
		"response": "%s:%s" % ["KEY_DOWN" if key_event.pressed else "KEY_UP", key_name],
		"action": "KEY_DOWN" if key_event.pressed else "KEY_UP",
		"key": key_name,
		"keycode": key_event.keycode,
		"physical_keycode": key_event.physical_keycode,
		"unicode": key_event.unicode,
		"repeat": key_event.echo,
	})


func login(username: String, password: String, experimental_group_code: String = "") -> Dictionary:
	var clean_username := username.strip_edges()
	if clean_username.is_empty() or password.is_empty():
		return {"ok": false, "message": "\u7528\u6237\u540d\u548c\u5bc6\u7801\u4e0d\u80fd\u4e3a\u7a7a"}
	if not user_data_store.has_user(clean_username):
		return {"ok": false, "message": "\u7528\u6237\u4e0d\u5b58\u5728\uff0c\u53ef\u4ee5\u5148\u521b\u5efa\u65b0\u7528\u6237"}
	if not user_data_store.validate_login(clean_username, password):
		return {"ok": false, "message": "\u5bc6\u7801\u9519\u8bef\uff0c\u8bf7\u91cd\u65b0\u8f93\u5165"}
	if not is_valid_experimental_group(experimental_group_code):
		return {"ok": false, "message": "\u8bf7\u9009\u62e9\u6709\u6548\u7684\u5b9e\u9a8c\u7ec4\u522b"}

	user_data_store.set_current_user(clean_username)
	if not user_data_store.set_experimental_group(experimental_group_code, clean_username):
		return {"ok": false, "message": "\u7ec4\u522b\u4fdd\u5b58\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5"}
	current_username = clean_username
	send_game_event("KEYBOARD_RECORDING_START")
	return {"ok": true, "message": "\u767b\u5f55\u6210\u529f"}


func create_user(username: String, password: String, experimental_group_code: String = "") -> Dictionary:
	var result: Dictionary = user_data_store.create_user(
		username,
		password,
		UserDataStoreScript.DEFAULT_FOCUS_BASELINE,
		experimental_group_code
	)
	if bool(result.get("ok", false)):
		current_username = username.strip_edges()
		send_game_event("KEYBOARD_RECORDING_START")
	return result


func is_logged_in() -> bool:
	return not current_username.is_empty()


func get_current_user() -> Dictionary:
	if not is_logged_in():
		return {}
	return user_data_store.get_user(current_username)


func get_experimental_groups() -> Array:
	return EXPERIMENTAL_GROUPS.duplicate(true)


func is_valid_experimental_group(group_code: String) -> bool:
	for group in EXPERIMENTAL_GROUPS:
		if str(group.get("code", "")) == group_code:
			return true
	return false


func get_experimental_group_label(group_code: String) -> String:
	for group in EXPERIMENTAL_GROUPS:
		if str(group.get("code", "")) == group_code:
			return str(group.get("label", group_code))
	return "\u672a\u9009\u62e9"


func get_current_experimental_group_code() -> String:
	if not is_logged_in():
		return ""
	return user_data_store.get_experimental_group(current_username)


func current_group_uses_eeg() -> bool:
	return get_current_experimental_group_code() in [GROUP_EEG, GROUP_GESTURE_EEG]


func current_group_uses_gesture() -> bool:
	return get_current_experimental_group_code() in [GROUP_GESTURE, GROUP_GESTURE_EEG]


func get_level_index_for_scene(scene_path: String) -> int:
	return LEVEL_SCENE_PATHS.find(scene_path)


func get_level_number_for_scene(scene_path: String) -> int:
	var index := get_level_index_for_scene(scene_path)
	if index == -1:
		return 0
	return index + 1


func get_level_label(scene_path: String = "") -> String:
	var path := active_bridge_level_path if scene_path.is_empty() else scene_path
	var index := get_level_index_for_scene(path)
	if index == -1:
		return "\u5173\u5361"
	return "\u7b2c %d \u5173" % (index + 1)


func can_select_level(scene_path: String) -> bool:
	var index := get_level_index_for_scene(scene_path)
	if index == -1:
		return false
	if index == 0:
		return true
	if not is_logged_in():
		return false
	return user_data_store.is_level_completed(LEVEL_SCENE_PATHS[index - 1], current_username)


func begin_bridge_level(scene_path: String, force_restart: bool = false) -> void:
	var index := get_level_index_for_scene(scene_path)
	if index == -1:
		return
	_set_gameplay_capture_scope("bridge_build", scene_path)
	var scene_instance_id := _get_current_bridge_scene_instance_id(scene_path)
	var scene_instance_changed := scene_instance_id != 0 and scene_instance_id != active_bridge_scene_instance_id
	if force_restart or active_bridge_level_path != scene_path or bridge_started_msec <= 0 or scene_instance_changed:
		active_bridge_level_path = scene_path
		active_bridge_level_index = index
		active_bridge_scene_instance_id = scene_instance_id
		bridge_failure_count = 0
		bridge_started_msec = Time.get_ticks_msec()
		last_bridge_result.clear()
		bridge_level_started.emit(active_bridge_level_path, bridge_failure_count)
	elif scene_instance_id != 0:
		active_bridge_scene_instance_id = scene_instance_id


func ensure_bridge_level_started(scene_path: String) -> void:
	begin_bridge_level(scene_path, false)


func record_bridge_failure() -> int:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		begin_bridge_level(current_scene.scene_file_path, false)

	bridge_failure_count += 1
	bridge_failure_recorded.emit(bridge_failure_count)
	return bridge_failure_count


func get_bridge_failure_count() -> int:
	return bridge_failure_count


func finish_bridge_level() -> Dictionary:
	_set_gameplay_capture_scope("", "")
	var elapsed_seconds := _elapsed_seconds_since(bridge_started_msec)
	var level_path := active_bridge_level_path
	if level_path.is_empty() and get_tree().current_scene != null:
		level_path = get_tree().current_scene.scene_file_path
		active_bridge_level_index = get_level_index_for_scene(level_path)

	var level_index := get_level_index_for_scene(level_path)
	var next_level_path := get_next_level_path(level_path)
	last_bridge_result = {
		"level_path": level_path,
		"level_index": level_index,
		"level_label": get_level_label(level_path),
		"elapsed_seconds": elapsed_seconds,
		"failure_count": bridge_failure_count,
		"next_level_path": next_level_path,
		"parkour_segment_paths": get_parkour_segment_paths_for_level(level_path),
	}

	if is_logged_in() and not level_path.is_empty():
		user_data_store.record_level_success(level_path, bridge_failure_count + 1, elapsed_seconds, current_username)
		user_data_store.add_play_time(elapsed_seconds, current_username)

	bridge_level_completed.emit(last_bridge_result.duplicate(true))
	return get_last_bridge_result()


func begin_parkour(level_path: String = "") -> void:
	_set_gameplay_capture_scope("parkour", PARKOUR_SCENE_PATH)
	if not level_path.is_empty():
		parkour_level_path = level_path
	elif not active_bridge_level_path.is_empty():
		parkour_level_path = active_bridge_level_path
	else:
		parkour_level_path = ""

	parkour_level_index = get_level_index_for_scene(parkour_level_path)
	parkour_started_msec = Time.get_ticks_msec()
	last_parkour_result.clear()


func finish_parkour() -> Dictionary:
	_set_gameplay_capture_scope("", "")
	var elapsed_seconds := _elapsed_seconds_since(parkour_started_msec)
	var next_level_path := get_next_level_path(parkour_level_path)
	last_parkour_result = {
		"level_path": parkour_level_path,
		"level_index": parkour_level_index,
		"level_label": get_level_label(parkour_level_path),
		"elapsed_seconds": elapsed_seconds,
		"next_level_path": next_level_path,
		"parkour_segment_paths": get_current_parkour_segment_paths(),
	}
	if is_logged_in():
		user_data_store.add_play_time(elapsed_seconds, current_username)
	return get_last_parkour_result()


func get_next_level_path(scene_path: String = "") -> String:
	var path := active_bridge_level_path if scene_path.is_empty() else scene_path
	var index := get_level_index_for_scene(path)
	if index == -1:
		return ""
	var next_index := index + 1
	if next_index >= LEVEL_SCENE_PATHS.size():
		return ""
	return LEVEL_SCENE_PATHS[next_index]


func get_current_parkour_segment_paths() -> Array[String]:
	if not parkour_level_path.is_empty():
		return get_parkour_segment_paths_for_level(parkour_level_path)
	if not active_bridge_level_path.is_empty():
		return get_parkour_segment_paths_for_level(active_bridge_level_path)
	return _make_parkour_segment_paths(1, 4)


func get_parkour_segment_paths_for_level(scene_path: String) -> Array[String]:
	var level_number := get_level_number_for_scene(scene_path)
	if level_number >= 1 and level_number <= 10:
		return _make_parkour_segment_paths(1, 4)
	if level_number >= 11 and level_number <= 24:
		return _make_parkour_segment_paths(13, 16)
	if level_number >= 25 and level_number <= 45:
		return _make_parkour_segment_paths(9, 12)
	if level_number >= 46 and level_number <= 55:
		return _make_parkour_segment_paths(5, 8)

	return _get_parkour_segment_paths_by_scene_name(scene_path)


func get_last_bridge_result() -> Dictionary:
	return last_bridge_result.duplicate(true)


func get_last_parkour_result() -> Dictionary:
	return last_parkour_result.duplicate(true)


func get_best_time_for_level(scene_path: String) -> float:
	if not is_logged_in():
		return 0.0
	return user_data_store.get_level_best_time_seconds(scene_path, current_username)


func _make_parkour_segment_paths(first_index: int, last_index: int) -> Array[String]:
	var paths: Array[String] = []
	for index in range(first_index, last_index + 1):
		paths.append("res://element/parkourmap/parkourmap%d.tscn" % index)
	return paths


func _get_parkour_segment_paths_by_scene_name(scene_path: String) -> Array[String]:
	if scene_path.contains("grass"):
		return _make_parkour_segment_paths(1, 4)
	if scene_path.contains("snow"):
		return _make_parkour_segment_paths(13, 16)
	if scene_path.contains("volcano"):
		return _make_parkour_segment_paths(9, 12)
	if scene_path.contains("city"):
		return _make_parkour_segment_paths(5, 8)
	return _make_parkour_segment_paths(1, 4)


func _elapsed_seconds_since(start_msec: int) -> float:
	if start_msec <= 0:
		return 0.0
	return maxf(float(Time.get_ticks_msec() - start_msec) / 1000.0, 0.0)


func _get_current_bridge_scene_instance_id(scene_path: String) -> int:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return 0
	if current_scene.scene_file_path != scene_path:
		return 0
	return current_scene.get_instance_id()


func send_game_event(event_type: String, fields: Dictionary = {}) -> void:
	if event_type.strip_edges().is_empty():
		return

	var group_code := get_current_experimental_group_code()
	var payload: Dictionary = fields.duplicate(true)
	payload["event_type"] = event_type
	payload["condition"] = group_code
	payload["experimental_group_label"] = get_experimental_group_label(group_code)
	payload["game_mode"] = gameplay_mode
	payload["scene_path"] = gameplay_scene_path
	payload["game_time_unix_ms"] = int(Time.get_unix_time_from_system() * 1000.0)
	payload["game_ticks_usec"] = Time.get_ticks_usec()
	collector_udp.put_packet(JSON.stringify(payload).to_utf8_buffer())


func _sync_gameplay_capture_scope() -> void:
	var current_scene := get_tree().current_scene
	var scene_path := ""
	if current_scene != null:
		scene_path = current_scene.scene_file_path

	var mode := ""
	if LEVEL_SCENE_PATHS.has(scene_path):
		mode = "bridge_build"
	elif scene_path == PARKOUR_SCENE_PATH:
		mode = "parkour"

	_set_gameplay_capture_scope(mode, scene_path if not mode.is_empty() else "")


func _set_gameplay_capture_scope(mode: String, scene_path: String) -> void:
	if gameplay_mode == mode and gameplay_scene_path == scene_path:
		return

	if not gameplay_mode.is_empty():
		send_game_event("BLOCK_END", {"block_id": gameplay_scene_path})

	gameplay_mode = mode
	gameplay_scene_path = scene_path
	if not gameplay_mode.is_empty():
		send_game_event("BLOCK_START", {"block_id": gameplay_scene_path})
