extends Node2D

const START_SEGMENT: PackedScene = preload("res://element/parkourmap/parkourmap1.tscn")
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
var last_segment_scene: PackedScene
var next_segment_x := 0.0
var next_surface_y := 0.0
var last_player_x := 0.0


func _ready() -> void:
	randomize()
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
	for scene in SEGMENT_SCENES:
		var instance := scene.instantiate()
		if _contains_tiles(instance):
			playable_segments.append(scene)
		else:
			push_warning("Skipping empty parkour segment: %s" % scene.resource_path)
		instance.free()

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
	next_surface_y = starting_ground_y

	if playable_segments.is_empty():
		return

	var first_scene := START_SEGMENT if playable_segments.has(START_SEGMENT) else _take_random_segment()
	_spawn_segment(first_scene, true)
	while active_segments.size() < max(initial_segment_count, 1):
		_spawn_segment(_take_random_segment())
	_fill_forward()


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
	var entry_y: float = float(measurements["entry_y"])
	var exit_y: float = float(measurements["exit_y"])
	var alignment_y: float = float(measurements["start_y"]) if is_starting_segment else entry_y
	segment.position.y = next_surface_y - alignment_y
	segment.set_meta("end_x", next_segment_x + width)
	active_segments.append(segment)
	next_segment_x += width + segment_spacing
	next_surface_y = segment.position.y + exit_y


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
	var start_sample_x: float = player.position.x
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
