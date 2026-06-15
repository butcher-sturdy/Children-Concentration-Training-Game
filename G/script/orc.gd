extends AnimatableBody2D

signal player_collide(body:CharacterBody2D)
@export var move_speed: float = 120.0
@export var pause_time: float = 1.0
@export var move_range: float = 200.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var center_x: float
var left_limit: float
var right_limit: float
var direction: int = 1
var is_paused: bool = false
var pause_timer: float = 0.0

func _ready():
	center_x = position.x
	left_limit = center_x - move_range
	right_limit = center_x + move_range
	
	sprite.play("walk")
	flip_sprite()

func _physics_process(delta):
	if is_paused:
		pause_timer -= delta
		if pause_timer <= 0:
			is_paused = false
			direction *= -1
			sprite.play("walk")
			flip_sprite()
		return

	position.x += direction * move_speed * delta

	if direction == 1 and position.x >= right_limit:
		position.x = right_limit
		pause()

	if direction == -1 and position.x <= left_limit:
		position.x = left_limit
		pause()

func pause():
	is_paused = true
	pause_timer = pause_time
	sprite.play("idle")
	
func player_collided(body:Node2D)->void:
	emit_signal("player_collide",body)
	
func flip_sprite():
	sprite.flip_h = direction == -1
