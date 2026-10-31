## Scene4.gd — 愈伤组织诱导培养
## 先高温暗培养（热激），再转入光照下培养，诱导花药形成愈伤组织
extends SceneBase

var temp_set: float = 25.0
var is_dark_mode: bool = false
var growth_timer: float = 0.0
var timer_running: bool = false
var _dish_taken: bool = false     # 培养皿已取出

var anther_node: Area3D           # 培养皿交互节点（跟随移动）

# UI 控件
var ui_temp_lbl: Label
var ui_timer_lbl: Label
var ui_temp_minus: Button
var ui_temp_plus: Button
var ui_light_btn: Button
var ui_wait_btn: Button

func _ready() -> void:
	scene_number = 4
	scene_title  = "愈伤组织诱导培养"
	super._ready()

# =====================================================================
# 摄像机：俯视整个实验室，左暗箱、中操作台、右光照箱清晰可见
# =====================================================================
func _configure_camera() -> void:
	camera.position = Vector3(0.0, 5.5, 9.0) * 0.8
	camera.look_at(Vector3(0.0, 1.0, -0.5))
	camera.fov = 58.0

# =====================================================================
# 场景搭建
# =====================================================================
func _setup_scene() -> void:
	_build_room()
	_build_dark_incubator()
	_build_light_incubator()
	_build_operation_table()
	_build_control_panel()

func _build_room() -> void:
	# 地板（浅灰绿）
	add_static(mk_plane(Vector2(26, 26)), Vector3.ZERO, Color(0.72, 0.76, 0.72))
	# 后墙
	add_static(mk_box(Vector3(22, 6, 0.2)), Vector3(0, 3.0, -4.0), Color(0.88, 0.90, 0.86))
	# 地脚线
	add_static(mk_box(Vector3(22, 0.18, 0.18)), Vector3(0, 0.09, -3.9), Color(0.68, 0.70, 0.68))
	# 天花板灯（发光）
	for xi in [-4.0, 0.0, 4.0]:
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(1.0, 0.98, 0.92)
		lmat.emission_enabled = true; lmat.emission = Color(0.55, 0.52, 0.30)
		var lmi := MeshInstance3D.new(); lmi.mesh = mk_box(Vector3(1.6, 0.06, 0.5))
		lmi.material_override = lmat; lmi.position = Vector3(xi, 4.5, -1.0)
		add_child(lmi)

# ----- 左：高温暗培养箱 -----
func _build_dark_incubator() -> void:
	# 主体（半透明深蓝灰，可看到内部花药）
	add_glass(mk_box(Vector3(2.2, 2.6, 1.5)), Vector3(-4.5, 1.3, -2.2), Color(0.22, 0.24, 0.38, 0.38))
	# 前门面板（更透明，像玻璃门）
	add_glass(mk_box(Vector3(2.0, 2.4, 0.06)), Vector3(-4.5, 1.3, -1.44), Color(0.32, 0.32, 0.48, 0.22))
	# 门缝线（亮色条纹，增加质感）
	add_static(mk_box(Vector3(0.02, 2.2, 0.04)), Vector3(-4.5, 1.3, -1.40), Color(0.55, 0.55, 0.68))
	# 门把手
	add_static(mk_cyl(0.05, 0.35), Vector3(-3.65, 1.3, -1.40),
		Color(0.75, 0.78, 0.80), Vector3(90, 0, 0))
	# LED 温度显示屏（发光绿）
	var disp_mat := StandardMaterial3D.new()
	disp_mat.albedo_color = Color(0.05, 0.85, 0.20)
	disp_mat.emission_enabled = true; disp_mat.emission = Color(0.0, 0.55, 0.08)
	var disp_mi := MeshInstance3D.new(); disp_mi.mesh = mk_box(Vector3(0.65, 0.22, 0.02))
	disp_mi.material_override = disp_mat; disp_mi.position = Vector3(-3.75, 2.25, -1.42)
	add_child(disp_mi)
	# 底座
	add_static(mk_box(Vector3(2.4, 0.14, 1.7)), Vector3(-4.5, 0.07, -2.2), Color(0.18, 0.18, 0.28))

	create_interactable("dark_incubator",
		Vector3(-4.5, 1.3, -2.0),
		mk_box(Vector3(2.2, 2.6, 1.8)),
		Color(0, 0, 0, 0), Color(0.60, 0.60, 0.85), "高温暗培养箱")
	interactables["dark_incubator"]["area"].get_child(0).visible = false
	attach_label3d("dark_incubator", "高温暗培养箱", Vector3(0, 1.85, 0), 40, Color(0.82, 0.80, 1.0))

