extends CharacterBody2D

# 基础移动/跳跃配置
@export var move_speed: float = 300.0
@export var jump_force: float = -800.0
@export var gravity: float = 1800.0   
@export var is_auto_run: bool = true

# 专注度相关阈值（Player自主配置）
@export var invincible_threshold: float = 50.0  # 无敌阈值
@export var fly_threshold: float = 75.0         # 飞行阈值
@export var fly_speed_multiplier: float = 1.5   # 飞行速度倍数

@export var max_lives: int = 3                  # 最大命数（默认3条）
var current_lives: int                        # 当前剩余命数
@export var hit_cooldown: float = 1.0           # 碰撞冷却（避免重复扣血，默认1秒）
var is_hit_cooldown: bool = true               # 冷却状态标记

# 引用节点
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
#发送生命数改变的信号
signal life_changed(current_lives:int,max_lives:int)
# 缓存初始状态
var original_mask: int       # 初始碰撞掩码
var original_speed: float    # 初始移动速度
var fly_base_y: float = 0.0  # 飞行锁定Y轴
var last_on_ground_position: Vector2
var start_position:Vector2

# 本地状态判断
var is_invincible: bool = false  # 是否无敌
var is_flying: bool = false      # 是否飞行

func _ready() -> void:
	# 缓存初始值
	original_mask = collision_mask
	original_speed = move_speed
	last_on_ground_position = global_position
	start_position = global_position
	# 新增：初始化生命值
	current_lives = max_lives
	print("游戏开始！剩余命数：", current_lives)
	# 动画初始化
	if animated_sprite:
		animated_sprite.animation = "walk" if is_auto_run else "idle"
		animated_sprite.play()

func _physics_process(delta: float) -> void:
	#发送信号
	emit_signal("life_changed",current_lives,max_lives)
	if current_lives <= 0:
			reset_game()
	# 新增：碰撞冷却倒计时
	if is_hit_cooldown:
		hit_cooldown -= delta
		if hit_cooldown <= 0:
			is_hit_cooldown = false
			hit_cooldown = 1.0  # 重置冷却时间
	#实时更新最后与地面接触的位置
	_update_last_ground_position()
	# 1. 更新本地状态（修正：concentration → Global）
	update_focus_states()
	# 2. 处理状态生效
	handle_focus_effects()
	# 3. 基础物理逻辑
	handle_gravity(delta)
	handle_movement()
	if not is_flying:
		handle_jump()
	move_and_slide()
	update_animation(1.0 if is_auto_run else Input.get_axis("move_left", "move_right"))

# ========== Player自主判断状态（修正标识符：concentration → Global） ==========
func update_focus_states() -> void:
	# 读取Global的专注度，用自己的阈值判断
	is_invincible = concentration.focus_level >= self.invincible_threshold
	is_flying = concentration.focus_level >= self.fly_threshold

# ========== Player处理状态生效 ==========
func handle_focus_effects() -> void:
	# 1. 无敌状态：取消与障碍物碰撞（Layer 2）
	if is_invincible:
		collision_mask = collision_mask & ~(1 << 1)  # 移除Obstacle图层
	else:
		collision_mask = original_mask               # 恢复碰撞

	# 2. 飞行状态：锁定Y轴 + 用自己的倍数加速
	if is_flying:
		if fly_base_y == 0.0:
			fly_base_y = global_position.y
		global_position.y = fly_base_y               # 悬浮
		move_speed = original_speed * self.fly_speed_multiplier  # 用Player自己的倍数
	else:
		move_speed = original_speed                  # 恢复速度
		fly_base_y = 0.0                             # 重置Y轴锁定

# 重力处理（飞行时关闭）
func handle_gravity(delta: float) -> void:
	if not is_on_floor() and not is_flying:
		velocity.y += gravity * delta
	elif not is_flying:
		velocity.y = 0.0

# 移动逻辑
func handle_movement() -> void:
	velocity.x = 0.0
	if is_auto_run:
		velocity.x = move_speed
	else:
		velocity.x = Input.get_axis("move_left", "move_right") * move_speed

