extends Node

@export var focus_level: float = 0.0

# 实时读取TXT配置
@export var read_interval: float = 0.2
var read_timer: float = 0.0
const FILE_PATH: String = "user://concentration.txt"

# 安全修改专注度
func set_focus_level(value: float) -> void:
	focus_level = clamp(value, 0.0, 100.0)

func _process(delta: float) -> void:
	# 只保留定时读取文件
	read_timer += delta
	if read_timer >= read_interval:
		read_focus_from_file()
		read_timer = 0.0

# 从TXT读取并更新
func read_focus_from_file():
	if not FileAccess.file_exists(FILE_PATH):
		write_default_file()
		return
	
	var file = FileAccess.open(FILE_PATH, FileAccess.READ)
	if not file:
		return
	
	var content = file.get_line().strip_edges()
	file.close()
	
	if content.is_valid_float():
		var new_value = clamp(float(content), 0.0, 100.0)
		if new_value != focus_level:
			focus_level = new_value
			print("外部文件更新专注度：", round(focus_level), "%")

# 自动创建默认文件
func write_default_file():
	var file = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	file.store_line("50")
	file.close()
