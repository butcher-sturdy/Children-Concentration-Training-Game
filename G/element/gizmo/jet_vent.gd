extends Area2D

@export var boost_strength: float = 1200.0 

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:

	print("【雷达】检测到物体：", body.name) 
	
	if body.is_in_group("Player") or body.name == "player":
		if "velocity" in body:
	
			body.global_position.y -= 10 
			
	
			body.velocity.y = -boost_strength
			print("起飞咯！当前吹力：", boost_strength)
