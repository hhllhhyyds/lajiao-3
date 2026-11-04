## Scene7.gd — 染色体加倍
## 用秋水仙素处理单倍体植株，使染色体加倍，获得纯合二倍体(DH系)植株
extends SceneBase

var treatment_done: bool = false
var verify_done: bool = false
var final_plant_shown: bool = false

# 动态节点
var haploid_plant: Node3D
var dh_plant: Node3D
var dh_plant_lbl: LabelProjector.TagLabel
var dh_peppers: Node3D          # DH 植株上的果实容器，长大后才结出来
var flower_pot: Node3D          # 移栽用的花盆
var pot_label: LabelProjector.TagLabel   # 花盆上方的提示标签
var room_caption: LabelProjector.TagLabel  # 画面正中的“恒温光照培养室内景”
var colchicine_bottle_visual: Node3D  # 可见的秋水仙素瓶
var growth_timer: float = 0.0
var growing: bool = false

# UI
var treatment_progress_lbl: Label
var chrom_overlay: Control
var micro_static_lbl: LabelProjector.TagLabel  # 显微镜标签（处理完成后才显示）

const MICRO_SCOPE := preload("res://assets/props/microscope.glb")
const PEPPER_SCENE := preload("res://assets/props/pepper_plant.glb")
const PLANTLET_SCENE := preload("res://assets/props/plantlet.glb")
const BEAKER_SCENE := preload("res://assets/props/beaker.glb")
const REAGENT_SCENE := preload("res://assets/props/reagent_bottle.glb")
const MAT_COLCHICINE := preload("res://materials/amber_glass.tres")
const MAT_TILE := preload("res://materials/tile_wall.tres")
const MAT_FLOOR := preload("res://materials/floor_epoxy.tres")
const MAT_BENCH := preload("res://materials/epoxy_bench.tres")
const MAT_STEEL := preload("res://materials/stainless.tres")
const MAT_LEAF := preload("res://materials/plantlet_leaf.tres")
const MAT_STEM := preload("res://materials/plantlet_stem.tres")
const MAT_MICRO := preload("res://materials/microscope_body.tres")
const MAT_MICRO_LENS := preload("res://materials/microscope_lens.tres")
const MAT_JAR := preload("res://materials/glass_jar.tres")
const MAT_AGAR := preload("res://materials/agar.tres")

func _ready() -> void:
	scene_number = 7
	scene_title  = "染色体加倍"
	super._ready()

func _configure_camera() -> void:
	camera.position = Vector3(0.55, 2.70, 7.60)
	camera.look_at(Vector3(0.0, 1.45, 0.10))
	camera.fov = 50.0

func _setup_scene() -> void:
	_build_lab()
	_build_haploid_plant()
	_build_colchicine_bottle()
	_build_treatment_vessel()
	_build_microscope()
	_build_flower_pot()
	_build_dh_plant()
	_build_chrom_overlay()
	_build_treatment_panel()


## box 墙面的 UV 是 0..1，直接套世界坐标 UV 的材质会把瓷砖拉成两米一块。
func _tiled(w: float, h: float) -> StandardMaterial3D:
	var m := MAT_TILE.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(w * 2.5, h * 2.5, 1.0)
	return m
func _build_lab() -> void:
	var floor_mi := add_static(mk_plane(Vector2(22, 22)), Vector3.ZERO, Color.WHITE)
	floor_mi.material_override = MAT_FLOOR
	var wall := add_static(mk_box(Vector3(14, 4.5, 0.2)), Vector3(0, 2.25, -4), Color.WHITE)
	wall.material_override = _tiled(14.0, 4.5)
	var top := add_static(mk_box(Vector3(10.0, 0.12, 3.4)), Vector3(0, 0.90, -0.4), Color.WHITE)
	top.material_override = MAT_BENCH

