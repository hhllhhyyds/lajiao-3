## Scene5.gd — 倍性鉴定
## 通过显微镜观察染色体数目，筛选真正的单倍体植株
extends SceneBase

# 辣椒的染色体数：单倍体 n=12，二倍体 2n=24
const HAPLOID_N := 12
const DIPLOID_2N := 24

# 4株植株的染色体数（随机，其中1-2株是单倍体）
var plant_chromosomes: Array[int] = [12, 24, 12, 36]
var selected_plants: Array[bool] = [false, false, false, false]
var plant_confirmed: bool = false

var microscope_active: bool = false
var current_viewed_plant: int = -1

# UI
var micro_overlay: Control
var chrom_display: Label
var chrom_count_lbl: Label
var confirm_btn: Button
var plant_status_labels: Array[Label] = []
var plant_select_btns: Array[Button] = []

const MICRO_SCOPE := preload("res://assets/props/microscope.glb")
const PLANTLET_SCENE := preload("res://assets/props/plantlet.glb")
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
const RACK_SCENE := preload("res://assets/props/tube_rack.glb")
const REAGENT_SCENE := preload("res://assets/props/reagent_bottle.glb")
const DISH_SCENE := preload("res://assets/props/petri_dish.glb")

func _ready() -> void:
	scene_number = 6
	scene_title  = "倍性鉴定"
	env_preset = "indoor"
	light_focus = Vector3(0.0, 1.5, -0.2)
	light_radius = 4.0
	light_intensity = 0.55
	# 随机化（保证至少1株单倍体）
	plant_chromosomes[randi() % 4] = HAPLOID_N
	plant_chromosomes[(randi() % 3 + 1 + plant_chromosomes.find(HAPLOID_N)) % 4] = DIPLOID_2N
	super._ready()

func _configure_camera() -> void:
	camera.position = Vector3(0.0, 2.45, 6.60)
	camera.look_at(Vector3(0.0, 1.28, 0.05))
	camera.fov = 55.0

func _setup_scene() -> void:
	_build_lab()
	_build_microscope()
	_build_plants()
	_build_microscope_overlay()

func _build_lab() -> void:
	var floor_mi := add_static(mk_plane(Vector2(22, 22)), Vector3.ZERO, Color.WHITE)
	floor_mi.material_override = MAT_FLOOR
	var wall := add_static(mk_box(Vector3(14, 4, 0.2)), Vector3(0, 2, -4), Color.WHITE)
	wall.material_override = _tiled(14.0, 4.0)

	# 台面（深色环氧）+ 不锈钢腿
	var top := add_static(mk_box(Vector3(8.4, 0.10, 3.0)), Vector3(0, 0.92, -0.4), Color.WHITE)
	top.material_override = MAT_BENCH
	for xo in [-3.9, 3.9]:
		for zo in [-1.7, 1.0]:
			var leg := add_static(mk_box(Vector3(0.09, 0.87, 0.09)), Vector3(xo, 0.435, zo), Color.WHITE)
			leg.material_override = MAT_STEEL

	_dress_bench()


## box 墙面的 UV 是 0..1，直接套世界坐标 UV 的材质会把瓷砖拉成两米一块。
## 世界 UV 下 1 单位 = 1 m，材质用 2.5 次重复；换算到 box 面就是 宽/高 × 2.5。
func _tiled(w: float, h: float) -> StandardMaterial3D:
	var m := MAT_TILE.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(w * 2.5, h * 2.5, 1.0)
	return m

## 台面补器材：现在只有显微镜和四个瓶子，中景空
func _dress_bench() -> void:
	for x in [-2.2, 2.2]:
		PropKit.spawn(self, RACK_SCENE, Vector3(x, 0.97, -1.30), Vector3(0, -10.0, 0), {},
			Vector3(3.4, 3.4, 3.4))
	for i in 4:
		var x := -1.5 + i * 1.0
		PropKit.spawn(self, REAGENT_SCENE, Vector3(x, 0.97, -1.45), Vector3.ZERO, {},
			Vector3(2.4 + float(i % 2) * 0.4, 2.4 + float(i % 2) * 0.4, 2.4 + float(i % 2) * 0.4))
	for i in 2:
		PropKit.spawn(self, DISH_SCENE, Vector3(-2.9, 0.97 + i * 0.018, -0.55), Vector3.ZERO, {},
			Vector3(4.0, 4.0, 4.0))

func _build_microscope() -> void:
	# 真实显微镜模型，放大到与场景比例匹配
	PropKit.spawn(self, MICRO_SCOPE, Vector3(0.0, 0.97, -0.55), Vector3(0.0, 12.0, 0.0), {
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
	}, Vector3(4.6, 4.6, 4.6))

	create_interactable("microscope",
		Vector3(0.0, 1.45, -0.55), mk_box(Vector3(0.9, 1.4, 0.8)),
		Color(0.28, 0.28, 0.32, 0.0), Color(0.55, 0.55, 0.68), "显微镜（点击观察）")
	interactables["microscope"]["area"].get_child(0).visible = false
	var micro_lbl := add_label3d("显微镜\n（点击观察）", Vector3(0.0, 2.55, -0.55), 62, Color(0.75, 0.30, 1.0))
	micro_lbl.outline_size = 8
	micro_lbl.outline_modulate = Color(0.2, 0.0, 0.3, 0.8)

