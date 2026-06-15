extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "player":
		queue_free() 
		print("吃到草莓啦！专注力真棒！")
