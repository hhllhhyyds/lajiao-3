## Scene3.gd — 花药消毒与接种
## 花药消毒处理后在无菌环境下夹取花药并接种到培养基
extends SceneBase

# 操作状态追踪
var disinfect_step: int = 0  # 0=pick bud, 1=alcohol, 2=sterile_water1, 3=naclo, 4=sterile_water2, 5=cabinet, 6=peel, 7=inoculate

# 花药可见节点，用于移动动画

const BOTTLE_SCENE := preload("res://assets/props/reagent_bottle.glb")
const MEDIA_SCENE := preload("res://assets/props/media_bottle.glb")
const FLASK_SCENE := preload("res://assets/props/conical_flask.glb")
const MAT_AMBER := preload("res://materials/amber_glass.tres")
const MAT_CAP := preload("res://materials/cap_black.tres")
const MAT_CAP_BLUE := preload("res://materials/cap_blue.tres")
const MAT_CLEAR_BOTTLE := preload("res://materials/clear_bottle.tres")
const MAT_WHITE_BOTTLE := preload("res://materials/white_bottle.tres")
const MAT_STAINLESS := preload("res://materials/stainless.tres")
const MAT_BENCH := preload("res://materials/epoxy_bench.tres")
const MAT_TILE := preload("res://materials/tile_wall.tres")
const MAT_FLOOR := preload("res://materials/floor_epoxy.tres")
const MAT_LABEL_PAPER := preload("res://materials/label_paper.tres")
const DISH_SCENE := preload("res://assets/props/petri_dish.glb")
const TWEEZERS_SCENE := preload("res://assets/props/tweezers.glb")
const MAT_ANTHER := preload("res://materials/anther_pale.tres")
const MAT_STEEL_DARK := preload("res://materials/steel_dark.tres")
const MAT_STEEL_BRIGHT := preload("res://materials/steel_bright.tres")

# 各操作目标位置（悬停在试剂/器具上方）
const POS_BUD      := Vector3(-4.5, 1.35, 0.3)
const POS_ALCOHOL  := Vector3(-3.8, 1.55, 0.0)
const POS_WATER1   := Vector3(-2.3, 1.55, 0.0)
const POS_NACLO    := Vector3(-0.8, 1.55, 0.0)
const POS_WATER2   := Vector3( 0.7, 1.55, 0.0)
const POS_CABINET  := Vector3( 2.05, 1.10, -0.22)
const POS_TWEEZERS := Vector3( 2.45, 1.12, -0.75)
const POS_MEDIUM   := Vector3( 2.45, 1.16,  1.15)

# 镊子长轴是 +X，Y 转 180° 后钳口指向 -X，所以镊子横在画面里、始终水平，
# 原点比钳口往右退 0.65m
const TWZ_REST_POS := Vector3(-3.85, 1.22, 0.30)
const TWZ_REST_ROT := Vector3(0.0, 180.0, 0.0)
const TWZ_CARRY_DX := 0.65

var bud_label: LabelProjector.TagLabel
var twz_label: LabelProjector.TagLabel
var tweezer_model: Node3D
var held_anther: MeshInstance3D

func _ready() -> void:
	scene_number = 3
	scene_title  = "花药消毒与接种"
	light_focus = Vector3(0.0, 1.5, 0.0)
	light_radius = 4.0
	light_intensity = 0.80
	super._ready()

func _configure_camera() -> void:
	camera.position = Vector3(1.95, 2.55, 8.60)
	camera.look_at(Vector3(-0.45, 1.42, 0.10))
	camera.fov = 40.0

func _setup_scene() -> void:
	_build_lab_bench()
	_build_bottles()
	_build_sterile_cabinet()
	_build_flower_bud()
	_build_medium()

func _build_lab_bench() -> void:
	# 台面：深色环氧树脂板，压在不锈钢框上；地面铺环氧地坪
	var top := add_static(mk_box(Vector3(10.0, 0.10, 3.40)), Vector3(0.0, 0.94, 0.0), Color.WHITE)
	top.material_override = MAT_BENCH
	var edge := add_static(mk_box(Vector3(10.1, 0.06, 3.50)), Vector3(0.0, 0.885, 0.0), Color.WHITE)
	edge.material_override = MAT_STAINLESS

	# 台面下的柜体（整块，不再做细腿，超净台里本来就是这样）
	var body := add_static(mk_box(Vector3(9.9, 0.86, 3.3)), Vector3(0.0, 0.43, 0.0), Color.WHITE)
	body.material_override = MAT_STAINLESS

	var floor_mi := add_static(mk_plane(Vector2(14, 9)), Vector3(0.0, 0.0, 0.6), Color.WHITE)
	floor_mi.material_override = MAT_FLOOR

