extends Node2D

signal platform_spawned(spawn_pos: Vector2, platform: Node2D)
signal platform_removed(spawn_pos: Vector2, platform: Node2D)

const ANSWER_HINT_SCRIPT_PATH: String = "res://script/bridge_build_answer_hint.gd"
const FOCUS_SOLID_META: String = "focus_feedback_solid"
const FOCUS_BASE_MODULATE_META: String = "focus_feedback_base_modulate"

# 导出变量
@export var platform_scene: PackedScene
@export var platform_size: Vector2 = Vector2(100, 35)
@export var preview_alpha: float = 1.0
@export var texture_scale_multiplier: float = 1.0
@export var collision_mask: int = 1
@export var focus_outline_threshold: float = 40.0
@export var focus_half_threshold: float = 60.0
@export var focus_solid_threshold: float = 75.0
@export_range(0.0, 1.0, 0.01) var focus_outline_alpha: float = 0.18
@export_range(0.0, 1.0, 0.01) var focus_half_alpha_start: float = 0.35
@export_range(0.0, 1.0, 0.01) var focus_half_alpha_end: float = 0.55
@export_range(0.0, 1.0, 0.01) var focus_forming_alpha_start: float = 0.65
@export_range(0.0, 1.0, 0.01) var focus_forming_alpha_end: float = 0.95

# 为 Vector2.ZERO 时，自动使用统一的短距离作为一格大小。
@export var grid_step: Vector2 = Vector2.ZERO
@export var grid_origin: Vector2 = Vector2(385, 430)
@export var initial_cursor_position: Vector2 = Vector2(385, 430)
@export var held_move_initial_delay: float = 0.25
@export var held_move_repeat_interval: float = 0.08
@export var use_mouse_position_for_mouse_actions: bool = true

# 最大生成数量
@export var max_platform_count: int = 10
var current_platform_count: int = 0

var space_state: PhysicsDirectSpaceState2D
var cursor_position: Vector2 = Vector2.ZERO
var placed_platform_rects: Array[Rect2] = []
var placed_platform_positions: Array[Vector2] = []
var placed_platform_nodes: Array[Node2D] = []
var held_move_direction: Vector2 = Vector2.ZERO
var held_move_timer: float = 0.0
var keyboard_cursor_active: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO
var preview_texture: Texture2D
var preview_source_scene: PackedScene
var preview_region_rect: Rect2 = Rect2()
var preview_region_enabled: bool = false
var preview_draw_offset: Vector2 = Vector2.ZERO
var preview_draw_size: Vector2 = Vector2.ZERO
var placement_rect_offset: Vector2 = Vector2.ZERO
var placement_rect_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	space_state = get_world_2d().direct_space_state
	refresh_preview_texture()
	cursor_position = snap_to_grid(initial_cursor_position)
	last_mouse_position = get_viewport().get_mouse_position()
	install_answer_hint()
	queue_redraw()

func install_answer_hint() -> void:
	# 自动挂载答案提示脚本。以后新建 bridgebuild 关卡时，只要使用本放置器，
	# 就会自动拥有答案记录按钮和 P 键提示。
	if get_node_or_null("BridgeBuildAnswerHint") != null:
		return
	if get_tree().current_scene != null and get_tree().current_scene.find_child("BridgeBuildAnswerHint", true, false) != null:
		return

	var hint_script := load(ANSWER_HINT_SCRIPT_PATH) as Script
	if hint_script == null:
		print("未找到搭桥答案提示脚本：", ANSWER_HINT_SCRIPT_PATH)
		return

	var hint_node := hint_script.new() as Node
	if hint_node == null:
		print("搭桥答案提示脚本根类型必须是 Node。")
		return

	hint_node.name = "BridgeBuildAnswerHint"
	add_child(hint_node)

func _input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		match get_keycode(key_event):
			KEY_LEFT:
				start_held_move(Vector2.LEFT)
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				start_held_move(Vector2.RIGHT)
				get_viewport().set_input_as_handled()
			KEY_UP:
				start_held_move(Vector2.UP)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				start_held_move(Vector2.DOWN)
				get_viewport().set_input_as_handled()

