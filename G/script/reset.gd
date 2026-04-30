extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("mouse_right"):
		get_tree().reload_current_scene()
		print("已重置")


func _on_obstacle_1_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_obstacle_2_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_obstacle_3_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_obstacle_4_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_obstacle_5_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_obstacle_6_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_obstacle_7_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