func _build_haploid_plant() -> void:
	# 培养皿里的琼脂：和场景六的图示一致，苗是插在培养基上的，不是直接摆台面
	var agar := add_static(mk_cyl(0.34, 0.12), Vector3(-3.5, 1.02, 0.5), Color(0.70, 0.82, 0.66))
	agar.material_override = MAT_AGAR

	haploid_plant = Node3D.new()
	haploid_plant.position = Vector3(-3.5, 1.12, 0.5)
	haploid_plant.name = "HaploidPlant"
	add_child(haploid_plant)

	var hp := PropKit.spawn(haploid_plant, PLANTLET_SCENE, Vector3.ZERO, Vector3.ZERO, {
		"plantlet_leaf": MAT_LEAF,
		"plantlet_stem": MAT_STEM,
		"plantlet_root": MAT_LEAF,
	}, Vector3(11.0, 11.0, 11.0))
	# 摆在台面上，根丝不该露出来
	for node in hp.find_children("plantlet_root*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visible = false
	# 无果实（单倍体高度不育）

	create_interactable("haploid_plant_obj",
		Vector3(-3.5, 1.75, 0.5), mk_cyl(0.45, 1.6),
		Color(0.0, 0.0, 0.0, 0.0), Color(0.65, 1.0, 0.65), "单倍体植株（高度不育）")
	interactables["haploid_plant_obj"]["area"].get_child(0).visible = false
	var lbl_haploid := attach_label3d("haploid_plant_obj", "单倍体植株\n(n=12，高度不育)", Vector3(0, 0.68, 0), 36, Color(0.25, 0.95, 0.35))
	if lbl_haploid:
		lbl_haploid.outline_size = 8
		lbl_haploid.outline_modulate = Color(0.0, 0.2, 0.0, 0.8)
		lbl_haploid.font_px = 30   # size 参数会被 _font_for 钳到 18px，放大走 font_px

func _build_colchicine_bottle() -> void:
	# 创建可移动的瓶子节点
	colchicine_bottle_visual = Node3D.new()
	colchicine_bottle_visual.position = Vector3(-0.8, 1.42, -0.2)
	colchicine_bottle_visual.name = "ColchicineBottle"
	add_child(colchicine_bottle_visual)

	# 秋水仙素瓶：真实试剂瓶模型，瓶身换成琥珀色玻璃
	PropKit.spawn(colchicine_bottle_visual, REAGENT_SCENE, Vector3(0.0, -0.60, 0.0),
		Vector3.ZERO, {
		"reagent_body": MAT_COLCHICINE,
		"reagent_cap": MAT_STEEL,
	}, Vector3(3.2, 3.2, 3.2))

	create_interactable("colchicine",
		Vector3(-0.8, 1.42, -0.2), mk_cyl(0.22, 0.88),
		Color(0.90, 0.45, 0.05, 0.0), Color(1.0, 0.65, 0.20), "点击取用秋水仙素溶液")
	interactables["colchicine"]["area"].get_child(0).visible = false
	for ch in interactables["colchicine"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			ch.font_size = 41
	# 画面正中央的场景说明：黄色加粗
	room_caption = add_label3d("25℃恒温光照培养室内景", Vector3(0.0, 3.62, -1.20), 40, Color(1.0, 0.90, 0.18))
	room_caption.font_px = 36
	room_caption.bold = true
	room_caption.outline_size = 7
	room_caption.outline_modulate = Color(0.28, 0.18, 0.0, 0.95)

	var lbl_colch := add_label3d("秋水仙素溶液", Vector3(-0.8, 1.98, -0.2), 36, Color(1.0, 0.55, 0.10))
	lbl_colch.font_px = 28

func _build_treatment_vessel() -> void:
	# 处理容器：真实烧杯 + 蓝紫溶液
	# 烧杯玻璃单独复制一份并压低不透明度（0.40 → 0.16），
	# 否则叠在蓝紫溶液外面会显得发白、看不清里面的东西
	var beaker_glass := MAT_JAR.duplicate() as StandardMaterial3D
	beaker_glass.albedo_color.a = 0.10
	PropKit.spawn(self, BEAKER_SCENE, Vector3(-2.0, 0.96, 0.3), Vector3.ZERO, {
		"beaker_body": beaker_glass,
	}, Vector3(5.4, 5.4, 5.4))
	var sol := MeshInstance3D.new()
	sol.mesh = mk_cyl(0.36, 0.40)
	var sol_mat := StandardMaterial3D.new()
	# 液面降到 1.36：株高约 0.5、从 1.0 起，这样植株上半截露出液面；
	# 溶液本身也压到 0.25，否则透过它完全看不到里面的苗
	sol_mat.albedo_color = Color(0.42, 0.48, 0.86, 0.25)
	sol_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sol_mat.roughness = 0.12
	sol.material_override = sol_mat
	sol.position = Vector3(-2.0, 1.16, 0.3)
	add_child(sol)

	create_interactable("treat_vessel",
		Vector3(-2.0, 1.50, 0.3), mk_cyl(0.58, 1.0),
		Color(0.80, 0.82, 0.88, 0.0), Color(0.90, 0.92, 1.0), "处理容器")
	interactables["treat_vessel"]["area"].get_child(0).visible = false
	var lbl_vessel := attach_label3d("treat_vessel", "处理容器", Vector3(0, 0.45, 0), 36, Color(0.80, 0.85, 1.0))
	lbl_vessel.font_px = 28

func _build_microscope() -> void:
	PropKit.spawn(self, MICRO_SCOPE, Vector3(1.55, 0.96, -0.35), Vector3(0.0, -14.0, 0.0), {
		"micro_base": MAT_MICRO,
		"micro_pillar": MAT_MICRO,
		"micro_arm": MAT_MICRO,
		"micro_tube": MAT_MICRO,
		"micro_stage": MAT_STEEL,
		"micro_stage_hole": MAT_MICRO_LENS,
		"micro_nosepiece": MAT_STEEL,
		"micro_objective": MAT_STEEL,
		"micro_eyepiece": MAT_STEEL,
		"micro_knob": MAT_STEEL,
	}, Vector3(4.4, 4.4, 4.4))

	create_interactable("micro_verify",
		Vector3(1.55, 1.6, -0.3), mk_box(Vector3(0.65, 0.95, 0.55)),
		Color(0.22, 0.22, 0.28, 0.0), Color(0.55, 0.55, 0.70), "验证显微镜（检查染色体）")
	interactables["micro_verify"]["area"].get_child(0).visible = false
	for ch in interactables["micro_verify"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			ch.font_size = 41
	# 单行黑字，压在浅色瓷砖墙上也看得清；白色描边让字形边缘更利落
	micro_static_lbl = add_label3d("光学显微镜（染色体倍性验证）", Vector3(1.55, 2.92, -0.3), 40, Color(0.05, 0.05, 0.05))
	micro_static_lbl.font_px = 30
	micro_static_lbl.outline_size = 7
	micro_static_lbl.outline_modulate = Color(1.0, 1.0, 1.0, 0.45)
	# 一开始就要能看到"这是什么仪器"，不再等处理完成后才出现
	micro_static_lbl.visible = true

## 红色悬停提示词统一排在各自固定标签的"下方"，避免压住物体本身。
## 基类默认放在"物体顶端 + 0.35"，这里按各物体的固定标签高度往下推。
func _tooltip_offset(obj_name: String) -> Vector3:
	match obj_name:
		"haploid_plant_obj": return Vector3(0.0, 0.14, 0.0)
		"colchicine": return Vector3(0.0, 0.12, 0.0)
		"treat_vessel": return Vector3(0.0, 0.12, 0.0)
		"micro_verify": return Vector3(0.0, 0.74, 0.0)
	return Vector3(0.0, -0.45, 0.0)

## 红色提示词要醒目：正红 + 大字 + 深色描边（基类默认是偏粉的 (1.0,0.55,0.55)）
func _style_tooltip(_obj_name: String, lbl: Label3D) -> void:
	lbl.font_size = 40
	lbl.modulate = Color(1.0, 0.14, 0.10)
	lbl.outline_size = 9
	lbl.outline_modulate = Color(0.12, 0.0, 0.0, 0.95)

## 单颗红辣椒：上粗下尖的锥形果身 + 圆头尖端 + 绿色花萼。
## 原来拿球体在 Y 方向拉伸 2.2 倍，看着像根塑料香肠，这里改成真正的果实轮廓。
func _mk_pepper() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.06, 0.04)
	mat.roughness = 0.30
	mat.metallic = 0.0
	mat.metallic_specular = 0.55

	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.050
	cm.bottom_radius = 0.013
	cm.height = 0.23
	cm.radial_segments = 18
	cm.rings = 6
	body.mesh = cm
	body.material_override = mat
	body.position = Vector3(0.0, -0.115, 0.0)
	root.add_child(body)

	var tip := MeshInstance3D.new()
	tip.mesh = mk_sphere(0.016)
	tip.material_override = mat
	tip.position = Vector3(0.0, -0.232, 0.0)
	root.add_child(tip)

	# 花萼：果实顶端的绿色小托盘
	var calyx := MeshInstance3D.new()
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.22, 0.44, 0.17)
	gmat.roughness = 0.65
	var gm := CylinderMesh.new()
	gm.top_radius = 0.028
	gm.bottom_radius = 0.042
	gm.height = 0.026
	gm.radial_segments = 12
	calyx.mesh = gm
	calyx.material_override = gmat
	calyx.position = Vector3(0.0, 0.008, 0.0)
	root.add_child(calyx)

	return root

## 花盆：陶土色锥形盆 + 营养土面，移栽后的幼苗就长在这里
func _build_flower_pot() -> void:
	var pot := Node3D.new()
	pot.position = Vector3(3.40, 0.96, 0.80)
	pot.name = "FlowerPot"
	add_child(pot)
	flower_pot = pot

	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.56, 0.29, 0.17)
	pm.roughness = 0.78
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.30
	cm.bottom_radius = 0.21
	cm.height = 0.30
	cm.radial_segments = 22
	body.mesh = cm
	body.material_override = pm
	body.position = Vector3(0.0, 0.15, 0.0)
	pot.add_child(body)

	var soil := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.275
	sm.bottom_radius = 0.275
	sm.height = 0.03
	sm.radial_segments = 22
	soil.mesh = sm
	var soilm := StandardMaterial3D.new()
	soilm.albedo_color = Color(0.17, 0.12, 0.08)
	soilm.roughness = 1.0
	soil.material_override = soilm
	soil.position = Vector3(0.0, 0.29, 0.0)
	pot.add_child(soil)

	create_interactable("flower_pot",
		Vector3(3.40, 1.12, 0.80),
		mk_box(Vector3(0.62, 0.38, 0.62)),
		Color(0, 0, 0, 0), Color(0.55, 0.85, 0.45), "花盆")
	interactables["flower_pot"]["area"].get_child(0).visible = false
	pot_label = attach_label3d("flower_pot", "移栽花盆\n（点击移栽幼苗）", Vector3(-0.30, 0.78, 0.0), 34, Color(0.85, 1.0, 0.80))
	pot_label.font_px = 32          # size 参数会被钳到 17px，放大走 font_px

