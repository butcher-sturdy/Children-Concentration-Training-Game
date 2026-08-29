extends Control

const TITLE_SCENE_PATH := "res://main_scene/title.tscn"
const UserDataStoreScript = preload("res://script/user_data_store.gd")

@onready var username_input: LineEdit = %UsernameInput
@onready var password_input: LineEdit = %PasswordInput
@onready var group_select: OptionButton = %GroupSelect
@onready var login_button: Button = %LoginButton
@onready var create_button: Button = %CreateButton
@onready var message_label: Label = %MessageLabel
@onready var user_info_label: Label = %UserInfoLabel

var session: Node
var user_data_store


func _ready() -> void:
	session = get_node_or_null("/root/game_session")
	if session != null:
		user_data_store = session.get("user_data_store")
	if user_data_store == null:
		user_data_store = UserDataStoreScript.new()

	if not login_button.pressed.is_connected(_on_login_pressed):
		login_button.pressed.connect(_on_login_pressed)
	if not create_button.pressed.is_connected(_on_create_pressed):
		create_button.pressed.connect(_on_create_pressed)
	if not username_input.text_submitted.is_connected(_on_text_submitted):
		username_input.text_submitted.connect(_on_text_submitted)
	if not password_input.text_submitted.is_connected(_on_text_submitted):
		password_input.text_submitted.connect(_on_text_submitted)
	if not username_input.text_changed.is_connected(_on_username_changed):
		username_input.text_changed.connect(_on_username_changed)

	_populate_group_select()
	username_input.grab_focus()
	_set_message("Demo: demo / 123456    Debug: debug / debug (all levels unlocked)", false)
	_show_empty_user_info()


func _on_text_submitted(_text: String) -> void:
	_on_login_pressed()


func _on_username_changed(_text: String) -> void:
	_select_saved_group_for_username(username_input.text.strip_edges())


func _on_login_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text
	var group_code := _get_selected_group_code()

	if username.is_empty() or password.is_empty() or group_code.is_empty():
		_set_message("\u7528\u6237\u540d\u3001\u5bc6\u7801\u548c\u5b9e\u9a8c\u7ec4\u522b\u4e0d\u80fd\u4e3a\u7a7a\u3002", false)
		return

	var result: Dictionary = {}
	if session != null and session.has_method("login"):
		result = session.call("login", username, password, group_code)
	else:
		result = _login_without_session(username, password, group_code)

	if not bool(result.get("ok", false)):
		_set_message(str(result.get("message", "Login failed.")), false)
		password_input.clear()
		password_input.grab_focus()
		return

	_set_message("Login success: %s" % username, true)
	_show_user_info(username)
	call_deferred("_go_to_title")


func _on_create_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text
	var group_code := _get_selected_group_code()
	if group_code.is_empty():
		_set_message("\u8bf7\u9009\u62e9\u5b9e\u9a8c\u7ec4\u522b\u3002", false)
		return
	var result: Dictionary = {}
	if session != null and session.has_method("create_user"):
		result = session.call("create_user", username, password, group_code)
	else:
		result = user_data_store.create_user(
			username,
			password,
			UserDataStoreScript.DEFAULT_FOCUS_BASELINE,
			group_code
		)

	if bool(result.get("ok", false)):
		_set_message("%s: %s" % [str(result.get("message", "User created.")), username], true)
		_show_user_info(username)
		call_deferred("_go_to_title")
	else:
		_set_message(str(result.get("message", "Create user failed.")), false)


func _set_message(text: String, is_success: bool) -> void:
	message_label.text = text
	if is_success:
		message_label.add_theme_color_override("font_color", Color(0.1, 0.45, 0.2, 1.0))
	else:
		message_label.add_theme_color_override("font_color", Color(0.65, 0.14, 0.11, 1.0))


func _show_empty_user_info() -> void:
	user_info_label.text = "Progress and level times are saved after login.\nRuntime save:\n%s\nProject data:\n%s" % [
		user_data_store.get_save_file_path(),
		user_data_store.get_project_data_file_path()
	]


