extends Node2D

const SEGMENT_SCENES: Array[PackedScene] = [
	preload("res://element/parkourmap/parkourmap1.tscn"),
	preload("res://element/parkourmap/parkourmap2.tscn"),
	preload("res://element/parkourmap/parkourmap3.tscn"),
	preload("res://element/parkourmap/parkourmap4.tscn"),
	preload("res://element/parkourmap/parkourmap5.tscn"),
	preload("res://element/parkourmap/parkourmap6.tscn"),
	preload("res://element/parkourmap/parkourmap7.tscn"),
	preload("res://element/parkourmap/parkourmap8.tscn"),
	preload("res://element/parkourmap/parkourmap9.tscn"),
	preload("res://element/parkourmap/parkourmap10.tscn"),
	preload("res://element/parkourmap/parkourmap11.tscn"),
	preload("res://element/parkourmap/parkourmap12.tscn"),
	preload("res://element/parkourmap/parkourmap13.tscn"),
	preload("res://element/parkourmap/parkourmap14.tscn"),
	preload("res://element/parkourmap/parkourmap15.tscn"),
	preload("res://element/parkourmap/parkourmap16.tscn"),
]
const KILLZONE_SCRIPT: Script = preload("res://script/killzone.gd")

@export var initial_segment_count: int = 3
@export var generation_distance: float = 7000.0
@export var recycle_distance: float = 5000.0
@export var segment_spacing: float = 0.0
@export var minimum_segment_length: float = 640.0
@export var starting_ground_y: float = 740.0

@onready var player: CharacterBody2D = $player
@onready var segment_container: Node2D = $Segments

var playable_segments: Array[PackedScene] = []
var segment_bag: Array[PackedScene] = []
var active_segments: Array[Node2D] = []
var start_segment_scene: PackedScene
var last_segment_scene: PackedScene
var next_segment_x := 0.0
var last_player_x := 0.0
var player_start_position := Vector2.ZERO
var player_ground_offset_y := 0.0
var fixed_segment_y := 0.0
var has_fixed_segment_y := false


func _ready() -> void:
	randomize()
	player_start_position = player.position
	player_ground_offset_y = starting_ground_y - player_start_position.y
	_collect_playable_segments()
	_rebuild_course()
	last_player_x = player.position.x


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("mouse_right"):
		get_tree().reload_current_scene()
		return

	if player.position.x < last_player_x - 1000.0:
		_rebuild_course()

	_fill_forward()
	_recycle_passed_segments()
	last_player_x = player.position.x


func _collect_playable_segments() -> void:
	playable_segments.clear()
	var configured_segments := _get_configured_segment_scenes()
	start_segment_scene = configured_segments[0] if not configured_segments.is_empty() else null

	for scene in configured_segments:
		var instance := scene.instantiate()
		if _contains_tiles(instance):
			playable_segments.append(scene)
		else:
			push_warning("Skipping empty parkour segment: %s" % scene.resource_path)
		instance.free()

	if playable_segments.is_empty():
		push_warning("No playable parkour segments were found in the selected pool. Falling back to all segments.")
		for scene in SEGMENT_SCENES:
			var instance := scene.instantiate()
			if _contains_tiles(instance):
				playable_segments.append(scene)
			instance.free()
		start_segment_scene = playable_segments[0] if not playable_segments.is_empty() else null

	if playable_segments.is_empty():
		push_error("No playable parkour segments were found.")


func _rebuild_course() -> void:
	for segment in active_segments:
		if is_instance_valid(segment):
			segment_container.remove_child(segment)
			segment.queue_free()

	active_segments.clear()
	segment_bag.clear()
	last_segment_scene = null
	next_segment_x = 0.0
	fixed_segment_y = 0.0
	has_fixed_segment_y = false

	if playable_segments.is_empty():
		return

	var first_scene := start_segment_scene if start_segment_scene != null and playable_segments.has(start_segment_scene) else _take_random_segment()
	_spawn_segment(first_scene, true)
	while active_segments.size() < max(initial_segment_count, 1):
		_spawn_segment(_take_random_segment())
	_fill_forward()


