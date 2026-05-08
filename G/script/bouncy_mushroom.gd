extends Area2D


func _ready() -> void:
	# 用代码直接告诉引擎：只要有东西进入碰撞框，就去执行下面那个函数
	# 用这行代码，你以后都不需要在右侧面板点来点去连线了！
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# 判断踩上来的是不是咱们名叫 "player" 的小人
	if body.name == "player":
		# 给小人一个超大的向上速度（Y轴负数代表向上弹！）
		body.velocity.y = -1800