# ----- 右：光照培养箱 -----
func _build_light_incubator() -> void:
	# 主体（半透明乳白，可看到内部灯管和培养物）
	add_glass(mk_box(Vector3(2.2, 2.6, 1.5)), Vector3(4.5, 1.3, -2.2), Color(0.90, 0.92, 0.88, 0.30))
	# 前门（淡蓝玻璃，高度透明）
	add_glass(mk_box(Vector3(2.0, 2.4, 0.06)), Vector3(4.5, 1.3, -1.44), Color(0.68, 0.82, 0.96, 0.20))
	# 门缝
	add_static(mk_box(Vector3(0.02, 2.2, 0.04)), Vector3(4.5, 1.3, -1.40), Color(0.50, 0.65, 0.80))
	# 内部发光灯管（×3）
	for i in 3:
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(1.0, 0.98, 0.88)
		lmat.emission_enabled = true; lmat.emission = Color(0.65, 0.60, 0.20)
		var lmi := MeshInstance3D.new(); lmi.mesh = mk_cyl(0.035, 1.7)
		lmi.material_override = lmat
		lmi.position = Vector3(4.5, 2.4 - i * 0.55, -2.2)
		lmi.rotation_degrees = Vector3(0, 0, 90)
		add_child(lmi)
	# 门把手
	add_static(mk_cyl(0.05, 0.35), Vector3(5.35, 1.3, -1.40),
		Color(0.55, 0.58, 0.60), Vector3(90, 0, 0))
	# 底座
	add_static(mk_box(Vector3(2.4, 0.14, 1.7)), Vector3(4.5, 0.07, -2.2), Color(0.72, 0.74, 0.70))

	create_interactable("light_incubator",
		Vector3(4.5, 1.3, -2.0),
		mk_box(Vector3(2.2, 2.6, 1.8)),
		Color(0, 0, 0, 0), Color(1.0, 1.0, 0.72), "光照培养箱")
	interactables["light_incubator"]["area"].get_child(0).visible = false
	attach_label3d("light_incubator", "光照培养箱", Vector3(0, 1.85, 0), 40, Color(0.88, 1.0, 0.62))

# ----- 中：操作台 + 培养皿 -----
func _build_operation_table() -> void:
	# 台腿（四根）
	for xo in [-0.9, 0.9]:
		for zo in [-0.5, 0.8]:
			add_static(mk_box(Vector3(0.09, 0.92, 0.09)),
				Vector3(xo, 0.46, zo), Color(0.50, 0.52, 0.55))
	# 台面
	add_static(mk_box(Vector3(2.4, 0.09, 1.6)), Vector3(0.0, 0.97, 0.15), Color(0.95, 0.96, 0.92))
	# 台面边沿（深色）
	add_static(mk_box(Vector3(2.42, 0.04, 1.62)), Vector3(0.0, 0.93, 0.15), Color(0.45, 0.48, 0.45))
	# 下层板
	add_static(mk_box(Vector3(2.2, 0.05, 1.4)), Vector3(0.0, 0.42, 0.15), Color(0.75, 0.78, 0.75))

	# 培养皿（放在台面中央）
	# 皿壁（深色圆环）
	add_static(mk_cyl(0.55, 0.06), Vector3(0.0, 1.03, 0.15), Color(0.32, 0.40, 0.32))
	# 皿内壁（奶白）
	add_static(mk_cyl(0.48, 0.07), Vector3(0.0, 1.06, 0.15), Color(0.96, 0.95, 0.90))
	# 花药内容物（金黄色，足够高便于点击）
	anther_node = create_interactable("anther_dish",
		Vector3(0.0, 1.18, 0.15),
		mk_cyl(0.40, 0.26),
		Color(0.85, 0.70, 0.18), Color(1.0, 0.90, 0.25), "诱导愈伤组织培养皿")
	attach_label3d("anther_dish", "诱导愈伤组织培养皿\n（点击取出）", Vector3(0, 0.47, 0), 42, Color(1.0, 0.95, 0.60))

