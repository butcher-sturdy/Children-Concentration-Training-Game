extends Node2D
class_name BridgeBuildAnswerHint


const ANSWER_SAVE_PATH: String = "res://script/bridge_build_answers.json"
const STORAGE_PLATFORM_META: String = "bridge_build_answer_storage_platform"

# Optional per-scene override. Leave empty to use bridge_build_answers.json.
@export var override_answer_positions: Array[Vector2] = []

# Hint input and trigger condition.
@export var hint_action: String = "p"
@export var use_focus_condition: bool = false
@export var focus_trigger_threshold: float = 75.0
@export var failure_hint_threshold: int = 3
@export var impatient_early_hint_offset: int = 1
@export var emotion_file_path: String = "C:/Users/ASUS/Desktop/emotion.txt"
@export var emotion_read_interval: float = 0.25
@export var emotion_trigger_threshold: float = 7.25
@export var emotion_release_threshold: float = 6.4
@export var emotion_smoothing_seconds: float = 1.2
@export var impatient_required_seconds: float = 2.5

# Hint display settings.
@export var hint_alpha: float = 0.42
@export var flash_low_alpha: float = 0.12
@export var flash_high_alpha: float = 0.82
@export var flash_count: int = 5
@export var flash_half_interval: float = 0.12
@export var hint_z_index: int = 20

# Runtime answer-recording button settings.
@export var storage_button_text: String = "Record Answer"
@export var saving_button_text: String = "Save Answer"
@export var storage_button_offset: Vector2 = Vector2(-220, 40)
@export var storage_button_size: Vector2 = Vector2(170, 54)

var answer_positions: Array[Vector2] = []
var hint_visuals: Array[Node2D] = []
var next_hint_index: int = 0
var is_flashing: bool = false
var active_flash_tween_count: int = 0
var pending_hint_target_count: int = 0

var emotion_read_timer: float = 0.0
var raw_emotion_level: float = 0.0
var smoothed_emotion_level: float = 0.0
var has_emotion_sample: bool = false
var impatient_hold_seconds: float = 0.0
var sustained_impatient: bool = false
var last_known_failure_count: int = 0
var auto_hint_start_failure: int = 0

var storage_mode_enabled: bool = false
var editing_positions: Array[Vector2] = []
var editing_platforms: Array[Node2D] = []
var ignore_spawn_signal: bool = false
var ignore_remove_signal: bool = false

var platform_spawner: Node2D
var storage_button: Button

func _ready() -> void:
	platform_spawner = _find_platform_spawner()
	_connect_platform_spawner()
	_connect_game_session()
	_load_answers_for_current_scene()
	_create_storage_button()
	call_deferred("_sync_failure_count_from_session")

func _process(delta: float) -> void:
	if storage_mode_enabled:
		return
	_update_emotion_state(delta)
	_maybe_trigger_auto_hint()
	if not _hint_input_pressed():
		return
	if not _hint_condition_met():
		return
	trigger_hint()

func trigger_hint() -> void:
	if next_hint_index < answer_positions.size():
		reveal_hints_up_to(next_hint_index + 1, true)
		return
	if answer_positions.is_empty():
		print("No saved bridge build answer hints for the current scene.")
		return
	if platform_spawner == null or is_flashing:
		return

	if not hint_visuals.is_empty():
		_flash_hint_indices([hint_visuals.size() - 1])

func reveal_hints_up_to(target_count: int, report_missing: bool = false) -> void:
	if answer_positions.is_empty():
		if report_missing:
			print("No saved bridge build answer hints for the current scene.")
		return
	if platform_spawner == null:
		return

	var clamped_target := clampi(target_count, 0, answer_positions.size())
	if clamped_target <= next_hint_index:
		return

	if is_flashing:
		pending_hint_target_count = maxi(pending_hint_target_count, clamped_target)
		return

	var flash_indices: Array[int] = []
	while next_hint_index < clamped_target:
		var revealed_index := next_hint_index
		var new_visual := _create_hint_visual(answer_positions[revealed_index])
		if new_visual == null:
			return

		hint_visuals.append(new_visual)
		flash_indices.append(revealed_index)
		next_hint_index += 1

	_flash_hint_indices(flash_indices)

func _connect_game_session() -> void:
	add_to_group("bridge_hint")
	var session := get_node_or_null("/root/game_session")
	if session == null:
		return
	if session.has_signal("bridge_level_started"):
		var started_callable := Callable(self, "_on_bridge_level_started")
		if not session.is_connected("bridge_level_started", started_callable):
			session.connect("bridge_level_started", started_callable)
	if session.has_method("get_bridge_failure_count"):
		last_known_failure_count = int(session.call("get_bridge_failure_count"))
	if session.has_signal("bridge_failure_recorded"):
		var failure_callable := Callable(self, "_on_bridge_failure_recorded")
		if not session.is_connected("bridge_failure_recorded", failure_callable):
			session.connect("bridge_failure_recorded", failure_callable)

