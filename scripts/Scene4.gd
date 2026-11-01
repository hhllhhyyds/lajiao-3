## Scene4.gd — 愈伤组织诱导培养
## 先高温暗培养（热激），再转入光照下培养，诱导花药形成愈伤组织
extends SceneBase

var temp_set: float = 25.0
var is_dark_mode: bool = false
var growth_timer: float = 0.0
var timer_running: bool = false
var _dish_taken: bool = false     # 培养皿已取出
var _dish_label: LabelProjector.TagLabel

const INCUBATOR_SCENE := preload("res://assets/props/incubator.glb")
const BENCH_SCENE := preload("res://assets/props/lab_bench.glb")
const DISH_SCENE := preload("res://assets/props/petri_dish.glb")
const MAT_TILE := preload("res://materials/tile_wall.tres")
const MAT_FLOOR := preload("res://materials/floor_epoxy.tres")
const MAT_INC_DARK := preload("res://materials/incubator_dark.tres")
const MAT_INC_INNER_DARK := preload("res://materials/incubator_inner_dark.tres")
const MAT_INC_LIGHT := preload("res://materials/fridge_case.tres")
const MAT_INC_INNER := preload("res://materials/fridge_inner.tres")
const MAT_INC_GLASS := preload("res://materials/fridge_door.tres")
const MAT_INC_GLASS_DARK := preload("res://materials/incubator_glass_dark.tres")
const MAT_STEEL := preload("res://materials/stainless.tres")
const MAT_DISPLAY := preload("res://materials/display_black.tres")
const MAT_HOOD_FRAME := preload("res://materials/steel_bright.tres")

var anther_node: Area3D           # 培养皿交互节点（跟随移动）
var anther_ball: MeshInstance3D   # 皿内的花药（暗培养阶段）
var callus_root: Node3D           # 皿内的愈伤组织（光照阶段）

# UI 控件
var ui_temp_lbl: Label
var ui_timer_lbl: Label
var ui_temp_minus: Button
var ui_temp_plus: Button
var ui_light_btn: Button

func _ready() -> void:
	scene_number = 4
	scene_title  = "愈伤组织诱导培养"
	light_focus = Vector3(0.0, 1.25, -1.0)
	light_radius = 4.2
	light_intensity = 0.46
	super._ready()

# =====================================================================
# 摄像机：俯视整个实验室，左暗箱、中操作台、右光照箱清晰可见
# =====================================================================
func _configure_camera() -> void:
	camera.position = Vector3(0.25, 2.45, 5.90)
	camera.look_at(Vector3(0.0, 1.12, -0.85))
	camera.fov = 52.0

# =====================================================================
# 场景搭建
# =====================================================================
func _setup_scene() -> void:
	_build_room()
	_build_dark_incubator()
	_build_light_incubator()
	_build_operation_table()
	_build_control_panel()
	_park_tooltips()


## box 墙面的 UV 是 0..1，直接套世界坐标 UV 的材质会把瓷砖拉成两米一块。
func _tiled(w: float, h: float) -> StandardMaterial3D:
	var m := MAT_TILE.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(w * 2.5, h * 2.5, 1.0)
	return m
func _build_room() -> void:
	var floor_mi := add_static(mk_plane(Vector2(26, 26)), Vector3.ZERO, Color.WHITE)
	floor_mi.material_override = MAT_FLOOR
	var wall := add_static(mk_box(Vector3(22, 6, 0.2)), Vector3(0, 3.0, -4.0), Color.WHITE)
	wall.material_override = _tiled(22.0, 6.0)
	add_static(mk_box(Vector3(22, 0.18, 0.18)), Vector3(0, 0.09, -3.9), Color(0.30, 0.32, 0.33))

	# 顶部灯带
	for xi in [-4.0, 0.0, 4.0]:
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(1.0, 0.99, 0.95)
		lmat.emission_enabled = true
		lmat.emission = Color(0.80, 0.80, 0.74)
		lmat.emission_energy_multiplier = 1.5
		var lmi := MeshInstance3D.new()
		lmi.mesh = mk_box(Vector3(1.8, 0.05, 0.36))
		lmi.material_override = lmat
		lmi.position = Vector3(xi, 4.3, -0.6)
		add_child(lmi)

