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

# 展示花：位置、朝向、半径（花心里放五枚花药）
const FLOWER_CENTER := Vector3(-1.00, 1.88, 0.30)
const FLOWER_EULER := Vector3(412.0, -18.0, 0.0)
const FLOWER_RADIUS := 0.92
var _flower_xf: Transform3D
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
	# 提示条排队：红框/绿框严格一条退出后另一条才出现，避免重叠
	queue_toasts = true
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
	add_static(mk_plane(Vector2(90, 90)), Vector3.ZERO, Color(0.24, 0.36, 0.15))
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

	# 一朵展示花：五种发育程度的花药都长在这一朵花里
	_build_display_flower()

	# 五枚花药按花心里的一小簇摆放（坐标是花朵平面内的局部坐标）
	_anther_specimen("bud_correct", Vector3(0.00, 0.02, -0.30), 0.15,
		Color(0.64, 0.54, 0.02), Color(1.0, 0.92, 0.35), "单核靠边期花药", 29.0, 8.0)
	_anther_specimen("bud_uninuclear_early", Vector3(0.29, 0.02, -0.09), 0.12,
		Color(0.34, 0.50, 0.03), Color(0.78, 0.95, 0.30), "单核早期花药", 24.0, 4.0)
	_anther_specimen("bud_late", Vector3(0.18, 0.02, 0.24), 0.17,
		Color(0.48, 0.31, 0.02), Color(0.90, 0.72, 0.12), "二核期花药", 33.0, 14.0)
	_anther_specimen("bud_mature", Vector3(-0.18, 0.02, 0.24), 0.12,
		Color(0.32, 0.16, 0.40), Color(0.82, 0.62, 1.0), "成熟花粉期花药", 24.0, -6.0)
	_anther_specimen("bud_early", Vector3(-0.29, 0.02, -0.09), 0.12,
		Color(0.14, 0.40, 0.14), Color(0.62, 1.0, 0.62), "花粉母细胞期花药", 24.0, -12.0)

	# 标签：花药说明跟在"盛花期"后面，用括号括起来
	var plant_lbl := add_label3d(
		"处于盛花状态的辣椒植株（这朵花里有 5 种发育程度的花药）",
		Vector3(-1.0, 2.86, 0), 54, Color(0.8, 1.0, 0.8))
	plant_lbl.outline_size = 6
	plant_lbl.outline_modulate = Color(0.1, 0.3, 0.1, 0.9)
	plant_lbl.font_px = 34   # size 参数会被 _font_for 钳在 27px，放大只能走 font_px
	plant_lbl.bold = true

## 展示花：花瓣平铺成盘，花心留空，花药立在中间不会被遮挡
func _build_display_flower() -> void:
	_flower_xf = Transform3D(
		Basis.from_euler(Vector3(deg_to_rad(FLOWER_EULER.x), deg_to_rad(FLOWER_EULER.y), 0.0)),
		FLOWER_CENTER)

	var flower := Node3D.new()
	flower.position = FLOWER_CENTER
	flower.rotation_degrees = FLOWER_EULER
	add_child(flower)

	# 花托
	var calyx := MeshInstance3D.new()
	calyx.mesh = mk_cyl(FLOWER_RADIUS * 0.33, FLOWER_RADIUS * 0.06)
	calyx.material_override = MAT_CALYX
	calyx.position = Vector3(0.0, -0.010, 0.0)
	flower.add_child(calyx)

	# 六枚花瓣：基本平铺，只有很轻的上翘，保证从任何角度都不遮花心
	for i in 6:
		var pivot := Node3D.new()
		pivot.rotation_degrees = Vector3(0.0, i * 60.0, 0.0)
		var petal := MeshInstance3D.new()
		petal.mesh = mk_sphere(0.5)
		petal.scale = Vector3(FLOWER_RADIUS * 0.50, FLOWER_RADIUS * 0.07,
			FLOWER_RADIUS * 0.72)
		petal.material_override = MAT_PETAL
		petal.position = Vector3(0.0, FLOWER_RADIUS * 0.03, FLOWER_RADIUS * 0.66)
		petal.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
		pivot.add_child(petal)
		flower.add_child(pivot)

