extends TextureButton

@export_file("*.tscn") var scene_path: String = ""

func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if scene_path.is_empty():
		disabled = true
		modulate = Color(0.62, 0.58, 0.52, 0.86)

func _on_pressed() -> void:
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)
