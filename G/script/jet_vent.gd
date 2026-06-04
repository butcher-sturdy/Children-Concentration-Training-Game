extends Area2D

@export var boost_strength: float = 1200.0
@export var forward_push: float = 200.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body.is_in_group("Player") or body.name == "player"):
		return

	body.global_position.y -= 20

	if "velocity" in body:
		var launch_velocity := Vector2(forward_push, -boost_strength)
		body.velocity = launch_velocity
		body.set_deferred("velocity", launch_velocity)
