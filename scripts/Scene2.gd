## Scene2.gd — 辣椒花药选取
## 在盛花期选取单核靠边期花药，并进行低温预处理
extends SceneBase

var temp_value: float = 22.0    # 当前温度（℃）
var temp_lbl: Label             # 温度显示标签
var temp_minus_btn: Button
var temp_plus_btn: Button
var time_btn: Button
var time_lbl: Label
var hours_elapsed: float = 0.0
var time_running: bool = false
var bud_collected: bool = false
var bud_model: Node3D  # 用于动画的花药模型

func _ready() -> void:
	scene_number = 2
	scene_title  = "辣椒花药选取"
	super._ready()

func _configure_camera() -> void:
	camera.position = Vector3(3.5, 3.8, 6.5)
	camera.look_at(Vector3(0.0, 1.2, 0.0))
	camera.fov = 48.0

func _setup_scene() -> void:
	_build_ground()
	_build_pepper_plant()
	_build_cold_storage()
	_build_temp_controls()

func _build_ground() -> void:
	add_static(mk_plane(Vector2(22, 22)), Vector3.ZERO, Color(0.14, 0.32, 0.14))
	# 小土丘
	add_static(mk_sphere(1.2), Vector3(-5, -0.8, -4), Color(0.22, 0.42, 0.18))
	add_static(mk_sphere(0.9), Vector3(5, -0.7, -5), Color(0.20, 0.40, 0.17))

func _build_pepper_plant() -> void:
	# 主茎
	add_static(mk_cyl(0.10, 1.8), Vector3(-1.0, 0.9, 0.0), Color(0.22, 0.52, 0.20))
	# 侧枝
	for i in 4:
		var a := i * TAU / 4
		var bx := sin(a) * 0.45; var bz := cos(a) * 0.45
		add_static(mk_cyl(0.05, 0.60), Vector3(-1.0 + bx, 1.1 + i*0.12, bz),
			Color(0.20, 0.50, 0.18), Vector3(sin(a)*30, 0, cos(a)*30))
	# 叶片（三棱锥）
	for i in 8:
		var a := i * TAU / 8
		var lx := sin(a) * 0.65; var lz := cos(a) * 0.65
		var deg := rad_to_deg(a)
		add_static(mk_prism(Vector3(0.22, 0.28, 0.22)),
			Vector3(-1.0 + lx, 0.38 + i*0.11, lz),
			Color(0.20, 0.58, 0.20), Vector3(0, deg, 0))

	# === 花瓣（5片，白色椭球体）===
	for i in 5:
		var a := i * TAU / 5
		var px := sin(a) * 0.38; var pz := cos(a) * 0.38
		var petal := add_glass(mk_capsule(0.26, 0.80),
			Vector3(-1.0 + px, 1.55, pz),
			Color(1.0, 1.0, 1.0, 0.45),
			Vector3(0.0, rad_to_deg(a), 72.0))
		petal.scale = Vector3(1.8, 0.55, 2.8)

	add_label3d("←花瓣", Vector3(0.9, 1.85, 0.5), 40, Color.WHITE)

