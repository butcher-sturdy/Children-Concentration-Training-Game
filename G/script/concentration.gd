extends Node

# 核心数据：专注度 + 调整步长（灵敏度）
@export var focus_level: float = 0.0          # 专注度（0-100%）
@export var focus_step: float = 1.0           # 每次调整的步长（替代之前的scroll_sensitivity）

# 安全修改专注度（限制0-100范围）
func set_focus_level(value: float) -> void:
	focus_level = clamp(value, 0.0, 100.0)
	print("当前专注度：", round(focus_level), "%")

# 每帧检测输入映射（无需监听InputEvent，更简洁）
func _process(_delta: float) -> void:
	# 检测“专注度增加”动作（滚轮上/↑键）
	if Input.is_action_just_pressed("mouse_up"):
		set_focus_level(focus_level + focus_step)
	# 检测“专注度减少”动作（滚轮下/↓键）
	if Input.is_action_just_pressed("mouse_down"):
		set_focus_level(focus_level - focus_step)
