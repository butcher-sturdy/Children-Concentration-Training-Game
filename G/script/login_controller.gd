extends Control

const UserDataStoreScript = preload("res://script/user_data_store.gd")

@onready var username_input: LineEdit = %UsernameInput
@onready var password_input: LineEdit = %PasswordInput
@onready var login_button: Button = %LoginButton
@onready var create_button: Button = %CreateButton
@onready var message_label: Label = %MessageLabel
@onready var user_info_label: Label = %UserInfoLabel

var user_data_store

func _ready() -> void:
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
	_set_message("请输入用户名和密码。初始账号：demo / 123456", false)
	_show_empty_user_info()

func _on_text_submitted(_text: String) -> void:
	_on_login_pressed()

func _on_login_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text

	if username.is_empty() or password.is_empty():
		_set_message("用户名和密码不能为空", false)
		return

	if not user_data_store.has_user(username):
		_set_message("用户不存在，可以点击“创建用户”建立新账号", false)
		return

	if not user_data_store.validate_login(username, password):
		_set_message("密码错误，请重新输入", false)
		password_input.clear()
		password_input.grab_focus()
		return

	user_data_store.set_current_user(username)
	_set_message("登录成功：%s" % username, true)
	_show_user_info(username)

func _on_create_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text
	var result: Dictionary = user_data_store.create_user(username, password)

	if bool(result.get("ok", false)):
		_set_message("%s：%s" % [str(result.get("message", "")), username], true)
		_show_user_info(username)
	else:
		_set_message(str(result.get("message", "创建失败")), false)

func _set_message(text: String, is_success: bool) -> void:
	message_label.text = text
	if is_success:
		message_label.add_theme_color_override("font_color", Color(0.1, 0.45, 0.2, 1.0))
	else:
		message_label.add_theme_color_override("font_color", Color(0.65, 0.14, 0.11, 1.0))

func _show_empty_user_info() -> void:
	user_info_label.text = "运行时保存到：\n%s\n项目数据文件：\n%s" % [
		user_data_store.get_save_file_path(),
		user_data_store.get_project_data_file_path()
	]

func _show_user_info(username: String) -> void:
	var user: Dictionary = user_data_store.get_user(username)
	if user.is_empty():
		_show_empty_user_info()
		return

	var attempts_data: Variant = user.get("level_success_attempts", {})
	var attempt_lines: PackedStringArray = PackedStringArray()
	if typeof(attempts_data) == TYPE_DICTIONARY:
		var attempts: Dictionary = attempts_data as Dictionary
		for level_id in attempts.keys():
			attempt_lines.append("%s：%s 次" % [str(level_id), str(attempts[level_id])])

	var attempt_text: String = "暂无"
	if not attempt_lines.is_empty():
		attempt_text = "\n".join(attempt_lines)

	user_info_label.text = "当前用户：%s\n专注度基线：%.1f\n通关尝试记录：\n%s\n游玩总时间：%s" % [
		str(user.get("username", username)),
		float(user.get("focus_baseline", 0.0)),
		attempt_text,
		_format_play_time(float(user.get("total_play_time_seconds", 0.0)))
	]

func _format_play_time(seconds: float) -> String:
	var total_seconds: int = int(round(seconds))
	var hours: int = int(total_seconds / 3600)
	var minutes: int = int((total_seconds % 3600) / 60)
	var remaining_seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, remaining_seconds]