## 移栽步骤：幼苗出现在花盆里（很小，还没长大）
func _show_seedling_in_pot() -> void:
	dh_plant.visible = true
	dh_plant.scale = Vector3.ONE * 0.08
	if dh_plant_lbl: dh_plant_lbl.visible = false
	if dh_peppers:
		dh_peppers.visible = false
		for p in dh_peppers.get_children():
			(p as Node3D).scale = Vector3.ZERO

## 光照培养步骤：幼苗慢慢长成成株（先不长果）
func _grow_dh_plant() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(dh_plant, "scale", Vector3.ONE, 3.6)

## 最后一步：辣椒一颗颗从枝条上“结”出来（各自从挂点长出来，不是整体飞起来）
func _show_fruits() -> void:
	if dh_plant_lbl: dh_plant_lbl.visible = true
	if dh_peppers == null:
		return
	dh_peppers.visible = true
	dh_peppers.scale = Vector3.ONE      # 容器本身不缩放，否则整串果实会一起向外飞
	var i := 0
	for p in dh_peppers.get_children():
		var pepper := p as Node3D
		if pepper == null:
			i += 1
			continue
		pepper.scale = Vector3.ZERO      # 从挂点（花萼）开始长出来
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.30 * float(i))
		tw.tween_property(pepper, "scale", Vector3.ONE, 0.9)
		i += 1