## 暗培养箱 / 光照培养箱共用同一套箱体模型，只换材质和内部灯
func _spawn_incubator(pos: Vector3, dark: bool) -> void:
	var mapping := {
		"incubator_body": MAT_INC_DARK if dark else MAT_INC_LIGHT,
		"incubator_recess": MAT_INC_INNER_DARK if dark else MAT_INC_INNER,
		"incubator_shelf": MAT_STEEL,
		"incubator_frame": MAT_STEEL,
		"incubator_handle": MAT_STEEL,
		"incubator_foot": MAT_STEEL,
		"incubator_glass": MAT_INC_GLASS_DARK if dark else MAT_INC_GLASS,
		"incubator_panel": MAT_DISPLAY,
		"incubator_display": MAT_DISPLAY,
	}
	PropKit.spawn(self, INCUBATOR_SCENE, pos, Vector3.ZERO, mapping, Vector3(1.6, 1.35, 1.35))

	# 隔板上摆几个培养皿，空柜子看起来像道具
	var dish_mat := StandardMaterial3D.new()
	dish_mat.albedo_color = Color(0.90, 0.91, 0.88)
	dish_mat.roughness = 0.35
	for i in 4:
		var shelf_z: float = (0.34 + (i % 2) * 0.52) * 1.35
		var dish := MeshInstance3D.new()
		dish.mesh = mk_cyl(0.085, 0.026)
		dish.material_override = dish_mat
		dish.position = pos + Vector3(-0.22 + (i % 2) * 0.44, shelf_z + 0.020, 0.02)
		add_child(dish)

	# 箱内照明：光照箱是冷白灯管，暗箱只留一点门缝微光
	if dark:
		return
	for i in 3:
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(1.0, 0.99, 0.92)
		lmat.emission_enabled = true
		lmat.emission = Color(0.92, 0.94, 0.86)
		lmat.emission_energy_multiplier = 2.4
		var tube_mi := MeshInstance3D.new()
		tube_mi.mesh = mk_cyl(0.022, 0.95)
		tube_mi.material_override = lmat
		tube_mi.rotation_degrees = Vector3(0, 0, 90)
		tube_mi.position = pos + Vector3(0.0, 1.24 - i * 0.33, -0.25)
		add_child(tube_mi)

	var glow := OmniLight3D.new()
	glow.position = pos + Vector3(0.0, 1.0, -0.15)
	glow.light_color = Color(0.86, 0.94, 1.0)
	glow.light_energy = 1.3
	glow.omni_range = 2.6
	add_child(glow)

func _build_dark_incubator() -> void:
	_spawn_incubator(Vector3(-4.05, 0.0, -2.2), true)

	create_interactable("dark_incubator",
		Vector3(-4.05, 1.3, -2.0),
		mk_box(Vector3(1.9, 2.6, 1.6)),
		Color(0, 0, 0, 0), Color(0.60, 0.60, 0.85), "高温暗培养箱")
	interactables["dark_incubator"]["area"].get_child(0).visible = false
	attach_label3d("dark_incubator", "高温暗培养箱（33–37 ℃，黑暗）", Vector3(0.60, 0.62, 0.62), 40, Color(0.82, 0.80, 1.0))

func _build_light_incubator() -> void:
	_spawn_incubator(Vector3(4.05, 0.0, -2.2), false)

	create_interactable("light_incubator",
		Vector3(4.05, 1.3, -2.0),
		mk_box(Vector3(1.9, 2.6, 1.6)),
		Color(0, 0, 0, 0), Color(1.0, 1.0, 0.72), "光照培养箱")
	interactables["light_incubator"]["area"].get_child(0).visible = false
	attach_label3d("light_incubator", "光照培养箱（25 ℃，光照）", Vector3(-0.60, 0.62, 0.62), 40, Color(0.88, 1.0, 0.62))

