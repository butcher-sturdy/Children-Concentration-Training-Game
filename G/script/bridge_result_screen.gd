extends Control

const TITLE_SCENE_PATH := "res://main_scene/title.tscn"
const PARKOUR_SCENE_PATH := "res://main_scene/parkour.tscn"

@onready var title_label: Label = %TitleLabel
@onready var time_label: Label = %TimeLabel
@onready var failure_label: Label = %FailureLabel
@onready var best_time_label: Label = %BestTimeLabel
@onready var continue_button: BaseButton = %ContinueButton
@onready var title_button: BaseButton = %TitleButton

var session: Node


func _ready() -> void:
	session = get_node_or_null("/root/game_session")
	_update_result_text()

	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if not title_button.pressed.is_connected(_on_title_pressed):
		title_button.pressed.connect(_on_title_pressed)

	continue_button.grab_focus()


func _update_result_text() -> void:
	var result := _get_result()
	var level_label := str(result.get("level_label", "建造关卡"))
	var elapsed_seconds := float(result.get("elapsed_seconds", 0.0))
	var failure_count := int(result.get("failure_count", 0))
	var best_seconds := 0.0

	if session != null and session.has_method("get_best_time_for_level"):
		best_seconds = float(session.call("get_best_time_for_level", str(result.get("level_path", ""))))

	title_label.text = "%s 完成" % level_label
	time_label.text = "通关时间：%s" % _format_time(elapsed_seconds)
	failure_label.text = "失败次数：%d" % failure_count
	if best_seconds > 0.0:
		best_time_label.text = "最佳时间：%s" % _format_time(best_seconds)
	else:
		best_time_label.text = "最佳时间：本次已记录"


func _get_result() -> Dictionary:
	if session != null and session.has_method("get_last_bridge_result"):
		return session.call("get_last_bridge_result")
	return {}


func _on_continue_pressed() -> void:
	if session != null and session.has_method("begin_parkour"):
		session.call("begin_parkour")
	get_tree().change_scene_to_file(PARKOUR_SCENE_PATH)


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
