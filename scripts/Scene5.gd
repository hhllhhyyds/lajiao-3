## Scene5.gd — 生芽与生根诱导
## 将愈伤组织转入生芽和生根培养基，发育成完整植株
extends SceneBase

var shoot_growth: float = 0.0
var root_growth: float = 0.0
var shoot_timer_running: bool = false
var root_timer_running: bool = false

# 动态节点
var callus_root: Node3D       # 愈伤组织视觉节点（用于移动动画）
var shoot_plant_node: Node3D  # 生芽植株节点（生长动画 + 移动动画）
var root_node: Node3D         # 生根节点
var root_strands: Array = []  # 预建好的根系条目，用于生长动画
var shoot_model: Node3D          # 组培苗模型（随进度放大）
var tweezer_model: Node3D        # 无菌镊子
var _tweezers_held: bool = false # 镊子是否已拿在手里
var _twz_tip_local: Vector3 = Vector3.ZERO  # 钳口在镊子局部坐标里的位置
var _callus_held: bool = false   # 愈伤组织是否已被镊子夹住（跟随钳口）
var _shootling_held: bool = false # 带芽幼苗是否已被镊子夹住（跟随钳口）

const FLASK_SCENE := preload("res://assets/props/conical_flask.glb")
const PLANTLET_SCENE := preload("res://assets/props/plantlet.glb")
const MAT_TILE := preload("res://materials/tile_wall.tres")
const MAT_FLOOR := preload("res://materials/floor_epoxy.tres")
const MAT_BENCH := preload("res://materials/epoxy_bench.tres")
const MAT_STEEL := preload("res://materials/stainless.tres")
const MAT_FLASK := preload("res://materials/glassware_clear.tres")
const MAT_JAR := preload("res://materials/glass_jar.tres")
const TWEEZERS_SCENE := preload("res://assets/props/tweezers.glb")
const MAT_STEEL_BRIGHT := preload("res://materials/steel_bright.tres")
const MAT_STEEL_DARK := preload("res://materials/steel_dark.tres")

# 无菌镊子：两次转移都必须先拿起它，否则拒绝操作
const TWZ_REST_POS := Vector3(1.28 + BENCH_DX, 1.03, 0.86)
const TWZ_REST_ROT := Vector3(0.0, 12.0, 0.0)
const TWZ_CARRY_POS := Vector3(BENCH_DX, 1.62, 0.35)
const TWZ_CARRY_ROT := Vector3(0.0, 180.0, -20.0)  # 绕 Y 转 180°：镊身落在物体右侧
const TWZ_SCALE := 9.0
const MAT_PLANTLET_LEAF := preload("res://materials/plantlet_leaf.tres")
const MAT_PLANTLET_STEM := preload("res://materials/plantlet_stem.tres")

# 两只锥形瓶的横向位置
const FLASK_X := 3.6
# 超净台外面的玻璃罩尺寸
const HOOD_X := 4.60
const HOOD_Z := 1.55
const HOOD_BOTTOM := 1.06   # 台面高度：罩子下缘坐在桌面上
const HOOD_TOP := 4.05      # 高过三根顶灯（灯管在 y=3.90）
# 整个超净台区域（台面 / 玻璃罩 / 顶灯 / 瓶 / 愈伤 / 镊子）的横向偏移。
# 培养箱已移除，这里归零，让超净台区域落在画面正中央。
const BENCH_DX := 0.0

# UI
var shoot_lbl: Label
var root_lbl: Label
var _toast_gen: int = 0   # 提示条代次，用来丢弃被更新提示顶掉的旧请求

func _ready() -> void:
	scene_number = 5
	scene_title  = "生芽与生根诱导"
	super._ready()
	_add_room_caption()

## 场景说明：挂在灯管下方（3D 画面里的顶灯在屏幕 y≈185~200 一带）
func _add_room_caption() -> void:
	var lbl := Label.new()
	lbl.text = "无菌超净台内室"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.anchor_left = 0.5; lbl.anchor_right = 0.5
	lbl.offset_left = -200.0; lbl.offset_right = 200.0
	lbl.offset_top = 302.0; lbl.offset_bottom = 346.0
	_style_label(lbl, 26, Color(0.04, 0.04, 0.04))
	# 中文字体 simhei 没有粗体字重，用 FontVariation 合成加粗
	var fv := FontVariation.new()
	fv.base_font = lbl.get_theme_font("font")
	fv.variation_embolden = 0.9
	lbl.add_theme_font_override("font", fv)
	hud_panel.add_child(lbl)

	# 墙面中央靠上的第二行：白字，配深色描边，否则压在浅色瓷砖墙上会看不清
	var lbl2 := Label.new()
	lbl2.text = "25℃恒温光照培养室内景"
	lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl2.anchor_left = 0.5; lbl2.anchor_right = 0.5
	lbl2.offset_left = -270.0; lbl2.offset_right = 270.0
	lbl2.offset_top = 172.0; lbl2.offset_bottom = 232.0
	_style_label(lbl2, 36, Color(1.0, 0.90, 0.20))   # 亮黄
	# 加粗：embolden 提升字重
	var l2fv := FontVariation.new()
	l2fv.base_font = lbl2.get_theme_font("font")
	l2fv.variation_embolden = 1.6
	lbl2.add_theme_font_override("font", l2fv)
	lbl2.add_theme_constant_override("outline_size", 6)
	lbl2.add_theme_color_override("font_outline_color", Color(0.28, 0.18, 0.0, 0.95))
	hud_panel.add_child(lbl2)