func _on_bridge_level_started(level_path: String, failure_count: int) -> void:
	if level_path != _get_current_scene_path():
		return
	_reset_runtime_hint_state(failure_count, true)

func _on_bridge_failure_recorded(failure_count: int) -> void:
	last_known_failure_count = failure_count
	_maybe_trigger_auto_hint()

func _sync_failure_count_from_session() -> void:
	var session := get_node_or_null("/root/game_session")
	if session == null or not session.has_method("get_bridge_failure_count"):
		return

	var failure_count := int(session.call("get_bridge_failure_count"))
	if failure_count <= 0:
		_reset_runtime_hint_state(0, true)
		return

	last_known_failure_count = failure_count
	_maybe_trigger_auto_hint()

func _reset_runtime_hint_state(failure_count: int = 0, clear_visuals: bool = true) -> void:
	last_known_failure_count = maxi(failure_count, 0)
	next_hint_index = 0
	pending_hint_target_count = 0
	auto_hint_start_failure = 0
	if clear_visuals:
		_clear_hint_visuals()

func _maybe_trigger_auto_hint() -> void:
	if storage_mode_enabled:
		return
	var start_failure := auto_hint_start_failure
	if start_failure <= 0:
		start_failure = _get_auto_hint_start_failure()
	if last_known_failure_count < start_failure:
		return

	if auto_hint_start_failure <= 0:
		auto_hint_start_failure = start_failure
	var target_count := last_known_failure_count - start_failure + 1
	reveal_hints_up_to(target_count)

func _get_auto_hint_start_failure() -> int:
	var base_threshold := maxi(failure_hint_threshold, 1)
	if sustained_impatient:
		return maxi(base_threshold - maxi(impatient_early_hint_offset, 0), 1)
	return base_threshold

func _update_emotion_state(delta: float) -> void:
	emotion_read_timer += delta
	if emotion_read_timer >= emotion_read_interval:
		emotion_read_timer = 0.0
		_read_emotion_level()

	if not has_emotion_sample:
		return

	var alpha := 1.0 - exp(-delta / maxf(emotion_smoothing_seconds, 0.001))
	smoothed_emotion_level = lerpf(smoothed_emotion_level, raw_emotion_level, clampf(alpha, 0.0, 1.0))

	if smoothed_emotion_level >= emotion_trigger_threshold:
		impatient_hold_seconds += delta
	elif smoothed_emotion_level <= emotion_release_threshold:
		impatient_hold_seconds = 0.0
	else:
		impatient_hold_seconds = maxf(impatient_hold_seconds - delta * 0.5, 0.0)

	var was_sustained := sustained_impatient
	sustained_impatient = impatient_hold_seconds >= impatient_required_seconds
	if sustained_impatient and not was_sustained:
		_maybe_trigger_auto_hint()

func _read_emotion_level() -> void:
	if emotion_file_path.is_empty() or not FileAccess.file_exists(emotion_file_path):
		return

	var file := FileAccess.open(emotion_file_path, FileAccess.READ)
	if file == null:
		return

	var content := file.get_as_text().strip_edges()
	file.close()
	if not content.is_valid_float():
		return

	raw_emotion_level = clampf(float(content), 0.0, 10.0)
	if not has_emotion_sample:
		smoothed_emotion_level = raw_emotion_level
		has_emotion_sample = true

func toggle_storage_mode() -> void:
	if storage_mode_enabled:
		_exit_storage_mode()
	else:
		_enter_storage_mode()

func _enter_storage_mode() -> void:
	if platform_spawner == null:
		print("Cannot enter answer storage mode: platform_spawn was not found.")
		return

	storage_mode_enabled = true
	_clear_hint_visuals()
	_load_answers_for_current_scene()
	editing_positions.clear()
	editing_platforms.clear()

	# Recreate saved answer platforms for editing without recording them again.
	ignore_spawn_signal = true
	for saved_position in answer_positions:
		var platform := platform_spawner.call("spawn_platform", saved_position) as Node2D
		if platform != null:
			_register_editing_platform(saved_position, platform)
	ignore_spawn_signal = false

	_update_storage_button()
	print("Entered answer storage mode.")

func _exit_storage_mode() -> void:
	var saved_positions: Array[Vector2] = []
	for editing_position in editing_positions:
		saved_positions.append(editing_position)
	_save_answers_for_current_scene(saved_positions)

	storage_mode_enabled = false
	_clear_editing_platforms()

	answer_positions.clear()
	for saved_position in saved_positions:
		answer_positions.append(saved_position)
	next_hint_index = 0

	_update_storage_button()
	print("Answer positions saved.")

