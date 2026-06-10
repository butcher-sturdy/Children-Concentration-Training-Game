extends CharacterBody2D

const PARKOUR_RESULT_SCENE_PATH := "res://main_scene/parkour_result.tscn"
const COUNTDOWN_PANEL_TEXTURE := preload("res://asset/4/parkour_countdown_panel.png")
const COUNTDOWN_GO_TEXT := "\u5f00\u59cb"

@export var move_speed: float = 300.0
@export var jump_force: float = -800.0
@export var gravity: float = 1800.0
@export var is_auto_run: bool = true
@export_range(-1, 1, 2) var run_direction: int = 1

@export var invincible_threshold: float = 50.0
@export var fly_threshold: float = 75.0
@export var fly_speed_multiplier: float = 1.5
@export var use_focus_threshold_effects: bool = true

@export var max_lives: int = 3
@export var hit_cooldown: float = 1.0
@export var fall_kill_y: float = 1080.0
@export var respawn_pause_seconds: float = 3.0
@export var respawn_countdown_go_seconds: float = 0.45
@export var stuck_reset_seconds: float = 7.0
@export var stuck_x_epsilon: float = 2.0
@export var use_focus_guard_effects: bool = false
@export var focus_guard_threshold: float = 70.0
@export var focus_guard_delay: float = 2.0
@export var serene_fall_guard_duration: float = 5.0

signal life_changed(current_lives: int, max_lives: int)
signal protection_changed(active: bool)
signal serene_state_changed(active: bool)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_lives: int
var is_hit_cooldown: bool = true
var hit_cooldown_timer: float = 0.0
var original_mask: int
var original_speed: float
var fly_base_y: float = 0.0
var last_on_ground_position: Vector2
var start_position: Vector2
var is_changing_scene := false
var respawn_pause_timer := 0.0
var energy_boost_remaining := 0.0
var energy_boost_speed_multiplier := 2.0
var serene_fall_guard_remaining := 0.0
var focus_guard_charge_time := 0.0
var focus_guard_active := false
var protection_visual_active := false
var serene_visual_phase := 0.0
var is_invincible: bool = false
var is_flying: bool = false
var stuck_reference_x := 0.0
var stuck_timer := 0.0
var countdown_canvas: CanvasLayer
var countdown_root: Control
var countdown_label: Label


func _ready() -> void:
	run_direction = 1 if run_direction >= 0 else -1
	original_mask = collision_mask
	original_speed = move_speed
	last_on_ground_position = global_position
	start_position = global_position
	current_lives = max_lives
	hit_cooldown_timer = hit_cooldown
	_create_respawn_countdown_ui()
	_reset_stuck_monitor()
	_begin_parkour_session()

	if animated_sprite:
		animated_sprite.animation = "walk" if is_auto_run else "idle"
		animated_sprite.play()


func _physics_process(delta: float) -> void:
	life_changed.emit(current_lives, max_lives)
	if current_lives <= 0:
		_go_to_result()
		return

	_update_hit_cooldown(delta)
	_update_last_ground_position()
	_update_focus_guard(delta)
	_update_energy_boost(delta)
	_update_serene_visual(delta)
	_refresh_protection_signal()
	update_focus_states()
	handle_focus_effects()
	_update_respawn_pause(delta)
	if _is_respawn_paused():
		velocity = Vector2.ZERO
		_reset_stuck_monitor()
		update_animation(0.0)
		return

	handle_gravity(delta)
	handle_movement()
	if not is_flying:
		handle_jump()
	move_and_slide()
	_check_fall_killzone()
	if not _is_respawn_paused():
		_update_stuck_reset(delta)
	update_animation(float(run_direction) if is_auto_run else Input.get_axis("move_left", "move_right"))


func update_focus_states() -> void:
	is_invincible = is_energy_boost_active() or focus_guard_active
	is_flying = is_energy_boost_active()

	if use_focus_threshold_effects:
		is_invincible = is_invincible or concentration.focus_level >= invincible_threshold
		is_flying = is_flying or concentration.focus_level >= fly_threshold


func handle_focus_effects() -> void:
	if is_energy_boost_active():
		collision_mask = 0
	elif is_invincible:
		collision_mask = original_mask & ~(1 << 1)
	else:
		collision_mask = original_mask

	if is_flying:
		if fly_base_y == 0.0:
			fly_base_y = global_position.y
		global_position.y = fly_base_y
		var speed_multiplier := energy_boost_speed_multiplier if is_energy_boost_active() else fly_speed_multiplier
		move_speed = original_speed * speed_multiplier
	else:
		move_speed = original_speed
		fly_base_y = 0.0


func activate_energy_boost(duration: float, speed_multiplier: float = 2.0) -> void:
	var was_active := is_energy_boost_active()
	energy_boost_remaining = maxf(duration, 0.0)
	energy_boost_speed_multiplier = maxf(speed_multiplier, 1.0)
	if energy_boost_remaining > 0.0:
		serene_fall_guard_remaining = minf(serene_fall_guard_duration, energy_boost_remaining)
		fly_base_y = global_position.y
		if not was_active:
			serene_state_changed.emit(true)
	_refresh_protection_signal()


