extends Area2D

@export var launch_velocity: Vector2 = Vector2(620.0, -900.0)
@export var recharge_time: float = 0.18

@onready var sprite: Sprite2D = $Sprite2D

var is_recharging := false
var launched_body_ids := {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	if is_recharging:
		return

	for body in get_overlapping_bodies():
		if _try_launch(body):
			return

func _on_body_entered(body: Node2D) -> void:
	_try_launch(body)

func _on_body_exited(body: Node2D) -> void:
	launched_body_ids.erase(body.get_instance_id())

func _try_launch(body: Node2D) -> bool:
	var character := body as CharacterBody2D
	if is_recharging or not _can_launch(character):
		return false

	var body_id := character.get_instance_id()
	if launched_body_ids.has(body_id):
		return false

	launched_body_ids[body_id] = true
	is_recharging = true
	character.global_position += Vector2(8, -18)
	character.velocity = launch_velocity
	character.set_deferred("velocity", launch_velocity)
	if character.has_method("continue_running"):
		character.call("continue_running", character)

	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.08, 0.82), 0.06)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)

	get_tree().create_timer(recharge_time).timeout.connect(func(): is_recharging = false)
	return true

func _can_launch(body: CharacterBody2D) -> bool:
	if body == null:
		return false

	return body.is_in_group("Player") or body.has_method("continue_running")
