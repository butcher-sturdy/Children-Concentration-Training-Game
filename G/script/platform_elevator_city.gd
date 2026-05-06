extends AnimatableBody2D

signal player_touched(body: CharacterBody2D)
signal platform_arrived(body: CharacterBody2D)

@export var start_position: Vector2 = Vector2.ZERO
@export var end_position: Vector2 = Vector2.ZERO
@export var vertical_offset: float = -240.0
@export var move_duration: float = 1.5
@export var return_delay: float = 1.5

@onready var detect_area: Area2D = $Area2D

var has_triggered: bool = false


func _ready() -> void:
	if start_position == Vector2.ZERO:
		start_position = position

	position = start_position
	if detect_area != null:
		detect_area.body_entered.connect(_on_player_enter)


func _on_player_enter(body: Node2D) -> void:
	var player := body as CharacterBody2D
	if has_triggered or player == null or not player.is_in_group("Player"):
		return

	has_triggered = true
	var target_position := get_target_position()

	emit_signal("player_touched", player)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target_position, move_duration)
	tween.tween_callback(func(): _emit_platform_arrived(player))
	tween.tween_interval(return_delay)
	tween.tween_property(self, "position", start_position, move_duration)
	tween.tween_callback(func(): has_triggered = false)


func _emit_platform_arrived(player: CharacterBody2D) -> void:
	if is_instance_valid(player):
		emit_signal("platform_arrived", player)


func get_target_position() -> Vector2:
	if end_position == Vector2.ZERO:
		return start_position + Vector2(0.0, vertical_offset)
	return Vector2(start_position.x, end_position.y)