func get_keycode(key_event: InputEventKey) -> int:
	# 有些键盘布局下 keycode 可能为 0，physical_keycode 更稳定。
	if key_event.keycode != KEY_NONE:
		return key_event.keycode
	return key_event.physical_keycode

func _process(delta: float) -> void:
	update_cursor_control_mode()

	if use_mouse_position_for_mouse_actions and not keyboard_cursor_active:
		cursor_position = snap_to_grid(get_global_mouse_position())
	else:
		update_held_move(delta)
	update_platform_focus_states()
	queue_redraw()

	if Input.is_action_just_pressed("mouse_left") and not is_mouse_over_gui():
		try_spawn_platform(get_mouse_action_position())

	if Input.is_action_just_pressed("mouse_right") and not is_mouse_over_gui():
		remove_platform_at(get_mouse_action_position())

func move_cursor(direction: Vector2) -> void:
	cursor_position = snap_to_grid(cursor_position + direction * get_grid_step())
	queue_redraw()

func start_held_move(direction: Vector2) -> void:
	keyboard_cursor_active = true
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

func get_mouse_action_position() -> Vector2:
	# 鼠标输入动作默认使用真实鼠标位置；如需恢复旧的键盘光标逻辑，
	# 可在检查器里关闭 use_mouse_position_for_mouse_actions。
	if use_mouse_position_for_mouse_actions:
		cursor_position = snap_to_grid(get_global_mouse_position())
		keyboard_cursor_active = false
	return cursor_position

func update_cursor_control_mode() -> void:
	if not use_mouse_position_for_mouse_actions:
		return

	var mouse_position := get_viewport().get_mouse_position()
	if mouse_position.distance_to(last_mouse_position) > 0.1:
		keyboard_cursor_active = false
	last_mouse_position = mouse_position

func is_mouse_over_gui() -> bool:
	# 点击 UI 按钮时不放置 / 删除平台，避免按“记录答案”时误记录一个平台。
	return get_viewport().gui_get_hovered_control() != null

func try_spawn_platform(spawn_pos: Vector2) -> void:
	if platform_scene == null:
		print("请先赋值平台场景！")
		return
	if current_platform_count >= max_platform_count:
		print("已达最大平台数量！")
		return
	if not can_place_platform_at(spawn_pos):
		print("当前位置不能放置平台！")
		return

	spawn_platform(spawn_pos)

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

	var target_rect: Rect2 = get_platform_rect(spawn_pos)
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = target_rect.size

	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, target_rect.position + target_rect.size * 0.5)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	return not space_state.intersect_shape(query, 1).is_empty()

func spawn_platform(spawn_pos: Vector2) -> Node2D:
	var new_platform: Node2D = platform_scene.instantiate() as Node2D
	if new_platform == null:
		print("平台预制体根节点必须是 Node2D！")
		return null

	new_platform.global_position = spawn_pos + get_platform_center_offset()
	new_platform.scale = Vector2(texture_scale_multiplier, texture_scale_multiplier)
	new_platform.name = "RigidPlatform_" + str(current_platform_count + 1)
	apply_platform_focus_state(new_platform, get_current_focus_level())
	add_child(new_platform)

	placed_platform_rects.append(get_platform_rect(spawn_pos))
	placed_platform_positions.append(spawn_pos)
	placed_platform_nodes.append(new_platform)
	current_platform_count += 1
	emit_signal("platform_spawned", spawn_pos, new_platform)
	print("平台生成于合法位置：", spawn_pos)
	return new_platform

func remove_platform_at(spawn_pos: Vector2) -> bool:
	var platform_index := get_platform_index_at(spawn_pos)
	if platform_index == -1:
		print("鼠标位置没有可撤销的平台：", spawn_pos)
		return false

	return remove_platform_by_index(platform_index)

func remove_platform_node(platform: Node2D) -> bool:
	var platform_index := placed_platform_nodes.find(platform)
	if platform_index == -1:
		return false
	return remove_platform_by_index(platform_index)