func _configure_camera() -> void:
	# 沿原视线方向拉远约 16%（而不是改 fov：改 fov 会连带改变透视压缩）
	camera.position = Vector3(0.0, 3.65, 10.80)
	camera.look_at(Vector3(0.0, 1.72, -0.10))
	camera.fov = 46.0

func _setup_scene() -> void:
	_build_room()
	_build_glass_hood()
	_build_callus()
	_build_tweezers()
	_build_shoot_medium()
	_build_root_medium()
	_build_info_panel()

## 超净台外面的玻璃罩：五面薄玻璃 + 不锈钢边框。
## 下缘坐在台面上（1.06），上缘要罩住三根灯管（灯管在 y=3.90），所以做到 4.05。
## 透明度压到 0.07——正面那片会盖住整个画面，太浓会把台面颜色整片冲淡。
func _build_glass_hood() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.72, 0.84, 0.95, 0.07)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic = 0.0
	glass.rim_enabled = true
	glass.rim = 0.6
	glass.rim_tint = 1.0
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	var h := HOOD_TOP - HOOD_BOTTOM
	var cy := (HOOD_TOP + HOOD_BOTTOM) * 0.5
	var panes := [
		[Vector3(HOOD_X * 2.0, h, 0.02), Vector3(BENCH_DX, cy, HOOD_Z)],
		[Vector3(HOOD_X * 2.0, h, 0.02), Vector3(BENCH_DX, cy, -HOOD_Z)],
		[Vector3(0.02, h, HOOD_Z * 2.0), Vector3(BENCH_DX - HOOD_X, cy, 0)],
		[Vector3(0.02, h, HOOD_Z * 2.0), Vector3(BENCH_DX + HOOD_X, cy, 0)],
		[Vector3(HOOD_X * 2.0, 0.02, HOOD_Z * 2.0), Vector3(BENCH_DX, HOOD_TOP, 0)],
	]
	for p in panes:
		var mi := add_static(mk_box(p[0]), p[1], Color.WHITE)
		mi.material_override = glass
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var t := 0.05
	var bars := []
	for y in [HOOD_BOTTOM + t * 0.5, HOOD_TOP]:
		bars.append([Vector3(HOOD_X * 2.0 + t, t, t), Vector3(BENCH_DX, y, -HOOD_Z)])
		bars.append([Vector3(HOOD_X * 2.0 + t, t, t), Vector3(BENCH_DX, y, HOOD_Z)])
		bars.append([Vector3(t, t, HOOD_Z * 2.0 + t), Vector3(BENCH_DX - HOOD_X, y, 0)])
		bars.append([Vector3(t, t, HOOD_Z * 2.0 + t), Vector3(BENCH_DX + HOOD_X, y, 0)])
	for x in [-HOOD_X, HOOD_X]:
		for z in [-HOOD_Z, HOOD_Z]:
			bars.append([Vector3(t, h, t), Vector3(BENCH_DX + x, cy, z)])
	for b in bars:
		var mi := add_static(mk_box(b[0]), b[1], Color.WHITE)
		mi.material_override = MAT_STEEL