# =====================================================================
# 右侧条件控制面板 UI
# =====================================================================
func _build_control_panel() -> void:
	var cp := Panel.new()
	cp.anchor_right = 1.0
	cp.offset_left = -310; cp.offset_right = -10
	cp.offset_top = 70; cp.offset_bottom = 210
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.10, 0.06, 0.95)
	ps.set_border_width_all(1); ps.border_color = Color(0.22, 0.55, 0.28)
	ps.set_corner_radius_all(8)
	cp.add_theme_stylebox_override("panel", ps)
	canvas_layer.add_child(cp)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 12; vb.offset_right = -12
	vb.offset_top = 10; vb.offset_bottom = -10
	vb.add_theme_constant_override("separation", 10)
	cp.add_child(vb)

	var h1 := Label.new(); h1.text = "🌡  培养条件设置（供参考）"
	h1.add_theme_font_size_override("font_size", 15)
	h1.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	vb.add_child(h1)

	var hb_t := HBoxContainer.new(); vb.add_child(hb_t)


	ui_temp_lbl = Label.new(); ui_temp_lbl.text = "  25.0 ℃  "
	ui_temp_lbl.add_theme_font_size_override("font_size", 20)
	ui_temp_lbl.add_theme_color_override("font_color", Color.WHITE)
	ui_temp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_temp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb_t.add_child(ui_temp_lbl)

	ui_light_btn = Button.new()
	ui_light_btn.custom_minimum_size = Vector2(90, 34)
	_style_button(ui_light_btn, Color(0.35, 0.28, 0.04))
	ui_light_btn.pressed.connect(func(): _on_toggle_light())
	hb_t.add_child(ui_light_btn)

	ui_temp_plus = Button.new(); ui_temp_plus.text = "升温 ▲"
	ui_temp_plus.custom_minimum_size = Vector2(72, 34)
	_style_button(ui_temp_plus, Color(0.50, 0.18, 0.10))
	ui_temp_plus.pressed.connect(func(): _on_temp_up())
	hb_t.add_child(ui_temp_plus)

	ui_temp_minus = Button.new(); ui_temp_minus.text = "▼ 降温"
	ui_temp_minus.custom_minimum_size = Vector2(72, 34)
	_style_button(ui_temp_minus, Color(0.15, 0.22, 0.50))
	ui_temp_minus.pressed.connect(func(): _on_temp_down())
	hb_t.add_child(ui_temp_minus)

	_update_light_display()

	var sep := Control.new(); sep.custom_minimum_size = Vector2(0, 6); vb.add_child(sep)

	ui_timer_lbl = Label.new(); ui_timer_lbl.text = "培养时间：— 天"
	ui_timer_lbl.add_theme_font_size_override("font_size", 15)
	ui_timer_lbl.add_theme_color_override("font_color", Color(0.75, 0.90, 0.78))
	vb.add_child(ui_timer_lbl)

	ui_wait_btn = Button.new(); ui_wait_btn.text = "⏩  加速模拟培养过程"
	ui_wait_btn.custom_minimum_size = Vector2(0, 68)
	_style_button(ui_wait_btn, Color(0.08, 0.32, 0.14))
	ui_wait_btn.pressed.connect(_on_wait_pressed)
	ui_wait_btn.visible = false
	vb.add_child(ui_wait_btn)