func _connect_platform_spawner() -> void:
	if platform_spawner == null:
		return
	if platform_spawner.has_signal("platform_spawned"):
		var spawned_callable := Callable(self, "_on_platform_spawned")
		if not platform_spawner.is_connected("platform_spawned", spawned_callable):
			platform_spawner.connect("platform_spawned", spawned_callable)
	if platform_spawner.has_signal("platform_removed"):
		var removed_callable := Callable(self, "_on_platform_removed")
		if not platform_spawner.is_connected("platform_removed", removed_callable):
			platform_spawner.connect("platform_removed", removed_callable)

func _on_platform_spawned(spawn_pos: Vector2, platform: Node2D) -> void:
	if not storage_mode_enabled or ignore_spawn_signal:
		return
	_register_editing_platform(spawn_pos, platform)

func _on_platform_removed(spawn_pos: Vector2, platform: Node2D) -> void:
	if not storage_mode_enabled or ignore_remove_signal:
		return

	var index := editing_platforms.find(platform)
	if index == -1:
		index = _find_editing_position_index(spawn_pos)
	if index == -1:
		return

	editing_platforms.remove_at(index)
	editing_positions.remove_at(index)

func _register_editing_platform(spawn_pos: Vector2, platform: Node2D) -> void:
	platform.set_meta(STORAGE_PLATFORM_META, true)
	platform.name = "AnswerStoragePlatform_" + str(editing_platforms.size() + 1)
	editing_positions.append(spawn_pos)
	editing_platforms.append(platform)

func _find_editing_position_index(spawn_pos: Vector2) -> int:
	for index in range(editing_positions.size()):
		if editing_positions[index].distance_to(spawn_pos) <= 1.0:
			return index
	return -1

func _clear_editing_platforms() -> void:
	ignore_remove_signal = true
	for platform in editing_platforms.duplicate():
		if is_instance_valid(platform):
			if platform_spawner != null and platform_spawner.has_method("remove_platform_node"):
				platform_spawner.call("remove_platform_node", platform)
			else:
				platform.queue_free()
	ignore_remove_signal = false

	editing_platforms.clear()
	editing_positions.clear()

func _load_answers_for_current_scene() -> void:
	answer_positions.clear()
	_reset_runtime_hint_state(0, true)

	if not override_answer_positions.is_empty():
		for answer_position in override_answer_positions:
			answer_positions.append(answer_position)
		return

	var scene_path := _get_current_scene_path()
	var saved_answers := _load_answer_file()
	if saved_answers.has(scene_path):
		for saved_position in _positions_from_variant(saved_answers[scene_path]):
			answer_positions.append(saved_position)
		return