func _build_dh_plant() -> void:
	# DH 植株：直接用场景二那株整株辣椒模型（主干二歧分枝 + 叶片），
	# 再用几枚红辣椒果实点出"完全可育"；原来用圆柱+球体拼的假植株已经删掉
	dh_plant = Node3D.new()
	dh_plant.position = Vector3(3.40, 1.26, 0.80)   # 站在花盆的土面上
	dh_plant.visible = false
	dh_plant.name = "DHPlant"
	add_child(dh_plant)

	PropKit.spawn(dh_plant, PEPPER_SCENE, Vector3.ZERO, Vector3(0.0, 26.0, 0.0), {
		"pepper_plant_stem": MAT_STEM,
		"pepper_plant_br": MAT_STEM,
		"pepper_plant_leaf": MAT_LEAF,
	}, Vector3(1.25, 1.25, 1.25))

	# 挂着成熟的红辣椒：细长形，略微下垂
	var peppers := [
		[Vector3(0.30, 1.05, 0.10), Vector3(0.0, 0.0, 22.0)],
		[Vector3(-0.34, 1.22, -0.08), Vector3(0.0, 0.0, -26.0)],
		[Vector3(0.06, 1.34, 0.34), Vector3(14.0, 0.0, 0.0)],
		[Vector3(-0.14, 0.92, -0.30), Vector3(-12.0, 0.0, 8.0)],
	]
	# 果实单独放在一个容器里：植株先长大，果实最后才结出来
	dh_peppers = Node3D.new()
	dh_peppers.name = "DHPeppers"
	dh_plant.add_child(dh_peppers)
	for p in peppers:
		var pepper := _mk_pepper()
		pepper.position = p[0]
		pepper.rotation_degrees = p[1]
		dh_peppers.add_child(pepper)

	dh_plant_lbl = add_label3d("DH系植株\n(2n=24，完全可育)", Vector3(3.40, 3.30, 0.80), 30, Color(0.5, 1.0, 0.5))
	dh_plant_lbl.font_px = 28
	dh_plant_lbl.visible = false