# =====================================================================
# 步骤定义
# =====================================================================
func _define_steps() -> void:
	steps = [
		{
			"title": "📖  诱导愈伤组织——最关键步骤",
			"body": "诱导愈伤组织分两个阶段：\n"
				+ "① 热激阶段：33–37 ℃ + 黑暗培养 2–10 天（热激诱导小孢子<花粉细胞>脱分化）\n"
				+ "② 光照培养：转入 25 ℃ + 光照条件下培养（促进愈伤组织细胞增殖）\n"
				+ "右侧面板可调节温度和光照模式。",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "① 取出培养皿 → 放入高温暗培养箱",
			"body": "先点击中央操作台上的【诱导愈伤组织培养皿】取出，\n"
				+ "再点击左侧的【高温暗培养箱】将培养皿放入。\n"
				+ "可先用右侧面板将温度调至 33–37 ℃、切换为黑暗模式。",
			"click_to_advance": false,
			"active_objects": ["anther_dish", "dark_incubator"]
		},
		{
			"title": "② 热激暗培养（33–37 ℃，黑暗，2–10 天）",
			"body": "花药正在高温暗培养箱中进行热激处理。\n"
				+ "点击右侧的【⏩ 加速模拟培养过程】按钮，观察花药的变化。\n"
				+ "花药将逐渐膨大，小孢子（花粉）细胞开始脱分化，形成愈伤组织。",
			"click_to_advance": false,
			"active_objects": []
		},
		{
			"title": "③ 转入光照培养箱（25 ℃，光照）",
			"body": "热激处理完成！愈伤组织已初步形成。\n"
				+ "点击右侧的【光照培养箱】，将愈伤组织转入进行下一阶段培养。",
			"click_to_advance": false,
			"active_objects": ["light_incubator"],
			"correct_object": "light_incubator",
			"correct_message": "愈伤组织已转入光照培养箱 ✓"
		},
		{
			"title": "④ 光照培养，愈伤组织增殖",
			"body": "在 25 ℃ 光照条件下，愈伤组织将快速增殖成较大的绿色组织块。\n"
				+ "点击【⏩ 加速模拟培养过程】按钮，观察愈伤组织的生长。",
			"click_to_advance": false,
			"active_objects": [],
			"completion_text": "愈伤组织诱导完成！\n经过热激（33–37℃，黑暗）→ 光照（25℃）两阶段处理，\n花药中的单倍体小孢子（花粉细胞）成功脱分化形成了愈伤组织。\n这是单倍体育种最关键的一步！\n接下来将诱导愈伤组织分化出芽和根，发育成完整植株。"
		},
	]

# =====================================================================
# 交互逻辑
# =====================================================================
func _on_interactable_clicked(obj_name: String) -> void:
	match current_step_index:
		1:
			if obj_name == "anther_dish":
				flash_message("已取出培养皿，请点击左侧暗培养箱放入", true)
				_dish_taken = true
				_refresh_highlights(["dark_incubator"])
			elif obj_name == "dark_incubator":
				if not _dish_taken:
					flash_message("请先点击操作台上的培养皿将其取出！", false)
				elif temp_set < 33.0 or temp_set > 37.0:
					flash_message("温度不对！热激需要 33–37 ℃，当前 %.0f ℃\n请用右侧面板先升温！" % temp_set, false)
				elif not is_dark_mode:
					flash_message("需要切换为【黑暗模式】才能进行热激培养！\n请点击右侧面板的光照切换按钮！", false)
				else:
					flash_message("培养皿已放入高温暗培养箱 ✓", true)
					_animate_dish_to(Vector3(-4.5, 1.3, -2.0))
					await get_tree().create_timer(1.0).timeout
					advance_step()
					ui_wait_btn.visible = true
		3:
			if obj_name == "light_incubator":
				if temp_set < 23.0 or temp_set > 27.0:
					flash_message("温度不对！光照培养需要 25 ℃，当前 %.0f ℃\n请先降温至 25 ℃！" % temp_set, false)
				elif is_dark_mode:
					flash_message("需要切换为【光照模式】才能进行光照培养！\n请点击右侧面板的光照切换按钮！", false)
				else:
					flash_message("愈伤组织已转入光照培养箱 ✓", true)
					_animate_dish_to(Vector3(4.5, 1.3, -2.0))
					await get_tree().create_timer(1.0).timeout
					advance_step()
					ui_wait_btn.visible = true
					timer_running = false; growth_timer = 0.0
		_:
			pass