## 超净台内壁是 box，面 UV 只有 0..1，直接套世界 UV 的瓷砖材质会被拉成大板
func _tiled(w: float, h: float) -> StandardMaterial3D:
	var m := MAT_TILE.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(w * 1.6, h * 1.6, 1.0)
	return m

func _panel(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := add_static(mk_box(size), pos, Color.WHITE)
	mi.material_override = mat
	return mi

## 给瓶子加标签纸、液面标签上的字，让它看起来是被用过的试剂瓶
## 场景三每个器物上方都已经有固定标签，悬停名称牌再往上抬一截，
## 免得红色提示压在固定标签上
## 场景三的红色提示牌做得和场景二一样醒目
func _style_tooltip(_obj_name: String, lbl: Label3D) -> void:
	lbl.font_size = 52
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.26, 0.18)

## 红色名称牌挂在物体正上方，抬到固定标签之上，两者不打架
func _tooltip_offset(obj_name: String) -> Vector3:
	# 培养皿在最右边，单行红字很长，左移一点免得顶出画面
	if obj_name == "medium_plate":
		return Vector3(-0.50, 0.95, 0.0)
	return Vector3(0.0, 0.62, 0.0)

func _dress_bottle(base: Vector3, radius: float, height: float,
		text: String, liquid: Color = Color(0, 0, 0, 0)) -> void:
	var label_y := base.y + height * 0.42
	var band_h := height * 0.34

	var band := MeshInstance3D.new()
	band.mesh = mk_cyl(radius + 0.0015, band_h)
	band.material_override = MAT_LABEL_PAPER
	band.position = Vector3(base.x, label_y, base.z)
	add_child(band)

	# 液面：只给透明瓶子加
	if liquid.a > 0.0:
		var liq := MeshInstance3D.new()
		liq.mesh = mk_cyl(radius * 0.92, height * 0.52)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = liquid
		lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lm.roughness = 0.12
		liq.material_override = lm
		liq.position = Vector3(base.x, base.y + height * 0.28, base.z)
		add_child(liq)

