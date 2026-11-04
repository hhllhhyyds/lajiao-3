## Scene3.gd — 花药消毒与接种
## 花药消毒处理后在无菌环境下夹取花药并接种到培养基
extends SceneBase

# 操作状态追踪
var disinfect_step: int = 0  # 0=pick bud, 1=alcohol, 2=sterile_water1, 3=naclo, 4=sterile_water2, 5=cabinet, 6=peel, 7=inoculate
var _tweezers_held: bool = false   # 第①步是否已拿起无菌镊子

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
const BEAKER_SCENE := preload("res://assets/props/beaker.glb")
const MAT_GLASS_BORO := preload("res://materials/glass_borosilicate.tres")
const MAT_AGAR := preload("res://materials/agar_base.tres")
const MAT_AGAR_TOP := preload("res://materials/agar.tres")
const MAT_DISH_SHELL := preload("res://materials/dish_shell.tres")
const DISH_SCENE := preload("res://assets/props/petri_dish.glb")
const TWEEZERS_SCENE := preload("res://assets/props/tweezers.glb")
const MAT_ANTHER := preload("res://materials/anther_pale.tres")
const MAT_STEEL_DARK := preload("res://materials/steel_dark.tres")
const MAT_STEEL_BRIGHT := preload("res://materials/steel_bright.tres")

# 各操作目标位置（悬停在试剂/器具上方）
const POS_BUD      := Vector3(-4.5, 1.35, 0.3)
const POS_ALCOHOL  := Vector3(-3.35, 1.55, 0.0)
const POS_WATER1   := Vector3(-2.3, 1.55, 0.0)
const POS_NACLO    := Vector3(-0.8, 1.55, 0.0)
const POS_WATER2   := Vector3( 0.7, 1.55, 0.0)
const POS_CABINET  := Vector3( 2.05, 1.10, -0.22)
const POS_TWEEZERS := Vector3( 2.45, 1.12, -0.75)
const POS_MEDIUM   := Vector3( 2.45, 1.16,  1.15)

# 镊子长轴是 +X，Y 转 180° 后钳口指向 -X，所以镊子横在画面里、始终水平，
# 原点比钳口往右退 0.65m
const TWZ_REST_POS := Vector3(-4.88, 1.00, 0.40)   # 平放在桌面、花药左侧，不与花药接触
const TWZ_REST_ROT := Vector3(0.0, 0.0, 0.0)   # 镊尖统一朝 +X，夹取后不再翻转
const TWZ_CARRY_DX := -0.65   # 镊尖朝 +X，故本体停在瓶口左侧，尖端指向瓶口

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
# 红字统一排在各自固定标签正上方 0.24 m 处（数值按各标签实测高度标定）
const _TIP_DY := {
	"bottle_alcohol": 0.30,
	"bottle_water1": 0.26,
	"bottle_naclo": 0.62,
	"bottle_water2": 0.26,
	"flower_bud": 1.86,
	"medium_plate": 0.03,
	"tweezers": -1.13,
}

## 提示条字号：绿框（成功）加大到 30，红框同步提到 28 保持层级
func flash_message(msg: String, good: bool = true, dur: float = 2.2,
		font_size: int = 20, custom_color: Color = Color(-1, -1, -1),
		half_w: int = 220, half_h: int = 40, show_prefix: bool = true,
		offset_x: float = 0.0, offset_y: float = 186.0) -> void:
	var fs := maxi(font_size, 30) if good else maxi(font_size, 28)
	super.flash_message(msg, good, dur, fs, custom_color, half_w,
		maxi(half_h, 44), show_prefix, offset_x, offset_y)

func _style_tooltip(obj_name: String, lbl: Label3D) -> void:
	# 次氯酸钠那条上移后离物体更远，字号单独放大一档
	lbl.font_size = 34 if obj_name == "bottle_naclo" else 28
	lbl.outline_size = 6
	lbl.modulate = Color(1.0, 0.26, 0.18)

