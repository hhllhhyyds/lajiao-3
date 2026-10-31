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

const PLANT_SCENE := preload("res://assets/props/pepper_plant.glb")
const ANTHER_SCENE := preload("res://assets/props/anther.glb")
const MAT_STEM := preload("res://materials/stem.tres")
const MAT_LEAF := preload("res://materials/leaf.tres")
const MAT_PETAL := preload("res://materials/petal.tres")
const MAT_CALYX := preload("res://materials/calyx.tres")
const MAT_FILAMENT := preload("res://materials/anther_filament.tres")
const MAT_PICKED := preload("res://materials/anther_picked.tres")
const MAT_CASE := preload("res://materials/fridge_case.tres")
const MAT_INNER := preload("res://materials/fridge_inner.tres")
const MAT_STEEL := preload("res://materials/stainless.tres")
const MAT_DOOR := preload("res://materials/fridge_door.tres")
const MAT_DISPLAY := preload("res://materials/display_black.tres")

func _ready() -> void:
	scene_number = 2
	scene_title  = "辣椒花药选取"
	env_preset = "outdoor"
	light_focus = Vector3(-0.8, 1.3, 0.0)
	light_radius = 3.2
	light_intensity = 0.95
	light_key_yaw = 24.0
	super._ready()

func _configure_camera() -> void:
	camera.position = Vector3(1.90, 2.45, 7.15)
	camera.look_at(Vector3(0.10, 1.15, 0.10))
	camera.fov = 42.0

func _setup_scene() -> void:
	_build_ground()
	_build_pepper_plant()
	_build_cold_storage()
	_build_temp_controls()

func _build_ground() -> void:
	# 田块：深绿草地 + 植株根部一圈裸土
	add_static(mk_plane(Vector2(26, 26)), Vector3.ZERO, Color(0.10, 0.19, 0.07))
	add_static(mk_cyl(0.92, 0.04), Vector3(-1.0, 0.015, 0.0), Color(0.10, 0.078, 0.055))
	add_static(mk_sphere(1.6), Vector3(-7.5, -1.1, -6.5), Color(0.13, 0.23, 0.09))
	add_static(mk_sphere(1.2), Vector3(7.0, -1.0, -6.0), Color(0.12, 0.21, 0.08))

	# 草丛：给地面一个尺度参照，否则 26 m 的平面看不出大小
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261101
	for i in 220:
		var ang := rng.randf() * TAU
		var dist := 0.9 + rng.randf() * 6.5
		var p := Vector3(-1.0 + cos(ang) * dist, 0.0, sin(ang) * dist)
		# 让开低温箱和植株根部
		if p.x > 0.6 and p.x < 3.4 and p.z > -1.6 and p.z < 0.8:
			continue
		var h := 0.05 + rng.randf() * 0.10
		var blade := add_static(mk_cyl(0.006 + rng.randf() * 0.006, h), p + Vector3(0, h * 0.5, 0),
			Color(0.16 + rng.randf() * 0.08, 0.30 + rng.randf() * 0.10, 0.10))
		blade.rotation_degrees = Vector3(rng.randf_range(-9.0, 9.0), rng.randf() * 360.0,
			rng.randf_range(-9.0, 9.0))