func _build_room() -> void:
	var floor_mi := add_static(mk_plane(Vector2(22, 22)), Vector3.ZERO, Color.WHITE)
	floor_mi.material_override = MAT_FLOOR
	# 相机拉远后视野变宽，墙也要跟着加宽，否则会看到墙的左右边界
	# 墙加高到 6 m：原 4.8 m 时墙顶边线正好落在"25℃恒温光照培养室"那行字上，
	# 加高后这行完整落在瓷砖面上，上方也不再有灰色天空带穿过去
	var wall := add_static(mk_box(Vector3(22, 6.0, 0.2)), Vector3(0, 3.0, -4.5), Color.WHITE)
	wall.material_override = _tiled(22.0, 6.0)

	# 台面 + 不锈钢腿（9 m 宽：右沿 4.5，右侧留给培养箱，两者互不遮挡）
	var top := add_static(mk_box(Vector3(9.0, 0.12, 3.0)), Vector3(BENCH_DX, 0.94, 0.0), Color.WHITE)
	top.material_override = MAT_BENCH
	for xo in [-4.0, 4.0]:
		for zo in [-1.2, 1.2]:
			var leg := add_static(mk_box(Vector3(0.10, 0.94, 0.10)), Vector3(BENCH_DX + xo, 0.47, zo), Color.WHITE)
			leg.material_override = MAT_STEEL

	# 顶灯：冷白柔光，取代原来的黄色点光源（能量 2.5 直接过曝）
	for i in 3:
		var lx := -3.0 + i * 3.0
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(1.0, 1.0, 0.97)
		lmat.emission_enabled = true
		lmat.emission = Color(0.92, 0.94, 0.92)
		lmat.emission_energy_multiplier = 1.4
		var lmi := MeshInstance3D.new()
		lmi.mesh = mk_box(Vector3(2.4, 0.04, 0.5))
		lmi.material_override = lmat
		lmi.position = Vector3(BENCH_DX + lx, 3.90, 0.0)
		add_child(lmi)


## box 墙面的 UV 是 0..1，直接套世界坐标 UV 的材质会把瓷砖拉成两米一块。
## 世界 UV 下 1 单位 = 1 m，材质用 2.5 次重复；换算到 box 面就是 宽/高 × 2.5。
func _tiled(w: float, h: float) -> StandardMaterial3D:
	var m := MAT_TILE.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(w * 2.5, h * 2.5, 1.0)
	return m

func _build_callus() -> void:
	# 培养皿底座（中央）
	add_static(mk_cyl(0.62, 0.10), Vector3(BENCH_DX, 1.00, 0.0), Color(0.75, 0.85, 0.72))

	# 愈伤组织节点（可整体移动）
	callus_root = Node3D.new()
	callus_root.position = Vector3(BENCH_DX, 1.12, 0)
	callus_root.name = "CallusRoot"
	add_child(callus_root)

	# 愈伤组织：一堆大小不一、颜色略异的瘤状体，堆成一坨
	for i in 26:
		var a := i * 2.399
		var r := 0.03 + sqrt(float(i) / 26.0) * 0.20
		var h := 0.010 + (sin(float(i) * 1.7) * 0.5 + 0.5) * 0.075
		var sp := MeshInstance3D.new()
		var sz := 0.042 + float(i % 5) * 0.011
		sp.mesh = mk_sphere(sz)
		var mat := StandardMaterial3D.new()
		# 深一些、饱和一些的黄绿：原来的浅绿压在浅色培养皿上几乎看不出轮廓
		mat.albedo_color = Color.from_hsv(
			0.245 + float(i % 3) * 0.012,
			0.62 + float(i % 4) * 0.045,
			0.50 + float(i % 5) * 0.032)
		mat.roughness = 0.68
		sp.material_override = mat
		sp.position = Vector3(sin(a) * r, h, cos(a) * r)
		callus_root.add_child(sp)

	create_interactable("callus",
		Vector3(BENCH_DX, 1.15, 0.0), mk_cyl(0.55, 0.28),
		Color(0.38, 0.75, 0.38, 0.0), Color(0.55, 0.95, 0.55), "愈伤组织")
	interactables["callus"]["area"].get_child(0).visible = false

func _build_tweezers() -> void:
	# 平放在台面上，转移愈伤组织 / 幼苗之前必须先点它拿起来
	tweezer_model = PropKit.spawn(self, TWEEZERS_SCENE, TWZ_REST_POS, TWZ_REST_ROT, {
		"tweezer_arm": MAT_STEEL_BRIGHT,
		"tweezer_tail": MAT_STEEL_BRIGHT,
		"tweezer_tip": MAT_STEEL_DARK,
	}, Vector3.ONE * TWZ_SCALE)
	create_interactable("tweezers",
		TWZ_REST_POS + Vector3(0.0, 0.16, 0.0), mk_box(Vector3(0.95, 0.40, 0.40)),
		Color(0.72, 0.72, 0.75, 0.0), Color(0.90, 0.95, 1.0), "无菌镊子")
	interactables["tweezers"]["area"].get_child(0).visible = false
	var lbl_twz := attach_label3d("tweezers", "无菌镊子", Vector3(0.0, 0.14, 0.58), 44,
		Color(0.86, 0.87, 0.90))
	if lbl_twz: lbl_twz.outline_size = 10; lbl_twz.outline_modulate = Color(0.20, 0.20, 0.20, 1.0)
	_compute_tweezer_tip()