func _build_bottles() -> void:
	# 真实瓶型（Blender 旋转成型）：棕色试剂瓶 / 两支广口瓶 / 锥形瓶
	# 本关是 4 倍尺度（台面 10 m 宽），所以道具整体放大
	PropKit.spawn(self, BOTTLE_SCENE, Vector3(-3.80, 0.99, -0.30), Vector3.ZERO, {
		"bottle_body": MAT_AMBER,
		"bottle_cap": MAT_CAP,
		"bottle_cap_ridge": MAT_CAP,
	}, Vector3(3.8, 3.8, 3.8))

	PropKit.spawn(self, FLASK_SCENE, Vector3(-2.30, 0.99, -0.30), Vector3.ZERO, {
		"flask_body": MAT_CLEAR_BOTTLE,
	}, Vector3(3.6, 3.6, 3.6))

	PropKit.spawn(self, MEDIA_SCENE, Vector3(-0.80, 0.99, -0.30), Vector3.ZERO, {
		"media_body": MAT_WHITE_BOTTLE,
		"media_cap": MAT_CAP,
		"media_cap_ridge": MAT_CAP,
	}, Vector3(4.4, 4.4, 4.4))

	PropKit.spawn(self, FLASK_SCENE, Vector3(0.70, 0.99, -0.30), Vector3.ZERO, {
		"flask_body": MAT_CLEAR_BOTTLE,
	}, Vector3(3.6, 3.6, 3.6))

	# 标签纸 + 液面
	_dress_bottle(Vector3(-3.80, 0.99, -0.30), 0.128, 0.70, "75% 乙醇")
	_dress_bottle(Vector3(-2.30, 0.99, -0.30), 0.132, 0.18, "无菌水",
		Color(0.62, 0.80, 0.92, 0.55))
	_dress_bottle(Vector3(-0.80, 0.99, -0.30), 0.186, 0.48, "8% NaClO",
		Color(0.86, 0.90, 0.86, 0.60))
	_dress_bottle(Vector3(0.70, 0.99, -0.30), 0.132, 0.18, "无菌水",
		Color(0.62, 0.80, 0.92, 0.55))

	create_interactable("bottle_alcohol",
		Vector3(-3.8, 1.42, -0.3), mk_cyl(0.22, 0.82),
		Color(0.72, 0.45, 0.10, 0.0), Color(1.0, 0.75, 0.25), "75% 酒精")
	interactables["bottle_alcohol"]["area"].get_child(0).visible = false
	var lbl_alc := attach_label3d("bottle_alcohol", "75% 酒精", Vector3(0, 0.82, 0), 50, Color(1.0, 0.85, 0.5))
	if lbl_alc: lbl_alc.outline_size = 8; lbl_alc.outline_modulate = Color(0.3, 0.15, 0.0, 0.9)

	create_interactable("bottle_water1",
		Vector3(-2.3, 1.40, -0.3), mk_cyl(0.20, 0.75),
		Color(0.60, 0.82, 0.95, 0.0), Color(0.70, 0.95, 1.0), "无菌水")
	interactables["bottle_water1"]["area"].get_child(0).visible = false
	var lbl_w1 := attach_label3d("bottle_water1", "无菌水", Vector3(0, 0.74, 0), 50, Color(0.7, 0.9, 1.0))
	if lbl_w1: lbl_w1.outline_size = 8; lbl_w1.outline_modulate = Color(0.0, 0.15, 0.3, 0.9)

	create_interactable("bottle_naclo",
		Vector3(-0.8, 1.42, -0.3), mk_cyl(0.22, 0.82),
		Color(0.92, 0.93, 0.95, 0.0), Color(1.0, 1.0, 1.0), "8% NaClO")
	interactables["bottle_naclo"]["area"].get_child(0).visible = false
	var lbl_naclo := attach_label3d("bottle_naclo", "8% NaClO\n(次氯酸钠)", Vector3(0, 0.84, 0), 50, Color(0.9, 0.95, 1.0))
	if lbl_naclo: lbl_naclo.outline_size = 8; lbl_naclo.outline_modulate = Color(0.1, 0.15, 0.3, 0.9)

	create_interactable("bottle_water2",
		Vector3(0.7, 1.40, -0.3), mk_cyl(0.20, 0.75),
		Color(0.60, 0.82, 0.95, 0.0), Color(0.70, 0.95, 1.0), "无菌水（终漂）")
	interactables["bottle_water2"]["area"].get_child(0).visible = false
	var lbl_w2 := attach_label3d("bottle_water2", "无菌水（终漂）", Vector3(0, 0.74, 0), 50, Color(0.7, 0.9, 1.0))
	if lbl_w2: lbl_w2.outline_size = 8; lbl_w2.outline_modulate = Color(0.0, 0.15, 0.3, 0.9)

func _build_sterile_cabinet() -> void:
	# 超净台内部：背板 / 左右侧板 / 顶板，开口朝相机（真实层流罩就是这样拍的）
	var w := 11.6
	var d := 5.0
	var h := 4.6
	var cx := 0.35
	var cz := 0.6
	var inner := Color(0.80, 0.82, 0.81)

	_panel(Vector3(w, h, 0.14), Vector3(cx, h * 0.5, cz - d * 0.5), _tiled(w, h))
	_panel(Vector3(0.14, h, d), Vector3(cx - w * 0.5, h * 0.5, cz), _tiled(d, h))
	_panel(Vector3(0.14, h, d), Vector3(cx + w * 0.5, h * 0.5, cz), _tiled(d, h))
	_panel(Vector3(w, 0.14, d), Vector3(cx, h, cz), _tiled(w, d))

	# 顶部灯带：超净台的照明是它最标志性的东西
	var lamp := add_static(mk_box(Vector3(w * 0.86, 0.06, 0.30)), Vector3(cx, h - 0.16, cz + 0.4), Color(0.94, 0.96, 0.98))
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.92, 0.95, 0.98)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(0.85, 0.92, 1.0)
	lamp_mat.emission_energy_multiplier = 1.6
	lamp.material_override = lamp_mat
	var lamp_light := OmniLight3D.new()
	lamp_light.position = Vector3(cx, h - 0.5, cz + 0.5)
	lamp_light.light_color = Color(0.88, 0.94, 1.0)
	lamp_light.light_energy = 1.6
	lamp_light.omni_range = 9.0
	add_child(lamp_light)

	# 前挡板：只在台面前缘立一块矮不锈钢板，不挡视线
	_panel(Vector3(w, 0.30, 0.08), Vector3(cx, 1.12, cz + d * 0.5 - 0.1), MAT_STAINLESS)

	create_interactable("sterile_cabinet",
		Vector3(cx, 2.0, cz), mk_box(Vector3(11.2, 4.6, d - 0.4)),
		Color(0.62, 0.78, 0.92, 0.0), Color(0.75, 0.92, 1.0), "超净工作台（无菌区）")
	interactables["sterile_cabinet"]["area"].get_child(0).visible = false
	var lbl_room := add_label3d("实验室超净台（无菌环境）内室", Vector3(0.30, 3.50, 2.6), 60,
		Color.WHITE)
	# 白字配深色描边，压在灰墙上才立得住；字号加粗加大
	if lbl_room:
		lbl_room.font_px = 32
		lbl_room.bold = true
		lbl_room.outline_size = 8
		lbl_room.outline_modulate = Color(0.02, 0.03, 0.07, 0.95)

