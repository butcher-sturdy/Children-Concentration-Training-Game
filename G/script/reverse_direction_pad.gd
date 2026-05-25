extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

var triggered_body_ids := {}
var activation_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	var character := body as CharacterBody2D
	if character == null or not _can_reverse(character):
		return

	var body_id := character.get_instance_id()
	if triggered_body_ids.has(body_id):
		return

	triggered_body_ids[body_id] = true
	if character.has_method("flip_move_direction"):
		character.call("flip_move_direction")
	else:
		character.velocity.x *= -1.0

	_play_activation_animation()

func _on_body_exited(body: Node2D) -> void:
	triggered_body_ids.erase(body.get_instance_id())

func _can_reverse(character: CharacterBody2D) -> bool:
	return character.is_in_group("Player") or character.has_method("flip_move_direction")

func _play_activation_animation() -> void:
	if activation_tween and activation_tween.is_valid():
		activation_tween.kill()

	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	activation_tween = create_tween()
	activation_tween.tween_property(sprite, "scale", Vector2(1.04, 0.84), 0.07)
	activation_tween.parallel().tween_property(sprite, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.07)
	activation_tween.tween_property(sprite, "scale", Vector2.ONE, 0.14)
	activation_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.14)