## 算出镊子钳口在世界空间里的位置（取模型 +X 方向最远端，与 Scene3 的朝向约定一致）
func _compute_tweezer_tip() -> void:
	if tweezer_model == null or not is_instance_valid(tweezer_model):
		return
	var inv := tweezer_model.global_transform.affine_inverse()
	var best_x := -1.0e9
	var best := Vector3.ZERO
	for node in tweezer_model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var ab: AABB = mi.get_aabb()
		var xf := inv * mi.global_transform
		var cy := (ab.position.y + ab.end.y) * 0.5
		var cz := (ab.position.z + ab.end.z) * 0.5
		for cx in [ab.position.x, ab.end.x]:
			var p: Vector3 = xf * Vector3(cx, cy, cz)
			if p.x > best_x:
				best_x = p.x
				best = p
	_twz_tip_local = best

func _tip_world() -> Vector3:
	if tweezer_model == null or not is_instance_valid(tweezer_model):
		return Vector3.ZERO
	return tweezer_model.global_transform * _twz_tip_local

## 钳口相对镊子节点的世界偏移（含旋转与缩放）
func _jaws_offset() -> Vector3:
	if tweezer_model == null or not is_instance_valid(tweezer_model):
		return Vector3.ZERO
	return tweezer_model.global_transform.basis * _twz_tip_local

## 把"钳口"送到 target，而不是把镊子节点送过去。
## 钳口在模型 +X 最远端，节点直接移到瓶口会让钳口偏出一米多。
func _tweezers_jaws_to(target: Vector3, dur: float) -> void:
	if tweezer_model == null or not is_instance_valid(tweezer_model):
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tweezer_model, "position", target - _jaws_offset(), dur)
	await tw.finished

## 锥形瓶玻璃：烟灰半透明——靠颜色对比出轮廓。
## 说明：试过 inverted-hull 外扩壳描边（next_pass + grow + cull_front），
## 在本管线下不可行：瓶体是半透明、外扩壳的背面会整片透出来；
## 而 grow 在缩放 8.8 的模型上会被放大同样倍数，壳直接包住整只瓶子。
## 最终用"偏暗的冷色玻璃"：在白瓷砖墙前有清晰轮廓，同时仍然通透。
func _make_flask_glass() -> StandardMaterial3D:
	var glass := MAT_JAR.duplicate() as StandardMaterial3D
	glass.albedo_color = Color(0.26, 0.36, 0.48, 0.34)
	glass.roughness = 0.05
	return glass

func _build_shoot_medium() -> void:
	# 生芽培养基架子（左侧）

	# 锥形瓶（真实玻璃器皿模型），瓶内培养基单独做一层
	# 玻璃太"厚"会把瓶里的颜色整片盖白：降低不透明度与边缘反光，让培养基透出来
	var glass := _make_flask_glass()
	PropKit.spawn(self, FLASK_SCENE, Vector3(BENCH_DX - FLASK_X, 1.00, 0.0), Vector3.ZERO, {
		"flask_body": glass,
	}, Vector3(8.8, 8.8, 8.8))
	var medium := MeshInstance3D.new()
	medium.mesh = mk_cyl(0.29, 0.44)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color.from_hsv(0.580, 0.95, 0.55)
	mm.roughness = 0.5
	medium.material_override = mm
	medium.position = Vector3(BENCH_DX - FLASK_X, 1.20, 0.0)
	add_child(medium)

	create_interactable("shoot_medium",
		Vector3(BENCH_DX - FLASK_X, 1.52, 0.0), mk_cyl(0.55, 1.00),
		Color(0.25, 0.55, 0.95, 0.0), Color(0.50, 0.75, 1.0), "诱导再分化生芽培养基")
	interactables["shoot_medium"]["area"].get_child(0).visible = false
	var lbl_shoot := attach_label3d("shoot_medium", "诱导再分化生芽培养基", Vector3(0, 1.38, 0), 44, Color(0.55, 0.82, 1.0))
	if lbl_shoot: lbl_shoot.outline_size = 8; lbl_shoot.outline_modulate = Color(0.0, 0.1, 0.3, 0.8)

	# 生芽植株节点（跟随愈伤组织，初始不可见）
	shoot_plant_node = Node3D.new()
	shoot_plant_node.position = Vector3(BENCH_DX - FLASK_X, 1.50, 0.0)
	shoot_plant_node.visible = false
	shoot_plant_node.name = "ShootPlant"
	add_child(shoot_plant_node)

	# 瓶里的带芽幼苗：第②步要用镊子把它夹出来，再放进生根培养基
	create_interactable("shootling",
		Vector3(BENCH_DX - FLASK_X, 1.78, 0.0), mk_cyl(0.30, 0.46),
		Color(0.45, 0.85, 0.40, 0.0), Color(0.60, 1.0, 0.55), "带芽幼苗")
	interactables["shootling"]["area"].get_child(0).visible = false

