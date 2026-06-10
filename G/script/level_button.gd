extends Button

@export_file("*.tscn") var scene_path: String = ""
@export var locked_modulate: Color = Color(0.45, 0.45, 0.45, 0.74)
@export var unlocked_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)

var session: Node

func _ready() -> void:
	session = get_node_or_null("/root/game_session")
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_refresh_lock_state()

func _refresh_lock_state() -> void:
	if scene_path.is_empty():
		disabled = true
		modulate = locked_modulate
		return

	var can_play := true
	if session != null and session.has_method("can_select_level"):
		can_play = bool(session.call("can_select_level", scene_path))

	disabled = not can_play
	modulate = unlocked_modulate if can_play else locked_modulate
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_play else Control.CURSOR_ARROW
	tooltip_text = "" if can_play else "请先通关上一关"

func _on_pressed() -> void:
	if scene_path.is_empty() or disabled:
		return
	if session != null and session.has_method("begin_bridge_level"):
		session.call("begin_bridge_level", scene_path, true)
	get_tree().change_scene_to_file(scene_path)
