## LevelSelect.gd — 关卡选择界面
extends Node

var canvas: CanvasLayer

const LEVEL_DESC := [
	"配制三种诱导培养基\n正确匹配培养基配方",
	"在盛花期选取单核靠边期花药\n并进行低温预处理",
	"75%酒精和次氯酸钠消毒\n无菌环境下接种花药",
	"高温暗培养热激处理\n诱导花药形成愈伤组织",
	"转入生芽和生根培养基\n发育成完整幼苗",
	"通过染色体计数鉴定\n筛选真正的单倍体植株",
	"秋水仙素处理染色体加倍\n获得双单倍体(DH系)植株",
]
const LEVEL_ICONS := ["🧪", "🌸", "🧫", "🌱", "🌿", "🔬", "🧬"]

func _ready() -> void:
	canvas = CanvasLayer.new(); add_child(canvas)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.10, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(1280, 0)
	vbox.offset_top = 0
	scroll.add_child(vbox)

	# 标题栏
	var title_panel := Panel.new()
	title_panel.custom_minimum_size = Vector2(0, 88)
	_style_panel(title_panel, Color(0.03, 0.12, 0.05, 1.0))
	vbox.add_child(title_panel)

	var title_hbox := HBoxContainer.new()
	title_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_hbox.offset_left = 20; title_hbox.offset_right = -20
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_panel.add_child(title_hbox)

	var back_btn := Button.new(); back_btn.text = "← 返回主菜单"
	_style_btn(back_btn, Color(0.20, 0.08, 0.04))
	back_btn.custom_minimum_size = Vector2(190, 54)
	back_btn.pressed.connect(GameManager.go_to_main_menu)
	title_hbox.add_child(back_btn)

	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(sp)

	var title_lbl := Label.new(); title_lbl.text = "🌶  选择实验关卡"
	title_lbl.add_theme_font_size_override("font_size", 52)
	title_lbl.add_theme_color_override("font_color", Color(0.30, 1.0, 0.45))
	title_hbox.add_child(title_lbl)

	var sp2 := Control.new(); sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(sp2)

	var reset_btn := Button.new(); reset_btn.text = "重置进度"
	_style_btn(reset_btn, Color(0.25, 0.05, 0.04))
	reset_btn.custom_minimum_size = Vector2(150, 54)
	reset_btn.pressed.connect(_on_reset_pressed)
	title_hbox.add_child(reset_btn)

	# 进度条
	var prog_panel := Panel.new()
	prog_panel.custom_minimum_size = Vector2(0, 56)
	_style_panel(prog_panel, Color(0.05, 0.14, 0.06, 1.0))
	vbox.add_child(prog_panel)

	var prog_label := Label.new()
	var done := GameManager.completed_levels.size()
	prog_label.text = "已完成 %d / 7 关卡  (%d%%)" % [done, int(done / 7.0 * 100)]
	prog_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prog_label.add_theme_font_size_override("font_size", 30)
	prog_label.add_theme_color_override("font_color", Color(0.70, 0.92, 0.72))
	prog_panel.add_child(prog_label)

	# 关卡卡片网格
	var sp3 := Control.new(); sp3.custom_minimum_size = Vector2(0, 12); vbox.add_child(sp3)
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(center)
	center.add_child(grid)

	var card_width := 380

	for i in 7:
		var lv := i + 1
		var unlocked := true
		var completed := GameManager.is_level_completed(lv)
		var card := _make_card(lv, unlocked, completed, card_width)
		grid.add_child(card)

	var sp4 := Control.new(); sp4.custom_minimum_size = Vector2(0, 30); vbox.add_child(sp4)

func _make_card(lv: int, unlocked: bool, completed: bool, width: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(width, 262)

	var bg_color: Color
	if completed:
		bg_color = Color(0.06, 0.22, 0.08, 1.0)
	elif unlocked:
		bg_color = Color(0.05, 0.14, 0.18, 1.0)
	else:
		bg_color = Color(0.08, 0.08, 0.10, 1.0)

	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.set_border_width_all(2)
	s.border_color = Color(0.25, 0.75, 0.35) if completed \
		else (Color(0.15, 0.45, 0.65) if unlocked else Color(0.22, 0.22, 0.24))
	s.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", s)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18; vb.offset_right = -18
	vb.offset_top = 14; vb.offset_bottom = -14
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vb)

	# 图标 + 状态
	var top_h := HBoxContainer.new()
	top_h.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(top_h)

	var icon_lbl := Label.new()
	icon_lbl.text = LEVEL_ICONS[lv - 1]
	icon_lbl.add_theme_font_size_override("font_size", 58)
	top_h.add_child(icon_lbl)

	if completed:
		var check := Label.new(); check.text = " ✓"
		check.add_theme_font_size_override("font_size", 48)
		check.add_theme_color_override("font_color", Color(0.25, 0.95, 0.40))
		top_h.add_child(check)

	var num_lbl := Label.new()
	num_lbl.text = "关卡 %d：%s" % [lv, GameManager.get_level_name(lv)]
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.add_theme_font_size_override("font_size", 30)
	var tc := Color(0.25, 0.95, 0.45) if completed \
		else (Color(0.30, 0.72, 0.95) if unlocked else Color(0.45, 0.45, 0.50))
	num_lbl.add_theme_color_override("font_color", tc)
	vb.add_child(num_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = LEVEL_DESC[lv - 1]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 24)
	desc_lbl.add_theme_color_override("font_color", Color(0.68, 0.82, 0.70))
	vb.add_child(desc_lbl)

	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 6); vb.add_child(sp)

	var btn := Button.new()
	if completed:
		btn.text = "重新游玩"
	elif unlocked:
		btn.text = "进入实验 ▶"
	else:
		btn.text = "🔒 尚未解锁"
	btn.disabled = not unlocked
	_style_btn(btn,
		Color(0.08, 0.35, 0.14) if completed \
		else (Color(0.08, 0.25, 0.38) if unlocked else Color(0.15, 0.15, 0.18)))
	btn.custom_minimum_size = Vector2(300, 50)
	if unlocked:
		btn.pressed.connect(func(): GameManager.go_to_level(lv))
	vb.add_child(btn)

	return card

func _on_reset_pressed() -> void:
	GameManager.reset_progress()
	get_tree().reload_current_scene()

func _style_panel(p: Panel, color: Color) -> void:
	var s := StyleBoxFlat.new(); s.bg_color = color
	p.add_theme_stylebox_override("panel", s)

func _style_btn(btn: Button, bg: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = bg if state == "normal" else (bg.lightened(0.2) if state == "hover" else bg.darkened(0.2))
		s.set_border_width_all(1); s.border_color = Color(0.28, 0.65, 0.35)
		s.set_corner_radius_all(6)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color.WHITE)