# 跳跃逻辑（飞行时禁用）
func handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

# 动画更新
func update_animation(input_dir: float) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if not is_on_floor() or is_flying:
		return
	elif is_auto_run or input_dir != 0.0:
		if animated_sprite.animation != "walk":
			animated_sprite.animation = "walk"
			animated_sprite.play()
		animated_sprite.flip_h = false
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.animation = "idle"
			animated_sprite.frame = 0
			animated_sprite.play()

# ========== 碰撞障碍物扣血逻辑 ==========
func _on_body_entered(body: Node2D) -> void:
	# 扣血条件：碰撞障碍物 + 非无敌 + 不在冷却中
	if not is_invincible and not is_hit_cooldown:
		current_lives -= 1  # 扣1条命
		print("碰撞障碍物！剩余命数：", current_lives)
		is_hit_cooldown = true  # 启动冷却
		
		# 命数扣完 → 重置游戏
		

# ========== 游戏重置逻辑（命数扣完时调用） ==========
func reset_game() -> void:
	print("命数耗尽！重新开始游戏...")
	# 1. 重置玩家位置和速度
	global_position = start_position
	velocity = Vector2.ZERO
	# 2. 重置生命值
	current_lives = max_lives
	# 3. 重置专注度（可选，根据需求开启/关闭）
	concentration.set_focus_level(0.0)
	# 4. 重置所有状态
	is_invincible = false
	is_flying = false
	collision_mask = original_mask  # 恢复碰撞掩码
	move_speed = original_speed     # 恢复基础速度
	fly_base_y = 0.0                # 重置飞行Y轴
	is_hit_cooldown = false         # 重置冷却状态
	hit_cooldown = 1.0              # 重置冷却时间
	print("重置完成！剩余命数：", current_lives)
func _update_last_ground_position() -> void:
	# 条件：1. 不在飞行状态 2. 检测到与地面接触（CharacterBody2D内置方法）
	if not is_flying and is_on_floor():
		# 仅当位置变化时更新（可选，减少冗余赋值）
		if global_position != last_on_ground_position: 
			last_on_ground_position = global_position
			# 可选：调试用，打印最后一次地面位置
			#print("最后一次地面位置更新：", last_on_ground_position)
# 原有死亡重置（killzone触发，保留）
func _on_killzone_body_entered(body: Node2D) -> void:
	if not is_hit_cooldown:
		global_position = last_on_ground_position
		velocity = Vector2.ZERO
		pause_gravity_for_2_seconds()
		current_lives -= 1
	print("玩家返回初始位置！")
	
	
	
var gravity_timer: Timer = null  # 用于控制重力恢复的Timer
func pause_gravity_for_2_seconds():
	# 1. 先保存原始重力值（避免后续改不回去）
	var original_gravity = gravity
	
	# 2. 立即将重力设为0
	gravity = 0.0
	print("重力已暂停，2秒后恢复")
	
	

	# 3. 先清理旧的Timer（避免重复触发）
	if gravity_timer and is_instance_valid(gravity_timer):
		gravity_timer.stop()
		gravity_timer.queue_free()
	
	# 4. 创建新的一次性Timer（2秒后触发）
	gravity_timer = Timer.new()
	gravity_timer.wait_time = 0.7  # 持续2秒
	gravity_timer.one_shot = true  # 只触发一次
	gravity_timer.autostart = true  # 自动启动
	
	# 5. 绑定超时信号：恢复重力
	gravity_timer.timeout.connect(func():
		gravity = original_gravity  # 恢复原始重力值
		print("2秒已到，重力恢复为：", original_gravity)
		gravity_timer.queue_free()  # 释放Timer，避免内存占用
	)
	
	# 6. 必须将Timer添加到场景树（否则Timer不工作）
	add_child(gravity_timer)
	
	
func change_auto_run_mode()->void:
	global_position = start_position
	is_auto_run=!is_auto_run
	
func jump_to_subtitle(body: Node2D)->void:
	if body.is_in_group("Player"):
		print("到达终点")
		get_tree().change_scene_to_file("res://main_scene/subtitle.tscn")