func remove_platform_by_index(platform_index: int) -> bool:
	if platform_index < 0 or platform_index >= placed_platform_nodes.size():
		return false

	var removed_position := placed_platform_positions[platform_index]
	var removed_platform := placed_platform_nodes[platform_index]

	placed_platform_positions.remove_at(platform_index)
	placed_platform_rects.remove_at(platform_index)
	placed_platform_nodes.remove_at(platform_index)
	current_platform_count = maxi(0, current_platform_count - 1)

	if is_instance_valid(removed_platform):
		removed_platform.queue_free()

	emit_signal("platform_removed", removed_position, removed_platform)
	print("已撤销鼠标位置的平台：", removed_position)
	return true

func get_platform_index_at(spawn_pos: Vector2) -> int:
	var target_rect := get_platform_rect(spawn_pos)
	var target_center := target_rect.position + target_rect.size * 0.5

	for index in range(placed_platform_rects.size() - 1, -1, -1):
		var placed_rect := placed_platform_rects[index]
		if placed_rect.has_point(target_center) or placed_rect.intersects(target_rect, true):
			return index

		if placed_platform_positions[index].distance_to(spawn_pos) <= get_grid_step().length() * 0.5:
			return index

	return -1

func get_platform_rect(spawn_pos: Vector2) -> Rect2:
	return Rect2(spawn_pos + get_platform_placement_offset(), get_platform_placement_size())

func get_platform_placement_offset() -> Vector2:
	if placement_rect_size.x > 0.0 and placement_rect_size.y > 0.0:
		return placement_rect_offset
	return Vector2.ZERO

func get_platform_placement_size() -> Vector2:
	if placement_rect_size.x > 0.0 and placement_rect_size.y > 0.0:
		return placement_rect_size
	return get_platform_footprint_size()

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

func refresh_preview_texture() -> void:
	preview_texture = null
	preview_source_scene = platform_scene
	preview_region_rect = Rect2()
	preview_region_enabled = false
	preview_draw_offset = Vector2.ZERO
	preview_draw_size = Vector2.ZERO
	placement_rect_offset = Vector2.ZERO
	placement_rect_size = Vector2.ZERO

	if platform_scene == null:
		return

	var scene_root: Node = platform_scene.instantiate()
	var sprite: Sprite2D = find_preview_sprite(scene_root)
	if sprite != null and sprite.texture != null:
		preview_texture = sprite.texture
		if sprite.region_enabled and sprite.region_rect.size.x > 0.0 and sprite.region_rect.size.y > 0.0:
			preview_region_enabled = true
			preview_region_rect = sprite.region_rect
		else:
			preview_region_rect = Rect2(Vector2.ZERO, preview_texture.get_size())
		update_preview_draw_rect(sprite, scene_root)
	update_platform_placement_rect(scene_root)
	scene_root.free()

func update_preview_draw_rect(sprite: Sprite2D, scene_root: Node) -> void:
	var sprite_source_size: Vector2 = get_preview_texture_size()
	if sprite_source_size.x <= 0.0 or sprite_source_size.y <= 0.0:
		return

	var sprite_rect_position: Vector2 = sprite.offset
	if sprite.centered:
		sprite_rect_position -= sprite_source_size * 0.5

	var sprite_rect: Rect2 = Rect2(sprite_rect_position, sprite_source_size)
	var sprite_transform: Transform2D = sprite.global_transform
	var scene_root_2d: Node2D = scene_root as Node2D
	if scene_root_2d != null:
		sprite_transform = scene_root_2d.global_transform.affine_inverse() * sprite.global_transform

	var sprite_bounds: Rect2 = get_transformed_rect(sprite_rect, sprite_transform)
	preview_draw_offset = get_platform_center_offset() + sprite_bounds.position * texture_scale_multiplier
	preview_draw_size = sprite_bounds.size * texture_scale_multiplier

