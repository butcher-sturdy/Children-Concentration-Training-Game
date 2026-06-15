extends Label 


func _ready() -> void:
	text = "生命值：3"


func _on_character_body_2d_life_changed(current_lives: int, max_lives: int) -> void:
	text = "生命值：%d" % [current_lives]