## 操作台上方的超净台玻璃罩：四周铝合金框 + 透明玻璃三面一顶
func _build_hood() -> void:
	var hw := 1.28            # 半宽
	var z0 := -0.06           # 后沿
	var z1 := 1.34            # 前沿
	var y0 := 1.00            # 台面
	var y1 := 2.18            # 罩顶
	var mid_z := (z0 + z1) * 0.5
	var depth := z1 - z0
	var height := y1 - y0

	# 不锈钢立柱与顶框
	for sx in [-1.0, 1.0]:
		for sz in [z0, z1]:
			var post := add_static(mk_box(Vector3(0.055, height, 0.055)),
				Vector3(sx * hw, y0 + height * 0.5, sz), Color.WHITE)
			post.material_override = MAT_HOOD_FRAME
	for sz in [z0, z1]:
		var rail := add_static(mk_box(Vector3(hw * 2.0, 0.055, 0.055)),
			Vector3(0.0, y1, sz), Color.WHITE)
		rail.material_override = MAT_STEEL
	for sx in [-1.0, 1.0]:
		var rail := add_static(mk_box(Vector3(0.055, 0.055, depth)),
			Vector3(sx * hw, y1, mid_z), Color.WHITE)
		rail.material_override = MAT_HOOD_FRAME

	# 罩内玻璃材质：比培养箱门稍微实一点，才看得出"罩住"
	var hood_glass := StandardMaterial3D.new()
	hood_glass.albedo_color = Color(0.80, 0.90, 0.97, 0.26)
	hood_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hood_glass.roughness = 0.06
	hood_glass.metallic = 0.0
	hood_glass.metallic_specular = 1.0
	hood_glass.rim_enabled = true
	hood_glass.rim = 0.35

	# 玻璃：正前、左右、顶面、后壁
	var front := add_static(mk_box(Vector3(hw * 2.0 - 0.10, height - 0.06, 0.015)),
		Vector3(0.0, y0 + height * 0.5, z1), Color.WHITE)
	front.material_override = hood_glass
	set_top_layer(front)
	for sx in [-1.0, 1.0]:
		var side := add_static(mk_box(Vector3(0.015, height - 0.06, depth - 0.06)),
			Vector3(sx * hw, y0 + height * 0.5, mid_z), Color.WHITE)
		side.material_override = hood_glass
		set_top_layer(side)
	var top := add_static(mk_box(Vector3(hw * 2.0 - 0.10, 0.015, depth - 0.06)),
		Vector3(0.0, y1, mid_z), Color.WHITE)
	top.material_override = hood_glass
	set_top_layer(top)

func _build_operation_table() -> void:
	PropKit.spawn(self, BENCH_SCENE, Vector3(0.0, 0.0, 0.55), Vector3.ZERO, {}, Vector3(1.0, 1.0, 1.0))
	_build_hood()

	# 培养皿：真实模型 + 金黄色内容物
	anther_node = create_interactable("anther_dish",
		Vector3(0.0, 1.06, 0.55),
		mk_cyl(0.26, 0.06),
		Color(0.85, 0.70, 0.18), Color(1.0, 0.90, 0.25), "放置了花药的诱导愈伤组织培养皿")
	anther_node.get_child(0).visible = false

	PropKit.spawn(anther_node, DISH_SCENE, Vector3(0.0, -0.02, 0.0), Vector3.ZERO, {
		"petri_dish_lid": MAT_INC_GLASS,
		"petri_dish_base": MAT_INC_INNER,
	}, Vector3(5.0, 5.0, 5.0))

	var agar := MeshInstance3D.new()
	agar.mesh = mk_cyl(0.26, 0.02)
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.80, 0.66, 0.20)
	amat.roughness = 0.45
	agar.material_override = amat
	agar.position = Vector3(0.0, 0.012, 0.0)
	anther_node.add_child(agar)

	# 皿内那枚花药：淡黄色圆球，放在琼脂中央
	anther_ball = MeshInstance3D.new()
	anther_ball.mesh = mk_sphere(0.080)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.95, 0.89, 0.58)
	bmat.roughness = 0.42
	anther_ball.material_override = bmat
	anther_ball.position = Vector3(0.0, 0.084, 0.0)
	anther_node.add_child(anther_ball)
	var anther_hi := MeshInstance3D.new()
	anther_hi.mesh = mk_sphere(0.027)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(1.0, 0.97, 0.80)
	hmat.roughness = 0.30
	anther_hi.material_override = hmat
	anther_hi.position = Vector3(-0.026, 0.132, -0.024)
	anther_node.add_child(anther_hi)

	# 愈伤组织：几块大小不一的球叠成的黄绿色不规则团块，暗培养结束后替换花药
	callus_root = Node3D.new()
	callus_root.position = Vector3(0.0, 0.088, 0.0)
	callus_root.visible = false
	anther_node.add_child(callus_root)
	var callus_mat := StandardMaterial3D.new()
	callus_mat.albedo_color = Color(0.72, 0.82, 0.34)
	callus_mat.roughness = 0.62
	var lumps := [
		[Vector3(0.0, 0.0, 0.0), 0.092, Vector3(1.05, 0.80, 0.95)],
		[Vector3(0.062, 0.028, 0.030), 0.052, Vector3(1.0, 0.9, 1.0)],
		[Vector3(-0.058, 0.020, -0.038), 0.046, Vector3(1.0, 0.85, 1.05)],
		[Vector3(0.012, 0.052, -0.058), 0.038, Vector3(1.0, 0.9, 1.0)],
		[Vector3(-0.030, 0.038, 0.062), 0.034, Vector3(1.0, 0.9, 1.0)],
	]
	for l in lumps:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = float(l[1]); sm.height = float(l[1]) * 2.0
		sm.radial_segments = 9; sm.rings = 5
		mi.mesh = sm
		mi.material_override = callus_mat
		mi.position = l[0]
		mi.scale = l[2]
		callus_root.add_child(mi)

	# 台面上的花药小块（散落在皿内）
	for i in 6:
		var ang := i * 1.05
		var fleck := MeshInstance3D.new()
		fleck.mesh = mk_sphere(0.018)
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(0.94, 0.86, 0.42)
		fmat.roughness = 0.55
		fleck.material_override = fmat
		fleck.position = Vector3(cos(ang) * 0.13, 0.028, sin(ang) * 0.13)
		anther_node.add_child(fleck)

	_dish_label = attach_label3d("anther_dish", "放置了花药的\n诱导愈伤组织培养皿（点击取出）",
		Vector3(0, 0.34, 0), 42, Color(1.0, 0.95, 0.60))