func _build_chrom_overlay() -> void:
	chrom_overlay = Control.new()
	chrom_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrom_overlay.visible = false
	canvas_layer.add_child(chrom_overlay)

	var bg := ColorRect.new(); bg.color = Color(0.01, 0.03, 0.02, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrom_overlay.add_child(bg)

	# 主面板（矩形，非圆形）
	var panel := Panel.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -520; panel.offset_right = 520
	panel.offset_top = -368; panel.offset_bottom = 368
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.03, 0.09, 0.06, 0.96)
	ps.set_border_width_all(3); ps.border_color = Color(0.35, 0.65, 0.40)
	ps.shadow_color = Color(0, 0, 0, 0.55)
	ps.shadow_size = 18
	ps.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", ps)
	chrom_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20; vbox.offset_right = -20
	vbox.offset_top = 62; vbox.offset_bottom = -16
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# 标题
	var title := Label.new(); title.text = "🔬  显微镜视野 — 染色体数目验证"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.78, 1.0, 0.84))
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.10, 0.04, 0.95))
	vbox.add_child(title)

	var sep1 := HSeparator.new(); vbox.add_child(sep1)

	# 两列对比
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 22)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# ── 右列：处理后 2n=24 ──
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 6)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(rv)

	var n24 := Label.new(); n24.text = "2n = 24"
	n24.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n24.add_theme_font_size_override("font_size", 72)
	n24.add_theme_color_override("font_color", Color(0.38, 0.72, 1.0))
	rv.add_child(n24)

	var dl := Label.new(); dl.text = "（双单倍体 DH系）"
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.add_theme_font_size_override("font_size", 28)
	dl.add_theme_color_override("font_color", Color(0.62, 0.75, 0.95))
	rv.add_child(dl)

	# 24条染色体图示（每行6条，共4行）
	var c24 := Label.new()
	c24.text = "║ ║ ║ ║ ║ ║\n║ ║ ║ ║ ║ ║\n║ ║ ║ ║ ║ ║\n║ ║ ║ ║ ║ ║"
	c24.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c24.add_theme_font_size_override("font_size", 30)
	c24.add_theme_color_override("font_color", Color(0.38, 0.72, 1.0))
	# 染色体竖条太细：embolden 加字重 + 同色描边再加粗一圈
	var c24_fv := FontVariation.new()
	c24_fv.base_font = c24.get_theme_font("font")
	c24_fv.variation_embolden = 1.6
	c24.add_theme_font_override("font", c24_fv)
	c24.add_theme_constant_override("outline_size", 6)
	c24.add_theme_color_override("font_outline_color", Color(0.30, 0.62, 0.95))
	rv.add_child(c24)

	var sep2 := HSeparator.new(); vbox.add_child(sep2)

	var close_btn := Button.new(); close_btn.text = "✓  已确认，继续"
	close_btn.custom_minimum_size = Vector2(240, 56)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(close_btn, Color(0.10, 0.28, 0.12))
	close_btn.add_theme_font_size_override("font_size", 30)
	close_btn.pressed.connect(func():
		chrom_overlay.visible = false
		advance_step()   # 先进"光照培养"这步，植株长大放到再下一步
	)
	vbox.add_child(close_btn)