func _build_root_medium() -> void:
	# 生根培养基架子（右侧）

	var glass := _make_flask_glass()
	PropKit.spawn(self, FLASK_SCENE, Vector3(BENCH_DX + FLASK_X, 1.00, 0.0), Vector3.ZERO, {
		"flask_body": glass,
	}, Vector3(8.8, 8.8, 8.8))
	var medium := MeshInstance3D.new()
	medium.mesh = mk_cyl(0.29, 0.44)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color.from_hsv(0.070, 0.95, 0.64)
	# 半透明：不透明的琼脂会把长出来的白色根系整块挡住，看不见生根结果
	mm.albedo_color.a = 0.48
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.roughness = 0.5
	medium.material_override = mm
	medium.position = Vector3(BENCH_DX + FLASK_X, 1.20, 0.0)
	add_child(medium)

	create_interactable("root_medium",
		Vector3(BENCH_DX + FLASK_X, 1.52, 0.0), mk_cyl(0.55, 1.00),
		Color(0.72, 0.58, 0.42, 0.0), Color(0.90, 0.75, 0.55), "诱导再分化生根培养基")
	interactables["root_medium"]["area"].get_child(0).visible = false
	var lbl_root := attach_label3d("root_medium", "诱导再分化生根培养基", Vector3(0, 1.38, 0), 44, Color(0.78, 0.52, 0.25))
	if lbl_root: lbl_root.outline_size = 8; lbl_root.outline_modulate = Color(0.2, 0.1, 0.0, 0.8)

	# 根系节点（初始不可见，从植株基部往下长，位于右侧培养基内）
	root_node = Node3D.new()
	root_node.position = Vector3(BENCH_DX + FLASK_X, 1.46, 0.0)
	root_node.visible = false
	root_node.name = "RootNode"
	add_child(root_node)

func _build_info_panel() -> void:
	var info_panel := Panel.new()
	info_panel.anchor_top = 1.0; info_panel.anchor_bottom = 1.0
	info_panel.anchor_right = 0.226   # 右边框紧贴文字（状态文字最宽约 279 px）
	info_panel.offset_top = -420 - 500; info_panel.offset_bottom = -320 - 500
	info_panel.offset_left = 8; info_panel.offset_right = -8
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.10, 0.04, 0.92)
	ps.set_border_width_all(1); ps.border_color = Color(0.25, 0.55, 0.28)
	ps.set_corner_radius_all(6)
	info_panel.add_theme_stylebox_override("panel", ps)
	canvas_layer.add_child(info_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10; vb.offset_right = -10; vb.offset_top = 6; vb.offset_bottom = -6
	vb.add_theme_constant_override("separation", 6)
	info_panel.add_child(vb)

	shoot_lbl = Label.new(); shoot_lbl.text = "🌿 生芽进度：等待转移"
	shoot_lbl.add_theme_font_size_override("font_size", 26)
	shoot_lbl.add_theme_color_override("font_color", Color(0.40, 0.75, 1.0))
	shoot_lbl.add_theme_constant_override("outline_size", 2)
	shoot_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.1, 0.3, 0.7))
	vb.add_child(shoot_lbl)

	root_lbl = Label.new(); root_lbl.text = "🌱 生根进度：等待转移"
	root_lbl.add_theme_font_size_override("font_size", 26)
	root_lbl.add_theme_color_override("font_color", Color(0.72, 0.48, 0.22))
	root_lbl.add_theme_constant_override("outline_size", 2)
	root_lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0, 0.7))
	vb.add_child(root_lbl)

## 红色提示词要"跳"出来：正红 + 加大字号 + 厚深色描边
## （基类默认 39 号、偏粉的 (1.0,0.55,0.55)、6 号描边，在亮背景下不够醒目）
func _style_tooltip(_obj_name: String, lbl: Label3D) -> void:
	lbl.font_size = 52
	lbl.modulate = Color(1.0, 0.10, 0.06)
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0.10, 0.0, 0.0, 0.95)