func _build_pepper_plant() -> void:
	# 整株模型（Blender 参数化生成：主干二歧分枝 + 叶片 + 白花）
	PropKit.spawn(self, PLANT_SCENE, Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 20.0, 0.0), {
		"pepper_plant_stem": MAT_STEM,
		"pepper_plant_br": MAT_STEM,
		"pepper_plant_leaf": MAT_LEAF,
		"pepper_plant_calyx": MAT_CALYX,
		"pepper_plant_fl": MAT_PETAL,
	}, Vector3(1.55, 1.55, 1.55))

	add_label3d("←花瓣", Vector3(-0.30, 1.70, 0.55), 40, Color.WHITE)

	# 五个发育期的花药标本（球体只做碰撞，外观用真实花药模型）
	_anther_specimen("bud_correct", Vector3(-1.54, 1.90, 0.26), 0.22,
		Color(1.0, 0.92, 0.05), Color(1.0, 1.0, 0.40), "单核靠边期花药", 21.0, 18.0)
	_anther_specimen("bud_early", Vector3(-1.98, 1.68, 0.02), 0.17,
		Color(0.60, 0.90, 0.62), Color(0.75, 1.0, 0.76), "花粉母细胞期花药", 18.0, -32.0)
	_anther_specimen("bud_late", Vector3(-0.62, 1.98, -0.40), 0.28,
		Color(0.75, 0.55, 0.05), Color(0.90, 0.70, 0.15), "二核期花药", 26.0, 42.0)
	_anther_specimen("bud_uninuclear_early", Vector3(-0.44, 1.78, 0.74), 0.17,
		Color(0.68, 0.88, 0.22), Color(0.80, 1.0, 0.35), "单核早期花药", 18.0, 8.0)
	_anther_specimen("bud_mature", Vector3(-1.28, 1.60, 0.88), 0.17,
		Color(0.80, 0.65, 0.90), Color(0.92, 0.80, 1.0), "成熟花粉期花药", 18.0, -14.0)

	# 花药区域说明标签
	var bud_area_lbl := add_label3d("处于不同发育时期的花药→", Vector3(-2.95, 2.05, 0.10), 46, Color.WHITE)
	bud_area_lbl.outline_size = 5
	bud_area_lbl.outline_modulate = Color(0.2, 0.1, 0.0, 0.8)

	# 标签
	var plant_lbl := add_label3d("处于盛花状态的辣椒植株", Vector3(-1.0, 2.62, 0), 50, Color(0.8, 1.0, 0.8))
	plant_lbl.outline_size = 6
	plant_lbl.outline_modulate = Color(0.1, 0.3, 0.1, 0.9)

## 花药标本：球形碰撞体 + 真实花药外观，材质与交互体共用以便高亮
func _anther_specimen(nm: String, pos: Vector3, size: float, color: Color,
		hover: Color, tooltip: String, scl: float, tilt: float = 20.0) -> void:
	create_interactable(nm, pos, mk_sphere(size), color, hover, tooltip)
	var area: Area3D = interactables[nm]["area"]
	area.get_child(0).visible = false
	PropKit.spawn(area, ANTHER_SCENE, Vector3(0.0, 0.05, 0.0), Vector3(tilt, 0.0, 0.0), {
		"anther_body": interactables[nm]["mat"],
		"anther_filament": MAT_FILAMENT,
	}, Vector3(scl, scl, scl))

