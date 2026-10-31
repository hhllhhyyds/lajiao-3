## Scene3.gd — 花药消毒与接种
## 花药消毒处理后在无菌环境下剥取花药并接种到培养基
extends SceneBase

# 操作状态追踪
var disinfect_step: int = 0  # 0=pick bud, 1=alcohol, 2=sterile_water1, 3=naclo, 4=sterile_water2, 5=cabinet, 6=peel, 7=inoculate

# 花药可见节点，用于移动动画
var bud_node: MeshInstance3D

const BOTTLE_SCENE := preload("res://assets/props/reagent_bottle.glb")
const MEDIA_SCENE := preload("res://assets/props/media_bottle.glb")
const FLASK_SCENE := preload("res://assets/props/conical_flask.glb")
const MAT_AMBER := preload("res://materials/amber_glass.tres")
const MAT_CAP := preload("res://materials/cap_black.tres")
const MAT_CAP_BLUE := preload("res://materials/cap_blue.tres")
const MAT_CLEAR_BOTTLE := preload("res://materials/clear_bottle.tres")
const MAT_WHITE_BOTTLE := preload("res://materials/white_bottle.tres")

# 各操作目标位置（悬停在试剂/器具上方）
const POS_BUD      := Vector3(-4.5, 1.35, 0.3)
const POS_ALCOHOL  := Vector3(-3.8, 1.55, 0.0)
const POS_WATER1   := Vector3(-2.3, 1.55, 0.0)
const POS_NACLO    := Vector3(-0.8, 1.55, 0.0)
const POS_WATER2   := Vector3( 0.7, 1.55, 0.0)
const POS_CABINET  := Vector3( 3.6, 2.10, 0.0)
const POS_TWEEZERS := Vector3( 2.45, 2.90, 0.0)
const POS_MEDIUM   := Vector3( 2.45, 2.20, 2.90)

func _ready() -> void:
	scene_number = 3
	scene_title  = "花药消毒与接种"
	light_focus = Vector3(0.0, 1.5, 0.0)
	light_radius = 4.0
	light_intensity = 0.55
	super._ready()

func _configure_camera() -> void:
	camera.position = Vector3(0.5, 3.5, 8.0) * 1.2
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	camera.fov = 50.0

func _setup_scene() -> void:
	_build_lab_bench()
	_build_bottles()
	_build_sterile_cabinet()
	_build_flower_bud()
	_build_medium()

func _build_lab_bench() -> void:
	# 实验台面
	add_static(mk_box(Vector3(10.0, 0.18, 3.5)), Vector3(0.0, 0.9, 0.0), Color(0.90, 0.88, 0.82))
	# 实验台腿
	for x in [-4.5, 4.5]:
		for z in [-1.5, 1.5]:
			add_static(mk_box(Vector3(0.12, 0.9, 0.12)), Vector3(x, 0.45, z), Color(0.75, 0.72, 0.68))
	# 地面（白色瓷砖风格）
	add_static(mk_plane(Vector2(22, 22)), Vector3.ZERO, Color(0.85, 0.88, 0.86))
	# 墙
	add_static(mk_box(Vector3(14, 5, 0.2)), Vector3(0, 2.5, -2.2), Color(0.88, 0.90, 0.86))

