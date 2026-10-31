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

func _ready() -> void:
	scene_number = 6
	scene_title  = "倍性鉴定"
	# 随机化（保证至少1株单倍体）
	plant_chromosomes[randi() % 4] = HAPLOID_N
	plant_chromosomes[(randi() % 3 + 1 + plant_chromosomes.find(HAPLOID_N)) % 4] = DIPLOID_2N
	super._ready()

func _configure_camera() -> void:
	camera.position = Vector3(0.0, 3.5, 8.5) * 1.1
	camera.look_at(Vector3(0.0, 1.2, 0.0))
	camera.fov = 50.0

func _setup_scene() -> void:
	_build_lab()
	_build_microscope()
	_build_plants()
	_build_microscope_overlay()

func _build_lab() -> void:
	add_static(mk_plane(Vector2(22, 22)), Vector3.ZERO, Color(0.82, 0.86, 0.84))
	add_static(mk_box(Vector3(14, 4, 0.2)), Vector3(0, 2, -4), Color(0.90, 0.90, 0.88))
	add_static(mk_box(Vector3(10, 0.16, 3.5)), Vector3(0, 0.90, -0.5), Color(0.88, 0.90, 0.86))

func _build_microscope() -> void:
	# 显微镜底座
	add_static(mk_box(Vector3(0.8, 0.12, 0.6)), Vector3(0, 0.98, -0.5), Color(0.25, 0.25, 0.30))
	# 镜臂
	add_static(mk_cyl(0.06, 1.0), Vector3(-0.15, 1.5, -0.5), Color(0.28, 0.28, 0.32))
	# 镜头
	add_static(mk_cyl(0.12, 0.3), Vector3(0, 2.18, -0.5), Color(0.22, 0.22, 0.26))
	add_static(mk_cyl(0.05, 0.45), Vector3(0, 2.0, -0.5), Color(0.20, 0.20, 0.24))
	# 目镜
	add_static(mk_cyl(0.07, 0.20), Vector3(-0.15, 2.42, -0.5), Color(0.30, 0.30, 0.35))
	# 载物台
	add_static(mk_box(Vector3(0.6, 0.06, 0.5)), Vector3(0, 1.55, -0.5), Color(0.35, 0.35, 0.38))

	create_interactable("microscope",
		Vector3(0.0, 1.7, -0.5), mk_box(Vector3(0.7, 1.0, 0.6)),
		Color(0.28, 0.28, 0.32, 0.0), Color(0.55, 0.55, 0.68), "显微镜（点击观察）")
	interactables["microscope"]["area"].get_child(0).visible = false
	var micro_lbl := add_label3d("显微镜\n（点击观察）", Vector3(0.0, 3.30, -0.5), 66, Color(0.75, 0.30, 1.0))
	micro_lbl.outline_size = 8
	micro_lbl.outline_modulate = Color(0.2, 0.0, 0.3, 0.8)

func _build_plants() -> void:
	# 4株小植物（来自花药培养）
	var names := ["A株", "B株", "C株", "D株"]
	for i in 4:
		var x := -4.5 + i * 3.0
		var name := "plant_%d" % i
		_draw_small_plant(Vector3(x, 1.0, 1.2), i)
		create_interactable(name,
			Vector3(x, 1.5, 1.2), mk_cyl(0.35, 1.0),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.85, 0.95, 0.55), "点击查看 %s 染色体" % names[i])
		interactables[name]["area"].get_child(0).visible = false
		var plant_lbl := add_label3d(names[i], Vector3(x, 2.6, 1.2), 56, Color(0.25, 0.95, 0.35))
		plant_lbl.outline_size = 8
		plant_lbl.outline_modulate = Color(0.0, 0.2, 0.0, 0.8)

func _draw_small_plant(pos: Vector3, idx: int) -> void:
	add_static(mk_cyl(0.06, 1.2), pos + Vector3(0, 0.6, 0), Color(0.22, 0.55, 0.22))
	for j in 5:
		var a := j * TAU / 5
		add_static(mk_sphere(0.12), pos + Vector3(sin(a)*0.25, 0.5 + j*0.2, cos(a)*0.25),
			Color(0.20, 0.55, 0.25))
	# 花（白色/浅色）
	var has_flower: bool = (plant_chromosomes[idx] == HAPLOID_N)
	# 根系小示意
	add_static(mk_cyl(0.03, 0.30), pos + Vector3(0.12, 0.08, 0), Color(0.78, 0.72, 0.58))
	add_static(mk_cyl(0.03, 0.30), pos + Vector3(-0.08, 0.06, 0.1), Color(0.78, 0.72, 0.58))

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
	chrom_display.add_theme_font_size_override("font_size", 26)
	chrom_display.add_theme_color_override("font_color", Color(0.6, 0.9, 0.65))
	view_panel.add_child(chrom_display)

	chrom_count_lbl = Label.new()
	chrom_count_lbl.anchor_left = 0.5; chrom_count_lbl.anchor_right = 0.5
	chrom_count_lbl.anchor_top = 0.5; chrom_count_lbl.anchor_bottom = 0.5
	chrom_count_lbl.offset_left = -260; chrom_count_lbl.offset_right = 260
	chrom_count_lbl.offset_top = 220; chrom_count_lbl.offset_bottom = 268
	chrom_count_lbl.text = ""
	chrom_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chrom_count_lbl.add_theme_font_size_override("font_size", 24)
	chrom_count_lbl.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	micro_overlay.add_child(chrom_count_lbl)

	var close_btn := Button.new()
	close_btn.text = "✖  关闭显微镜视野"
	close_btn.anchor_left = 0.5; close_btn.anchor_right = 0.5
	close_btn.anchor_top = 0.5; close_btn.anchor_bottom = 0.5
	close_btn.offset_left = -150; close_btn.offset_right = 150
	close_btn.offset_top = 272; close_btn.offset_bottom = 318
	_style_button(close_btn, Color(0.22, 0.10, 0.06))
	close_btn.add_theme_font_size_override("font_size", 22)
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
	mark_btn.add_theme_font_size_override("font_size", 22)
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
