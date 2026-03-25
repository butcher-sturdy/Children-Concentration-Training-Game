extends Label 


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = "生命值：3"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_character_body_2d_life_changed(current_lives: int, max_lives: int) -> void:
	text = "生命值：%d" % [current_lives]
