extends Node2D

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("mouse_right"):
		get_tree().reload_current_scene()
		print("已重置")