func _build_control_panel() -> void:
	var cp := Panel.new()
	cp.anchor_right = 1.0
	cp.offset_left = -310; cp.offset_right = -10
	cp.offset_top = 70; cp.offset_bottom = 236
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.10, 0.06, 0.95)
	ps.set_border_width_all(1); ps.border_color = Color(0.22, 0.55, 0.28)
	ps.set_corner_radius_all(8)
	cp.add_theme_stylebox_override("panel", ps)
	canvas_layer.add_child(cp)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 324; vb.offset_right = -12
	vb.offset_top = 10; vb.offset_bottom = -10
	vb.add_theme_constant_override("separation", 10)
	cp.add_child(vb)

	var h1 := Label.new(); h1.text = "🌡  培养条件设置（供参考）"
	h1.add_theme_font_size_override("font_size", 24)
	h1.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	vb.add_child(h1)

	var hb_t := HBoxContainer.new(); vb.add_child(hb_t)


	ui_temp_lbl = Label.new(); ui_temp_lbl.text = "  25.0 ℃  "
	ui_temp_lbl.add_theme_font_size_override("font_size", 34)
	ui_temp_lbl.add_theme_color_override("font_color", Color.WHITE)
	ui_temp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_temp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb_t.add_child(ui_temp_lbl)

	ui_light_btn = Button.new()
	ui_light_btn.custom_minimum_size = Vector2(150, 52)
	_style_button(ui_light_btn, Color(0.35, 0.28, 0.04))
	ui_light_btn.add_theme_font_size_override("font_size", 24)
	ui_light_btn.pressed.connect(func(): _on_toggle_light())
	hb_t.add_child(ui_light_btn)

	ui_temp_plus = Button.new(); ui_temp_plus.text = "升温 ▲"
	ui_temp_plus.custom_minimum_size = Vector2(112, 52)
	_style_button(ui_temp_plus, Color(0.50, 0.18, 0.10))
	ui_temp_plus.add_theme_font_size_override("font_size", 24)
	ui_temp_plus.pressed.connect(func(): _on_temp_up())
	hb_t.add_child(ui_temp_plus)

	ui_temp_minus = Button.new(); ui_temp_minus.text = "▼ 降温"
	ui_temp_minus.custom_minimum_size = Vector2(112, 52)
	_style_button(ui_temp_minus, Color(0.15, 0.22, 0.50))
	ui_temp_minus.add_theme_font_size_override("font_size", 24)
	ui_temp_minus.pressed.connect(func(): _on_temp_down())
	hb_t.add_child(ui_temp_minus)

	_update_light_display()

	var sep := Control.new(); sep.custom_minimum_size = Vector2(0, 6); vb.add_child(sep)

	ui_timer_lbl = Label.new(); ui_timer_lbl.text = "培养时间：— 天"
	ui_timer_lbl.add_theme_font_size_override("font_size", 22)
	ui_timer_lbl.add_theme_color_override("font_color", Color(0.75, 0.90, 0.78))
	vb.add_child(ui_timer_lbl)