func _build_treatment_panel() -> void:
	var tp := Panel.new()
	tp.anchor_right = 1.0
	tp.offset_left = -280; tp.offset_right = -10
	tp.offset_top = 70; tp.offset_bottom = 180
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.04, 0.10, 0.95)
	ps.set_border_width_all(1); ps.border_color = Color(0.45, 0.22, 0.72)
	ps.set_corner_radius_all(8)
	tp.add_theme_stylebox_override("panel", ps)
	canvas_layer.add_child(tp)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 12; vb.offset_right = -12
	vb.offset_top = 8; vb.offset_bottom = -8
	tp.add_child(vb)

	var h := Label.new(); h.text = "🧬  秋水仙素处理状态"
	h.add_theme_font_size_override("font_size", 16)
	h.add_theme_color_override("font_color", Color(0.75, 0.52, 1.0))
	vb.add_child(h)

	treatment_progress_lbl = Label.new(); treatment_progress_lbl.text = "等待操作..."
	treatment_progress_lbl.add_theme_font_size_override("font_size", 15)
	treatment_progress_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.90))
	vb.add_child(treatment_progress_lbl)

func _define_steps() -> void:
	steps = [
		{
			"title": "📖  染色体加倍——秋水仙素处理",
			"body": "单倍体植株（n=12）性状纯合但高度不育，须用【秋水仙素】使染色体加倍（12→24），才能得到可育、稳定的纯合二倍体（DH 系）。\n"
				+ "秋水仙素实现染色体数目加倍的原理：抑制纺锤体形成 → 染色体不能移向两极 → 细胞染色体数加倍。",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "① 取单倍体植株放入处理容器",
			"body": "点击左侧【单倍体植株】，放入中央处理容器。",
			"click_to_advance": false,
			"active_objects": ["haploid_plant_obj"],
			"correct_object": "haploid_plant_obj",
			"correct_message": "单倍体植株已放入处理容器"
		},
		{
			"title": "② 加入秋水仙素溶液",
			"body": "点击秋水仙素瓶，加入适量溶液（0.05–0.20%），浸泡 12–24 小时。",
			"click_to_advance": false,
			"active_objects": ["colchicine"],
			"correct_object": "colchicine",
			"correct_message": "秋水仙素已加入，开始处理"
		},
		{
			"title": "③ 等待染色体加倍处理",
			"body": "秋水仙素抑制纺锤体形成，染色体留在同一细胞内完成加倍。",
			"click_to_advance": false,
			"active_objects": []
		},
		{
			"title": "④ 显微镜验证染色体已加倍",
			"body": "处理完成。点击右侧【验证显微镜】，确认茎尖细胞染色体数由 12 变为 24。",
			"click_to_advance": false,
			"active_objects": ["micro_verify"],
			"correct_object": "micro_verify",
			"correct_message": "验证完成！染色体已成功加倍"
		},
		{
			"title": "⑤ 移栽到花盆",
			"body": "把幼苗移入装有营养土的花盆：保留根系、栽于盆中央、覆土轻压、浇透定根水，置于 25 ℃ 光照下。\n"
				+ "点击右侧【移栽花盆】。",
			"click_to_advance": false,
			"active_objects": ["flower_pot"],
			"correct_object": "flower_pot",
			"correct_message": "幼苗已移栽到花盆中"
		},
		{
			"title": "⑥ 光照培养",
			"body": "恒温光照培养：25 ℃，光照 16 h／黑暗 8 h，光强 2000–3000 lx。\n"
				+ "湿度 60%–70%，植株逐渐长成成熟的 DH 系植株。",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "⑦ DH系植株育成！",
			"body": "🎉  祝贺！\n"
				+ "★单倍体植株经秋水仙素处理后，染色体数目成功加倍（n=12 → 2n=24），获得了纯合二倍体植株（DH系植株）！\n"
				+ "★DH系植株特点：完全纯合、正常可育、可结出种子、性状可稳定遗传。\n"
				+ "★DH系植株经过后期植株表型鉴定筛选和扩大化培养后可以获得大量辣椒目标优良纯合子植株，大大缩短了获取优良纯合子植株所需的育种年限！",
			"click_to_advance": true,
			"active_objects": [],
			"completion_text": "🏆  单倍体育种全流程完成！\n你已成功完成辣椒单倍体育种流程的全部7个实验步骤：\n配制培养基 → 花药选取 → 消毒接种 → 愈伤诱导 → 生芽生根 → 倍性鉴定 → 染色体加倍\n最终获得的DH系植株完全纯合、性状稳定，可直接作为育种材料或亲本材料使用。\n与传统杂交育种相比，单倍体育种可将育种年限从7–8年缩短至2–3年！"
		},
	]

