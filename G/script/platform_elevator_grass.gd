extends RigidBody2D

@export var rise_height: float = 100.0
@export var rise_speed: float = 200.0
@export var player_node_name: String = "player"

var has_player_on: bool = false
var initial_y: float = 0.0
var target_y: float = 0.0
var is_rising: bool = false

func _ready() -> void:
	self.gravity_scale = 0.0
	self.lock_rotation = true
	self.contact_monitor = true
	self.max_contacts_reported = 10


func _physics_process(delta: float) -> void:
	if has_player_on and is_rising:
		var current_diff = target_y - global_position.y
		if current_diff > 0:
			self.set_linear_velocity(Vector2(0, -rise_speed))
		else:
			self.set_linear_velocity(Vector2.ZERO)
			global_position.y = target_y
			is_rising = false

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == player_node_name:
		has_player_on = true
		if not is_rising:
			initial_y = global_position.y
			target_y = initial_y - rise_height
			is_rising = true
		print("玩家站上平台，开始上升！")

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == player_node_name:
		has_player_on = false
		is_rising = false
		self.set_linear_velocity(Vector2.ZERO)
		global_position.y = initial_y
		print("玩家离开平台，复位到初始位置")

func reset_platform() -> void:
	self.set_linear_velocity(Vector2.ZERO)
	global_position.y = initial_y
	is_rising = false
	has_player_on = false
