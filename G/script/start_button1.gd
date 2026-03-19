extends TextureButton

@export var catalogue :PackedScene
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
func start_game()->void:
	get_tree().change_scene_to_packed(catalogue)
	
