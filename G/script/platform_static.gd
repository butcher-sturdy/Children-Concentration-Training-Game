extends AnimatableBody2D

signal player_touched(body:CharacterBody2D)
signal platform_arrived(body:CharacterBody2D)
@export var start_position: Vector2 = Vector2.ZERO
@export var end_position: Vector2 = Vector2.ZERO
@export var move_duration: float = 1.5

@onready var detect_area: Area2D = $Area2D
var has_triggered: bool = false

func _ready():
	position = start_position
	detect_area.body_entered.connect(_on_player_enter)

func _on_player_enter(body: Node2D):
	if not has_triggered and body.is_in_group("Player"):
		
		has_triggered = true
		# 先移动到终点 → 完成后自动返回
		var tween = create_tween()
		# 1. 先移动到终点
		emit_signal("player_touched",body)
		tween.tween_property(self, "position", end_position, move_duration)
		tween.tween_callback(func(): emit_signal("platform_arrived", body))
		tween.tween_interval(move_duration)
		tween.tween_property(self, "position", start_position, move_duration)
		
		# 可选：动画全部结束后，重置触发锁，允许再次触发
		has_triggered = false
