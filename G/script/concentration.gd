extends Node

@export var focus_level: float = 0.0
@export var read_interval: float = 0.2
@export var mouse_wheel_step: float = 5.0

const FILE_PATH: String = "C:/Users/ASUS/Desktop/concentration.txt"

var read_timer: float = 0.0

func _ready() -> void:
	if not FileAccess.file_exists(FILE_PATH):
		write_default_file()
	else:
		read_focus_from_file()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("mouse_up"):
		adjust_focus_level(mouse_wheel_step)
	if Input.is_action_just_pressed("mouse_down"):
		adjust_focus_level(-mouse_wheel_step)

	read_timer += delta
	if read_timer >= read_interval:
		read_focus_from_file()
		read_timer = 0.0

func set_focus_level(value: float) -> void:
	focus_level = clampf(value, 0.0, 100.0)

func adjust_focus_level(delta_value: float) -> void:
	set_focus_level(focus_level + delta_value)
	write_focus_to_file()
	print("Focus adjusted by mouse wheel: ", int(round(focus_level)), "%")

func read_focus_from_file() -> void:
	if not FileAccess.file_exists(FILE_PATH):
		write_default_file()
		return

	var file := FileAccess.open(FILE_PATH, FileAccess.READ)
	if not file:
		return

	var content := file.get_line().strip_edges()
	file.close()

	if content.is_valid_float():
		var new_value := clampf(float(content), 0.0, 100.0)
		if new_value != focus_level:
			focus_level = new_value
			print("Focus updated from file: ", int(round(focus_level)), "%")

func write_default_file() -> void:
	set_focus_level(50.0)
	write_focus_to_file()

func write_focus_to_file() -> void:
	var file := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_line(str(int(round(focus_level))))
	file.close()
