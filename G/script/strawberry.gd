extends Area2D

func _ready() -> void:
	# 代码自动连线：任何人碰到我，就触发下面的函数
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# 看看来吃我的是不是小人 "player"
	if body.name == "player":
		# 吃到啦！草莓自我销毁（从画面上消失）
		queue_free() 
		
		# （可选）如果你想在控制台看到提示，可以加下面这句
		print("吃到草莓啦！专注力真棒！")
