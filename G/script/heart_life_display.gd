extends HBoxContainer

@export var heart_texture: Texture2D = preload("res://asset/4/heart_pixel.png")
@export var heart_size: Vector2 = Vector2(42, 42)
@export var heart_spacing: int = 8

var heart_nodes: Array[TextureRect] = []
var active_tweens: Dictionary = {}
var shown_lives := -1


func _ready() -> void:
	add_theme_constant_override("separation", heart_spacing)


func _on_player_life_changed(current_lives: int, max_lives: int) -> void:
	var clamped_max: int = max(max_lives, 0)
	var clamped_lives: int = clampi(current_lives, 0, clamped_max)

	if heart_nodes.size() != clamped_max:
		_rebuild_hearts(clamped_max)
		shown_lives = -1

	if shown_lives == -1:
		_apply_lives_without_animation(clamped_lives)
	elif clamped_lives < shown_lives:
		for index in range(clamped_lives, shown_lives):
			_flash_and_hide_heart(index)
	elif clamped_lives > shown_lives:
		for index in range(clamped_lives):
			_show_heart(index)
		for index in range(clamped_lives, heart_nodes.size()):
			_hide_heart(index)

	shown_lives = clamped_lives


func _rebuild_hearts(max_lives: int) -> void:
	for tween in active_tweens.values():
		var old_tween := tween as Tween
		if old_tween:
			old_tween.kill()
	active_tweens.clear()

	for child in get_children():
		child.queue_free()

	heart_nodes.clear()
	for _index in range(max_lives):
		var heart := TextureRect.new()
		heart.texture = heart_texture
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = heart_size
		heart.size = heart_size
		heart.pivot_offset = heart_size * 0.5
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(heart)
		heart_nodes.append(heart)


func _apply_lives_without_animation(current_lives: int) -> void:
	for index in range(heart_nodes.size()):
		if index < current_lives:
			_show_heart(index)
		else:
			_hide_heart(index)


func _show_heart(index: int) -> void:
	if not _is_valid_heart_index(index):
		return

	_kill_heart_tween(index)
	var heart := heart_nodes[index]
	heart.visible = true
	heart.modulate = Color.WHITE
	heart.scale = Vector2.ONE


func _hide_heart(index: int) -> void:
	if not _is_valid_heart_index(index):
		return

	_kill_heart_tween(index)
	var heart := heart_nodes[index]
	heart.visible = false
	heart.modulate = Color.WHITE
	heart.scale = Vector2.ONE


func _flash_and_hide_heart(index: int) -> void:
	if not _is_valid_heart_index(index):
		return

	_kill_heart_tween(index)
	var heart := heart_nodes[index]
	heart.visible = true
	heart.modulate = Color.WHITE
	heart.scale = Vector2.ONE

	var tween := create_tween()
	active_tweens[index] = tween
	tween.tween_property(heart, "modulate", Color(1.0, 1.0, 1.0, 0.15), 0.07)
	tween.tween_property(heart, "modulate", Color.WHITE, 0.07)
	tween.tween_property(heart, "modulate", Color(1.0, 0.25, 0.25, 0.0), 0.12)
	tween.tween_callback(func() -> void:
		active_tweens.erase(index)
		if is_instance_valid(heart):
			heart.visible = false
			heart.modulate = Color.WHITE
			heart.scale = Vector2.ONE
	)


func _kill_heart_tween(index: int) -> void:
	if not active_tweens.has(index):
		return

	var old_tween := active_tweens[index] as Tween
	if old_tween:
		old_tween.kill()
	active_tweens.erase(index)


func _is_valid_heart_index(index: int) -> bool:
	return index >= 0 and index < heart_nodes.size()
