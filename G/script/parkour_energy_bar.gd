extends Control

@export var player_path: NodePath = NodePath("../../player")
@export var activation_threshold: float = 50.0
@export var charge_duration: float = 15.0
@export var boost_duration: float = 7.0
@export var boost_speed_multiplier: float = 2.0
@export var bar_size: Vector2 = Vector2(260.0, 44.0)

var player: Node = null
var charge_time := 0.0
var active_time_remaining := 0.0
var flash_phase := 0.0


func _ready() -> void:
	custom_minimum_size = bar_size
	size = bar_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player = get_node_or_null(player_path)
	if player == null:
		push_warning("Parkour energy bar could not find player at path: %s" % str(player_path))


func _process(delta: float) -> void:
	var focus_level := _get_focus_level()
	if active_time_remaining > 0.0:
		if not _is_player_serene_active():
			active_time_remaining = 0.0
			queue_redraw()
			return
		active_time_remaining = maxf(active_time_remaining - delta, 0.0)
		flash_phase += delta * _get_flash_frequency(100.0) * TAU
	elif focus_level >= activation_threshold:
		charge_time = minf(charge_time + delta, charge_duration)
		flash_phase += delta * _get_flash_frequency(focus_level) * TAU
		if charge_time >= charge_duration:
			_activate_boost()
	else:
		flash_phase = 0.0

	queue_redraw()


func _draw() -> void:
	var draw_size := size
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		draw_size = bar_size

	var focus_level := _get_focus_level()
	var active := active_time_remaining > 0.0
	var charging := focus_level >= activation_threshold and not active
	var pulse := (sin(flash_phase) + 1.0) * 0.5
	var focus_ratio := clampf((focus_level - activation_threshold) / maxf(100.0 - activation_threshold, 1.0), 0.0, 1.0)
	var progress := _get_progress()
	var outer_rect := Rect2(Vector2.ZERO, draw_size)
	var inner_rect := Rect2(Vector2(5.0, 5.0), draw_size - Vector2(10.0, 10.0))

	if charging or active:
		var glow_alpha := 0.16 + pulse * lerpf(0.14, 0.38, focus_ratio)
		var glow_color := Color(0.35, 0.85, 1.0, glow_alpha)
		if active:
			glow_color = Color(1.0, 0.92, 0.32, 0.28 + pulse * 0.3)
		draw_rect(Rect2(Vector2(-3.0, -3.0), draw_size + Vector2(6.0, 6.0)), glow_color, true)

	draw_rect(outer_rect, Color(0.02, 0.04, 0.08, 0.78), true)
	draw_rect(outer_rect, Color(0.88, 0.94, 1.0, 0.95), false, 2.0)
	draw_rect(inner_rect, Color(0.0, 0.0, 0.0, 0.48), true)

	if progress > 0.0:
		var fill_rect := Rect2(inner_rect.position, Vector2(inner_rect.size.x * progress, inner_rect.size.y))
		var fill_color := Color(0.19, 0.78, 1.0, 0.92).lerp(Color(1.0, 0.92, 0.25, 1.0), focus_ratio)
		if active:
			fill_color = Color(1.0, 0.82, 0.18, 1.0).lerp(Color.WHITE, pulse * 0.22)
		draw_rect(fill_rect, fill_color, true)

	for index in range(1, int(charge_duration)):
		var x := inner_rect.position.x + inner_rect.size.x * float(index) / charge_duration
		draw_line(
			Vector2(x, inner_rect.position.y + 3.0),
			Vector2(x, inner_rect.end.y - 3.0),
			Color(1.0, 1.0, 1.0, 0.16),
			1.0
		)


func _activate_boost() -> void:
	charge_time = 0.0
	active_time_remaining = maxf(boost_duration, 0.0)
	flash_phase = 0.0
	if player == null or not is_instance_valid(player):
		player = get_node_or_null(player_path)
	if player != null and player.has_method("activate_energy_boost"):
		player.call("activate_energy_boost", boost_duration, boost_speed_multiplier)
	else:
		push_warning("Parkour energy bar could not activate player energy boost.")


func _get_progress() -> float:
	if active_time_remaining > 0.0:
		return clampf(active_time_remaining / maxf(boost_duration, 0.001), 0.0, 1.0)
	return clampf(charge_time / maxf(charge_duration, 0.001), 0.0, 1.0)


func _get_focus_level() -> float:
	var focus_source := get_node_or_null("/root/concentration")
	if focus_source == null:
		return 0.0

	var value = focus_source.get("focus_level")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return clampf(float(value), 0.0, 100.0)
	return 0.0


func _get_flash_frequency(focus_level: float) -> float:
	var ratio := clampf((focus_level - activation_threshold) / maxf(100.0 - activation_threshold, 1.0), 0.0, 1.0)
	return lerpf(2.0, 12.0, ratio)


func _is_player_serene_active() -> bool:
	if player == null or not is_instance_valid(player):
		player = get_node_or_null(player_path)
	if player != null and player.has_method("is_energy_boost_active"):
		return bool(player.call("is_energy_boost_active"))
	return active_time_remaining > 0.0