## 红色名称牌统一压在各固定标签的正上方，紧挨着不叠字
func _tooltip_offset(obj_name: String) -> Vector3:
	# 培养皿在最右边，单行红字很长，左移一点免得顶出画面
	# 培养基那条跟固定标签一样居中偏移，才能正对在它上方
	var dx := 0.10 if obj_name == "medium_plate" else 0.0
	return Vector3(dx, float(_TIP_DY.get(obj_name, 0.30)), 0.0)

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
	PropKit.spawn(self, BOTTLE_SCENE, Vector3(-3.35, 0.99, -0.30), Vector3.ZERO, {
		"bottle_body": MAT_AMBER,
		"bottle_cap": MAT_CAP,
		"bottle_cap_ridge": MAT_CAP,
	}, Vector3(3.8, 3.8, 3.8))

	PropKit.spawn(self, FLASK_SCENE, Vector3(-2.30, 0.99, -0.30), Vector3.ZERO, {
		"flask_body": MAT_CLEAR_BOTTLE,
	}, Vector3(3.6, 3.6, 3.6))

	PropKit.spawn(self, BEAKER_SCENE, Vector3(-0.80, 0.99, -0.30), Vector3.ZERO, {
		"beaker_body": MAT_GLASS_BORO,
	}, Vector3(4.4, 4.4, 4.4))
	# 烧杯里的次氯酸钠溶液：淡黄绿色，略透明
	var naclo_liq := MeshInstance3D.new()
	naclo_liq.mesh = mk_cyl(0.125, 0.30)
	var naclo_mat := StandardMaterial3D.new()
	naclo_mat.albedo_color = Color(0.70, 0.85, 0.52, 0.92)
	naclo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	naclo_mat.roughness = 0.12
	naclo_mat.metallic = 0.0
	naclo_liq.material_override = naclo_mat
	naclo_liq.position = Vector3(-0.80, 1.14, -0.30)
	add_child(naclo_liq)

	PropKit.spawn(self, FLASK_SCENE, Vector3(0.70, 0.99, -0.30), Vector3.ZERO, {
		"flask_body": MAT_CLEAR_BOTTLE,
	}, Vector3(3.6, 3.6, 3.6))

	# 标签纸 + 液面
	_dress_bottle(Vector3(-3.35, 0.99, -0.30), 0.128, 0.70, "75% 乙醇")
	_dress_bottle(Vector3(-2.30, 0.99, -0.30), 0.132, 0.18, "无菌水",
		Color(0.62, 0.80, 0.92, 0.55))
	_dress_bottle(Vector3(0.70, 0.99, -0.30), 0.132, 0.18, "无菌水",
		Color(0.62, 0.80, 0.92, 0.55))

	create_interactable("bottle_alcohol",
		Vector3(-3.35, 1.42, -0.3), mk_cyl(0.22, 0.82),
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
	var lbl_room := add_label3d("无菌超净台内室", Vector3(0.30, 3.50, 2.6), 60,
		Color.WHITE)
	# 白字配深色描边，压在灰墙上才立得住；字号加粗加大
	if lbl_room:
		lbl_room.font_px = 32
		lbl_room.bold = true
		lbl_room.outline_size = 8
		lbl_room.outline_modulate = Color(0.02, 0.03, 0.07, 0.95)

func _build_flower_bud() -> void:
	create_interactable("flower_bud",
		Vector3(-3.86, 1.10, 0.30),   # 放在镊尖右侧，两者不重叠
		mk_sphere(0.15),
		Color(0.84, 0.75, 0.44),
		Color(0.93, 0.85, 0.46),
		"花药（已低温预处理）")
	for ch in interactables["flower_bud"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			# 红字要压在上面那行"花药"标签之上（-0.38 是旧的下方位置，已废弃）
			# 红字压在"花药"标签正上方（标签世界高 1.36，area 在 1.10）
			ch.position = Vector3(0.0, 0.52, 0.0)
	var lbl_bud := add_label3d("花药", Vector3(-4.38, 1.36, 0.30), 50, Color(0.9, 1.0, 0.7))
	bud_label = lbl_bud
	lbl_bud.outline_size = 8; lbl_bud.outline_modulate = Color(0.1, 0.25, 0.05, 0.9)

func _build_medium() -> void:
	# 培养皿：透明玻璃皿身 + 有纹理的琼脂培养基，表面带一层薄薄的凝结水光
	var dish := PropKit.spawn(self, DISH_SCENE, Vector3(2.45, 0.99, 1.15), Vector3.ZERO, {
		"petri_dish_lid": MAT_GLASS_BORO,
		"petri_dish_base": MAT_CLEAR_BOTTLE,
	}, Vector3(6.4, 6.4, 6.4))
	if dish != null:
		PropKit.contact_shadow(dish, 0.34)
	var agar_mat := StandardMaterial3D.new()
	agar_mat.albedo_color = Color(0.62, 0.78, 0.54)
	agar_mat.roughness = 0.55
	var agar := add_static(mk_cyl(0.300, 0.075), Vector3(2.45, 1.052, 1.15), Color.WHITE)
	agar.material_override = agar_mat
	set_top_layer(agar)
	# 琼脂表面：薄薄一层，带点湿润的高光
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.74, 0.88, 0.66)
	skin_mat.roughness = 0.18
	skin_mat.metallic = 0.0
	var agar_skin := add_static(mk_cyl(0.294, 0.012), Vector3(2.45, 1.090, 1.15), Color.WHITE)
	agar_skin.material_override = skin_mat
	set_top_layer(agar_skin)
	create_interactable("medium_plate",
		Vector3(2.45, 1.10, 1.15), mk_cyl(0.52, 0.20),
		Color(0.74, 0.88, 0.68, 0.0), Color(0.85, 1.0, 0.75), "愈伤组织诱导培养基")
	interactables["medium_plate"]["area"].get_child(0).visible = false
	var lbl_med := attach_label3d("medium_plate", "愈伤组织诱导培养基", Vector3(0.10, 0.24, 0), 52,
		Color(0.0, 0.85, 0.85))
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
		Vector3(-4.88, 1.22, 0.40), mk_box(Vector3(0.95, 0.36, 0.36)),
		Color(0.72, 0.72, 0.75, 0.0), Color(0.90, 0.95, 1.0), "用于夹取花药")
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
		6: pass   # 停在终漂后的位置，等玩家点培养基再接种
		_: _tweezers_rest()