func _build_plants() -> void:
	# 四株来自花药培养的组培苗，各带一个培养瓶
	var names := ["A株", "B株", "C株", "D株"]
	for i in 4:
		var x := -3.3 + i * 2.2
		var name := "plant_%d" % i
		_draw_small_plant(Vector3(x, 0.97, 1.0), i)
		create_interactable(name,
			Vector3(x, 1.45, 1.0), mk_cyl(0.40, 1.1),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.85, 0.95, 0.55), "点击查看 %s 染色体" % names[i])
		interactables[name]["area"].get_child(0).visible = false
		var plant_lbl := add_label3d(names[i], Vector3(x, 2.28, 1.0), 52, Color(0.25, 0.95, 0.35))
		plant_lbl.outline_size = 8
		plant_lbl.outline_modulate = Color(0.0, 0.2, 0.0, 0.8)

func _draw_small_plant(pos: Vector3, idx: int) -> void:
	# 培养瓶 + 组培苗
	var jar := add_static(mk_cyl(0.30, 0.62), pos + Vector3(0, 0.31, 0), Color.WHITE)
	jar.material_override = MAT_JAR
	var agar := add_static(mk_cyl(0.27, 0.10), pos + Vector3(0, 0.08, 0), Color(0.70, 0.82, 0.66))
	agar.material_override = MAT_AGAR

	var plantlet := PropKit.spawn(self, PLANTLET_SCENE, pos + Vector3(0.0, 0.14, 0.0),
		Vector3(0.0, float(idx) * 37.0, 0.0), {
		"plantlet_leaf": MAT_LEAF,
		"plantlet_stem": MAT_STEM,
		"plantlet_root": MAT_LEAF,
	}, Vector3(9.0, 9.0, 9.0))
	plantlet.name = "plantlet_%d" % idx
	for node in plantlet.find_children("plantlet_root*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visible = false

func _build_microscope_overlay() -> void:
	micro_overlay = Control.new()
	micro_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	micro_overlay.visible = false
	canvas_layer.add_child(micro_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	micro_overlay.add_child(bg)

	# 圆形显微镜视野
	var view_panel := Panel.new()
	view_panel.anchor_left = 0.5; view_panel.anchor_right = 0.5
	view_panel.anchor_top = 0.5; view_panel.anchor_bottom = 0.5
	view_panel.offset_left = -280; view_panel.offset_right = 280
	view_panel.offset_top = -240; view_panel.offset_bottom = 240
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.0, 0.05, 0.0)
	ps.set_border_width_all(6); ps.border_color = Color(0.3, 0.3, 0.35)
	ps.set_corner_radius_all(280)
	view_panel.add_theme_stylebox_override("panel", ps)
	micro_overlay.add_child(view_panel)

	# 染色体绘制区（用Label3D无法用，直接Label）
	chrom_display = Label.new()
	chrom_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrom_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chrom_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chrom_display.add_theme_font_size_override("font_size", 29)
	chrom_display.add_theme_color_override("font_color", Color(0.6, 0.9, 0.65))
	view_panel.add_child(chrom_display)

	chrom_count_lbl = Label.new()
	chrom_count_lbl.anchor_left = 0.5; chrom_count_lbl.anchor_right = 0.5
	chrom_count_lbl.anchor_top = 0.5; chrom_count_lbl.anchor_bottom = 0.5
	chrom_count_lbl.offset_left = -260; chrom_count_lbl.offset_right = 260
	chrom_count_lbl.offset_top = 220; chrom_count_lbl.offset_bottom = 268
	chrom_count_lbl.text = ""
	chrom_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chrom_count_lbl.add_theme_font_size_override("font_size", 26)
	chrom_count_lbl.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	micro_overlay.add_child(chrom_count_lbl)

	var close_btn := Button.new()
	close_btn.text = "✖  关闭显微镜视野"
	close_btn.anchor_left = 0.5; close_btn.anchor_right = 0.5
	close_btn.anchor_top = 0.5; close_btn.anchor_bottom = 0.5
	close_btn.offset_left = -150; close_btn.offset_right = 150
	close_btn.offset_top = 272; close_btn.offset_bottom = 318
	_style_button(close_btn, Color(0.22, 0.10, 0.06))
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(_close_microscope)
	micro_overlay.add_child(close_btn)

	# 标记为单倍体按钮
	var mark_btn := Button.new()
	mark_btn.text = "✓  标记为单倍体（染色体数 = n）"
	mark_btn.anchor_left = 0.5; mark_btn.anchor_right = 0.5
	mark_btn.anchor_top = 0.5; mark_btn.anchor_bottom = 0.5
	mark_btn.offset_left = -230; mark_btn.offset_right = 230
	mark_btn.offset_top = 324; mark_btn.offset_bottom = 372
	_style_button(mark_btn, Color(0.10, 0.38, 0.16))
	mark_btn.add_theme_font_size_override("font_size", 24)
	mark_btn.pressed.connect(_mark_current_as_haploid)
	micro_overlay.add_child(mark_btn)

func _define_steps() -> void:
	steps = [
		{
			"title": "📖  倍性鉴定——筛选真正的单倍体",
			"body": "花药中含有多种细胞：\n"
				+ "• 小孢子（花粉细胞）染色体组成为：n = 12\n"
				+ "• 花药壁细胞染色体组成为：2n = 24\n"
				+ "• 药隔细胞染色体组成为：2n = 24\n"
				+ "•花药中某些细胞也可能形成染色体多倍体性的愈伤组织。\n•因此必须通过【光学显微镜下染色体计数】等方法鉴定、筛选出真正的单倍体辣椒植株。",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "① 激活显微镜",
			"body": "点击实验台上的显微镜，激活观察模式。\n"
				+ "然后依次点击各株植物，观察其根尖细胞的染色体数目。",
			"click_to_advance": false,
			"active_objects": ["microscope"],
			"correct_object": "microscope",
			"correct_message": "显微镜已激活！"
		},
		{
			"title": "② 观察各植株染色体，标记单倍体",
			"body": "点击每株植物，在显微镜中观察其染色体数目。\n"
				+ "辣椒单倍体染色体数 = 12（n）；二倍体 = 24（2n）\n"
				+ "找到并点击【标记为单倍体】按钮，标记所有单倍体植株。\n"
				+ "观察并标记完所有4株植物后，点击确认完成鉴定。",
			"click_to_advance": false,
			"active_objects": ["plant_0", "plant_1", "plant_2", "plant_3"]
		},
		{
			"title": "③ 确认鉴定结果",
			"body": "请确认你已正确标记了单倍体植株。",
			"click_to_advance": true,
			"active_objects": [],
			"completion_text": "辣椒幼苗染色体倍性鉴定完成！\n通过光学显微镜染色体计数，成功筛选出了单倍体辣椒植株（n = 12）。\n※实际操作中还可用流式细胞仪、SSR分子标记等更快速的方法进行大规模单倍体植株鉴定工作。\n※下一步：用秋水仙素处理，使单倍体辣椒幼苗染色体数目加倍，获得纯合二倍体植株（DH系植株）。"
		},
	]

func _on_interactable_clicked(obj_name: String) -> void:
	match current_step_index:
		1:
			if obj_name == "microscope":
				flash_message("显微镜已激活！", true)
				microscope_active = true
				await get_tree().create_timer(0.6).timeout
				advance_step()
				_refresh_highlights(["plant_0", "plant_1", "plant_2", "plant_3"])
		2:
			if obj_name.begins_with("plant_"):
				var idx := int(obj_name.split("_")[1])
				current_viewed_plant = idx
				_open_microscope(idx)
		_: pass

func _open_microscope(plant_idx: int) -> void:
	var n := plant_chromosomes[plant_idx]
	micro_overlay.visible = true
	var plant_names := ["A株", "B株", "C株", "D株"]
	chrom_count_lbl.text = "正在观察 %s  | 染色体数：%d" % [plant_names[plant_idx], n]
	# 绘制染色体（文字模拟）
	var disp := ""
	var cols := 6
	for i in n:
		disp += "║ "
		if (i + 1) % cols == 0:
			disp += "\n"
	chrom_display.text = disp

func _close_microscope() -> void:
	micro_overlay.visible = false
	current_viewed_plant = -1

func _mark_current_as_haploid() -> void:
	if current_viewed_plant < 0: return
	var n := plant_chromosomes[current_viewed_plant]
	var plant_names := ["A株", "B株", "C株", "D株"]
	if n == HAPLOID_N:
		selected_plants[current_viewed_plant] = true
		flash_message("%s 是单倍体（n=12），已标记！" % plant_names[current_viewed_plant], true)
	else:
		flash_message("%s 不是单倍体（染色体数=%d，非12）" % [plant_names[current_viewed_plant], n], false)
	_close_microscope()

	# 检查是否可进入下一步
	var all_viewed := true
	# 不强制全部观察，只要标记操作后检查标记数
	var marked := selected_plants.filter(func(b): return b).size()
	if marked >= 1 and current_step_index == 2:
		flash_message("已标记 %d 株单倍体植株，可进入确认步骤" % marked, true)
		await get_tree().create_timer(1.0).timeout
		advance_step()
		_refresh_highlights([])