## 提示条（绿=成功 / 红=失败）：放在台面前沿下方，既压不到台面上的实验物体，
## 也不会盖住灯管下方那行"无菌超净台内室"。
## 同一时刻只允许存在一条：上一条没消失就先收掉它，等一下再弹新的，避免两框重叠。
func flash_message(msg: String, good: bool = true, dur: float = 2.2,
		font_size: int = 20, custom_color: Color = Color(-1, -1, -1),
		half_w: int = 220, half_h: int = 40, show_prefix: bool = true,
		offset_x: float = 0.0, offset_y: float = 140.0) -> void:
	_toast_gen += 1
	var gen := _toast_gen
	if _last_toast != null and is_instance_valid(_last_toast):
		_last_toast.visible = false
		_last_toast.queue_free()
		_last_toast = null
		await get_tree().create_timer(0.16).timeout
		if gen != _toast_gen:
			return   # 这期间又来了更新的提示，交给那一条去显示
	# 提示文字放大到 28（调用方没指定时用基类默认的 20，这里统一抬上来）
	super.flash_message(msg, good, dur, maxi(font_size, 28), custom_color,
		half_w, maxi(half_h, 46), show_prefix, offset_x, offset_y)

func _define_steps() -> void:
	steps = [
		{
			"title": "📖  生芽与生根诱导",
			"body": "愈伤组织具有全能性：改变生长素与细胞分裂素配比，"
					+ "可先后诱导再分化生芽、生根，最终长成完整植株。",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "① 将愈伤组织转入生芽培养基",
			"body": "用【无菌镊子】夹起愈伤组织，再点击左侧【生芽培养基】完成转移；芽会自动分化。",
			"click_to_advance": false,
			"active_objects": ["tweezers", "callus", "shoot_medium"]
		},
		{
			"title": "② 将带芽幼苗转入生根培养基",
			"body": "再用镊子夹起带芽幼苗，点击右侧【生根培养基】完成转移；根系会自动生长。",
			"click_to_advance": false,
			"active_objects": ["tweezers", "shootling", "root_medium"],
			"correct_object": "root_medium",
			"correct_message": "幼苗已转入生根培养基",
			"completion_text": "生芽与生根完成！\n愈伤组织已分化为具根、茎、叶的辣椒幼苗，体现了细胞全能性。\n下一步：鉴定染色体倍性，筛选真正的单倍体植株。"
		},
	]

var _callus_transferred: bool = false
var _shootling_taken: bool = false

func _on_interactable_clicked(obj_name: String) -> void:
	match current_step_index:
		1:
			if obj_name == "tweezers":
				_pick_up_tweezers()
			elif obj_name == "callus":
				if not _tweezers_held:
					flash_message("请先拿起【无菌镊子】再夹取愈伤组织！", false)
					return
				flash_message("已用镊子夹起愈伤组织，请点击左侧生芽培养基", true)
				_callus_transferred = true
				_clamp_callus()
				_refresh_highlights(["shoot_medium"])
			elif obj_name == "shoot_medium":
				if not _tweezers_held:
					flash_message("转移必须用【无菌镊子】，请先拿起镊子！", false)
					return
				if not _callus_transferred:
					flash_message("请先用镊子夹起愈伤组织！", false)
					return
				flash_message("愈伤组织正在转移至生芽培养基…", true)
				# 隐藏愈伤组织标签
				var callus_area := interactables.get("callus", {}).get("area") as Area3D
				if callus_area:
					for ch in callus_area.get_children():
						if ch is Label3D:
							ch.visible = false
				# 镊子夹着愈伤组织飞到瓶口，再松手落进瓶里
				await _carry_callus_to_shoot()
				shoot_plant_node.visible = true
				_return_tweezers()
				# 芽自动开始分化，无需按钮；长满后由 _process 推进到下一步
				_refresh_highlights([])
				shoot_timer_running = true
		2:
			if obj_name == "tweezers":
				_pick_up_tweezers()
			elif obj_name == "shootling":
				if not _tweezers_held:
					flash_message("请先拿起【无菌镊子】再夹取幼苗！", false)
					return
				if _shootling_taken:
					return
				_shootling_taken = true
				flash_message("已用镊子夹起带芽幼苗，请点击右侧生根培养基", true)
				_clamp_shootling()
				_refresh_highlights(["root_medium"])
			elif obj_name == "root_medium":
				if not _tweezers_held:
					flash_message("转移必须用【无菌镊子】，请先拿起镊子！", false)
					return
				if not _shootling_taken:
					flash_message("请先用镊子夹起左侧培养基里的幼苗！", false)
					return
				flash_message("带芽幼苗正在转移至生根培养基…", true)
				# 镊子夹着幼苗从左瓶送到右瓶，再松手放下
				await _carry_shootling_to_root()
				root_node.visible = true
				_build_root_strands()
				_return_tweezers()
				# 根系自动生长，长满后由 _process 通关
				_refresh_highlights([])
				root_timer_running = true
		_: pass

