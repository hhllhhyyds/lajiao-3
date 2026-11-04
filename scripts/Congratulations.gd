## Congratulations.gd — 完成画面
extends Node

var canvas: CanvasLayer
var _t: float = 0.0
var _confetti: Array[Control] = []

func _ready() -> void:
	canvas = CanvasLayer.new(); add_child(canvas)
	_build_ui()
	_spawn_confetti()

func _process(delta: float) -> void:
	_t += delta
	for c in _confetti:
		if is_instance_valid(c):
			c.position.y += delta * 120
			c.position.x += sin(_t * 2 + c.position.y * 0.01) * delta * 30
			c.rotation += delta * 2.5
			if c.position.y > 740:
				c.position.y = -20
				c.position.x = randf_range(0, 1280)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.10, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var center := Control.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel := Panel.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top  = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -520; panel.offset_right = 520
	panel.offset_top  = -430; panel.offset_bottom = 430
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.14, 0.06, 0.97)
	ps.set_border_width_all(3); ps.border_color = Color(0.28, 0.80, 0.38)
	ps.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 32; vb.offset_right = -32
	vb.offset_top = 28; vb.offset_bottom = -28
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)

	_lbl(vb, "🏆  实验全部完成！", 60, Color(1.0, 0.88, 0.15))
	_sp(vb, 14)
	_lbl(vb, "辣椒单倍体育种流程探究实验平台", 40, Color(0.35, 1.0, 0.50))
	_sp(vb, 24)

	var summary := """你已成功完成全部 6 个实验步骤：

 🌸  场景 1  —  辣椒花药选取（单核靠边期花药 + 低温预处理）
 🧪  场景 2  —  花药消毒与接种（酒精 + NaClO 无菌操作）
 🌱  场景 3  —  愈伤组织诱导（热激暗培养 → 光照培养）
 🌿  场景 4  —  生芽与生根（细胞分裂素 + 生长素培养基）
 🔬  场景 5  —  倍性鉴定（染色体计数，筛选 n=12 单倍体）
 🧬  场景 6  —  染色体加倍（秋水仙素 → 纯合 DH 系植株）"""
	_lbl(vb, summary, 27, Color(0.82, 0.95, 0.84))
	_sp(vb, 26)
	_lbl(vb, "单倍体育种优势：将育种年限从 7–8 年缩短至 2–3 年！", 28, Color(0.65, 0.92, 0.68))
	_sp(vb, 32)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 20)
	vb.add_child(hb)

	_btn(hb, "🔄  重新实验", func(): GameManager.reset_progress(); GameManager.go_to_level(1))
	_btn(hb, "📋  关卡选择", GameManager.go_to_level_select, Color(0.10, 0.28, 0.42))
	_btn(hb, "🏠  返回主菜单", GameManager.go_to_main_menu, Color(0.24, 0.08, 0.05))

func _spawn_confetti() -> void:
	var colors := [
		Color(0.20, 0.85, 0.35), Color(0.95, 0.22, 0.22),
		Color(0.25, 0.60, 0.95), Color(1.0, 0.88, 0.10),
		Color(0.80, 0.30, 0.90), Color(0.95, 0.55, 0.12)
	]
	for i in 60:
		var c := ColorRect.new()
		c.size = Vector2(randf_range(8, 18), randf_range(8, 18))
		c.position = Vector2(randf_range(0, 1280), randf_range(-100, 760))
		c.color = colors[randi() % colors.size()]
		c.rotation = randf() * TAU
		canvas.add_child(c)
		_confetti.append(c)

func _lbl(parent: Control, text: String, fs: int, color: Color) -> Label:
	var l := Label.new(); l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l); return l

func _sp(parent: Control, h: int) -> void:
	var s := Control.new(); s.custom_minimum_size = Vector2(0, h); parent.add_child(s)

func _btn(parent: Control, text: String, cb: Callable,
		bg: Color = Color(0.10, 0.38, 0.16)) -> Button:
	var btn := Button.new(); btn.text = text
	btn.custom_minimum_size = Vector2(250, 64)
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = bg if state == "normal" else (bg.lightened(0.22) if state == "hover" else bg.darkened(0.2))
		s.set_border_width_all(1); s.border_color = Color(0.30, 0.70, 0.38)
		s.set_corner_radius_all(8)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(cb)
	parent.add_child(btn); return btn
