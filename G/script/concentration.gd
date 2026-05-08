extends Node

@export var focus_level: float = 0.0

# 实时读取TXT配置
@export var read_interval: float = 0.2
var read_timer: float = 0.0

# 【关键修改 1】：把 Windows 的 C 盘路径，改成 Godot 项目自身的根目录！
# 这样不仅 Mac 和 Windows 都能通用，而且 txt 文件会直接生成在你左下角的文件系统里，非常方便你手动修改测试。
const FILE_PATH: String = "res://concentration.txt"

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
	# 【关键修改 2】：增加安全防护 (if file:)！
	# 以后万一没权限创建文件，游戏也不会崩溃，只会打印一句警告。
	if file:
		file.store_line("50")
		file.close()
	else:
		print("警告：无法创建脑电波文件，请检查路径！")
