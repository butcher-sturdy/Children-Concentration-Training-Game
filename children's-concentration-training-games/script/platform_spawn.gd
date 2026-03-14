extends Node2D

# 导出变量
@export var platform_scene: PackedScene
@export var platform_texture: Texture2D
@export var platform_size: Vector2 = Vector2(100, 35)
@export var preview_alpha: float = 0.5
@export var texture_scale_multiplier: float = 1.0
# 碰撞查询层（匹配需要阻挡的碰撞体层，默认Layer 1）
@export var collision_mask: int = 1

# 最大生成数量
@export var max_platform_count: int = 10
var current_platform_count: int = 0
# 物理空间查询对象（用于检测碰撞）
var space_state: PhysicsDirectSpaceState2D

func _ready() -> void:
	# 获取2D物理空间状态（全局），用于碰撞查询
	space_state = get_world_2d().direct_space_state

func _process(delta: float) -> void:
	queue_redraw()
	
	# 检测放置平台输入
	if Input.is_action_just_pressed("mouse_left"):
		if not platform_scene or not platform_texture:
			print("请先赋值平台预制体/纹理！")
			return
		if current_platform_count >= max_platform_count:
			print("已达最大平台数量！")
			return
		
		# 获取合法鼠标位置（非碰撞体区域）
		var legal_mouse_pos = get_legal_mouse_position()
		if legal_mouse_pos != Vector2.INF:  # 仅当位置合法时生成平台
			spawn_platform(legal_mouse_pos)
		# 2. 检测重新加载场景（右键）【核心修改：场景重载逻辑】
	if Input.is_action_just_pressed("mouse_right"):
		reload_current_scene()
			
func reload_current_scene() -> void:
	# 获取当前场景的树，调用重载方法
	var scene_tree = get_tree()
	# 重载当前活动场景（会销毁所有动态生成的节点，重置变量）
	scene_tree.reload_current_scene()
	# 打印提示（注意：场景重载后当前脚本会重新初始化，后续代码可能不执行
	print("正在重置场景...所有平台已清除")

# 核心：获取合法的鼠标位置（避开碰撞体）
func get_legal_mouse_position() -> Vector2:
	# 1. 获取原始鼠标全局位置
	var raw_mouse_pos = get_global_mouse_position()
	
	# 2. 构造点碰撞查询参数
	var query = PhysicsPointQueryParameters2D.new()
	query.position = raw_mouse_pos  # 查询鼠标位置
	query.collision_mask = collision_mask  # 仅检测指定碰撞层的物体
	query.exclude = get_children()  # 排除当前节点的子节点（避免检测到已生成的平台）
	
	# 3. 执行碰撞查询
	var collision_result = space_state.intersect_point(query)
	
	# 4. 处理查询结果
	if collision_result:
		# 命中碰撞体 → 返回非法标记（或可选：偏移到最近合法位置）
		# 可选：简单偏移（向右上偏移10像素，直到无碰撞）
		# var offset_pos = raw_mouse_pos + Vector2(10, -10)
		# return offset_pos if not space_state.intersect_point(PhysicsPointQueryParameters2D.create(offset_pos, collision_mask)) else Vector2.INF
		return Vector2.INF  # 非法位置
	else:
		# 未命中碰撞体 → 返回原始位置
		return raw_mouse_pos

func spawn_platform(spawn_pos: Vector2) -> void:
	var new_platform = platform_scene.instantiate()
	new_platform.global_position = spawn_pos + platform_size / 1.55  # 左上对齐→中心偏移
	new_platform.scale = Vector2(texture_scale_multiplier, texture_scale_multiplier)  # 同步放大
	new_platform.name = "RigidPlatform_" + str(current_platform_count + 1)
	add_child(new_platform)
	
	current_platform_count += 1
	print("平台生成于合法位置：", spawn_pos)

func _draw() -> void:
	if not platform_texture:
		return
	
	# 获取合法鼠标位置（用于绘制预览图）
	var legal_mouse_pos = get_legal_mouse_position()
	if legal_mouse_pos == Vector2.INF:
		return  # 碰撞体区域 → 不绘制预览图
	
	# 转换为局部位置（左上对齐）
	var local_mouse_pos = to_local(legal_mouse_pos)
	
	# 计算缩放比例
	var texture_size = platform_texture.get_size()
	var scale = Vector2(platform_size.x / texture_size.x*1.3, platform_size.y / texture_size.y*1.1)
   
	
	# 设置绘制变换（左上基准）
	draw_set_transform(local_mouse_pos, 0.0, scale)
	
	# 绘制半透明预览图
	draw_texture(platform_texture, Vector2.ZERO, Color(1, 1, 1, preview_alpha))
	
	
	
	
	
	
	
	
