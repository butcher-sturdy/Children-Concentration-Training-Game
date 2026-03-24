extends CharacterBody2D

# 导出变量（可在编辑器调整）
@export var move_speed: float = 300.0
@export var jump_force: float = -600.0  # Y轴向下，负数向上跳
@export var gravity: float = 1800.0
@export var is_auto_run: bool = true  # 新增：自动向右跑开关（默认开启）

# 引用AnimatedSprite2D子节点（名称匹配）
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var start_position: Vector2

func _physics_process(delta: float) -> void:
	# 1. 处理重力（使用CharacterBody2D内置velocity）
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0  # 地面清零垂直速度，避免叠加

	# 2. 处理水平移动【核心修改：自动向右跑】
	if is_auto_run:
		velocity.x = move_speed  # 固定向右跑，无需手动输入
	else:
		# 保留手动控制逻辑（关闭自动跑时可用）
		var input_dir: float = Input.get_axis("move_left", "move_right")
		velocity.x = input_dir * move_speed

	# 3. 处理跳跃（仅地面可跳）
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	# 4. 应用移动（CharacterBody2D核心方法）
	move_and_slide()

	# 5. 控制动画
	update_animation(1.0 if is_auto_run else Input.get_axis("move_left", "move_right"))

# 动画控制逻辑（适配自动跑）
func update_animation(input_dir: float) -> void:
	# 空动画保护：检查节点和帧资源是否有效
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	# 空中保持最后一帧
	if not is_on_floor():
		return
	# 自动跑/地面移动 → 播放walk + 固定向右（不翻转）
	elif is_auto_run or input_dir != 0.0:
		if animated_sprite.animation != "walk":
			animated_sprite.animation = "walk"
			animated_sprite.play()
		animated_sprite.flip_h = false  # 自动跑固定向右，关闭翻转
	# 地面静止（仅关闭自动跑时触发）→ 播放idle
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.animation = "idle"
			animated_sprite.frame = 0  # 重置到第一帧
			animated_sprite.play()

func _ready() -> void:
	start_position = global_position
	# 验证动画配置
	if animated_sprite and animated_sprite.sprite_frames:
		if not animated_sprite.sprite_frames.has_animation("idle"):
			print("AnimatedSprite2D 未配置 idle 动画！")
		if not animated_sprite.sprite_frames.has_animation("walk"):
			print("AnimatedSprite2D 未配置 walk 动画！")
	else:
		print("AnimatedSprite2D 未绑定帧资源！")
	
	# 初始播放动画（自动跑默认播放walk）
	if animated_sprite:
		animated_sprite.animation = "walk" if is_auto_run else "idle"
		animated_sprite.play()

# 响应 KillZone 信号的方法
func _on_killzone_body_entered(body: Node2D) -> void:
	global_position = start_position
	is_auto_run=false
	velocity = Vector2.ZERO
	print("玩家返回初始位置！")
	
func change_auto_run_mode()->void:
	global_position = start_position
	is_auto_run=!is_auto_run
	
func jump_to_subtitle(body: Node2D)->void:
	if body.is_in_group("Player"):
		print("到达终点")
		get_tree().change_scene_to_file("res://main_scene/subtitle.tscn")
