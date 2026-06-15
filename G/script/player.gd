extends CharacterBody2D

const ATTENTION_EMOTION_HUD_SCRIPT := preload("res://script/attention_emotion_hud.gd")

@export var move_speed: float = 300.0
@export var jump_force: float = -600.0
@export var gravity: float = 1800.0
@export_range(-1, 1, 2) var run_direction: int = 1
@export var is_auto_run: bool = true
@export var air_damping: float = 1.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var start_position: Vector2


func _ready() -> void:
	run_direction = 1 if run_direction >= 0 else -1
	start_position = global_position
	_start_bridge_session_if_needed()
	_install_attention_emotion_hud()

	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.animation = "walk" if is_auto_run else "idle"
		animated_sprite.play()
	else:
		print("AnimatedSprite2D is not configured.")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.x = lerp(velocity.x, 0.0, air_damping * delta)
	else:
		velocity.y = 0.0

	if is_on_floor():
		if is_auto_run:
			velocity.x = move_speed * run_direction
		else:
			velocity.x = Input.get_axis("move_left", "move_right") * move_speed

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	move_and_slide()
	update_animation(float(run_direction) if is_auto_run else Input.get_axis("move_left", "move_right"))


func update_animation(input_dir: float) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	if not is_on_floor():
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


func _on_killzone_body_entered(body: Node2D) -> void:
	if body != self and not body.is_in_group("Player"):
		return

	_record_bridge_failure()
	global_position = start_position
	run_direction = 1
	is_auto_run = false
	velocity = Vector2.ZERO
	print("Player returned to the bridge level start.")


func change_auto_run_mode() -> void:
	global_position = start_position
	run_direction = 1
	is_auto_run = not is_auto_run


func flip_move_direction() -> void:
	run_direction *= -1
	if is_auto_run:
		velocity.x = move_speed * run_direction
	if animated_sprite:
		animated_sprite.flip_h = run_direction < 0


func jump_to_subtitle(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("Bridge level complete.")
		var session := get_node_or_null("/root/game_session")
		if session != null and session.has_method("finish_bridge_level"):
			session.call("finish_bridge_level")
		get_tree().change_scene_to_file("res://main_scene/bridge_result.tscn")


func halt_running(_body: CharacterBody2D) -> void:
	is_auto_run = false
	print("stop")


func continue_running(_body: CharacterBody2D) -> void:
	is_auto_run = true
	print("continue")


func _on_elevator_platform_arrived(_body: CharacterBody2D) -> void:
	pass


func _start_bridge_session_if_needed() -> void:
	var session := get_node_or_null("/root/game_session")
	if session == null or not session.has_method("ensure_bridge_level_started"):
		return
	if get_tree().current_scene == null:
		return
	session.call("ensure_bridge_level_started", get_tree().current_scene.scene_file_path)


func _record_bridge_failure() -> void:
	var session := get_node_or_null("/root/game_session")
	if session != null and session.has_method("record_bridge_failure"):
		session.call("record_bridge_failure")


func _install_attention_emotion_hud() -> void:
	if get_node_or_null("AttentionEmotionHud") != null:
		return

	var hud := ATTENTION_EMOTION_HUD_SCRIPT.new() as CanvasLayer
	if hud == null:
		return
	hud.name = "AttentionEmotionHud"
	add_child(hud)
