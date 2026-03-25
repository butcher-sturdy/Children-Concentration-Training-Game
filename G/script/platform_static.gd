extends AnimatableBody2D

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
		move_platform(end_position, move_duration)

# 修复：接收 目标位置 + 时长 参数
func move_platform(target_pos: Vector2, duration: float):
	var tween = create_tween()
	# 1. 先移动到终点
	tween.tween_property(self, "position", target_pos, duration)
	# 2. 原地等待
	tween.tween_property(self, "position", target_pos, duration)
	# 3. 等待上一步完成 → 再移动回起点（链式动画，不会覆盖！）
	tween.tween_property(self, "position", start_position, duration)
	
	# 可选：动画全部结束后，重置触发锁，允许再次触发
	has_triggered = false