## 提示条字号加大：红框（失败）32，绿框（成功）30
func flash_message(msg: String, good: bool = true, dur: float = 2.2,
		font_size: int = 20, custom_color: Color = Color(-1, -1, -1),
		half_w: int = 220, half_h: int = 40, show_prefix: bool = true,
		offset_x: float = 0.0, offset_y: float = 0.0) -> void:
	var fs := maxi(font_size, 30) if good else maxi(font_size, 32)
	super.flash_message(msg, good, dur, fs, custom_color, half_w, half_h,
		show_prefix, offset_x, offset_y)

## 花药标本：球形碰撞体 + 真实花药外观，材质与交互体共用以便高亮。
## 悬停名称牌统一收小：基类默认字号偏大，五个花药标签会糊成一片
func _style_tooltip(_obj_name: String, lbl: Label3D) -> void:
	lbl.font_size = 26
	lbl.outline_size = 6
	lbl.modulate = Color(1.0, 0.26, 0.18)

## pos 是"花朵平面内"的局部坐标，花药统一竖直立在花心里
func _anther_specimen(nm: String, local_pos: Vector3, size: float, color: Color,
		hover: Color, tooltip: String, scl: float, tilt: float = 20.0) -> void:
	# 悬停高亮改成"只提亮 8%"：原来用的是明亮的 hover 色，鼠标一上去
	# 花药颜色会突然变浅，看起来像换了材质
	create_interactable(nm, _flower_xf * local_pos, mk_sphere(size), color,
		color.lightened(0.08), tooltip)
	var area: Area3D = interactables[nm]["area"]
	area.get_child(0).visible = false
	# 悬停名称牌：沿"花心 → 花药"方向推到花冠外侧
	var area_pos: Vector3 = _flower_xf * local_pos
	var out_dir := Vector3(area_pos.x - FLOWER_CENTER.x, 0.0, area_pos.z - FLOWER_CENTER.z)
	if out_dir.length() < 0.05:
		out_dir = Vector3(0.0, 0.0, 1.0)
	out_dir = out_dir.normalized()
	for ch in area.get_children():
		if ch is Label3D:
			# 排在所指花药的左/右侧（哪侧空间大放哪侧），文字边沿离花药还有一段距离，
			# 不会压在花药本体上
			var side := -1.0 if area_pos.x <= FLOWER_CENTER.x else 1.0
			ch.position = Vector3(side * 0.50, 0.06, 0.0)
			ch.font_size = 26
			ch.outline_size = 6
			ch.modulate = Color(1.0, 0.26, 0.18)
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
	var disp := add_static(mk_box(Vector3(0.66, 0.22, 0.04)),
		c + Vector3(0.0, h * 0.5 + 0.10, d * 0.5 - 0.10), Color(0.05, 0.10, 0.14))
	disp.material_override = MAT_DISPLAY
	var lbl_disp := add_label3d("3–5 ℃", c + Vector3(0.0, h * 0.5 + 0.10, d * 0.5 + 0.06), 34, Color(0.45, 1.0, 0.72))
	lbl_disp.font_px = 30          # size 参数会被 _font_for 钳到 17px，放大走 font_px
	lbl_disp.outline_size = 5
	lbl_disp.outline_modulate = Color(0.0, 0.10, 0.06, 0.9)
	lbl_disp.bold = true

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
	if lbl_cold:
		lbl_cold.outline_size = 7
		lbl_cold.outline_modulate = Color(0.05, 0.1, 0.3, 0.9)
		lbl_cold.font_px = 32   # 同上：绕过 _font_for 的 27px 上限
		lbl_cold.bold = true

