extends Node

const SETTING_SCENE := preload("res://main_scene/setting.tscn")

var pause_menu: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		if get_tree().paused:
			_close_pause_menu()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()

func _open_pause_menu() -> void:
	if is_instance_valid(pause_menu):
		return

	pause_menu = SETTING_SCENE.instantiate()
	add_child(pause_menu)
	get_tree().paused = true

func _close_pause_menu() -> void:
	get_tree().paused = false
	if is_instance_valid(pause_menu):
		pause_menu.queue_free()
	pause_menu = null