func _get_configured_segment_scenes() -> Array[PackedScene]:
	var requested_paths := _get_requested_segment_paths()
	var configured_segments: Array[PackedScene] = []
	for scene in SEGMENT_SCENES:
		if requested_paths.is_empty() or requested_paths.has(scene.resource_path):
			configured_segments.append(scene)

	if configured_segments.is_empty():
		push_warning("Parkour segment pool did not match any scene path. Falling back to all segments.")
		for scene in SEGMENT_SCENES:
			configured_segments.append(scene)

	return configured_segments


func _get_requested_segment_paths() -> Array[String]:
	var requested_paths: Array[String] = []
	var session := get_node_or_null("/root/game_session")
	if session == null or not session.has_method("get_current_parkour_segment_paths"):
		return requested_paths

	var raw_paths = session.call("get_current_parkour_segment_paths")
	if raw_paths is Array:
		for path in raw_paths:
			if path is String and not path.is_empty():
				requested_paths.append(path)
	return requested_paths


func _fill_forward() -> void:
	if playable_segments.is_empty():
		return

	while next_segment_x < player.position.x + generation_distance:
		_spawn_segment(_take_random_segment())


func _recycle_passed_segments() -> void:
	while active_segments.size() > 2:
		var first_segment := active_segments[0]
		var segment_end := float(first_segment.get_meta("end_x", 0.0))
		if segment_end >= player.position.x - recycle_distance:
			return

		active_segments.pop_front()
		first_segment.queue_free()


func _take_random_segment() -> PackedScene:
	if segment_bag.is_empty():
		segment_bag = playable_segments.duplicate()
		segment_bag.shuffle()
		if segment_bag.size() > 1 and segment_bag.back() == last_segment_scene:
			var swap_index := randi_range(0, segment_bag.size() - 2)
			var replacement := segment_bag[swap_index]
			segment_bag[swap_index] = segment_bag.back()
			segment_bag[segment_bag.size() - 1] = replacement

	var selected: PackedScene = segment_bag.pop_back() as PackedScene
	last_segment_scene = selected
	return selected


func _spawn_segment(scene: PackedScene, is_starting_segment: bool = false) -> void:
	var segment := scene.instantiate() as Node2D
	if segment == null:
		push_error("Parkour segment root must inherit Node2D: %s" % scene.resource_path)
		return

	segment.position = Vector2(next_segment_x, 0.0)
	segment_container.add_child(segment)
	_connect_segment_body_entered_signals(segment)
	var measurements: Dictionary = _measure_segment(segment)
	var width: float = maxf(float(measurements["right_edge"]), minimum_segment_length)
	var respawn_y: float = float(measurements["start_y"])
	if not has_fixed_segment_y:
		fixed_segment_y = starting_ground_y - respawn_y
		has_fixed_segment_y = true
	segment.position.y = fixed_segment_y
	var segment_start_x := to_local(segment.to_global(Vector2.ZERO)).x
	var segment_end_x := to_local(segment.to_global(Vector2(width, 0.0))).x
	var respawn_position := to_local(segment.to_global(Vector2(player_start_position.x, respawn_y - player_ground_offset_y)))
	segment.set_meta("start_x", segment_start_x)
	segment.set_meta("end_x", segment_end_x)
	segment.set_meta("respawn_position", respawn_position)
	active_segments.append(segment)
	next_segment_x += width + segment_spacing


func _contains_tiles(node: Node) -> bool:
	var layers: Array[TileMapLayer] = []
	_collect_tile_layers(node, layers)
	for layer in layers:
		if layer.get_used_rect().size.x > 0:
			return true
	return false


