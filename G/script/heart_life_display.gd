extends HBoxContainer

@export var heart_texture: Texture2D = preload("res://asset/4/heart_pixel.png")
@export var protection_enter_sound: AudioStream = preload("res://asset/1/sounds/power_up.wav")
@export var protection_exit_sound: AudioStream = preload("res://asset/1/sounds/tap.wav")
@export var heart_size: Vector2 = Vector2(42, 42)
@export var heart_spacing: int = 8

var heart_nodes: Array[TextureRect] = []
var active_tweens: Dictionary = {}
var protection_tweens: Dictionary = {}
var shown_lives := -1
var protection_active := false
var yellow_heart_texture: Texture2D
var protection_sound_player: AudioStreamPlayer


func _ready() -> void:
	add_theme_constant_override("separation", heart_spacing)
	yellow_heart_texture = _create_yellow_heart_texture()
	protection_sound_player = AudioStreamPlayer.new()
	add_child(protection_sound_player)


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


func _on_player_protection_changed(active: bool) -> void:
	if protection_active == active:
		return

	protection_active = active
	_play_protection_sound(active)
	for index in range(heart_nodes.size()):
		if heart_nodes[index].visible:
			_animate_protection_change(index)
		else:
			_apply_heart_texture(heart_nodes[index])


func _rebuild_hearts(max_lives: int) -> void:
	for tween in active_tweens.values():
		var life_tween := tween as Tween
		if life_tween:
			life_tween.kill()
	active_tweens.clear()
	for tween in protection_tweens.values():
		var protection_tween := tween as Tween
		if protection_tween:
			protection_tween.kill()
	protection_tweens.clear()

	for child in get_children():
		if child == protection_sound_player:
			continue
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
	_kill_protection_tween(index)
	var heart := heart_nodes[index]
	_apply_heart_texture(heart)
	heart.visible = true
	heart.modulate = Color.WHITE
	heart.scale = Vector2.ONE


func _hide_heart(index: int) -> void:
	if not _is_valid_heart_index(index):
		return

	_kill_heart_tween(index)
	_kill_protection_tween(index)
	var heart := heart_nodes[index]
	heart.visible = false
	heart.modulate = Color.WHITE
	heart.scale = Vector2.ONE


func _flash_and_hide_heart(index: int) -> void:
	if not _is_valid_heart_index(index):
		return

	_kill_heart_tween(index)
	_kill_protection_tween(index)
	var heart := heart_nodes[index]
	_apply_heart_texture(heart)
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


func _animate_protection_change(index: int) -> void:
	if not _is_valid_heart_index(index):
		return

	_kill_protection_tween(index)
	var heart := heart_nodes[index]
	_apply_heart_texture(heart)
	heart.modulate = Color(1.0, 1.0, 1.0, 0.62)
	heart.scale = Vector2(1.18, 1.18)

	var tween := create_tween()
	tween.set_parallel(true)
	protection_tweens[index] = tween
	tween.tween_property(heart, "modulate", Color.WHITE, 0.18)
	tween.tween_property(heart, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func() -> void:
		protection_tweens.erase(index)
		if is_instance_valid(heart):
			heart.modulate = Color.WHITE
			heart.scale = Vector2.ONE
	)


func _apply_heart_texture(heart: TextureRect) -> void:
	if protection_active and yellow_heart_texture != null:
		heart.texture = yellow_heart_texture
	else:
		heart.texture = heart_texture


func _create_yellow_heart_texture() -> Texture2D:
	if heart_texture == null:
		return null

	var image := heart_texture.get_image()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return null

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.05:
				continue

			var brightness := maxf(color.r, maxf(color.g, color.b))
			var highlight := minf(color.g + color.b, 1.0)
			image.set_pixel(
				x,
				y,
				Color(
					1.0,
					lerpf(0.72, 0.98, highlight) * brightness,
					lerpf(0.06, 0.32, highlight) * brightness,
					color.a
				)
			)

	return ImageTexture.create_from_image(image)


func _play_protection_sound(active: bool) -> void:
	if protection_sound_player == null:
		return

	protection_sound_player.stream = protection_enter_sound if active else protection_exit_sound
	if protection_sound_player.stream != null:
		protection_sound_player.play()


func _kill_protection_tween(index: int) -> void:
	if not protection_tweens.has(index):
		return

	var old_tween := protection_tweens[index] as Tween
	if old_tween:
		old_tween.kill()
	protection_tweens.erase(index)


func _is_valid_heart_index(index: int) -> bool:
	return index >= 0 and index < heart_nodes.size()
