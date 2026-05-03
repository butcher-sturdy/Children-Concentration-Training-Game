extends CanvasLayer

const TITLE_SCENE_PATH := "res://main_scene/title.tscn"

@onready var continue_button: BaseButton = get_node("continue")
@onready var back_to_title_button: BaseButton = get_node("back_to_title")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.process_mode = Node.PROCESS_MODE_ALWAYS
	back_to_title_button.process_mode = Node.PROCESS_MODE_ALWAYS

	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if not back_to_title_button.pressed.is_connected(_on_back_to_title_pressed):
		back_to_title_button.pressed.connect(_on_back_to_title_pressed)

	continue_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()

func _on_continue_pressed() -> void:
	get_tree().paused = false
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)
	else:
		queue_free()

func _on_back_to_title_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)
