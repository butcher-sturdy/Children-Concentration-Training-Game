extends Area2D

func _ready() -> void:
	# 自动连线：任何人碰到我，就触发下面的函数
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# 看看撞上来的是不是小人 "player"
	if body.name == "player":
		# === 击退的“物理魔法” ===
		
		# 2. 给一个小小的向上弹力（模仿被撞得后仰的动作）
		body.velocity.y = -300 
		# 1. 瞬间把小人的位置往左边（后方）移动 150 个像素
		body.global_position.x -= 225
		
		
		
		# 在调试台打印提示
		print("哎呀，撞到怪兽了，退后！")