func update_platform_placement_rect(scene_root: Node) -> void:
	var collision_bounds: Rect2 = get_collision_shape_bounds(scene_root, scene_root)
	if collision_bounds.size.x <= 0.0 or collision_bounds.size.y <= 0.0:
		return

	placement_rect_offset = get_platform_center_offset() + collision_bounds.position * texture_scale_multiplier
	placement_rect_size = collision_bounds.size * texture_scale_multiplier

func get_collision_shape_bounds(node: Node, scene_root: Node) -> Rect2:
	var bounds: Rect2 = Rect2()
	var has_bounds: bool = false

	var collision_shape: CollisionShape2D = node as CollisionShape2D
	if collision_shape != null and not collision_shape.disabled and collision_shape.shape != null:
		var collision_parent: Node = collision_shape.get_parent()
		if not (collision_parent is Area2D):
			var shape_bounds: Rect2 = get_shape_bounds(collision_shape.shape)
			if shape_bounds.size.x > 0.0 and shape_bounds.size.y > 0.0:
				var shape_transform: Transform2D = collision_shape.global_transform
				var scene_root_2d: Node2D = scene_root as Node2D
				if scene_root_2d != null:
					shape_transform = scene_root_2d.global_transform.affine_inverse() * collision_shape.global_transform
				bounds = get_transformed_rect(shape_bounds, shape_transform)
				has_bounds = true

	for child in node.get_children():
		var child_bounds: Rect2 = get_collision_shape_bounds(child, scene_root)
		if child_bounds.size.x <= 0.0 or child_bounds.size.y <= 0.0:
			continue
		if has_bounds:
			bounds = get_rect_union(bounds, child_bounds)
		else:
			bounds = child_bounds
			has_bounds = true

	return bounds

func get_shape_bounds(shape: Shape2D) -> Rect2:
	var rectangle: RectangleShape2D = shape as RectangleShape2D
	if rectangle != null:
		return Rect2(-rectangle.size * 0.5, rectangle.size)
	return Rect2()

func get_rect_union(first: Rect2, second: Rect2) -> Rect2:
	var min_pos: Vector2 = Vector2(
		minf(first.position.x, second.position.x),
		minf(first.position.y, second.position.y)
	)
	var max_pos: Vector2 = Vector2(
		maxf(first.position.x + first.size.x, second.position.x + second.size.x),
		maxf(first.position.y + first.size.y, second.position.y + second.size.y)
	)
	return Rect2(min_pos, max_pos - min_pos)

func get_transformed_rect(rect: Rect2, transform: Transform2D) -> Rect2:
	var top_left: Vector2 = transform * rect.position
	var top_right: Vector2 = transform * Vector2(rect.position.x + rect.size.x, rect.position.y)
	var bottom_left: Vector2 = transform * Vector2(rect.position.x, rect.position.y + rect.size.y)
	var bottom_right: Vector2 = transform * (rect.position + rect.size)

	var min_pos: Vector2 = Vector2(
		minf(minf(top_left.x, top_right.x), minf(bottom_left.x, bottom_right.x)),
		minf(minf(top_left.y, top_right.y), minf(bottom_left.y, bottom_right.y))
	)
	var max_pos: Vector2 = Vector2(
		maxf(maxf(top_left.x, top_right.x), maxf(bottom_left.x, bottom_right.x)),
		maxf(maxf(top_left.y, top_right.y), maxf(bottom_left.y, bottom_right.y))
	)
	return Rect2(min_pos, max_pos - min_pos)

func find_preview_sprite(node: Node) -> Sprite2D:
	var sprite: Sprite2D = node as Sprite2D
	if sprite != null and sprite.texture != null:
		return sprite

	for child in node.get_children():
		var child_sprite: Sprite2D = find_preview_sprite(child)
		if child_sprite != null:
			return child_sprite

	return null

func get_preview_texture_size() -> Vector2:
	if preview_texture == null:
		return Vector2.ZERO
	if preview_region_enabled:
		return preview_region_rect.size
	return preview_texture.get_size()

