extends Node

# 游戏全局状态管理器 (全局单例)

var current_level: int = 1

func _ready() -> void:
	_setup_emoji_font()

func _setup_emoji_font() -> void:
	var main_font = load("res://fonts/simhei.ttf") as FontFile
	var emoji_font = load("res://fonts/NotoColorEmoji-Regular.ttf") as FontFile
	if main_font == null or emoji_font == null:
		return
	if not main_font.fallbacks.has(emoji_font):
		main_font.fallbacks.append(emoji_font)
	ThemeDB.get_default_theme().default_font = main_font
var completed_levels: Array[int] = []
var total_levels: int = 7

# 关卡名称
var level_names: Array[String] = [
	"配制诱导培养基",
	"辣椒花药选取",
	"花药消毒与接种",
	"愈伤组织诱导",
	"生芽与生根",
	"倍性鉴定",
	"染色体加倍"
]

func complete_level(level: int) -> void:
	if level not in completed_levels:
		completed_levels.append(level)
	current_level = level + 1
	if level < total_levels:
		go_to_scene("res://scenes/Scene" + str(level + 1) + ".tscn")
	else:
		go_to_scene("res://scenes/Congratulations.tscn")

func go_to_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func go_to_main_menu() -> void:
	go_to_scene("res://scenes/MainMenu.tscn")

func go_to_level_select() -> void:
	go_to_scene("res://scenes/LevelSelect.tscn")

func go_to_level(level: int) -> void:
	current_level = level
	if level <= total_levels:
		go_to_scene("res://scenes/Scene" + str(level) + ".tscn")

func is_level_completed(level: int) -> bool:
	return level in completed_levels

func is_level_unlocked(level: int) -> bool:
	if level == 1:
		return true
	return (level - 1) in completed_levels

func reset_progress() -> void:
	completed_levels.clear()
	current_level = 1

func get_level_name(level: int) -> String:
	if level >= 1 and level <= level_names.size():
		return level_names[level - 1]
	return ""
