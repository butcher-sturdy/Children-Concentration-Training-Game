extends CanvasLayer
class_name AttentionEmotionHud

const DEFAULT_EMOTION_FILE_PATH := "C:/Users/ASUS/Desktop/emotion.txt"

@export var emotion_file_path: String = DEFAULT_EMOTION_FILE_PATH
@export var refresh_interval: float = 0.2
@export var top_offset: float = 18.0
@export var panel_size: Vector2 = Vector2(420, 48)

var refresh_timer := 0.0
var attention_value := 0.0
var emotion_value := 0.0
var has_emotion_value := false
var panel: PanelContainer
var value_label: Label


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_ui()
	_update_panel_position()
	_refresh_values()


func _process(delta: float) -> void:
	_update_panel_position()

	refresh_timer += delta
	if refresh_timer < refresh_interval:
		return

	refresh_timer = 0.0
	_refresh_values()


func _create_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "ValuePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = panel_size
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	value_label = Label.new()
	value_label.name = "ValueLabel"
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 24)
	value_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.82, 1.0))
	value_label.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.16, 1.0))
	value_label.add_theme_constant_override("outline_size", 4)
	value_label.custom_minimum_size = panel_size
	panel.add_child(value_label)


func _update_panel_position() -> void:
	if panel == null:
		return

	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	panel.size = panel_size
	panel.position = Vector2(
		(viewport_size.x - panel_size.x) * 0.5,
		top_offset
	)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.12, 0.16, 0.72)
	style.border_color = Color(0.95, 0.78, 0.28, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _refresh_values() -> void:
	attention_value = _read_attention_value()
	_read_emotion_value()
	_update_label()


func _read_attention_value() -> float:
	var focus_source := get_node_or_null("/root/concentration")
	if focus_source == null:
		return 0.0

	var value = focus_source.get("focus_level")
	if typeof(value) == TYPE_NIL:
		return 0.0
	return clampf(float(value), 0.0, 100.0)


func _read_emotion_value() -> void:
	if emotion_file_path.is_empty() or not FileAccess.file_exists(emotion_file_path):
		has_emotion_value = false
		return

	var file := FileAccess.open(emotion_file_path, FileAccess.READ)
	if file == null:
		has_emotion_value = false
		return

	var content := file.get_as_text().strip_edges()
	file.close()
	if not content.is_valid_float():
		has_emotion_value = false
		return

	emotion_value = clampf(float(content), 0.0, 10.0)
	has_emotion_value = true


func _update_label() -> void:
	if value_label == null:
		return

	var emotion_text := "--"
	if has_emotion_value:
		emotion_text = "%.1f" % emotion_value

	value_label.text = "Attention %.0f%%    Emotion %s/10" % [
		attention_value,
		emotion_text
	]