func _build_flower_bud() -> void:
	create_interactable("flower_bud",
		Vector3(-4.5, 1.10, 0.3),
		mk_sphere(0.15),
		Color(0.95, 0.89, 0.60),
		Color(1.0, 0.97, 0.55),
		"花药（已低温预处理）")
	for ch in interactables["flower_bud"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			ch.position = Vector3(0.0, -0.38, 0.0)
	var lbl_bud := add_label3d("花药", Vector3(-4.5, 1.72, 0.3), 50, Color(0.9, 1.0, 0.7))
	bud_label = lbl_bud
	lbl_bud.outline_size = 8; lbl_bud.outline_modulate = Color(0.1, 0.25, 0.05, 0.9)

func _build_medium() -> void:
	PropKit.spawn(self, DISH_SCENE, Vector3(2.45, 0.99, 1.15), Vector3.ZERO, {
		"petri_dish_lid": MAT_CLEAR_BOTTLE,
		"petri_dish_base": MAT_CLEAR_BOTTLE,
	}, Vector3(5.6, 5.6, 5.6))
	set_top_layer(add_static(mk_cyl(0.26, 0.06), Vector3(2.45, 1.04, 1.15), Color(0.76, 0.88, 0.70)))
	create_interactable("medium_plate",
		Vector3(2.45, 1.10, 1.15), mk_cyl(0.52, 0.20),
		Color(0.74, 0.88, 0.68, 0.0), Color(0.85, 1.0, 0.75), "愈伤组织诱导培养基")
	interactables["medium_plate"]["area"].get_child(0).visible = false
	var lbl_med := attach_label3d("medium_plate", "愈伤组织\n诱导培养基", Vector3(0.62, 0.06, 0), 36, Color(0.0, 0.85, 0.85))
	if lbl_med: lbl_med.outline_size = 10; lbl_med.outline_modulate = Color(0.0, 0.30, 0.30, 1.0)

	# 真实镊子：尾端圆环 + 两条扁簧，平放在台面上
	tweezer_model = PropKit.spawn(self, TWEEZERS_SCENE, TWZ_REST_POS, TWZ_REST_ROT, {
		"tweezer_arm": MAT_STEEL_BRIGHT,
		"tweezer_tail": MAT_STEEL_BRIGHT,
		"tweezer_tip": MAT_STEEL_DARK,
	}, Vector3(5.0, 5.0, 5.0))

	# 夹在尖端的花药（取花药后出现）
	held_anther = MeshInstance3D.new()
	held_anther.mesh = mk_sphere(0.020)
	held_anther.material_override = MAT_ANTHER
	held_anther.position = Vector3(0.130, 0.0, 0.0)
	held_anther.visible = false
	tweezer_model.add_child(held_anther)
	create_interactable("tweezers",
		Vector3(-4.17, 1.22, 0.30), mk_box(Vector3(0.95, 0.36, 0.36)),
		Color(0.72, 0.72, 0.75, 0.0), Color(0.90, 0.95, 1.0), "无菌镊子（夹取花药）")
	interactables["tweezers"]["area"].get_child(0).visible = false
	var lbl_twz := attach_label3d("tweezers", "无菌镊子", Vector3(0.0, -0.36, 0.26), 44,
		Color(0.86, 0.87, 0.90))
	twz_label = lbl_twz
	lbl_twz.outline_size = 10; lbl_twz.outline_modulate = Color(0.20, 0.20, 0.20, 1.0)

## 镊子从第①步起就夹着花药，跟着步骤在试剂瓶之间移动，最后接种到培养基
func _show_step(idx: int) -> void:
	super._show_step(idx)
	if tweezer_model == null or not is_instance_valid(tweezer_model):
		return
	# 花药从第①步起就在镊子上，台面上那颗原始花药从这时起隐藏
	# 第①步点掉花药之后，台面上的花药和它的标签都消失，改成夹在镊子上
	var picked := idx >= 2
	interactables["flower_bud"]["area"].get_child(0).visible = not picked
	if bud_label:
		bud_label.visible = not picked
	if held_anther:
		held_anther.visible = picked
	# 镊子标签只在取花药和需要点镊子那一步显示，免得跟着满台跑
	if twz_label:
		twz_label.visible = idx < 2
		twz_label.position = Vector3(0.02, -0.30, 0.55)
	match idx:
		2: _tweezers_dip(POS_ALCOHOL)
		3: _tweezers_dip(POS_WATER1)
		4: _tweezers_dip(POS_NACLO)
		5: _tweezers_dip(POS_WATER2)
		6: _tweezers_transfer()
		_: _tweezers_rest()

func _tweezers_rest() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tweezer_model, "position", TWZ_REST_POS, 0.45)
	tw.parallel().tween_property(tweezer_model, "rotation_degrees", TWZ_REST_ROT, 0.45)