func is_energy_boost_active() -> bool:
	return energy_boost_remaining > 0.0


func _update_energy_boost(delta: float) -> void:
	var was_active := is_energy_boost_active()
	if energy_boost_remaining > 0.0:
		energy_boost_remaining = maxf(energy_boost_remaining - delta, 0.0)
	if serene_fall_guard_remaining > 0.0:
		serene_fall_guard_remaining = maxf(serene_fall_guard_remaining - delta, 0.0)
	if was_active and not is_energy_boost_active():
		serene_fall_guard_remaining = 0.0
		serene_state_changed.emit(false)


func _update_focus_guard(delta: float) -> void:
	if not use_focus_guard_effects:
		_set_focus_guard_active(false)
		return

	if concentration.focus_level >= focus_guard_threshold:
		focus_guard_charge_time = minf(focus_guard_charge_time + delta, focus_guard_delay)
	else:
		focus_guard_charge_time = 0.0

	_set_focus_guard_active(focus_guard_charge_time >= focus_guard_delay)


func _set_focus_guard_active(active: bool) -> void:
	if focus_guard_active == active:
		return

	focus_guard_active = active
	if not active:
		focus_guard_charge_time = 0.0
	_refresh_protection_signal()


func _refresh_protection_signal() -> void:
	var active := focus_guard_active or is_energy_boost_active()
	if protection_visual_active == active:
		return

	protection_visual_active = active
	protection_changed.emit(active)


func _update_serene_visual(delta: float) -> void:
	if not animated_sprite:
		return

	if is_energy_boost_active():
		serene_visual_phase += delta * 18.0
		var pulse := (sin(serene_visual_phase) + 1.0) * 0.5
		animated_sprite.modulate = Color(0.72, 0.95, 1.0, lerpf(0.38, 1.0, pulse))
	else:
		serene_visual_phase = 0.0
		animated_sprite.modulate = Color.WHITE


func handle_gravity(delta: float) -> void:
	if not is_on_floor() and not is_flying:
		velocity.y += gravity * delta
	elif not is_flying and velocity.y > 0.0:
		velocity.y = 0.0


func handle_movement() -> void:
	velocity.x = 0.0
	if _is_respawn_paused():
		return
	if is_auto_run:
		velocity.x = move_speed * run_direction
	else:
		velocity.x = Input.get_axis("move_left", "move_right") * move_speed


func handle_jump() -> void:
	if _is_respawn_paused():
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force


func update_animation(input_dir: float) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if _is_respawn_paused():
		if animated_sprite.animation != "idle":
			animated_sprite.animation = "idle"
			animated_sprite.frame = 0
			animated_sprite.play()
		return
	if not is_on_floor() or is_flying:
		return
	elif is_auto_run or input_dir != 0.0:
		if animated_sprite.animation != "walk":
			animated_sprite.animation = "walk"
			animated_sprite.play()
		animated_sprite.flip_h = input_dir < 0.0
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.animation = "idle"
			animated_sprite.frame = 0
			animated_sprite.play()


func _on_body_entered(_body: Node2D) -> void:
	if is_invincible or is_hit_cooldown:
		return

	current_lives -= 1
	is_hit_cooldown = true
	hit_cooldown_timer = hit_cooldown
	life_changed.emit(current_lives, max_lives)
	if current_lives <= 0:
		_go_to_result()
		return

	_respawn_at_current_segment_start()


func _update_last_ground_position() -> void:
	if not is_flying and is_on_floor():
		last_on_ground_position = global_position


func _on_killzone_body_entered(body: Node2D) -> void:
	if body != self:
		return
	_trigger_killzone()


func _check_fall_killzone() -> void:
	if global_position.y >= fall_kill_y:
		_trigger_killzone()


func _trigger_killzone() -> void:
	if is_hit_cooldown:
		return

	if _is_fall_damage_blocked():
		_respawn_at_current_segment_start(false)
		is_hit_cooldown = true
		hit_cooldown_timer = hit_cooldown
		return

	current_lives -= 1
	life_changed.emit(current_lives, max_lives)
	if current_lives <= 0:
		_go_to_result()
		return

	_respawn_at_current_segment_start()
	is_hit_cooldown = true
	hit_cooldown_timer = hit_cooldown


func _is_fall_damage_blocked() -> bool:
	return focus_guard_active or serene_fall_guard_remaining > 0.0