func _animate_dish_to(target: Vector3) -> void:
	if not anther_node: return
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(anther_node, "position",
		target + Vector3(0, 0.2, 0), 0.8)

# =====================================================================
# 控制面板回调
# =====================================================================
func _on_temp_down() -> void:
	temp_set = temp_set - 2.0
	if temp_set < 15.0:
		temp_set = 15.0
	_update_temp_display()

func _on_temp_up() -> void:
	temp_set = temp_set + 2.0
	if temp_set > 45.0:
		temp_set = 45.0
	_update_temp_display()

func _update_temp_display() -> void:
	if not ui_temp_lbl: return
	ui_temp_lbl.text = "  %.1f ℃  " % temp_set
	# 根据当前步骤突出显示的正确温度范围
	var ok := false
	if current_step_index <= 2:
		ok = (temp_set >= 33.0 and temp_set <= 37.0)
	else:
		ok = (temp_set >= 23.0 and temp_set <= 27.0)
	var col := Color(0.35, 1.0, 0.45) if ok else Color(1.0, 0.85, 0.30)
	ui_temp_lbl.add_theme_color_override("font_color", col)

func _on_toggle_light() -> void:
	is_dark_mode = not is_dark_mode
	_update_light_display()

func _update_light_display() -> void:
	if not ui_light_btn: return
	if is_dark_mode:
		ui_light_btn.text = "🌑  当前：黑暗模式  →  切换光照"
	else:
		ui_light_btn.text = "💡  当前：光照模式  →  切换黑暗"

func _on_wait_pressed() -> void:
	if timer_running: return
	timer_running = true
	ui_wait_btn.disabled = true

# =====================================================================
# 培养生长动画（_process）
# =====================================================================
var _days_shown: float = 0.0

func _process(delta: float) -> void:
	if not timer_running: return
	growth_timer += delta * 3.5
	_days_shown = growth_timer

	if current_step_index == 2:
		ui_timer_lbl.text = "热激培养：%.1f 天" % _days_shown
		# 花药逐渐膨大 → 颜色变绿（愈伤组织）
		if anther_node:
			var sc := 1.0 + clampf(growth_timer / 6.0, 0.0, 0.9)
			anther_node.scale = Vector3(sc, 0.8 + sc * 0.4, sc)
			var mat := interactables.get("anther_dish", {}).get("mat") as StandardMaterial3D
			if mat:
				var t := clampf(growth_timer / 7.0, 0.0, 1.0)
				mat.albedo_color = Color(0.85 - t * 0.4, 0.70 + t * 0.15, 0.18 + t * 0.15)
		if growth_timer >= 7.0:
			timer_running = false
			ui_wait_btn.disabled = false
			flash_message("热激处理完成！花药已膨大，愈伤组织形成", true)
			await get_tree().create_timer(1.5).timeout
			advance_step()
			_refresh_highlights(["light_incubator"])
			ui_wait_btn.visible = false

	elif current_step_index == 4:
		ui_timer_lbl.text = "光照培养：%.1f 天" % _days_shown
		if anther_node:
			var sc := minf(anther_node.scale.x + delta * 0.35, 2.6)
			anther_node.scale = Vector3(sc, 1.1, sc)
			var mat := interactables.get("anther_dish", {}).get("mat") as StandardMaterial3D
			if mat:
				mat.albedo_color = Color(0.30, 0.78, 0.32)
		if growth_timer >= 10.0:
			timer_running = false
			ui_wait_btn.disabled = false
			flash_message("愈伤组织充分增殖，可进入下一关！", true)
			await get_tree().create_timer(1.5).timeout
			advance_step()