var _plant_in_vessel: bool = false
var _colchicine_added: bool = false
var _treatment_time: float = 0.0

func _on_interactable_clicked(obj_name: String) -> void:
	match current_step_index:
		1:
			if obj_name == "haploid_plant_obj":
				flash_message("单倍体植株已放入处理容器", true)
				_plant_in_vessel = true
				_animate_plant_to_vessel()
				await get_tree().create_timer(0.8).timeout
				advance_step()
		2:
			if obj_name == "colchicine":
				flash_message("秋水仙素溶液已加入，开始染色体加倍处理", true)
				_colchicine_added = true
				_animate_colchicine()
				await get_tree().create_timer(2.8).timeout  # 等待动画完成
				advance_step()
				# 开始处理计时
				_start_treatment()
		4:
			if obj_name == "micro_verify":
				_show_verification_microscope()
		5:
			if obj_name == "flower_pot":
				flash_message("幼苗已移栽到花盆中，持续光照培养", true)
				_show_seedling_in_pot()
				await get_tree().create_timer(1.0).timeout
				advance_step()
		_: pass

func _animate_plant_to_vessel() -> void:
	var tw := create_tween()
	tw.tween_property(haploid_plant, "position",
		Vector3(-2.0, 1.0, 0.5), 0.8).set_trans(Tween.TRANS_QUAD)

func _animate_colchicine() -> void:
	if not colchicine_bottle_visual:
		return

	var original_pos := colchicine_bottle_visual.position
	var original_rot := colchicine_bottle_visual.rotation
	var tw := create_tween()
	# 靠近处理容器的同时就开始倾斜（parallel），比"先平移再歪一下"自然
	tw.tween_property(colchicine_bottle_visual, "position", Vector3(-1.8, 1.62, 0.0), 0.6) \
		.set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(colchicine_bottle_visual, "rotation",
		Vector3(0.0, 0.0, 1.25), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)   # 保持瓶口朝下的倾倒姿态
	# 回正 + 返回原位，这两步也并行
	tw.tween_property(colchicine_bottle_visual, "rotation", original_rot, 0.35) \
		.set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(colchicine_bottle_visual, "position", original_pos, 0.6) \
		.set_trans(Tween.TRANS_QUAD)

	# 液体要等瓶身真的倾斜了才开始流，否则会出现"瓶还没歪液体就掉"的穿帮
	await get_tree().create_timer(0.55).timeout
	_create_liquid_drops()

