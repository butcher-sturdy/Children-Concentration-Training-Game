extends RigidBody2D

# ========== 可编辑配置（编辑器直接调整） ==========
@export var rise_height: float = 100.0  # 上升的总高度（像素）
@export var rise_speed: float = 200.0   # 上升速度（像素/秒）
@export var player_node_name: String = "player"  # 玩家节点名（注意和场景中名称大小写一致）

# ========== 状态变量 ==========
var has_player_on: bool = false  # 是否有玩家站在平台上
var initial_y: float = 0.0       # 玩家站上时的初始Y坐标
var target_y: float = 0.0        # 目标上升高度的Y坐标
var is_rising: bool = false      # 是否正在上升

func _ready() -> void:
	# 平台物理配置（修复4.x属性名+强制物理模式）
	self.gravity_scale = 0.0            # 关闭重力（平台自己上升）
	self.lock_rotation = true        # 修复：4.x替代lock_rotation
	self.contact_monitor = true         # 开启接触监测（检测玩家接触）
	self.max_contacts_reported = 10     # 最大接触数量（足够检测玩家）


func _physics_process(delta: float) -> void:
	# 只有玩家站在上面且未到目标高度时，才上升
	if has_player_on and is_rising:
		# 计算当前高度与目标高度的差值
		var current_diff = target_y - global_position.y
		# 未到达目标高度：继续上升
		if current_diff > 0:
			# 修复：用set_linear_velocity替代直接赋值velocity
			self.set_linear_velocity(Vector2(0, -rise_speed))
		# 到达目标高度：停止上升
		else:
			# 修复：清零速度（兼容物理引擎）
			self.set_linear_velocity(Vector2.ZERO)
			global_position.y = target_y  # 精准锁定目标高度
			is_rising = false  # 停止上升状态

# ========== 检测玩家接触（增强：加类型判断，避免误触发） ==========
func _on_body_entered(body: Node2D) -> void:
	# 修复：加CharacterBody2D类型判断，仅响应玩家（避免其他碰撞体误触发）
	if body is CharacterBody2D and body.name == player_node_name:
		has_player_on = true
		# 仅第一次站上时初始化高度（避免重复触发）
		if not is_rising:
			initial_y = global_position.y
			target_y = initial_y - rise_height  # 目标Y = 初始Y - 上升高度（向上）
			is_rising = true
		print("玩家站上平台，开始上升！")

# ========== 检测玩家离开（修复velocity赋值+保留复位逻辑） ==========
func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == player_node_name:
		has_player_on = false
		# 保留：玩家离开后平台复位
		is_rising = false
		self.set_linear_velocity(Vector2.ZERO)  # 修复：替代直接赋值velocity
		global_position.y = initial_y
		print("玩家离开平台，复位到初始位置")

# ========== 可选：重置平台到初始位置（比如死区触发后） ==========
func reset_platform() -> void:
	self.set_linear_velocity(Vector2.ZERO)  # 修复：替代直接赋值velocity
	global_position.y = initial_y
	is_rising = false
	has_player_on = false