func _show_user_info(username: String) -> void:
	var user: Dictionary = user_data_store.get_user(username)
	if user.is_empty():
		_show_empty_user_info()
		return

	var completion_data: Variant = user.get("level_completion", {})
	var completed_levels := {}
	if typeof(completion_data) == TYPE_DICTIONARY:
		var completion: Dictionary = completion_data as Dictionary
		for level_id in completion.keys():
			if bool(completion[level_id]):
				completed_levels[str(level_id)] = true
	var attempts_data: Variant = user.get("level_success_attempts", {})
	if typeof(attempts_data) == TYPE_DICTIONARY:
		for level_id in (attempts_data as Dictionary).keys():
			completed_levels[str(level_id)] = true

	var group_code := str(user.get("experimental_group_code", ""))
	user_info_label.text = "Current user: %s\nExperimental group: %s\nFocus baseline: %.1f\nCompleted: %d levels\nTotal play time: %s" % [
		str(user.get("username", username)),
		_get_group_label(group_code),
		float(user.get("focus_baseline", 0.0)),
		completed_levels.size(),
		_format_play_time(float(user.get("total_play_time_seconds", 0.0)))
	]


func _format_play_time(seconds: float) -> String:
	var total_seconds: int = int(round(seconds))
	var hours: int = int(total_seconds / 3600)
	var minutes: int = int((total_seconds % 3600) / 60)
	var remaining_seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, remaining_seconds]


func _login_without_session(username: String, password: String, group_code: String) -> Dictionary:
	if not user_data_store.has_user(username):
		return {"ok": false, "message": "User does not exist. Create one first."}
	if not user_data_store.validate_login(username, password):
		return {"ok": false, "message": "Wrong password. Please try again."}
	if not user_data_store.set_experimental_group(group_code, username):
		return {"ok": false, "message": "\u7ec4\u522b\u4fdd\u5b58\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5\u3002"}
	user_data_store.set_current_user(username)
	return {"ok": true, "message": "Login success."}


func _populate_group_select() -> void:
	group_select.clear()
	group_select.add_item("\u8bf7\u9009\u62e9\u5b9e\u9a8c\u7ec4\u522b")
	group_select.set_item_metadata(0, "")
	group_select.set_item_disabled(0, true)

	for group in _get_experimental_groups():
		var item_index := group_select.item_count
		group_select.add_item(str(group.get("label", "")))
		group_select.set_item_metadata(item_index, str(group.get("code", "")))
	group_select.select(0)


func _get_experimental_groups() -> Array:
	if session != null and session.has_method("get_experimental_groups"):
		return session.call("get_experimental_groups") as Array
	return [
		{"code": "blank_control", "label": "\u7a7a\u767d\u5bf9\u7167\u7ec4"},
		{"code": "eeg", "label": "\u8111\u7535\u7ec4"},
		{"code": "gesture", "label": "\u624b\u52bf\u7ec4"},
		{"code": "gesture_eeg", "label": "\u8111\u7535+\u624b\u52bf\u7ec4"},
	]


func _get_selected_group_code() -> String:
	var selected_index := group_select.selected
	if selected_index < 0:
		return ""
	return str(group_select.get_item_metadata(selected_index))


func _select_saved_group_for_username(username: String) -> void:
	if username.is_empty() or not user_data_store.has_user(username):
		group_select.select(0)
		return

	var saved_group: String = str(user_data_store.get_experimental_group(username))
	for index in range(group_select.item_count):
		if str(group_select.get_item_metadata(index)) == saved_group:
			group_select.select(index)
			return
	group_select.select(0)


func _get_group_label(group_code: String) -> String:
	if session != null and session.has_method("get_experimental_group_label"):
		return str(session.call("get_experimental_group_label", group_code))
	for group in _get_experimental_groups():
		if str(group.get("code", "")) == group_code:
			return str(group.get("label", group_code))
	return "\u672a\u9009\u62e9"


func _go_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)