func _create_liquid_drops() -> void:
	# 液面位置固定；瓶口位置按当前姿态实时计算，细流才能真正接到瓶口上
	const SURFACE := Vector3(-2.00, 1.37, 0.30)
	var mouth: Vector3 = colchicine_bottle_visual.global_position \
		+ colchicine_bottle_visual.global_basis * Vector3(0.0, 0.30, 0.0)

	# 细流：从瓶口到液面的一根细圆柱，按两点方向摆放
	var dir := SURFACE - mouth
	var seg_len: float = maxf(dir.length(), 0.05)
	var stream := MeshInstance3D.new()
	stream.mesh = mk_cyl(0.018, seg_len)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.58, 0.65, 0.90, 0.5)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.roughness = 0.05
	stream.material_override = sm
	stream.position = (mouth + SURFACE) * 0.5
	var axis := Vector3.UP.cross(dir.normalized())
	if axis.length() > 0.001:
		stream.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir.normalized()))
	add_child(stream)

	for i in 7:
		await get_tree().create_timer(0.09).timeout
		var drop := MeshInstance3D.new()
		drop.mesh = mk_sphere(0.032)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.58, 0.65, 0.90, 0.85)  # 蓝紫色半透明
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.05
		drop.material_override = mat
		drop.position = mouth
		drop.scale = Vector3(0.7, 1.7, 0.7)   # 拉长成水滴形状
		add_child(drop)

		# 自由落体：EASE_IN 让末段加速，落到液面就消失
		var tw := create_tween()
		tw.tween_property(drop, "position", SURFACE, 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(drop.queue_free)
		_splash(SURFACE)

	await get_tree().create_timer(0.5).timeout
	stream.queue_free()

## 液滴落点的一圈小涟漪：扁圆柱快速放大并淡出
func _splash(pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = mk_cyl(0.05, 0.012)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.80, 1.0, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.position = pos
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(2.4, 1.0, 2.4), 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "material_override:albedo_color:a", 0.0, 0.30)
	tw.tween_callback(ring.queue_free)


func _start_treatment() -> void:
	growing = true

var _shown_verification: bool = false

func _show_verification_microscope() -> void:
	_shown_verification = true
	chrom_overlay.visible = true
	# 系统提示词已删（原来这里会弹"染色体已从 12 条加倍为 24 条"），
	# 面板本身已经用 2n=24 的图示说明结果；推进仍由"已确认，继续"按钮负责

## 走到「⑥ DH系植株育成」这一步，植株才长大出现（原来是关掉镜检面板就冒出来）
## 提示条默认落在画面正中，会压住台面上的显微镜/烧杯/植株。
## 场景七统一往下挪到对话框上方，只占 HUD 区域。
func flash_message(msg: String, good: bool = true, dur: float = 2.2,
		font_size: int = 20, custom_color: Color = Color(-1, -1, -1),
		half_w: int = 220, half_h: int = 40, show_prefix: bool = true,
		offset_x: float = 0.0, offset_y: float = 196.0) -> void:
	# 红框绿框统一放大到 32 号，底部高度也同步加高
	super.flash_message(msg, good, dur, maxi(font_size, 32), custom_color,
		half_w, maxi(half_h, 48), show_prefix, offset_x, offset_y)

func _show_step(idx: int) -> void:
	super._show_step(idx)
	# 移栽完成之后，花盆上那句“点击移栽幼苗”就不该再挡在植株上了
	if idx >= 6 and pot_label:
		pot_label.visible = false
	if idx == 6:
		_grow_dh_plant()      # ⑥ 光照培养：花盆里的幼苗慢慢长成成株
	elif idx == 7:
		_show_fruits()        # ⑦ 育成：结出辣椒 + 挂上标签

func _show_dh_plant() -> void:
	# 幼苗状态的 DH 植株：先长成成株，长成之后再挂果
	dh_plant.visible = true
	dh_plant.scale = Vector3.ONE * 0.06
	if dh_plant_lbl: dh_plant_lbl.visible = false
	if dh_peppers:
		dh_peppers.visible = true
		dh_peppers.scale = Vector3.ONE * 0.04

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(dh_plant, "scale", Vector3.ONE, 3.2)
	tw.tween_callback(func():
		if dh_plant_lbl: dh_plant_lbl.visible = true)

	# 果实比枝叶晚一步：等植株定型后再从小长大
	if dh_peppers:
		var tw2 := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_interval(2.8)
		tw2.tween_property(dh_peppers, "scale", Vector3.ONE, 1.4)

func _process(delta: float) -> void:
	if not growing: return
	_treatment_time += delta * 12.0  # 加速
	treatment_progress_lbl.text = "处理进度：%.0f%%" % min(_treatment_time * 4, 100)
	if _treatment_time >= 25.0:
		growing = false
		treatment_progress_lbl.text = "处理完成 ✓  染色体已加倍"
		flash_message("秋水仙素处理完成！", true, 2.2, 30, Color(1.0, 0.55, 0.10))
		await get_tree().create_timer(1.5).timeout
		if micro_static_lbl: micro_static_lbl.visible = true
		advance_step()
		_refresh_highlights(["micro_verify"])