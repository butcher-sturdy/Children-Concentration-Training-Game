extends Area2D

@export var launch_velocity: Vector2 = Vector2(620.0, -900.0)

@onready var sprite: Sprite2D = $Sprite2D

var is_recharging := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if is_recharging or not (body is CharacterBody2D) or not body.is_in_group("Player"):
		return

	is_recharging = true
	body.global_position += Vector2(8, -18)
	body.velocity = launch_velocity
	if body.has_method("continue_running"):
		body.continue_running(body)

	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.08, 0.82), 0.06)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)

	get_tree().create_timer(0.35).timeout.connect(func(): is_recharging = false)
