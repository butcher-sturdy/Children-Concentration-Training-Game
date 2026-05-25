extends Node2D
class_name BridgeBuildAnswerHint

# 这个脚本负责：
# 1. 读取 / 保存每个 bridgebuild 关卡的答案，也就是平台放置位置。
# 2. 创建“记录答案 / 保存答案”按钮，用来进入或退出答案存储模式。
# 3. 在普通游戏模式下按 P 键，按保存顺序逐步显示平台提示。
#
# 存储模式使用方式：
# - 点击“记录答案”进入存储模式。
# - 在存储模式中放置的平台会按放置顺序记录，这个顺序就是之后的提示顺序。
# - 右键点击平台所在位置，可以删除该平台记录。
# - 再次点击“保存答案”，本次存储模式的平台会消失，但坐标会保存到 ANSWER_SAVE_PATH。
# - 以后再次点击“记录答案”，会先把已保存记录生成出来，方便继续修改。

const ANSWER_SAVE_PATH: String = "res://script/bridge_build_answers.json"
const STORAGE_PLATFORM_META: String = "bridge_build_answer_storage_platform"

# 当答案文件不存在，或某关还没保存答案时，会使用这里的默认答案。
# 修改格式：每个关卡路径对应一个 Vector2 数组，数组顺序就是提示顺序。
const DEFAULT_LEVEL_ANSWERS := {
	"res://main_scene/bridge_build1.tscn": [
		Vector2(854, 825.00006),
		Vector2(852.00006, 489.00006),
	],
	"res://main_scene/bridge_build2.tscn": [
		Vector2(520, 870),
		Vector2(1287, 101),
		Vector2(1172, 535),
	],
	"res://main_scene/bridge_build4.tscn": [],
	"res://main_scene/bridge_build5.tscn": [
		Vector2(781, 918),
		Vector2(948.00006, 343),
	],
	"res://main_scene/bridge_build_city_1.tscn": [],
	"res://main_scene/bridge_build_city_2.tscn": [],
}

# 如需某个场景临时不用答案文件，可以在检查器里手动填这里覆盖。
@export var override_answer_positions: Array[Vector2] = []

# 提示触发：默认内置条件满足，只需要按 P 对应的输入映射动作。
@export var hint_action: String = "p"
@export var use_focus_condition: bool = false
@export var focus_trigger_threshold: float = 75.0

# 提示显示参数。flash_count = 5 对应“闪烁 5 次”。
@export var hint_alpha: float = 0.42
@export var flash_low_alpha: float = 0.12
@export var flash_high_alpha: float = 0.82
@export var flash_count: int = 5
@export var flash_half_interval: float = 0.12
@export var hint_z_index: int = 20

# 第一次触发会让第一块平台闪烁；后续触发默认显示新平台，并让上一块平台闪烁。
@export var flash_previous_hint: bool = true
@export var flash_new_hint_after_first: bool = false

# 自动隐藏旧的黄色答案标记，避免游戏开始就暴露答案。
@export var hide_answer_marker_nodes: bool = true
@export var use_marker_nodes_when_missing: bool = true

# 存储按钮位置。默认放在右上角，避免挡住左上角开始按钮。
@export var storage_button_text: String = "记录答案"
@export var saving_button_text: String = "保存答案"
@export var storage_button_offset: Vector2 = Vector2(-220, 40)
@export var storage_button_size: Vector2 = Vector2(170, 54)

var answer_positions: Array[Vector2] = []
var hint_visuals: Array[Node2D] = []
var next_hint_index: int = 0
var is_flashing: bool = false
var active_flash_tween_count: int = 0

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
	_load_answers_for_current_scene()
	_create_storage_button()

	if hide_answer_marker_nodes:
		_hide_answer_markers()

func _process(_delta: float) -> void:
	if storage_mode_enabled:
		return
	if not _hint_input_pressed():
		return
	if not _hint_condition_met():
		return
	trigger_hint()