func _build_temp_controls() -> void:
	# 温度控制面板（UI覆盖层）
	var temp_panel := Panel.new()
	temp_panel.anchor_left = 1.0; temp_panel.anchor_right = 1.0
	temp_panel.offset_left = -390; temp_panel.offset_right = -10
	temp_panel.offset_top = 72; temp_panel.offset_bottom = 236
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.10, 0.18, 0.94)
	ps.set_border_width_all(1); ps.border_color = Color(0.20, 0.45, 0.80)
	ps.set_corner_radius_all(8)
	temp_panel.add_theme_stylebox_override("panel", ps)
	temp_panel.visible = false
	temp_panel.name = "TempPanel"
	canvas_layer.add_child(temp_panel)

	var title := Label.new(); title.text = "🌡  温度控制"
	title.position = Vector2(16, 10); title.size = Vector2(340, 34)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	temp_panel.add_child(title)

	temp_lbl = Label.new()
	temp_lbl.text = "%.1f ℃" % temp_value
	temp_lbl.position = Vector2(120, 52); temp_lbl.size = Vector2(140, 46)
	temp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	temp_lbl.add_theme_font_size_override("font_size", 34)
	temp_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	temp_panel.add_child(temp_lbl)

	temp_minus_btn = Button.new(); temp_minus_btn.text = "▼ 降温"
	temp_minus_btn.position = Vector2(16, 52); temp_minus_btn.size = Vector2(96, 46)
	_style_button(temp_minus_btn, Color(0.15, 0.25, 0.50))
	temp_minus_btn.add_theme_font_size_override("font_size", 21)
	temp_minus_btn.pressed.connect(_on_temp_minus)
	temp_panel.add_child(temp_minus_btn)

	temp_plus_btn = Button.new(); temp_plus_btn.text = "升温 ▲"
	temp_plus_btn.position = Vector2(276, 52); temp_plus_btn.size = Vector2(96, 46)
	_style_button(temp_plus_btn, Color(0.50, 0.18, 0.10))
	temp_plus_btn.add_theme_font_size_override("font_size", 21)
	temp_plus_btn.pressed.connect(_on_temp_plus)
	temp_panel.add_child(temp_plus_btn)

	# 等待计时按钮
	time_btn = Button.new(); time_btn.text = "⏱ 点击此处开始低温预处理"
	time_btn.position = Vector2(12, 112); time_btn.size = Vector2(364, 46)
	_style_button(time_btn, Color(0.08, 0.30, 0.14))
	time_btn.add_theme_font_size_override("font_size", 21)
	time_btn.pressed.connect(_on_time_btn_pressed)
	time_btn.visible = false
	temp_panel.add_child(time_btn)

	time_lbl = Label.new()
	time_lbl.text = "已处理：0 小时"
	time_lbl.position = Vector2(12, 118); time_lbl.size = Vector2(364, 34)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.add_theme_font_size_override("font_size", 21)
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
			"title": "🌸  选取花药：凭花药颜色判断发育时期",
			"body": "同一朵花中的花药发育时期不同，请选择最适合花药离体培养（植物组织培养）的花药：\n"
				+ "• 淡绿色—花粉母细胞期（2n=24），尚未开始减数分裂\n"
				+ "• 浅黄绿—单核早期（n=12），脱分化能力弱\n"
				+ "• 鲜黄色—单核靠边期（n=12），脱分化能力强\n"
				+ "• 深黄色—二核期（n=12），脱分化能力极低\n"
				+ "• 黄紫色—成熟花粉期（n=12），已失去脱分化能力",
			"click_to_advance": false,
			"active_objects": ["bud_correct", "bud_early", "bud_late", "bud_uninuclear_early", "bud_mature"],
			"correct_object": "bud_correct",
			"correct_message": "正确！选取了单核靠边期花药",
			"wrong_message": "这个阶段不适合，请重新选取！"
		},
		{
			"title": "❄  操作：放入低温预处理箱",
			"body": "点击低温预处理箱放入花药。低温可使细胞分裂同步化，提高愈伤诱导率。",
			"click_to_advance": false,
			"active_objects": ["cold_box"],
			"correct_object": "cold_box",
			"correct_message": "花药已放入低温预处理箱"
		},
		{
			"title": "🌡  操作：调节低温处理温度",
			"body": "最佳温度 3–5 ℃，请点击【▼ 降温】调到此区间。过低损伤细胞，过高则无效。",
			"click_to_advance": false,
			"active_objects": []
		},
		{
			"title": "⏱  操作：等待低温预处理完成",
			"body": "预处理需 24–72 小时。点击【开始低温预处理】模拟等待，自动推进至 48 小时。",
			"click_to_advance": false,
			"active_objects": [],
			"completion_text": "材料选取完成！\n已选取单核靠边期花药，并在 3–5 ℃ 下预处理 48 小时。\n低温预处理可使小孢子分裂同步化，提高愈伤诱导率。\n下一步：花药消毒与接种。"
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
	# 培养开始后花药在箱内缓慢旋转
	if bud_model and is_instance_valid(bud_model):
		bud_model.rotation.y += delta * 1.5
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

	# 放入培养箱时先不旋转，等开始培养后再转（见 _process）