func _save_answers_for_current_scene(positions: Array[Vector2]) -> void:
	var scene_path := _get_current_scene_path()
	if scene_path.is_empty():
		return

	var all_answers := _load_answer_file()
	all_answers[scene_path] = _positions_to_json_array(positions)

	var file := FileAccess.open(ANSWER_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("Failed to write bridge build answer file: ", ANSWER_SAVE_PATH)
		return

	file.store_string(JSON.stringify(all_answers, "\t"))
	file.close()
	print("Saved bridge build answer hints: ", ProjectSettings.globalize_path(ANSWER_SAVE_PATH))

func _load_answer_file() -> Dictionary:
	if not FileAccess.file_exists(ANSWER_SAVE_PATH):
		return {}

	var file := FileAccess.open(ANSWER_SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var content := file.get_as_text()
	file.close()
	if content.strip_edges().is_empty():
		return {}

	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		return parsed
	return {}

func _positions_to_json_array(positions: Array[Vector2]) -> Array:
	var result: Array = []
	for position in positions:
		result.append([position.x, position.y])
	return result

func _positions_from_variant(value) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if not (value is Array):
		return positions

	for item in value:
		if item is Array and item.size() >= 2:
			positions.append(Vector2(float(item[0]), float(item[1])))
		elif item is Dictionary and item.has("x") and item.has("y"):
			positions.append(Vector2(float(item["x"]), float(item["y"])))
	return positions

func _hint_input_pressed() -> bool:
	if hint_action.is_empty():
		return false
	if not InputMap.has_action(hint_action):
		return false
	return Input.is_action_just_pressed(hint_action)

func _hint_condition_met() -> bool:
	if not use_focus_condition:
		return true
	return concentration.focus_level >= focus_trigger_threshold

func _create_storage_button() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "AnswerStorageCanvas"
	add_child(canvas_layer)

	storage_button = Button.new()
	storage_button.name = "AnswerStorageButton"
	storage_button.anchor_left = 1.0
	storage_button.anchor_right = 1.0
	storage_button.anchor_top = 0.0
	storage_button.anchor_bottom = 0.0
	storage_button.offset_left = storage_button_offset.x
	storage_button.offset_top = storage_button_offset.y
	storage_button.offset_right = storage_button_offset.x + storage_button_size.x
	storage_button.offset_bottom = storage_button_offset.y + storage_button_size.y
	storage_button.text = storage_button_text
	storage_button.tooltip_text = "Record bridge-build answer hint positions for this level."
	storage_button.pressed.connect(Callable(self, "toggle_storage_mode"))
	canvas_layer.add_child(storage_button)

func _update_storage_button() -> void:
	if storage_button == null:
		return
	storage_button.text = saving_button_text if storage_mode_enabled else storage_button_text

func _create_hint_visual(answer_position: Vector2) -> Node2D:
	var platform_scene := _get_platform_scene()
	if platform_scene == null:
		return null

	var visual := platform_scene.instantiate() as Node2D
	if visual == null:
		return null

	visual.name = "AnswerHint_" + str(hint_visuals.size() + 1)
	visual.global_position = answer_position + _get_platform_center_offset()
	visual.scale = Vector2(_get_platform_scale(), _get_platform_scale())
	visual.modulate = Color(1.0, 1.0, 1.0, hint_alpha)
	visual.z_index = hint_z_index
	visual.z_as_relative = false

	_disable_hint_collision(visual)
	add_child(visual)
	return visual

func _flash_hint_indices(indices: Array[int]) -> void:
	is_flashing = true
	var flash_targets: Array[CanvasItem] = []

	for index in indices:
		if index < 0 or index >= hint_visuals.size():
			continue
		flash_targets.append(hint_visuals[index])

	if flash_targets.is_empty():
		is_flashing = false
		return

	active_flash_tween_count = flash_targets.size()
	for target in flash_targets:
		_flash_one_hint(target)

func _flash_one_hint(visual: CanvasItem) -> void:
	var normal_color := Color(1.0, 1.0, 1.0, hint_alpha)
	var low_color := Color(1.0, 1.0, 1.0, flash_low_alpha)
	var high_color := Color(1.0, 1.0, 1.0, flash_high_alpha)

	var tween := create_tween()
	for i in range(flash_count):
		tween.tween_property(visual, "modulate", high_color, flash_half_interval)
		tween.tween_property(visual, "modulate", low_color, flash_half_interval)

	tween.tween_property(visual, "modulate", normal_color, flash_half_interval)
	tween.tween_callback(_on_hint_flash_finished)

func _on_hint_flash_finished() -> void:
	active_flash_tween_count -= 1
	if active_flash_tween_count <= 0:
		active_flash_tween_count = 0
		is_flashing = false
		if pending_hint_target_count > next_hint_index:
			var target_count := pending_hint_target_count
			pending_hint_target_count = 0
			call_deferred("reveal_hints_up_to", target_count, false)
		else:
			pending_hint_target_count = 0

func _clear_hint_visuals() -> void:
	for visual in hint_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	hint_visuals.clear()
	is_flashing = false
	active_flash_tween_count = 0

func _get_platform_scene() -> PackedScene:
	if platform_spawner == null:
		return null
	return platform_spawner.get("platform_scene") as PackedScene

func _get_platform_center_offset() -> Vector2:
	if platform_spawner != null and platform_spawner.has_method("get_platform_center_offset"):
		return platform_spawner.call("get_platform_center_offset") as Vector2
	return Vector2.ZERO

func _get_platform_scale() -> float:
	if platform_spawner == null:
		return 1.0
	var scale_value = platform_spawner.get("texture_scale_multiplier")
	if scale_value is float:
		return scale_value
	return 1.0

func _disable_hint_collision(node: Node) -> void:
	var collision_object := node as CollisionObject2D
	if collision_object != null:
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	var rigid_body := node as RigidBody2D
	if rigid_body != null:
		rigid_body.freeze = true
		rigid_body.gravity_scale = 0.0

	var collision_shape := node as CollisionShape2D
	if collision_shape != null:
		collision_shape.disabled = true

	for child in node.get_children():
		_disable_hint_collision(child)

func _find_platform_spawner() -> Node2D:
	var parent_node := get_parent() as Node2D
	if _is_platform_spawner(parent_node):
		return parent_node

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	return _find_platform_spawner_recursive(current_scene)

func _find_platform_spawner_recursive(node: Node) -> Node2D:
	if _is_platform_spawner(node):
		return node as Node2D

	for child in node.get_children():
		var result := _find_platform_spawner_recursive(child)
		if result != null:
			return result

	return null

func _is_platform_spawner(node: Node) -> bool:
	if node == null:
		return false
	var script := node.get_script() as Script
	return script != null and script.resource_path == "res://script/platform_spawn.gd"

func _get_current_scene_path() -> String:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return ""
	return current_scene.scene_file_path