## 玩家点镊子后：镊子离开台面抬到"手持"位置
func _lift_tweezers() -> void:
	if tweezer_model == null or not is_instance_valid(tweezer_model):
		return
	# 拿起：只沿 Y 轴竖直上升，不做任何横向位移
	var up := Vector3(TWZ_REST_POS.x, TWZ_REST_POS.y + 0.55, TWZ_REST_POS.z)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(tweezer_model, "position", up, 0.5)
	if twz_label:
		twz_label.visible = false

## 镊子夹取花药时应处的横向位置（花药左侧 0.13 m）；抬起与下落都用它，保证竖直下落
func _bud_above(height: float = 0.55) -> Vector3:
	var area: Area3D = interactables.get("flower_bud", {}).get("area")
	if area == null:
		return TWZ_REST_POS + Vector3(0.0, height, 0.0)
	var p := area.global_position
	return Vector3(p.x - 0.45, p.y + height, p.z)

## 玩家点花药后：镊子从正上方竖直落下接触花药，台面上的花药消失、镊子上出现一粒
func _clamp_anther() -> void:
	var area: Area3D = interactables.get("flower_bud", {}).get("area")
	if tweezer_model and is_instance_valid(tweezer_model) and area:
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# 一条直线直奔花药，中途不转向
		tw.tween_property(tweezer_model, "position", _bud_above(0.06), 0.6)
		await tw.finished
	if area:
		area.get_child(0).visible = false
	if bud_label:
		bud_label.visible = false
	if held_anther:
		held_anther.visible = true
	await get_tree().create_timer(0.25).timeout

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
	# 终漂后直奔培养基落点，不再先悬停在培养基上方
	var down := Vector3(POS_MEDIUM.x + TWZ_CARRY_DX, POS_MEDIUM.y + 0.10, POS_MEDIUM.z)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tweezer_model, "position", down, 0.85)
	tw.parallel().tween_property(tweezer_model, "rotation_degrees", TWZ_REST_ROT, 0.85)
	tw.tween_callback(func():
		if held_anther:
			held_anther.visible = false
		_place_anthers())
	tw.tween_property(tweezer_model, "position", TWZ_REST_POS, 0.7)
	tw.parallel().tween_property(tweezer_model, "rotation_degrees", TWZ_REST_ROT, 0.7)

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
			"body": "全部操作在超净台内按序完成，任一步骤省略都会引发杂菌污染，导致实验失败：\n"
				+ "取花药 → 75% 酒精 30 s → 无菌水漂洗 → 8% NaClO 5–10 min\n"
				+ "→ 无菌水终漂 → 接种培养基",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "① 拿起镊子，夹取花药",
			"body": "先点击【无菌镊子】拿起镊子，再用镊子点击花药将其夹取。",
			"click_to_advance": false,
			"active_objects": ["tweezers", "flower_bud"],
			"correct_object": "tweezers",
			"correct_message": "已拿起无菌镊子"
		},
		{
			"title": "② 75% 酒精消毒（30 秒）",
			"body": "75% 酒精消毒 30 秒，去除表面大部分杂菌。浓度不可更高，否则损伤花药组织。",
			"click_to_advance": false,
			"active_objects": ["bottle_alcohol"],
			"correct_object": "bottle_alcohol",
			"correct_message": "75% 酒精消毒完成"
		},
		{
			"title": "③ 无菌水漂洗",
			"body": "用无菌水洗去残余酒精，避免影响后续操作。",
			"click_to_advance": false,
			"active_objects": ["bottle_water1"],
			"correct_object": "bottle_water1",
			"correct_message": "无菌水漂洗完成"
		},
		{
			"title": "④ 8% NaClO 消毒（5~10 分钟）",
			"body": "8% 次氯酸钠消毒 5–10 分钟，强氧化性可杀灭酒精难以去除的孢子与细菌。",
			"click_to_advance": false,
			"active_objects": ["bottle_naclo"],
			"correct_object": "bottle_naclo",
			"correct_message": "NaClO 消毒完成"
		},
		{
			"title": "⑤ 无菌水再次漂洗",
			"body": "用无菌水彻底冲净残余 NaClO。残留消毒液会抑制花药细胞生长。",
			"click_to_advance": false,
			"active_objects": ["bottle_water2"],
			"correct_object": "bottle_water2",
			"correct_message": "终漂完成，花药已完全无菌"
		},
		{
			"title": "⑥ 接种到诱导培养基",
			"body": "用无菌镊子将花药平放于诱导培养基上，分布均匀不重叠，完成后立即封口。",
			"click_to_advance": false,
			"active_objects": ["medium_plate"],
			"correct_object": "medium_plate",
			"correct_message": "花药已接种到诱导培养基上！",
			"completion_text": "花药消毒与接种完成！\n已按正确顺序完成：75% 酒精 → 无菌水 → 8% NaClO → 无菌水漂洗 → 接种到诱导培养基。\n严格的消毒程序是实验成功的关键，任何环节疏忽都会导致杂菌污染。\n接下来进行最关键的步骤：愈伤组织诱导培养。"
		},
	]

func _on_interactable_clicked(obj_name: String) -> void:
	# 第①步要先拿镊子，再用镊子夹花药
	# 第⑥步：玩家点培养基（悬停会先显示红字提示）后再接种
	if current_step_index == 6:
		if obj_name == "medium_plate":
			flash_message("用镊子将花药接种到培养基上", true)
			await _tweezers_transfer()
			advance_step()
			return

	if current_step_index == 1:
		if obj_name == "tweezers":
			_tweezers_held = true
			flash_message("已拿起无菌镊子，请点击花药夹取", true)
			_lift_tweezers()
			_refresh_highlights(["flower_bud"])
			return
		if obj_name == "flower_bud":
			if not _tweezers_held:
				flash_message("请先点击【无菌镊子】拿起镊子，再用它夹取花药", false)
				return
			flash_message("已用镊子夹取花药，准备消毒处理", true)
			await _clamp_anther()
			advance_step()
			return
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