func trigger_hint() -> void:
	if answer_positions.is_empty():
		print("当前关卡没有可提示的平台答案。")
		return
	if platform_spawner == null or is_flashing:
		return

	var flash_indices: Array[int] = []

	if next_hint_index < answer_positions.size():
		var revealed_index := next_hint_index
		var new_visual := _create_hint_visual(answer_positions[revealed_index])
		if new_visual == null:
			return

		hint_visuals.append(new_visual)

		if revealed_index == 0 or flash_new_hint_after_first:
			flash_indices.append(revealed_index)
		if flash_previous_hint and revealed_index > 0:
			flash_indices.append(revealed_index - 1)

		next_hint_index += 1
	else:
		flash_indices.append(hint_visuals.size() - 1)

	_flash_hint_indices(flash_indices)

func toggle_storage_mode() -> void:
	if storage_mode_enabled:
		_exit_storage_mode()
	else:
		_enter_storage_mode()

func _enter_storage_mode() -> void:
	if platform_spawner == null:
		print("未找到 platform_spawn 节点，无法进入答案存储模式。")
		return

	storage_mode_enabled = true
	_clear_hint_visuals()
	_load_answers_for_current_scene()
	editing_positions.clear()
	editing_platforms.clear()

	# 进入存储模式时，把之前保存的答案重新生成出来，方便右键删除或继续添加。
	ignore_spawn_signal = true
	for saved_position in answer_positions:
		var platform := platform_spawner.call("spawn_platform", saved_position) as Node2D
		if platform != null:
			_register_editing_platform(saved_position, platform)
	ignore_spawn_signal = false

	_update_storage_button()
	print("进入答案存储模式。左键放置记录，右键删除鼠标位置的平台记录。")

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
	print("答案已保存，存储模式平台已隐藏。")

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
	next_hint_index = 0
	_clear_hint_visuals()

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

	if DEFAULT_LEVEL_ANSWERS.has(scene_path):
		for default_position in DEFAULT_LEVEL_ANSWERS[scene_path]:
			answer_positions.append(default_position)
		if not answer_positions.is_empty() or not use_marker_nodes_when_missing:
			return

	if use_marker_nodes_when_missing:
		for marker_position in _get_marker_answer_positions():
			answer_positions.append(marker_position)

func _save_answers_for_current_scene(positions: Array[Vector2]) -> void:
	var scene_path := _get_current_scene_path()
	if scene_path.is_empty():
		return

	var all_answers := _load_answer_file()
	all_answers[scene_path] = _positions_to_json_array(positions)

	var file := FileAccess.open(ANSWER_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("答案文件写入失败：", ANSWER_SAVE_PATH)
		return

	file.store_string(JSON.stringify(all_answers, "\t"))
	file.close()
	print("答案已写入：", ProjectSettings.globalize_path(ANSWER_SAVE_PATH))

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
	storage_button.tooltip_text = "进入/保存 bridgebuild 平台答案存储模式"
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

func _get_marker_answer_positions() -> Array[Vector2]:
	var markers := _get_answer_marker_nodes()
	var positions: Array[Vector2] = []
	for marker in markers:
		positions.append(marker.global_position)
	return positions

func _get_answer_marker_nodes() -> Array[Node2D]:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		var empty_markers: Array[Node2D] = []
		return empty_markers

	var markers: Array[Node2D] = []
	var marker_root := current_scene.get_node_or_null("platform_position")
	if marker_root != null:
		_collect_node2d_children(marker_root, markers)
	else:
		_collect_named_markers(current_scene, markers)

	markers.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0
	)
	return markers

func _collect_node2d_children(node: Node, markers: Array[Node2D]) -> void:
	for child in node.get_children():
		var child_2d := child as Node2D
		if child_2d != null:
			markers.append(child_2d)

func _collect_named_markers(node: Node, markers: Array[Node2D]) -> void:
	if str(node.name).begins_with("FlagYellow"):
		var marker := node as Node2D
		if marker != null:
			markers.append(marker)

	for child in node.get_children():
		_collect_named_markers(child, markers)

func _hide_answer_markers() -> void:
	for marker in _get_answer_marker_nodes():
		marker.visible = false

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var marker_root := current_scene.get_node_or_null("platform_position") as CanvasItem
	if marker_root != null:
		marker_root.visible = false