func _build_bottles() -> void:
	# 真实瓶型（Blender 旋转成型）：棕色试剂瓶 / 两支广口瓶 / 锥形瓶
	# 本关是 4 倍尺度（台面 10 m 宽），所以道具整体放大
	PropKit.spawn(self, BOTTLE_SCENE, Vector3(-3.80, 0.99, -0.30), Vector3.ZERO, {
		"bottle_body": MAT_AMBER,
		"bottle_cap": MAT_CAP,
		"bottle_cap_ridge": MAT_CAP,
	}, Vector3(3.8, 3.8, 3.8))

	PropKit.spawn(self, MEDIA_SCENE, Vector3(-2.30, 0.99, -0.30), Vector3.ZERO, {
		"media_body": MAT_CLEAR_BOTTLE,
		"media_cap": MAT_CAP_BLUE,
		"media_cap_ridge": MAT_CAP_BLUE,
	}, Vector3(4.4, 4.4, 4.4))

	PropKit.spawn(self, MEDIA_SCENE, Vector3(-0.80, 0.99, -0.30), Vector3.ZERO, {
		"media_body": MAT_WHITE_BOTTLE,
		"media_cap": MAT_CAP,
		"media_cap_ridge": MAT_CAP,
	}, Vector3(4.4, 4.4, 4.4))

	PropKit.spawn(self, FLASK_SCENE, Vector3(0.70, 0.99, -0.30), Vector3.ZERO, {
		"flask_body": MAT_CLEAR_BOTTLE,
	}, Vector3(3.6, 3.6, 3.6))

	create_interactable("bottle_alcohol",
		Vector3(-3.8, 1.42, -0.3), mk_cyl(0.22, 0.82),
		Color(0.72, 0.45, 0.10, 0.0), Color(1.0, 0.75, 0.25), "75% 酒精")
	interactables["bottle_alcohol"]["area"].get_child(0).visible = false
	var lbl_alc := attach_label3d("bottle_alcohol", "75% 酒精", Vector3(0, 0.76, 0), 40, Color(1.0, 0.85, 0.5))
	if lbl_alc: lbl_alc.outline_size = 8; lbl_alc.outline_modulate = Color(0.3, 0.15, 0.0, 0.9)

	create_interactable("bottle_water1",
		Vector3(-2.3, 1.40, -0.3), mk_cyl(0.20, 0.75),
		Color(0.60, 0.82, 0.95, 0.0), Color(0.70, 0.95, 1.0), "无菌水")
	interactables["bottle_water1"]["area"].get_child(0).visible = false
	var lbl_w1 := attach_label3d("bottle_water1", "无菌水", Vector3(0, 0.68, 0), 40, Color(0.7, 0.9, 1.0))
	if lbl_w1: lbl_w1.outline_size = 8; lbl_w1.outline_modulate = Color(0.0, 0.15, 0.3, 0.9)

	create_interactable("bottle_naclo",
		Vector3(-0.8, 1.42, -0.3), mk_cyl(0.22, 0.82),
		Color(0.92, 0.93, 0.95, 0.0), Color(1.0, 1.0, 1.0), "8% NaClO")
	interactables["bottle_naclo"]["area"].get_child(0).visible = false
	var lbl_naclo := attach_label3d("bottle_naclo", "8% NaClO\n(次氯酸钠)", Vector3(0, 0.78, 0), 40, Color(0.9, 0.95, 1.0))
	if lbl_naclo: lbl_naclo.outline_size = 8; lbl_naclo.outline_modulate = Color(0.1, 0.15, 0.3, 0.9)

	create_interactable("bottle_water2",
		Vector3(0.7, 1.40, -0.3), mk_cyl(0.20, 0.75),
		Color(0.60, 0.82, 0.95, 0.0), Color(0.70, 0.95, 1.0), "无菌水（终漂）")
	interactables["bottle_water2"]["area"].get_child(0).visible = false
	var lbl_w2 := attach_label3d("bottle_water2", "无菌水（终漂）", Vector3(0, 0.70, 0), 40, Color(0.7, 0.9, 1.0))
	if lbl_w2: lbl_w2.outline_size = 8; lbl_w2.outline_modulate = Color(0.0, 0.15, 0.3, 0.9)

func _build_sterile_cabinet() -> void:
	var cab_outer := add_glass(mk_box(Vector3(11.5, 5.0, 5.0)), Vector3(0.35, 2.0, 1.0), Color(0.15, 0.45, 1.0, 0.12))
	(cab_outer.material_override as StandardMaterial3D).render_priority = -2
	var cab_inner := add_glass(mk_box(Vector3(11.2, 4.7, 4.7)), Vector3(0.35, 2.0, 1.0), Color(0.0, 0.0, 0.0, 0.0))
	(cab_inner.material_override as StandardMaterial3D).render_priority = -2
	add_static(mk_box(Vector3(11.0, 0.08, 4.5)), Vector3(0.35, 3.72, 1.0), Color(0.88, 0.92, 0.88))

	create_interactable("sterile_cabinet",
		Vector3(0.35, 2.0, 1.0), mk_box(Vector3(11.2, 4.8, 4.8)),
		Color(0.62, 0.78, 0.92, 0.0), Color(0.75, 0.92, 1.0), "超净工作台（无菌区）")
	interactables["sterile_cabinet"]["area"].get_child(0).visible = false
	var lbl_cab := add_label3d("超净工作台\n(无菌环境)", Vector3(4.2, 1.45, 2.0), 40, Color(1.0, 0.55, 0.75))
	lbl_cab.outline_size = 10; lbl_cab.outline_modulate = Color(0.45, 0.10, 0.25, 1.0)

