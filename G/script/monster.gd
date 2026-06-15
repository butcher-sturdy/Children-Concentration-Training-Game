extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "player":
		body.velocity.y = -300 
		body.global_position.x -= 300
		print("哎呀，撞到怪兽了，退后！")
