extends Control

const TITLE_SCENE_PATH := "res://main_scene/title.tscn"

@onready var title_label: Label = %TitleLabel
@onready var time_label: Label = %TimeLabel
@onready var next_label: Label = %NextLabel
@onready var next_button: BaseButton = %NextButton
@onready var title_button: BaseButton = %TitleButton

var session: Node
var next_level_path: String = ""


func _ready() -> void:
	session = get_node_or_null("/root/game_session")
	_update_result_text()

	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)
	if not title_button.pressed.is_connected(_on_title_pressed):
		title_button.pressed.connect(_on_title_pressed)

	next_button.grab_focus()


func _update_result_text() -> void:
	var result := _get_result()
	var level_label := str(result.get("level_label", "跑酷训练"))
	var elapsed_seconds := float(result.get("elapsed_seconds", 0.0))
	next_level_path = str(result.get("next_level_path", ""))

	title_label.text = "%s 跑酷结束" % level_label
	time_label.text = "通关时间：%s" % _format_time(elapsed_seconds)

	if next_level_path.is_empty():
		next_label.text = "全部关卡已完成"
		next_button.disabled = true
		next_button.modulate = Color(0.45, 0.45, 0.45, 0.74)
	else:
		var next_index := -1
		if session != null and session.has_method("get_level_index_for_scene"):
			next_index = int(session.call("get_level_index_for_scene", next_level_path))
		next_label.text = "下一关：第 %d 关" % (next_index + 1)


func _get_result() -> Dictionary:
	if session != null and session.has_method("get_last_parkour_result"):
		return session.call("get_last_parkour_result")
	return {}


func _on_next_pressed() -> void:
	if next_level_path.is_empty():
		return
	if session != null and session.has_method("begin_bridge_level"):
		session.call("begin_bridge_level", next_level_path, true)
	get_tree().change_scene_to_file(next_level_path)


func _on_title_pressed() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func _format_time(seconds: float) -> String:
	var total_seconds := int(floor(maxf(seconds, 0.0)))
	var minutes := int(total_seconds / 60)
	var remaining_seconds := total_seconds % 60
	var centiseconds := int(round((maxf(seconds, 0.0) - total_seconds) * 100.0))
	if centiseconds >= 100:
		centiseconds = 0
		remaining_seconds += 1
	if remaining_seconds >= 60:
		remaining_seconds = 0
		minutes += 1
	return "%02d:%02d.%02d" % [minutes, remaining_seconds, centiseconds]
