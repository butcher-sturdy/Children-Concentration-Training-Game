extends Node2D

# 导出变量
@export var platform_scene: PackedScene
@export var platform_texture: Texture2D
@export var platform_size: Vector2 = Vector2(100, 35)
@export var preview_alpha: float = 0.5
@export var texture_scale_multiplier: float = 1.0
@export var collision_mask: int = 1

# 为 Vector2.ZERO 时，自动使用统一的短距离作为一格大小。
@export var grid_step: Vector2 = Vector2.ZERO
@export var grid_origin: Vector2 = Vector2(385, 430)
@export var initial_cursor_position: Vector2 = Vector2(385, 430)
@export var held_move_initial_delay: float = 0.25
@export var held_move_repeat_interval: float = 0.08

# 最大生成数量
@export var max_platform_count: int = 10
var current_platform_count: int = 0

var space_state: PhysicsDirectSpaceState2D
var cursor_position: Vector2 = Vector2.ZERO
var placed_platform_rects: Array[Rect2] = []
var held_move_direction: Vector2 = Vector2.ZERO
var held_move_timer: float = 0.0

func _ready() -> void:
	space_state = get_world_2d().direct_space_state
	cursor_position = snap_to_grid(initial_cursor_position)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		match key_event.keycode:
			KEY_LEFT:
				start_held_move(Vector2.LEFT)
			KEY_RIGHT:
				start_held_move(Vector2.RIGHT)
			KEY_UP:
				start_held_move(Vector2.UP)
			KEY_DOWN:
				start_held_move(Vector2.DOWN)

func _process(delta: float) -> void:
	update_held_move(delta)
	queue_redraw()

	if Input.is_action_just_pressed("mouse_left"):
		try_spawn_platform()

	if Input.is_action_just_pressed("mouse_right"):
		reload_current_scene()

func move_cursor(direction: Vector2) -> void:
	cursor_position = snap_to_grid(cursor_position + direction * get_grid_step())
	queue_redraw()

func start_held_move(direction: Vector2) -> void:
	held_move_direction = direction
	held_move_timer = held_move_initial_delay
	move_cursor(direction)

func update_held_move(delta: float) -> void:
	if held_move_direction == Vector2.ZERO:
		return
	if not is_held_move_key_pressed():
		held_move_direction = Vector2.ZERO
		held_move_timer = 0.0
		return

	held_move_timer -= delta
	if held_move_timer <= 0.0:
		move_cursor(held_move_direction)
		held_move_timer = held_move_repeat_interval

func is_held_move_key_pressed() -> bool:
	if held_move_direction == Vector2.LEFT:
		return Input.is_key_pressed(KEY_LEFT)
	if held_move_direction == Vector2.RIGHT:
		return Input.is_key_pressed(KEY_RIGHT)
	if held_move_direction == Vector2.UP:
		return Input.is_key_pressed(KEY_UP)
	if held_move_direction == Vector2.DOWN:
		return Input.is_key_pressed(KEY_DOWN)
	return false

func try_spawn_platform() -> void:
	if platform_scene == null or platform_texture == null:
		print("请先赋值平台预制体/纹理！")
		return
	if current_platform_count >= max_platform_count:
		print("已达最大平台数量！")
		return
	if not can_place_platform_at(cursor_position):
		print("当前位置不能放置平台！")
		return

	spawn_platform(cursor_position)

func reload_current_scene() -> void:
	get_tree().reload_current_scene()
	print("正在重置场景...所有平台已清除")

func can_place_platform_at(spawn_pos: Vector2) -> bool:
	if overlaps_placed_platform(spawn_pos):
		return false
	return not overlaps_collision_body(spawn_pos)

func overlaps_placed_platform(spawn_pos: Vector2) -> bool:
	var target_rect: Rect2 = get_platform_rect(spawn_pos)
	for placed_rect in placed_platform_rects:
		if target_rect.intersects(placed_rect, false):
			return true
	return false

func overlaps_collision_body(spawn_pos: Vector2) -> bool:
	if space_state == null:
		space_state = get_world_2d().direct_space_state

	var footprint: Vector2 = get_platform_footprint_size()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = footprint

	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, spawn_pos + footprint * 0.5)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	return not space_state.intersect_shape(query, 1).is_empty()

func spawn_platform(spawn_pos: Vector2) -> void:
	var new_platform: Node2D = platform_scene.instantiate() as Node2D
	if new_platform == null:
		print("平台预制体根节点必须是 Node2D！")
		return

	new_platform.global_position = spawn_pos + get_platform_center_offset()
	new_platform.scale = Vector2(texture_scale_multiplier, texture_scale_multiplier)
	new_platform.name = "RigidPlatform_" + str(current_platform_count + 1)
	add_child(new_platform)

	placed_platform_rects.append(get_platform_rect(spawn_pos))
	current_platform_count += 1
	print("平台生成于合法位置：", spawn_pos)

func get_platform_rect(spawn_pos: Vector2) -> Rect2:
	return Rect2(spawn_pos, get_platform_footprint_size())

func get_platform_footprint_size() -> Vector2:
	return Vector2(platform_size.x * 1.3, platform_size.y * 1.1) * texture_scale_multiplier

func get_platform_center_offset() -> Vector2:
	return platform_size / 1.55 * texture_scale_multiplier

func get_grid_step() -> Vector2:
	if grid_step.x > 0.0 and grid_step.y > 0.0:
		return grid_step
	var footprint: Vector2 = get_platform_footprint_size()
	var step_length: float = minf(footprint.x, footprint.y) * 0.5
	return Vector2(step_length, step_length)

func snap_to_grid(raw_pos: Vector2) -> Vector2:
	var step: Vector2 = get_grid_step()
	var snapped_x: float = grid_origin.x + roundf((raw_pos.x - grid_origin.x) / step.x) * step.x
	var snapped_y: float = grid_origin.y + roundf((raw_pos.y - grid_origin.y) / step.y) * step.y
	return Vector2(snapped_x, snapped_y)

func _draw() -> void:
	if platform_texture == null:
		return

	var texture_size: Vector2 = platform_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var footprint: Vector2 = get_platform_footprint_size()
	var scale: Vector2 = Vector2(footprint.x / texture_size.x, footprint.y / texture_size.y)
	var preview_color: Color = Color(1, 1, 1, preview_alpha)
	if not can_place_platform_at(cursor_position):
		preview_color = Color(1, 0.25, 0.25, preview_alpha)

	draw_set_transform(to_local(cursor_position), 0.0, scale)
	draw_texture(platform_texture, Vector2.ZERO, preview_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