# ── 无菌镊子：拿起 / 送到目标 / 放回 ──
func _pick_up_tweezers() -> void:
	if tweezer_model == null or not is_instance_valid(tweezer_model):
		return
	if _tweezers_held:
		flash_message("镊子已经在手里了", true)
		return
	_tweezers_held = true
	flash_message("已拿起无菌镊子", true)
	var rot := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rot.tween_property(tweezer_model, "rotation_degrees", TWZ_CARRY_ROT, 0.30)
	await rot.finished
	await _tweezers_jaws_to(TWZ_CARRY_POS, 0.30)

func _tweezers_carry_to(dst: Vector3) -> void:
	if tweezer_model == null or not is_instance_valid(tweezer_model):
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tweezer_model, "position", dst, 0.55)
	tw.parallel().tween_property(tweezer_model, "rotation_degrees", TWZ_CARRY_ROT, 0.55)

func _return_tweezers() -> void:
	if tweezer_model == null or not is_instance_valid(tweezer_model):
		return
	_tweezers_held = false
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tweezer_model, "position", TWZ_REST_POS, 0.55)
	tw.parallel().tween_property(tweezer_model, "rotation_degrees", TWZ_REST_ROT, 0.55)

# ── 动画：镊子夹住愈伤组织（此后由 _process 让愈伤跟着钳口走） ──
func _clamp_callus() -> void:
	if tweezer_model == null or not is_instance_valid(tweezer_model) or callus_root == null:
		return
	# 镊子先探到愈伤组织上方（钳口对准它）
	await _tweezers_jaws_to(Vector3(0.0, 1.50, 0.16), 0.35)
	# 愈伤组织贴到钳口上
	var snap := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	snap.tween_property(callus_root, "position", _tip_world() + Vector3(0.0, -0.03, 0.0), 0.22)
	await snap.finished
	_callus_held = true

# ── 动画：镊子夹着愈伤组织送到左侧锥形瓶，然后松手放进瓶里 ──
func _carry_callus_to_shoot() -> void:
	if tweezer_model == null or not is_instance_valid(tweezer_model) or callus_root == null:
		return
	await _tweezers_jaws_to(Vector3(BENCH_DX - FLASK_X, 1.64, 0.0), 0.75)
	# 松手：愈伤组织从钳口落进瓶内并缩小
	_callus_held = false
	var drop := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(callus_root, "position", Vector3(BENCH_DX - FLASK_X, 1.52, 0.0), 0.28)
	drop.parallel().tween_property(callus_root, "scale", Vector3(0.5, 0.5, 0.5), 0.28)
	await drop.finished
	# 同步移动交互区域，免得高亮留在原位
	var area := interactables.get("callus", {}).get("area") as Area3D
	if area:
		area.position = Vector3(BENCH_DX - FLASK_X, 1.52, 0.0)

