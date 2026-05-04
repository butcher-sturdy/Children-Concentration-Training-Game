extends Area2D

@export var boost_strength: float = 1200.0 # 向上的升力
@export var forward_push: float = 200.0    # 向前的推力

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	
	if body.is_in_group("Player") or body.name == "player":
		print("【喷气口】成功捕捉到玩家！")
		
		
		body.global_position.y -= 20
		
		if "velocity" in body:
			
			body.velocity = Vector2(forward_push, -boost_strength)
			
			
			body.set_deferred("velocity", Vector2(forward_push, -boost_strength))
			
			print("起飞！升力：", boost_strength, " 推力：", forward_push)