func _measure_segment(segment: Node2D) -> Dictionary:
	var layers: Array[TileMapLayer] = []
	_collect_tile_layers(segment, layers)
	var cell_rects: Array[Rect2] = []
	for layer in layers:
		if layer.tile_set == null:
			continue
		var tile_size := Vector2(layer.tile_set.tile_size)
		for cell: Vector2i in layer.get_used_cells():
			var top_left := segment.to_local(layer.to_global(Vector2(cell.x, cell.y) * tile_size))
			var bottom_right := segment.to_local(layer.to_global(Vector2(cell.x + 1, cell.y + 1) * tile_size))
			var cell_position := Vector2(
				minf(top_left.x, bottom_right.x),
				minf(top_left.y, bottom_right.y)
			)
			var cell_size := Vector2(
				absf(bottom_right.x - top_left.x),
				absf(bottom_right.y - top_left.y)
			)
			cell_rects.append(Rect2(cell_position, cell_size))

	if cell_rects.is_empty():
		return {
			"right_edge": minimum_segment_length,
			"entry_y": starting_ground_y,
			"exit_y": starting_ground_y,
			"start_y": starting_ground_y,
		}

	var left_edge: float = cell_rects[0].position.x
	var right_edge: float = cell_rects[0].end.x
	for rect in cell_rects:
		left_edge = minf(left_edge, rect.position.x)
		right_edge = maxf(right_edge, rect.end.x)

	var entry_y := INF
	var exit_y := INF
	var start_y := INF
	var start_sample_x: float = player_start_position.x
	for rect in cell_rects:
		if rect.position.x <= left_edge + 1.0:
			entry_y = minf(entry_y, rect.position.y)
		if rect.end.x >= right_edge - 1.0:
			exit_y = minf(exit_y, rect.position.y)
		if rect.position.x <= start_sample_x and rect.end.x >= start_sample_x:
			start_y = minf(start_y, rect.position.y)

	if start_y == INF:
		start_y = entry_y

	return {
		"right_edge": right_edge,
		"entry_y": entry_y,
		"exit_y": exit_y,
		"start_y": start_y,
	}


func get_respawn_position_for_player(player_node: Node2D) -> Vector2:
	var player_x := to_local(player_node.global_position).x
	var segment := _find_segment_for_x(player_x)
	if segment == null:
		return to_global(player_start_position)

	var respawn_position := player_start_position
	var respawn_meta = segment.get_meta("respawn_position", player_start_position)
	if respawn_meta is Vector2:
		respawn_position = respawn_meta
	return to_global(respawn_position)


func sync_after_player_respawn() -> void:
	last_player_x = player.position.x
	_fill_forward()


func _find_segment_for_x(player_x: float) -> Node2D:
	var fallback_segment: Node2D = null
	var fallback_start_x := -INF

	for segment in active_segments:
		if not is_instance_valid(segment):
			continue

		var start_x := float(segment.get_meta("start_x", 0.0))
		var end_x := float(segment.get_meta("end_x", start_x))
		if player_x >= start_x and player_x <= end_x:
			return segment

		if start_x <= player_x and start_x > fallback_start_x:
			fallback_segment = segment
			fallback_start_x = start_x

	if fallback_segment != null:
		return fallback_segment

	if not active_segments.is_empty():
		return active_segments[0]

	return null


func _collect_tile_layers(node: Node, layers: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		layers.append(node as TileMapLayer)
	for child: Node in node.get_children():
		_collect_tile_layers(child, layers)


func _connect_segment_body_entered_signals(node: Node) -> void:
	if node.has_signal("body_entered"):
		if node.is_in_group("obstacle"):
			var hit_callback := Callable(player, "_on_body_entered")
			if not node.is_connected("body_entered", hit_callback):
				node.connect("body_entered", hit_callback)

		if _is_killzone_node(node):
			var killzone_callback := Callable(player, "_on_killzone_body_entered")
			if not node.is_connected("body_entered", killzone_callback):
				node.connect("body_entered", killzone_callback)

	for child: Node in node.get_children():
		_connect_segment_body_entered_signals(child)


func _is_killzone_node(node: Node) -> bool:
	if node.is_in_group("killzone") or node.is_in_group("KillZone"):
		return true

	if String(node.name).to_lower().begins_with("killzone"):
		return true

	var script: Script = node.get_script() as Script
	return script != null and script.resource_path == KILLZONE_SCRIPT.resource_path