## 生芽完成后收掉瓶里的愈伤组织团块：它已经再分化成芽，不应继续留在画面上
func _remove_callus_clump() -> void:
	if callus_root == null or not is_instance_valid(callus_root):
		return
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(callus_root, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
	tw.tween_callback(func():
		if callus_root != null and is_instance_valid(callus_root):
			callus_root.visible = false)

# ── 动画：镊子夹住左侧瓶里的带芽幼苗（此后由 _process 让它跟着钳口走） ──
func _clamp_shootling() -> void:
	if tweezer_model == null or not is_instance_valid(tweezer_model) or shoot_plant_node == null:
		return
	# 镊子伸到左侧瓶口，把幼苗夹出来
	await _tweezers_jaws_to(Vector3(BENCH_DX - FLASK_X, 1.62, 0.0), 0.45)
	_shootling_held = true

# ── 动画：镊子夹着幼苗从左瓶送到右瓶，再松手放进瓶里 ──
func _carry_shootling_to_root() -> void:
	if tweezer_model == null or not is_instance_valid(tweezer_model) or shoot_plant_node == null:
		return
	await _tweezers_jaws_to(Vector3(BENCH_DX + FLASK_X, 1.68, 0.0), 0.85)
	# 松手：幼苗落到生根培养基里
	_shootling_held = false
	var drop := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(shoot_plant_node, "position", Vector3(BENCH_DX + FLASK_X, 1.50, 0.0), 0.28)
	await drop.finished

# ── 生芽植株：逐帧重建（progress 0→1） ──
func _build_shoot_plant(progress: float) -> void:
	if progress <= 0.0:
		return
	if shoot_model == null or not is_instance_valid(shoot_model):
		shoot_model = PropKit.spawn(shoot_plant_node, PLANTLET_SCENE, Vector3.ZERO,
			Vector3.ZERO, {"plantlet_leaf": MAT_PLANTLET_LEAF, "plantlet_stem": MAT_PLANTLET_STEM,
			"plantlet_root": MAT_PLANTLET_LEAF}, Vector3.ONE * 0.01)
	shoot_model.scale = Vector3.ONE * (0.01 + progress * 7.0)
	# 瓶里的苗看不到根，根丝会从瓶底穿出去
	for node in shoot_model.find_children("plantlet_root*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visible = false

# ── 预建根系条（初始 scale=0，之后逐步放大） ──
var _root_defs := [
	{"a": 0.00,          "r": 0.10, "len": 0.30, "rx": -8.0},
	{"a": TAU * 0.125,   "r": 0.13, "len": 0.24, "rx": 12.0},
	{"a": TAU * 0.25,    "r": 0.09, "len": 0.36, "rx": -5.0},
	{"a": TAU * 0.375,   "r": 0.14, "len": 0.22, "rx": 10.0},
	{"a": TAU * 0.5,     "r": 0.11, "len": 0.32, "rx": -12.0},
	{"a": TAU * 0.625,   "r": 0.10, "len": 0.28, "rx": 6.0},
	{"a": TAU * 0.75,    "r": 0.12, "len": 0.20, "rx": -10.0},
	{"a": TAU * 0.875,   "r": 0.10, "len": 0.38, "rx": 8.0},
]

## 上粗下细的根：直筒看起来像白蜡烛，收尖才像根
func _mk_root(len: float, r0: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r0
	m.bottom_radius = r0 * 0.45
	m.height = len
	return m

func _build_root_strands() -> void:
	root_strands.clear()
	var idx := 0
	for rd in _root_defs:
		var a: float = rd["a"]
		var r: float = rd["r"]
		var len: float = rd["len"]
		var rx: float = rd["rx"]
		var mi := MeshInstance3D.new()
		mi.mesh = _mk_root(len, 0.019 + float(idx % 3) * 0.005)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.97, 0.95, 0.90)
		mat.roughness = 0.55
		mi.material_override = mat
		# 位置：根从植株底部向外向下延伸
		mi.position = Vector3(sin(a) * r, -len * 0.5, cos(a) * r)
		mi.rotation_degrees = Vector3(rx, rad_to_deg(a), 0)
		mi.scale = Vector3.ZERO   # 初始不可见，待动画放大
		root_node.add_child(mi)
		root_strands.append(mi)
		idx += 1

# =====================================================================
# _process：生芽 + 生根 动画
# =====================================================================
func _process(delta: float) -> void:
	# 被镊子夹住时，愈伤组织贴在钳口上跟着镊子走
	if _callus_held and callus_root != null and is_instance_valid(callus_root):
		callus_root.global_position = _tip_world() + Vector3(0.0, -0.03, 0.0)
	# 被镊子夹住时，带芽幼苗也贴在钳口上跟着走
	if _shootling_held and shoot_plant_node != null and is_instance_valid(shoot_plant_node):
		shoot_plant_node.global_position = _tip_world() + Vector3(0.0, -0.02, 0.0)

	# 生芽阶段
	if shoot_timer_running:
		shoot_growth += delta * 0.55
		shoot_growth = minf(shoot_growth, 1.0)
		shoot_lbl.text = "🌿 生芽进度：%.0f%%" % (shoot_growth * 100)
		_build_shoot_plant(shoot_growth)
		if shoot_growth >= 1.0:
			shoot_timer_running = false
			shoot_lbl.text = "🌿 生芽完成 ✓"
			# 愈伤组织已经再分化成芽，瓶里不应再留着原来的团块
			_remove_callus_clump()
			flash_message("愈伤组织再分化生芽成功！", true)
			await get_tree().create_timer(1.5).timeout
			advance_step()

	# 生根阶段：逐步放大预建的根系条
	if root_timer_running:
		root_growth += delta * 0.45
		root_growth = minf(root_growth, 1.0)
		root_lbl.text = "🌱 生根进度：%.0f%%" % (root_growth * 100)
		# 分批次放大：第 i 根在 progress > i/8 时开始生长
		var n := root_strands.size()
		for i in n:
			var strand = root_strands[i]
			if not is_instance_valid(strand): continue
			var start := float(i) / float(n)
			var s := clampf((root_growth - start) / (1.0 - start + 0.001), 0.0, 1.0)
			strand.scale = Vector3(s, s, s)
		if root_growth >= 1.0:
			root_timer_running = false
			root_lbl.text = "🌱 生根完成 ✓"
			# 不再弹"单倍体植株培育成功"提示条：左上角进度已显示"生根完成 ✓"，
			# 随后直接进入通关页，不必再压一条绿框
			await get_tree().create_timer(1.5).timeout
			advance_step()