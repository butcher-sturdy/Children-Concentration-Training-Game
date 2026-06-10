extends Control

const TITLE_SCENE_PATH := "res://main_scene/title.tscn"
const UserDataStoreScript = preload("res://script/user_data_store.gd")

@onready var username_input: LineEdit = %UsernameInput
@onready var password_input: LineEdit = %PasswordInput
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

	username_input.grab_focus()
	_set_message("Demo: demo / 123456    Debug: debug / debug (all levels unlocked)", false)
	_show_empty_user_info()


func _on_text_submitted(_text: String) -> void:
	_on_login_pressed()


func _on_login_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text

	if username.is_empty() or password.is_empty():
		_set_message("Username and password cannot be empty.", false)
		return

	var result: Dictionary = {}
	if session != null and session.has_method("login"):
		result = session.call("login", username, password)
	else:
		result = _login_without_session(username, password)

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
	var result: Dictionary = {}
	if session != null and session.has_method("create_user"):
		result = session.call("create_user", username, password)
	else:
		result = user_data_store.create_user(username, password)

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

	user_info_label.text = "Current user: %s\nFocus baseline: %.1f\nCompleted: %d levels\nTotal play time: %s" % [
		str(user.get("username", username)),
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


func _login_without_session(username: String, password: String) -> Dictionary:
	if not user_data_store.has_user(username):
		return {"ok": false, "message": "User does not exist. Create one first."}
	if not user_data_store.validate_login(username, password):
		return {"ok": false, "message": "Wrong password. Please try again."}
	user_data_store.set_current_user(username)
	return {"ok": true, "message": "Login success."}


func _go_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)