func get_current_focus_level() -> float:
	var focus_source := get_node_or_null("/root/concentration")
	if focus_source == null:
		return 0.0
	var focus_value: Variant = focus_source.get("focus_level")
	if typeof(focus_value) == TYPE_NIL:
		return 0.0
	return clampf(float(focus_value), 0.0, 100.0)

func get_focus_platform_alpha(focus_level: float) -> float:
	var focus := clampf(focus_level, 0.0, 100.0)
	if focus < focus_outline_threshold:
		return focus_outline_alpha
	if focus < focus_half_threshold:
		var half_t := clampf(
			(focus - focus_outline_threshold) / maxf(0.001, focus_half_threshold - focus_outline_threshold),
			0.0,
			1.0
		)
		return lerpf(focus_half_alpha_start, focus_half_alpha_end, half_t)
	if focus < focus_solid_threshold:
		var forming_t := clampf(
			(focus - focus_half_threshold) / maxf(0.001, focus_solid_threshold - focus_half_threshold),
			0.0,
			1.0
		)
		return lerpf(focus_forming_alpha_start, focus_forming_alpha_end, forming_t)
	return 1.0

func update_platform_focus_states() -> void:
	var focus_level := get_current_focus_level()
	for platform in placed_platform_nodes:
		if is_instance_valid(platform):
			apply_platform_focus_state(platform, focus_level)

func apply_platform_focus_state(platform: Node2D, focus_level: float) -> void:
	if not platform.has_meta(FOCUS_BASE_MODULATE_META):
		platform.set_meta(FOCUS_BASE_MODULATE_META, platform.modulate)

	var was_locked_solid := platform.has_meta(FOCUS_SOLID_META) and bool(platform.get_meta(FOCUS_SOLID_META))
	var is_locked_solid := was_locked_solid or focus_level >= focus_solid_threshold

	var base_modulate: Color = platform.modulate
	var base_modulate_value: Variant = platform.get_meta(FOCUS_BASE_MODULATE_META)
	if base_modulate_value is Color:
		base_modulate = base_modulate_value
	var alpha := 1.0 if is_locked_solid else get_focus_platform_alpha(focus_level)
	platform.modulate = Color(base_modulate.r, base_modulate.g, base_modulate.b, base_modulate.a * alpha)

	if not platform.has_meta(FOCUS_SOLID_META) or was_locked_solid != is_locked_solid:
		set_platform_collision_enabled(platform, is_locked_solid)
		platform.set_meta(FOCUS_SOLID_META, is_locked_solid)

func set_platform_collision_enabled(node: Node, enabled: bool) -> void:
	var collision_shape := node as CollisionShape2D
	if collision_shape != null:
		if collision_shape.is_inside_tree():
			collision_shape.set_deferred("disabled", not enabled)
		else:
			collision_shape.disabled = not enabled

	var collision_polygon := node as CollisionPolygon2D
	if collision_polygon != null:
		if collision_polygon.is_inside_tree():
			collision_polygon.set_deferred("disabled", not enabled)
		else:
			collision_polygon.disabled = not enabled

	for child in node.get_children():
		set_platform_collision_enabled(child, enabled)

func _draw() -> void:
	if preview_texture == null or preview_source_scene != platform_scene:
		refresh_preview_texture()
	if preview_texture == null:
		return

	var texture_size: Vector2 = get_preview_texture_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var focus_preview_alpha := clampf(get_focus_platform_alpha(get_current_focus_level()) * preview_alpha, 0.0, 1.0)
	var preview_color: Color = Color(1, 1, 1, focus_preview_alpha)
	if not can_place_platform_at(cursor_position):
		preview_color = Color(1, 0.25, 0.25, focus_preview_alpha)

	var draw_size: Vector2 = preview_draw_size
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		draw_size = get_platform_footprint_size()

	var draw_rect: Rect2 = Rect2(to_local(cursor_position + preview_draw_offset), draw_size)
	if preview_region_enabled:
		draw_texture_rect_region(preview_texture, draw_rect, preview_region_rect, preview_color)
	else:
		draw_texture_rect(preview_texture, draw_rect, false, preview_color)