# =====================================================================
# 步骤定义
# =====================================================================
## 红色名称牌：和场景三一样醒目，并抬到固定标签上方
func _style_tooltip(_obj_name: String, lbl: Label3D) -> void:
	lbl.font_size = 34
	lbl.outline_size = 7
	lbl.modulate = Color(1.0, 0.26, 0.18)

func _tooltip_offset(_obj_name: String) -> Vector3:
	return Vector3.ZERO

## 每个对象上方已经有固定标签，把红色名称牌摆到那条标签的正上方
const _LABEL_TOPS := {
	"dark_incubator": 0.62,
	"light_incubator": 0.62,
	"anther_dish": 0.34,
}
const _LABEL_DX := {
	"dark_incubator": 0.60,
	"light_incubator": -0.60,
	"anther_dish": 0.0,
}

func _park_tooltips() -> void:
	for nm in _LABEL_TOPS:
		var area: Area3D = interactables.get(nm, {}).get("area")
		if area == null:
			continue
		# 按到相机的距离补偿 pixel_size，三个红字看起来才一样大
		var dist := area.global_position.distance_to(camera.global_position)
		for ch in area.get_children():
			if ch is Label3D and not ch.get_meta("static_label", false):
				ch.position = Vector3(float(_LABEL_DX[nm]), float(_LABEL_TOPS[nm]) + 0.52, 0.0)
				ch.pixel_size = 0.0040 * dist / 5.6

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
				+ "培养过程会自动推进，观察花药逐渐膨大、转绿。\n"
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
				+ "培养过程会自动推进，观察愈伤组织的生长。",
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
					_animate_dish_to(Vector3(-4.05, 0.98, -2.2))
					await get_tree().create_timer(1.0).timeout
					advance_step()
		3:
			if obj_name == "light_incubator":
				if temp_set < 23.0 or temp_set > 27.0:
					flash_message("温度不对！光照培养需要 25 ℃，当前 %.0f ℃\n请先降温至 25 ℃！" % temp_set, false)
				elif is_dark_mode:
					flash_message("需要切换为【光照模式】才能进行光照培养！\n请点击右侧面板的光照切换按钮！", false)
				else:
					flash_message("愈伤组织已转入光照培养箱 ✓", true)
					_swap_anther_to_callus()
					_animate_dish_to(Vector3(4.05, 0.98, -2.2))
					await get_tree().create_timer(1.0).timeout
					advance_step()
		_:
			pass

## 进入培养阶段就自动开始模拟（原来靠"加速模拟"按钮触发，按钮已删）
func _show_step(idx: int) -> void:
	super._show_step(idx)
	if idx == 2 or idx == 4:
		growth_timer = 0.0
		timer_running = true

## 暗培养结束、转入光照箱时：皿里的花药换成黄绿色愈伤组织团块
func _swap_anther_to_callus() -> void:
	if anther_ball:
		anther_ball.visible = false
	if callus_root:
		callus_root.visible = true
	if _dish_label:
		_dish_label.text = "长出愈伤组织的\n诱导愈伤组织培养皿（点击取出）"

func _animate_dish_to(target: Vector3) -> void:
	if not anther_node: return
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(anther_node, "position",
		target + Vector3(0, 0.2, 0), 0.8)
	if _dish_label:
		_dish_label.visible = false

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
			flash_message("热激处理完成！花药已膨大，愈伤组织形成", true)
			await get_tree().create_timer(1.5).timeout
			advance_step()
			_refresh_highlights(["light_incubator"])

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
			flash_message("愈伤组织充分增殖，可进入下一关！", true)
			await get_tree().create_timer(1.5).timeout
			advance_step()