## 悬停到某个试剂瓶口，先靠近再往下浸一下
func _tweezers_dip(target: Vector3) -> void:
	var hover := Vector3(target.x + TWZ_CARRY_DX, target.y + 0.16, target.z)
	var dipped := Vector3(hover.x, hover.y - 0.14, hover.z)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tweezer_model, "position", hover, 0.55)
	tw.parallel().tween_property(tweezer_model, "rotation_degrees", TWZ_REST_ROT, 0.55)
	tw.tween_property(tweezer_model, "position", dipped, 0.30)
	tw.tween_property(tweezer_model, "position", hover, 0.30)

func _tweezers_transfer() -> void:
	if held_anther:
		held_anther.visible = true
	var above := Vector3(POS_MEDIUM.x + TWZ_CARRY_DX, POS_MEDIUM.y + 0.50, POS_MEDIUM.z)
	var down := Vector3(POS_MEDIUM.x + TWZ_CARRY_DX, POS_MEDIUM.y + 0.10, POS_MEDIUM.z)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tweezer_model, "position", above, 0.6)
	tw.parallel().tween_property(tweezer_model, "rotation_degrees", TWZ_REST_ROT, 0.6)
	tw.tween_property(tweezer_model, "position", down, 0.35)
	tw.tween_callback(func():
		if held_anther:
			held_anther.visible = false
		_place_anthers())
	tw.tween_property(tweezer_model, "position", above, 0.30)
	tw.tween_property(tweezer_model, "position", TWZ_REST_POS, 0.65)
	tw.parallel().tween_property(tweezer_model, "rotation_degrees", TWZ_REST_ROT, 0.65)

## 接种：在琼脂上放下一枚花药
func _place_anthers() -> void:
	var bead := MeshInstance3D.new()
	bead.mesh = mk_sphere(0.062)
	bead.material_override = MAT_ANTHER
	bead.position = Vector3(POS_MEDIUM.x, 1.125, POS_MEDIUM.z)
	add_child(bead)

func _define_steps() -> void:
	steps = [
		{
			"title": "📖  步骤说明：花药消毒与接种",
			"body": "全部操作都在超净台内完成，按顺序进行：\n"
				+ "① 取花药 → ② 75% 酒精消毒 → ③ 无菌水漂洗 → ④ 8% NaClO 消毒 → "
				+ "⑤ 无菌水漂洗 → ⑥ 接种诱导愈伤组织培养基\n"
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
			"title": "⑥ 接种到诱导培养基",
			"body": "用无菌镊子将花药水平放置在愈伤组织诱导培养基上。\n"
				+ "花药应均匀分布，避免重叠，接种密度适当。\n"
				+ "操作完成后立即封口，防止污染。",
			"click_to_advance": false,
			"active_objects": ["medium_plate"],
			"correct_object": "medium_plate",
			"correct_message": "花药已接种到诱导培养基上！",
			"completion_text": "花药消毒与接种完成！\n已按正确顺序完成：75% 酒精 → 无菌水 → 8% NaClO → 无菌水漂洗 → 接种到诱导培养基。\n严格的消毒程序是实验成功的关键，任何环节疏忽都会导致杂菌污染。\n接下来进行最关键的步骤：愈伤组织诱导培养。"
		},
	]

func _on_interactable_clicked(obj_name: String) -> void:
	var step: Dictionary = steps[current_step_index]
	var correct: String = step.get("correct_object", "")
	if obj_name == correct:
		flash_message(step.get("correct_message", "正确！"), true)
		_pulse_object(obj_name)
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