func _respawn_at_current_segment_start(clear_serene_state: bool = true) -> void:
	var respawn_position := start_position
	var parkour_root := get_parent()
	if parkour_root != null and parkour_root.has_method("get_respawn_position_for_player"):
		var requested_position = parkour_root.call("get_respawn_position_for_player", self)
		if requested_position is Vector2:
			respawn_position = requested_position

	global_position = respawn_position
	last_on_ground_position = global_position
	velocity = Vector2.ZERO
	run_direction = 1
	is_flying = false
	fly_base_y = 0.0
	if clear_serene_state:
		var was_active := is_energy_boost_active()
		energy_boost_remaining = 0.0
		serene_fall_guard_remaining = 0.0
		if was_active:
			serene_state_changed.emit(false)
	else:
		if is_energy_boost_active():
			fly_base_y = global_position.y
	_start_respawn_pause()
	_reset_stuck_monitor()
	_refresh_protection_signal()

	if parkour_root != null and parkour_root.has_method("sync_after_player_respawn"):
		parkour_root.call("sync_after_player_respawn")


func _update_respawn_pause(delta: float) -> void:
	if respawn_pause_timer <= 0.0:
		_hide_respawn_countdown()
		return
	respawn_pause_timer = maxf(respawn_pause_timer - delta, 0.0)
	_update_respawn_countdown_ui()
	if respawn_pause_timer <= 0.0:
		_hide_respawn_countdown()


func _is_respawn_paused() -> bool:
	return respawn_pause_timer > 0.0


func _start_respawn_pause() -> void:
	respawn_pause_timer = maxf(respawn_pause_seconds, 0.0)
	_update_respawn_countdown_ui()


func _create_respawn_countdown_ui() -> void:
	countdown_canvas = CanvasLayer.new()
	countdown_canvas.name = "RespawnCountdownCanvas"
	countdown_canvas.layer = 80
	add_child(countdown_canvas)

	countdown_root = Control.new()
	countdown_root.name = "RespawnCountdownOverlay"
	countdown_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_root.visible = false
	countdown_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_canvas.add_child(countdown_root)

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0.0, 0.06, 0.08, 0.36)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_root.add_child(dimmer)

	var panel := TextureRect.new()
	panel.name = "CountdownPanel"
	panel.texture = COUNTDOWN_PANEL_TEXTURE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.expand_mode = 1
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -180.0
	panel.offset_top = -180.0
	panel.offset_right = 180.0
	panel.offset_bottom = 180.0
	countdown_root.add_child(panel)

	countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72, 1.0))
	countdown_label.add_theme_color_override("font_outline_color", Color(0.04, 0.16, 0.20, 1.0))
	countdown_label.add_theme_constant_override("outline_size", 10)
	panel.add_child(countdown_label)


func _update_respawn_countdown_ui() -> void:
	if countdown_root == null or countdown_label == null:
		return

	countdown_root.visible = respawn_pause_timer > 0.0
	if respawn_pause_timer <= 0.0:
		return

	var number_time := maxf(respawn_pause_timer - respawn_countdown_go_seconds, 0.0)
	if number_time > 0.0:
		_set_countdown_text(str(int(ceil(number_time))), 112)
	else:
		_set_countdown_text(COUNTDOWN_GO_TEXT, 66)


func _set_countdown_text(text: String, font_size: int) -> void:
	countdown_label.text = text
	countdown_label.add_theme_font_size_override("font_size", font_size)


func _hide_respawn_countdown() -> void:
	if countdown_root != null:
		countdown_root.visible = false


func _update_stuck_reset(delta: float) -> void:
	if stuck_reset_seconds <= 0.0 or is_changing_scene or _is_respawn_paused():
		_reset_stuck_monitor()
		return

	var current_x := global_position.x
	if absf(current_x - stuck_reference_x) <= stuck_x_epsilon:
		stuck_timer += delta
		if stuck_timer >= stuck_reset_seconds:
			_respawn_at_current_segment_start(false)
			_reset_stuck_monitor()
	else:
		stuck_reference_x = current_x
		stuck_timer = 0.0


func _reset_stuck_monitor() -> void:
	stuck_reference_x = global_position.x
	stuck_timer = 0.0


func _update_hit_cooldown(delta: float) -> void:
	if not is_hit_cooldown:
		return

	hit_cooldown_timer -= delta
	if hit_cooldown_timer <= 0.0:
		is_hit_cooldown = false
		hit_cooldown_timer = hit_cooldown


func _go_to_result() -> void:
	if is_changing_scene:
		return

	is_changing_scene = true
	var session := get_node_or_null("/root/game_session")
	if session != null and session.has_method("finish_parkour"):
		session.call("finish_parkour")
	get_tree().change_scene_to_file(PARKOUR_RESULT_SCENE_PATH)


func change_auto_run_mode() -> void:
	global_position = start_position
	run_direction = 1
	is_auto_run = not is_auto_run
	_reset_stuck_monitor()


func flip_move_direction() -> void:
	run_direction *= -1
	if is_auto_run:
		velocity.x = move_speed * run_direction
	if animated_sprite:
		animated_sprite.flip_h = run_direction < 0


func jump_to_subtitle(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_go_to_result()


func _begin_parkour_session() -> void:
	var session := get_node_or_null("/root/game_session")
	if session != null and session.has_method("begin_parkour"):
		session.call("begin_parkour")