func _panel(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := add_static(mk_box(size), pos, Color.WHITE)
	mi.material_override = mat
	return mi

func _build_cold_storage() -> void:
	# 低温预处理柜：白色箱体 + 内胆 + 两层隔板 + 玻璃门 + 温度显示
	var w := 2.0
	var h := 1.8
	var d := 1.6
	var c := Vector3(2.05, 0.9, -0.42)
	var t := 0.05

	_panel(Vector3(w, h, t), c + Vector3(0.0, 0.0, -d * 0.5), MAT_CASE)
	_panel(Vector3(t, h, d), c + Vector3(-w * 0.5, 0.0, 0.0), MAT_CASE)
	_panel(Vector3(t, h, d), c + Vector3(w * 0.5, 0.0, 0.0), MAT_CASE)
	_panel(Vector3(w, t, d), c + Vector3(0.0, h * 0.5, 0.0), MAT_CASE)
	_panel(Vector3(w, t, d), c + Vector3(0.0, -h * 0.5, 0.0), MAT_CASE)

	# 内胆：比外壳略小一圈的浅色板，制造"箱内有空间"的层次
	_panel(Vector3(w - 0.1, h - 0.1, 0.02), c + Vector3(0.0, 0.0, -d * 0.5 + 0.05), MAT_INNER)

	# 隔板
	for sy in [-0.28, 0.16]:
		_panel(Vector3(w - 0.14, 0.03, d - 0.16), c + Vector3(0.0, sy, 0.02), MAT_STEEL)

	# 前框 + 玻璃门
	_panel(Vector3(w, 0.10, t), c + Vector3(0.0, h * 0.5 - 0.05, d * 0.5), MAT_CASE)
	_panel(Vector3(w, 0.10, t), c + Vector3(0.0, -h * 0.5 + 0.05, d * 0.5), MAT_CASE)
	_panel(Vector3(0.08, h, t), c + Vector3(-w * 0.5 + 0.04, 0.0, d * 0.5), MAT_CASE)
	_panel(Vector3(0.08, h, t), c + Vector3(w * 0.5 - 0.04, 0.0, d * 0.5), MAT_CASE)
	var door := add_glass(mk_box(Vector3(w - 0.16, h - 0.20, 0.02)),
		c + Vector3(0.0, 0.0, d * 0.5), Color(0.72, 0.86, 0.96, 0.16))
	door.material_override = MAT_DOOR

	# 门把手
	_panel(Vector3(0.05, 0.34, 0.05), c + Vector3(w * 0.5 - 0.16, 0.0, d * 0.5 + 0.05), MAT_STEEL)

	# 温度显示条
	var disp := add_static(mk_box(Vector3(0.42, 0.16, 0.04)),
		c + Vector3(0.0, h * 0.5 + 0.10, d * 0.5 - 0.10), Color(0.05, 0.10, 0.14))
	disp.material_override = MAT_DISPLAY
	var lbl_disp := add_label3d("3–5 ℃", c + Vector3(0.0, h * 0.5 + 0.10, d * 0.5 + 0.06), 34, Color(0.45, 1.0, 0.72))
	lbl_disp.outline_size = 5
	lbl_disp.outline_modulate = Color(0.0, 0.10, 0.06, 0.9)

	# 柜内冷光
	var cool := OmniLight3D.new()
	cool.position = c + Vector3(0.0, 0.30, 0.10)
	cool.light_color = Color(0.72, 0.88, 1.0)
	cool.light_energy = 1.1
	cool.omni_range = 1.9
	add_child(cool)

	create_interactable("cold_box",
		c,
		mk_box(Vector3(1.8, 1.6, 1.4)),
		Color(0.30, 0.50, 0.72, 0.0),
		Color(0.45, 0.72, 1.0),
		"低温预处理箱")
	interactables["cold_box"]["area"].get_child(0).visible = false
	var lbl_cold := attach_label3d("cold_box", "低温预处理箱", Vector3(0, 1.42, 0), 44, Color(0.72, 0.88, 1.0))
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

	# 采摘后的花药用真实模型，保持在原花药的位置（不要飘到画面外）
	bud_model = Node3D.new()
	bud_model.position = area.position
	add_child(bud_model)
	PropKit.spawn(bud_model, ANTHER_SCENE, Vector3.ZERO, Vector3(16.0, 0.0, 0.0), {
		"anther_body": MAT_PICKED,
		"anther_filament": MAT_FILAMENT,
	}, Vector3(20.0, 20.0, 20.0))

	# 采摘动画：轻微上提 + 放大，表示"被选中"
	var tw := create_tween()
	tw.tween_property(bud_model, "position", bud_model.position + Vector3(0, 0.22, 0), 0.4)
	tw.tween_property(bud_model, "scale", Vector3(1.25, 1.25, 1.25), 0.2)

	area.queue_free()

func _animate_bud_to_cold_box() -> void:
	if not bud_model:
		return

	# 花药飞向低温箱的动画
	var target_pos := Vector3(2.05, 0.6, -0.42)  # 低温箱内部位置
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bud_model, "position", target_pos, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bud_model, "scale", Vector3(0.8, 0.8, 0.8), 1.2)

	# 旋转效果
	tw.set_parallel(false)
	tw.tween_property(bud_model, "rotation", Vector3(0, TAU * 2, 0), 1.2)