# === 花药（五个，分散分布）===
	# 正确：单核靠边期（淡奶油黄色）
	create_interactable("bud_correct",
		Vector3(-1.2, 2.90, 0.20),
		mk_sphere(0.22),
		Color(1.0, 0.92, 0.05),
		Color(1.0, 1.0, 0.40),
		"单核靠边期花药")
	for ch in interactables["bud_correct"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			ch.position = Vector3(0.0, 0.28, 0.0); ch.font_size = 30

	# 错误：花粉母细胞期（绿色）
	create_interactable("bud_early",
		Vector3(-2.4, 2.30, 0.10),
		mk_sphere(0.17),
		Color(0.60, 0.90, 0.62),
		Color(0.75, 1.0, 0.76),
		"花粉母细胞期花药")
	for ch in interactables["bud_early"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			ch.position += Vector3(-0.4, -0.35, 0.0); ch.font_size = 30

	# 错误：二核期（深紫）
	create_interactable("bud_late",
		Vector3(-0.20, 2.50, -0.50),
		mk_sphere(0.28),
		Color(0.75, 0.55, 0.05),
		Color(0.90, 0.70, 0.15),
		"二核期花药")
	for ch in interactables["bud_late"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			ch.position = Vector3(0.0, 0.42, 0.0); ch.font_size = 30

	# 错误：单核早期（黄绿色）
	create_interactable("bud_uninuclear_early",
		Vector3(-0.20, 2.70, 1.00),
		mk_sphere(0.17),
		Color(0.68, 0.88, 0.22),
		Color(0.80, 1.0, 0.35),
		"单核早期花药")
	for ch in interactables["bud_uninuclear_early"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			ch.position = Vector3(0.0, -0.18, 0.0); ch.font_size = 30

	# 错误：成熟期（灰紫）
	create_interactable("bud_mature",
		Vector3(-1.2, 2.10, 1.20),
		mk_sphere(0.17),
		Color(0.80, 0.65, 0.90),
		Color(0.92, 0.80, 1.0),
		"成熟花粉期花药")
	for ch in interactables["bud_mature"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			ch.position = Vector3(-0.85, 0.0, 0.0); ch.font_size = 30

	# 花药区域说明标签
	var bud_area_lbl := add_label3d("处于不同发育时期的花药→", Vector3(-5.0, 1.95, 0.10), 46, Color.WHITE)
	bud_area_lbl.outline_size = 5
	bud_area_lbl.outline_modulate = Color(0.2, 0.1, 0.0, 0.8)

	# 标签
	var plant_lbl := add_label3d("处于盛花状态的辣椒植株", Vector3(-1.0, 3.7, 0), 50, Color(0.8, 1.0, 0.8))
	plant_lbl.outline_size = 6
	plant_lbl.outline_modulate = Color(0.1, 0.3, 0.1, 0.9)

func _build_cold_storage() -> void:
	# 低温处理箱外壳（半透明蓝色）
	add_glass(mk_box(Vector3(2.0, 1.8, 1.6)), Vector3(3.0, 0.9, -0.5), Color(0.22, 0.38, 0.72, 0.35))
	# 箱门玻璃（半透明浅蓝）
	add_glass(mk_box(Vector3(1.6, 1.3, 0.08)), Vector3(3.0, 1.0, 0.32), Color(0.55, 0.72, 0.95, 0.25))
	# 内部底板（半透明白色）
	add_glass(mk_box(Vector3(1.7, 0.15, 1.3)), Vector3(3.0, 0.2, -0.5), Color(0.80, 0.90, 0.98, 0.40))

	create_interactable("cold_box",
		Vector3(3.0, 1.0, -0.5),
		mk_box(Vector3(1.8, 1.6, 1.4)),
		Color(0.22, 0.38, 0.72, 0.0),   # 透明碰撞区
		Color(0.40, 0.58, 0.95),
		"低温预处理箱")
	# 隐藏透明区域的mesh
	interactables["cold_box"]["area"].get_child(0).visible = false
	var lbl_cold := attach_label3d("cold_box", "低温预处理箱\n(3–5 ℃)", Vector3(0, 1.2, 0), 44, Color(0.7, 0.85, 1.0))
	if lbl_cold: lbl_cold.outline_size = 7; lbl_cold.outline_modulate = Color(0.05, 0.1, 0.3, 0.9)

func _build_temp_controls() -> void:
	# 温度控制面板（UI覆盖层）
	var temp_panel := Panel.new()
	temp_panel.anchor_left = 1.0; temp_panel.anchor_right = 1.0
	temp_panel.offset_left = -270; temp_panel.offset_right = -10
	temp_panel.offset_top = 76; temp_panel.offset_bottom = 200
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.10, 0.18, 0.94)
	ps.set_border_width_all(1); ps.border_color = Color(0.20, 0.45, 0.80)
	ps.set_corner_radius_all(8)
	temp_panel.add_theme_stylebox_override("panel", ps)
	temp_panel.visible = false
	temp_panel.name = "TempPanel"
	canvas_layer.add_child(temp_panel)

	var title := Label.new(); title.text = "🌡  温度控制"
	title.position = Vector2(12, 8); title.size = Vector2(240, 30)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	temp_panel.add_child(title)

	temp_lbl = Label.new()
	temp_lbl.text = "%.1f ℃" % temp_value
	temp_lbl.position = Vector2(80, 44); temp_lbl.size = Vector2(100, 36)
	temp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	temp_lbl.add_theme_font_size_override("font_size", 24)
	temp_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	temp_panel.add_child(temp_lbl)

	temp_minus_btn = Button.new(); temp_minus_btn.text = "▼ 降温"
	temp_minus_btn.position = Vector2(12, 44); temp_minus_btn.size = Vector2(65, 36)
	_style_button(temp_minus_btn, Color(0.15, 0.25, 0.50))
	temp_minus_btn.pressed.connect(_on_temp_minus)
	temp_panel.add_child(temp_minus_btn)

	temp_plus_btn = Button.new(); temp_plus_btn.text = "升温 ▲"
	temp_plus_btn.position = Vector2(182, 44); temp_plus_btn.size = Vector2(65, 36)
	_style_button(temp_plus_btn, Color(0.50, 0.18, 0.10))
	temp_plus_btn.pressed.connect(_on_temp_plus)
	temp_panel.add_child(temp_plus_btn)

	# 等待计时按钮
	time_btn = Button.new(); time_btn.text = "⏱ 开始低温预处理"
	time_btn.position = Vector2(8, 90); time_btn.size = Vector2(244, 36)
	_style_button(time_btn, Color(0.08, 0.30, 0.14))
	time_btn.pressed.connect(_on_time_btn_pressed)
	time_btn.visible = false
	temp_panel.add_child(time_btn)

	time_lbl = Label.new()
	time_lbl.text = "已处理：0 小时"
	time_lbl.position = Vector2(12, 88); time_lbl.size = Vector2(244, 30)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.add_theme_font_size_override("font_size", 15)
	time_lbl.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0))
	time_lbl.visible = false
	temp_panel.add_child(time_lbl)

func _define_steps() -> void:
	steps = [
		{
			"title": "📖  步骤说明：选取花药",
			"body": "花药离体培养的第一步是选取合适的花药。\n",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "🌸  操作提示：选取适合进行花药离体培养的花药，可通过花药颜色判断花药内部生殖细胞处于何种发育时期。",
			"body": "盛花状态下的辣椒植株上有多个发育阶段不同的花药————花粉母细胞期花药呈淡绿色，花药中存在处于减数分裂Ⅰ前期的花粉母细胞（2n=24），尚未形成小孢子细胞（精子，n=12）；单核早期花药呈浅黄绿色，减数分裂已完成，产生了小孢子（n=12），但此时期小孢子的脱分化能力较弱；单核靠边期花药呈鲜黄色，此时期小孢子的脱分化能力很强；二核期花药呈深黄色，此时期小孢子细胞完成了一次有丝分裂趋向更加成熟的发育状态，但脱分化能力极低；成熟花粉期花药呈现黄紫色，小孢子细胞成熟度达到最高，具备受精能力，但细胞基本已完全失去脱分化能力。请结合提示信息仔细观察并选取合适的花药。",
			"click_to_advance": false,
			"active_objects": ["bud_correct", "bud_early", "bud_late", "bud_uninuclear_early", "bud_mature"],
			"correct_object": "bud_correct",
			"correct_message": "正确！选取了单核靠边期花药",
			"wrong_message": "这个阶段不适合，请重新选取！"
		},
		{
			"title": "❄  操作：放入低温预处理箱",
			"body": "将采集到的花药放入低温预处理箱。\n"
				+ "低温预处理可以使细胞分裂同步化，提高愈伤组织诱导率。\n"
				+ "请点击低温预处理箱，将花药放入。",
			"click_to_advance": false,
			"active_objects": ["cold_box"],
			"correct_object": "cold_box",
			"correct_message": "花药已放入低温预处理箱"
		},
		{
			"title": "🌡  操作：调节低温处理温度",
			"body": "低温预处理的最佳温度为 3–5 ℃。\n"
				+ "请点击【▼ 降温】按钮将温度降至 3–5 ℃范围内。\n"
				+ "温度过低会损伤细胞，温度过高则达不到预处理效果。",
			"click_to_advance": false,
			"active_objects": []
		},
		{
			"title": "⏱  操作：等待低温预处理完成",
			"body": "低温预处理需要 24–72 小时。\n"
				+ "点击【开始低温预处理】按钮模拟等待，处理时长自动推进至 48 小时。\n"
				+ "处理完成后，花药将作为实验材料进入下一步操作。",
			"click_to_advance": false,
			"active_objects": [],
			"completion_text": "材料选取完成！\n已成功选取单核靠边期花药，并在 3–5℃ 条件下进行了 48 小时低温预处理。\n低温预处理可以使小孢子（花粉细胞）细胞分裂同步化，显著提高后续愈伤组织诱导率。\n准备进入下一步：花药消毒与接种。"
		},
	]

func _on_interactable_clicked(obj_name: String) -> void:
	var step: Dictionary = steps[current_step_index]
	var correct: String = step.get("correct_object", "")

	match current_step_index:
		1:  # 选取花药
			if obj_name == correct:
				flash_message(step.get("correct_message", "正确！"), true)
				_animate_pick(obj_name)
				await get_tree().create_timer(1.2).timeout
				bud_collected = true
				advance_step()
			else:
				flash_message(step.get("wrong_message", "请重试"), false)
		2:  # 放入低温箱
			if obj_name == correct:
				flash_message("花药已放入低温预处理箱", true)
				_animate_bud_to_cold_box()
				await get_tree().create_timer(1.5).timeout
				var tp := canvas_layer.get_node("TempPanel") as Panel
				if tp: tp.visible = true
				advance_step()
		_:
			pass

func _on_temp_minus() -> void:
	if current_step_index != 3:
		return
	temp_value = maxf(0.0, temp_value - 2.0)
	temp_lbl.text = "%.1f ℃" % temp_value
	_check_temp_ok()

func _on_temp_plus() -> void:
	if current_step_index != 3:
		return
	temp_value = minf(25.0, temp_value + 2.0)
	temp_lbl.text = "%.1f ℃" % temp_value
	_check_temp_ok()

func _check_temp_ok() -> void:
	if temp_value >= 3.0 and temp_value <= 5.0:
		flash_message("温度已设置到 %.1f ℃，符合要求！" % temp_value, true)
		time_btn.visible = true
		advance_step()

func _on_time_btn_pressed() -> void:
	if current_step_index != 4:
		return
	time_btn.visible = false
	time_lbl.visible = true
	time_running = true

func _process(delta: float) -> void:
	if not time_running:
		return
	hours_elapsed += delta * 12.0  # 加速模拟
	time_lbl.text = "已处理：%.0f 小时" % hours_elapsed
	if hours_elapsed >= 48.0:
		time_running = false
		time_lbl.text = "低温预处理完成（48 小时）✓"
		flash_message("低温预处理完成！", true)
		await get_tree().create_timer(1.5).timeout
		advance_step()

func _animate_pick(bud_name: String) -> void:
	var area := interactables.get(bud_name, {}).get("area") as Area3D
	if not area:
		return

	# 创建花药模型用于后续动画
	bud_model = Node3D.new()
	bud_model.position = area.position
	add_child(bud_model)

	# 添加花药视觉（黄色球体）
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mk_sphere(0.18)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.92, 0.62)
	mesh_inst.material_override = mat
	bud_model.add_child(mesh_inst)

	# 采摘动画
	var tw := create_tween()
	tw.tween_property(bud_model, "position", bud_model.position + Vector3(0, 0.6, 0), 0.4)
	tw.tween_property(bud_model, "scale", Vector3(1.4, 1.4, 1.4), 0.2)

	# 隐藏原始交互区域
	area.queue_free()

func _animate_bud_to_cold_box() -> void:
	if not bud_model:
		return

	# 花药飞向低温箱的动画
	var target_pos := Vector3(3.0, 0.6, -0.5)  # 低温箱内部位置
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bud_model, "position", target_pos, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bud_model, "scale", Vector3(0.8, 0.8, 0.8), 1.2)

	# 旋转效果
	tw.set_parallel(false)
	tw.tween_property(bud_model, "rotation", Vector3(0, TAU * 2, 0), 1.2)