func _build_flower_bud() -> void:
	# 可见的花药球体（跟随动画移动）
	bud_node = MeshInstance3D.new()
	bud_node.mesh = mk_sphere(0.13)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.94, 0.90, 0.58)
	mat.no_depth_test = true; mat.render_priority = 2
	bud_node.material_override = mat
	bud_node.position = POS_BUD
	add_child(bud_node)

	create_interactable("flower_bud",
		Vector3(-4.5, 1.10, 0.3),
		mk_sphere(0.15),
		Color(0.94, 0.90, 0.58),
		Color(1.0, 0.98, 0.30),
		"花药（已低温预处理）")
	for ch in interactables["flower_bud"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			ch.position = Vector3(0.0, -0.38, 0.0)
	var lbl_bud := add_label3d("花药", Vector3(-4.5, 1.65, 0.3), 40, Color(0.9, 1.0, 0.7))
	lbl_bud.outline_size = 8; lbl_bud.outline_modulate = Color(0.1, 0.25, 0.05, 0.9)

func _build_medium() -> void:
	set_top_layer(add_static(mk_cyl(0.50, 0.08), Vector3(2.45, 1.92, 2.90), Color(0.82, 0.92, 0.78)))
	set_top_layer(add_static(mk_cyl(0.45, 0.10), Vector3(2.45, 1.97, 2.90), Color(0.74, 0.88, 0.68)))
	create_interactable("medium_plate",
		Vector3(2.45, 2.00, 2.90), mk_cyl(0.52, 0.20),
		Color(0.74, 0.88, 0.68, 0.0), Color(0.85, 1.0, 0.75), "愈伤组织诱导培养基")
	interactables["medium_plate"]["area"].get_child(0).visible = false
	var lbl_med := attach_label3d("medium_plate", "愈伤组织\n诱导培养基", Vector3(0, 0.38, 0), 28, Color(0.0, 0.85, 0.85))
	if lbl_med: lbl_med.outline_size = 10; lbl_med.outline_modulate = Color(0.0, 0.30, 0.30, 1.0)

	set_top_layer(add_static(mk_cyl(0.04, 1.0), Vector3(2.45, 2.69, -0.3), Color(0.72, 0.72, 0.75),
		Vector3(0, 0, 25)))
	create_interactable("tweezers",
		Vector3(2.45, 2.69, -0.3), mk_box(Vector3(1.1, 0.25, 0.25)),
		Color(0.72, 0.72, 0.75, 0.0), Color(0.90, 0.95, 1.0), "无菌镊子（剥取花药）")
	interactables["tweezers"]["area"].get_child(0).visible = false
	var lbl_twz := add_label3d("无菌镊子", Vector3(2.45, 3.3, -0.3), 40, Color(0.55, 0.55, 0.55))
	lbl_twz.outline_size = 10; lbl_twz.outline_modulate = Color(0.20, 0.20, 0.20, 1.0)

func _define_steps() -> void:
	steps = [
		{
			"title": "📖  步骤说明：花药消毒与接种",
			"body": "本步骤需要在超净台内按顺序进行操作：\n"
				+ "① 取花药 → ② 75% 酒精消毒 → ③ 无菌水漂洗 → ④ 8% NaClO 消毒 → "
				+ "⑤ 无菌水漂洗 → ⑥ 镊子剥取花药 → ⑦ 接种诱导愈伤组织培养基\n"
				+ "每步消毒步骤都不可省略，否则杂菌污染会导致实验失败！",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "① 取花药",
			"body": "点击台面上的花药，将其取到操作位置。",
			"click_to_advance": false,
			"active_objects": ["flower_bud"],
			"correct_object": "flower_bud",
			"correct_message": "已取花药，准备消毒处理"
		},
		{
			"title": "② 75% 酒精消毒（30 秒）",
			"body": "用 75% 酒精对花药表面进行消毒 30 秒，去除表面大部分杂菌。\n"
				+ "⚠  不能用更高浓度酒精，否则会损伤花药组织。",
			"click_to_advance": false,
			"active_objects": ["bottle_alcohol"],
			"correct_object": "bottle_alcohol",
			"correct_message": "75% 酒精消毒完成"
		},
		{
			"title": "③ 无菌水漂洗",
			"body": "用无菌水将花药上残余的酒精洗去，避免残余酒精影响后续操作。",
			"click_to_advance": false,
			"active_objects": ["bottle_water1"],
			"correct_object": "bottle_water1",
			"correct_message": "无菌水漂洗完成"
		},
		{
			"title": "④ 8% NaClO 消毒（5~10 分钟）",
			"body": "用 8% 次氯酸钠溶液进一步消毒，可杀灭酒精无法去除的孢子和细菌。\n"
				+ "次氯酸钠具有强氧化性，消毒更彻底。",
			"click_to_advance": false,
			"active_objects": ["bottle_naclo"],
			"correct_object": "bottle_naclo",
			"correct_message": "NaClO 消毒完成"
		},
		{
			"title": "⑤ 无菌水再次漂洗",
			"body": "用无菌水将花药上残余的 NaClO 彻底冲洗干净。\n"
				+ "残余消毒液会抑制花药细胞生长，必须充分漂洗。",
			"click_to_advance": false,
			"active_objects": ["bottle_water2"],
			"correct_object": "bottle_water2",
			"correct_message": "终漂完成，花药已完全无菌"
		},
		{
			"title": "⑥ 进入超净工作台（无菌区）",
			"body": "将消毒好的花药移入超净工作台中。\n"
				+ "超净工作台通过 HEPA 过滤器提供无菌气流，防止空气中杂菌污染。\n"
				+ "所有后续操作必须在无菌条件下进行！",
			"click_to_advance": false,
			"active_objects": ["sterile_cabinet"],
			"correct_object": "sterile_cabinet",
			"correct_message": "已进入无菌工作台"
		},
		{
			"title": "⑦ 镊子剥取花药",
			"body": "用无菌镊子小心地从花药中剥离花药（小孢子囊）。\n"
				+ "注意：剥取时不要损伤花药，也不要混入花丝等其他组织。\n"
				+ "花药壁细胞是二倍体，会干扰单倍体筛选。",
			"click_to_advance": false,
			"active_objects": ["tweezers"],
			"correct_object": "tweezers",
			"correct_message": "花药已成功剥离"
		},
		{
			"title": "⑧ 接种到诱导培养基",
			"body": "将剥离的花药水平放置在愈伤组织诱导培养基上。\n"
				+ "花药应均匀分布，避免重叠，接种密度适当。\n"
				+ "操作完成后立即封口，防止污染。",
			"click_to_advance": false,
			"active_objects": ["medium_plate"],
			"correct_object": "medium_plate",
			"correct_message": "花药已接种到诱导培养基上！",
			"completion_text": "花药消毒与接种完成！\n已按正确顺序完成：75% 酒精 → 无菌水 → 8% NaClO → 无菌水漂洗 → 超净工作台中剥取花药并接种。\n严格的消毒程序是实验成功的关键，任何环节疏忽都会导致杂菌污染。\n接下来进行最关键的步骤：愈伤组织诱导培养。"
		},
	]

func _on_interactable_clicked(obj_name: String) -> void:
	var step: Dictionary = steps[current_step_index]
	var correct: String = step.get("correct_object", "")
	if obj_name == correct:
		flash_message(step.get("correct_message", "正确！"), true)
		_pulse_object(obj_name)
		_animate_bud_to_step(current_step_index)
		await get_tree().create_timer(1.0).timeout
		advance_step()
	elif step.get("active_objects", []).has(obj_name):
		flash_message("顺序不对！请按消毒步骤依次操作。", false)

func _pulse_object(nm: String) -> void:
	var area := interactables.get(nm, {}).get("area") as Area3D
	if not area: return
	var tw := create_tween()
	tw.tween_property(area, "scale", Vector3(1.25, 1.25, 1.25), 0.15)
	tw.tween_property(area, "scale", Vector3(1.0, 1.0, 1.0), 0.15)

# 各步骤对应的花药目标位置
const _STEP_TARGETS := {
	1: POS_BUD,        # 取花药：花药出现在操作位置（小跳动）
	2: POS_ALCOHOL,    # 酒精消毒
	3: POS_WATER1,     # 无菌水漂洗
	4: POS_NACLO,      # NaClO 消毒
	5: POS_WATER2,     # 终漂
	6: POS_CABINET,    # 进入超净工作台
	7: POS_TWEEZERS,   # 镊子剥取
	8: POS_MEDIUM,     # 接种诱导培养基
}

func _animate_bud_to_step(step_idx: int) -> void:
	if not bud_node: return
	var target: Vector3 = _STEP_TARGETS.get(step_idx, bud_node.position)
	if target == bud_node.position: return

	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# 先上升一点，再飞向目标，避免穿模
	var mid := (bud_node.position + target) / 2.0 + Vector3(0, 0.6, 0)
	tw.tween_property(bud_node, "position", mid, 0.35)
	tw.tween_property(bud_node, "position", target, 0.45)

	# 到达时小弹跳
	tw.tween_property(bud_node, "position", target + Vector3(0, 0.08, 0), 0.1)
	tw.tween_property(bud_node, "position", target, 0.1)
