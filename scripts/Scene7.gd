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
var colchicine_bottle_visual: Node3D  # 可见的秋水仙素瓶
var growth_timer: float = 0.0
var growing: bool = false

# UI
var treatment_progress_lbl: Label
var chrom_overlay: Control
var micro_static_lbl: LabelProjector.TagLabel  # 显微镜标签（处理完成后才显示）

const MICRO_SCOPE := preload("res://assets/props/microscope.glb")
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
	_build_dh_plant()
	_build_chrom_overlay()
	_build_treatment_panel()

func _build_lab() -> void:
	var floor_mi := add_static(mk_plane(Vector2(22, 22)), Vector3.ZERO, Color.WHITE)
	floor_mi.material_override = MAT_FLOOR
	var wall := add_static(mk_box(Vector3(14, 4.5, 0.2)), Vector3(0, 2.25, -4), Color.WHITE)
	wall.material_override = MAT_TILE
	var top := add_static(mk_box(Vector3(10.0, 0.12, 3.4)), Vector3(0, 0.90, -0.4), Color.WHITE)
	top.material_override = MAT_BENCH

func _build_haploid_plant() -> void:
	haploid_plant = Node3D.new()
	haploid_plant.position = Vector3(-3.5, 1.0, 0.5)
	haploid_plant.name = "HaploidPlant"
	add_child(haploid_plant)

	PropKit.spawn(haploid_plant, PLANTLET_SCENE, Vector3.ZERO, Vector3.ZERO, {
		"plantlet_leaf": MAT_LEAF,
		"plantlet_stem": MAT_STEM,
		"plantlet_root": MAT_LEAF,
	}, Vector3(11.0, 11.0, 11.0))
	# 无果实（单倍体高度不育）

	create_interactable("haploid_plant_obj",
		Vector3(-3.5, 1.75, 0.5), mk_cyl(0.45, 1.6),
		Color(0.0, 0.0, 0.0, 0.0), Color(0.65, 1.0, 0.65), "单倍体植株（高度不育）")
	interactables["haploid_plant_obj"]["area"].get_child(0).visible = false
	var lbl_haploid := attach_label3d("haploid_plant_obj", "单倍体植株\n(n=12，高度不育)", Vector3(0, 1.25, 0), 36, Color(0.25, 0.95, 0.35))
	if lbl_haploid: lbl_haploid.outline_size = 8; lbl_haploid.outline_modulate = Color(0.0, 0.2, 0.0, 0.8)

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
		Color(0.90, 0.45, 0.05, 0.0), Color(1.0, 0.65, 0.20), "秋水仙素溶液")
	interactables["colchicine"]["area"].get_child(0).visible = false
	for ch in interactables["colchicine"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			ch.font_size = 38
			ch.position = Vector3(0.0, -0.80, 0.0)
	add_label3d("秋水仙素", Vector3(-0.8, 2.18, -0.2), 36, Color(1.0, 0.55, 0.10))

func _build_treatment_vessel() -> void:
	# 处理容器：真实烧杯 + 蓝紫溶液
	PropKit.spawn(self, BEAKER_SCENE, Vector3(-2.0, 0.96, 0.3), Vector3.ZERO, {
		"beaker_body": MAT_JAR,
	}, Vector3(5.4, 5.4, 5.4))
	var sol := MeshInstance3D.new()
	sol.mesh = mk_cyl(0.36, 0.56)
	var sol_mat := StandardMaterial3D.new()
	sol_mat.albedo_color = Color(0.42, 0.48, 0.86, 0.72)
	sol_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sol_mat.roughness = 0.18
	sol.material_override = sol_mat
	sol.position = Vector3(-2.0, 1.24, 0.3)
	add_child(sol)

	create_interactable("treat_vessel",
		Vector3(-2.0, 1.50, 0.3), mk_cyl(0.58, 1.0),
		Color(0.80, 0.82, 0.88, 0.0), Color(0.90, 0.92, 1.0), "处理容器")
	interactables["treat_vessel"]["area"].get_child(0).visible = false
	attach_label3d("treat_vessel", "处理容器", Vector3(0, -0.80, 0), 36, Color(0.80, 0.85, 1.0))

func _build_microscope() -> void:
	PropKit.spawn(self, MICRO_SCOPE, Vector3(2.6, 0.96, -0.35), Vector3(0.0, -14.0, 0.0), {
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
		Vector3(2.6, 1.6, -0.3), mk_box(Vector3(0.65, 0.95, 0.55)),
		Color(0.22, 0.22, 0.28, 0.0), Color(0.55, 0.55, 0.70), "验证显微镜（检查染色体）")
	interactables["micro_verify"]["area"].get_child(0).visible = false
	for ch in interactables["micro_verify"]["area"].get_children():
		if ch is Label3D and not ch.get_meta("static_label", false):
			ch.font_size = 38
			ch.position = Vector3(0.0, -0.95, 0.0)
	micro_static_lbl = add_label3d("光学显微镜\n（染色体倍性验证）", Vector3(2.6, 2.7, -0.3), 40, Color(0.75, 0.30, 1.0))
	micro_static_lbl.outline_size = 8; micro_static_lbl.outline_modulate = Color(0.2, 0.0, 0.3, 0.8)
	micro_static_lbl.visible = false

func _build_dh_plant() -> void:
	# DH植株（双单倍体，最终结果，初始隐藏）
	dh_plant = Node3D.new()
	dh_plant.position = Vector3(4.2, 1.0, 0.8)
	dh_plant.visible = false
	dh_plant.name = "DHPlant"
	add_child(dh_plant)

	add_static(mk_cyl(0.10, 2.2), Vector3(0, 1.1, 0), Color(0.22, 0.55, 0.22), Vector3.ZERO, dh_plant)
	for i in 10:
		var a := i * TAU / 10
		add_static(mk_sphere(0.18), Vector3(sin(a)*0.45, 0.5+i*0.2, cos(a)*0.45),
			Color(0.22, 0.62, 0.26), Vector3.ZERO, dh_plant)
	# 果实（红色辣椒）
	for i in 5:
		var a := i * TAU / 5 + 0.5
		add_static(mk_sphere(0.15), Vector3(sin(a)*0.38, 1.4+i*0.22, cos(a)*0.38),
			Color(0.90, 0.12, 0.08), Vector3.ZERO, dh_plant)
	# 花
	for i in 4:
		var a := i * TAU / 4 + 1.2
		add_static(mk_sphere(0.09), Vector3(sin(a)*0.30, 2.05+i*0.04, cos(a)*0.30),
			Color(0.98, 0.96, 0.92), Vector3.ZERO, dh_plant)
	dh_plant_lbl = add_label3d("DH系植株\n(2n=24，完全可育)", Vector3(4.2, 3.75, 0.8), 30, Color(0.5, 1.0, 0.5))
	dh_plant_lbl.visible = false

func _build_chrom_overlay() -> void:
	chrom_overlay = Control.new()
	chrom_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrom_overlay.visible = false
	canvas_layer.add_child(chrom_overlay)

	var bg := ColorRect.new(); bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrom_overlay.add_child(bg)

	# 主面板（矩形，非圆形）
	var panel := Panel.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -480; panel.offset_right = 480
	panel.offset_top = -320; panel.offset_bottom = 320
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.02, 0.06, 0.04)
	ps.set_border_width_all(3); ps.border_color = Color(0.35, 0.65, 0.40)
	ps.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", ps)
	chrom_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20; vbox.offset_right = -20
	vbox.offset_top = 14; vbox.offset_bottom = -14
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# 标题
	var title := Label.new(); title.text = "🔬  显微镜视野 — 染色体数目验证"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.55, 0.92, 0.62))
	vbox.add_child(title)

	var sep1 := HSeparator.new(); vbox.add_child(sep1)

	# 两列对比
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# ── 左列：处理前 n=12 ──
	var lv := VBoxContainer.new()
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_theme_constant_override("separation", 6)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lv)

	var bl := Label.new(); bl.text = "处理前"
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.add_theme_font_size_override("font_size", 22)
	bl.add_theme_color_override("font_color", Color(0.75, 0.88, 0.78))
	lv.add_child(bl)

	var n12 := Label.new(); n12.text = "n = 12"
	n12.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n12.add_theme_font_size_override("font_size", 60)
	n12.add_theme_color_override("font_color", Color(0.35, 1.0, 0.52))
	lv.add_child(n12)

	var hl := Label.new(); hl.text = "（单倍体）"
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.add_theme_font_size_override("font_size", 20)
	hl.add_theme_color_override("font_color", Color(0.62, 0.82, 0.68))
	lv.add_child(hl)

	# 12条染色体图示（每行6条，共2行）
	var c12 := Label.new()
	c12.text = "║ ║ ║ ║ ║ ║\n║ ║ ║ ║ ║ ║"
	c12.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c12.add_theme_font_size_override("font_size", 30)
	c12.add_theme_color_override("font_color", Color(0.40, 0.92, 0.55))
	lv.add_child(c12)

	# ── 中间箭头 ──
	var arrow := Label.new()
	arrow.text = "秋水仙素\n▶▶\n染色体\n加　倍"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 18)
	arrow.add_theme_color_override("font_color", Color(0.82, 0.55, 1.0))
	arrow.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(arrow)

	# ── 右列：处理后 2n=24 ──
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 6)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(rv)

	var al := Label.new(); al.text = "处理后"
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	al.add_theme_font_size_override("font_size", 22)
	al.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	rv.add_child(al)

	var n24 := Label.new(); n24.text = "2n = 24"
	n24.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n24.add_theme_font_size_override("font_size", 60)
	n24.add_theme_color_override("font_color", Color(0.38, 0.72, 1.0))
	rv.add_child(n24)

	var dl := Label.new(); dl.text = "（双单倍体 DH系）"
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.add_theme_font_size_override("font_size", 20)
	dl.add_theme_color_override("font_color", Color(0.62, 0.75, 0.95))
	rv.add_child(dl)

	# 24条染色体图示（每行6条，共4行）
	var c24 := Label.new()
	c24.text = "║ ║ ║ ║ ║ ║\n║ ║ ║ ║ ║ ║\n║ ║ ║ ║ ║ ║\n║ ║ ║ ║ ║ ║"
	c24.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c24.add_theme_font_size_override("font_size", 30)
	c24.add_theme_color_override("font_color", Color(0.38, 0.72, 1.0))
	rv.add_child(c24)

	var sep2 := HSeparator.new(); vbox.add_child(sep2)

	var close_btn := Button.new(); close_btn.text = "✓  已确认，继续"
	close_btn.custom_minimum_size = Vector2(200, 46)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(close_btn, Color(0.10, 0.28, 0.12))
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(func():
		chrom_overlay.visible = false
		_show_dh_plant()
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
	h.add_theme_font_size_override("font_size", 15)
	h.add_theme_color_override("font_color", Color(0.75, 0.52, 1.0))
	vb.add_child(h)

	treatment_progress_lbl = Label.new(); treatment_progress_lbl.text = "等待操作..."
	treatment_progress_lbl.add_theme_font_size_override("font_size", 14)
	treatment_progress_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.90))
	vb.add_child(treatment_progress_lbl)

func _define_steps() -> void:
	steps = [
		{
			"title": "📖  染色体加倍——秋水仙素处理",
			"body": "单倍体植株（n=12）虽然性状纯合，但高度不育（无法正常进行减数分裂产生配子），必须用【秋水仙素】处理，使染色体数目加倍（n=12→2n=24），才能获得正常可育、性状稳定的纯合二倍体植株（DH系植株）。\n"
				+ "★秋水仙素作用原理：抑制有丝分裂前期纺锤体的形成 → 染色体最终不能移向细胞两极 → 细胞中染色体数目加倍。",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "① 取单倍体植株放入处理容器",
			"body": "点击左侧的【单倍体植株】，将其放入中央的处理容器中，准备接受秋水仙素处理。",
			"click_to_advance": false,
			"active_objects": ["haploid_plant_obj"],
			"correct_object": "haploid_plant_obj",
			"correct_message": "单倍体植株已放入处理容器"
		},
		{
			"title": "② 加入秋水仙素溶液",
			"body": "点击秋水仙素瓶，将适量溶液（0.05–0.20%）加入处理容器中。\n"
				+ "浸泡处理 12–24 小时，使分生细胞染色体加倍。",
			"click_to_advance": false,
			"active_objects": ["colchicine"],
			"correct_object": "colchicine",
			"correct_message": "秋水仙素已加入，开始处理"
		},
		{
			"title": "③ 等待染色体加倍处理",
			"body": "正在进行秋水仙素处理中...\n"
				+ "秋水仙素与微管蛋白结合，阻止纺锤体形成，使细胞进入有丝分裂后无法正常完成，\n"
				+ "导致染色体不能被分配到子细胞，从而留在同一细胞中，实现染色体加倍。",
			"click_to_advance": false,
			"active_objects": []
		},
		{
			"title": "④ 显微镜验证染色体已加倍",
			"body": "处理完成！现在用显微镜检查植株根尖细胞，确认染色体数目已从 12 增加到 24。\n"
				+ "点击右侧的验证显微镜，观察染色体变化。",
			"click_to_advance": false,
			"active_objects": ["micro_verify"],
			"correct_object": "micro_verify",
			"correct_message": "验证完成！染色体已成功加倍"
		},
		{
			"title": "⑤ DH系植株育成！",
			"body": "🎉  祝贺！\n"
				+ "★单倍体植株经秋水仙素处理后，染色体数目成功加倍（n=12 → 2n=24），获得了纯和二倍体植株（DH系植株）！\n"
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
	# 瓶子向处理容器移动
	tw.tween_property(colchicine_bottle_visual, "position", Vector3(-1.8, 1.6, 0.0), 0.6).set_trans(Tween.TRANS_QUAD)
	# 倾斜倒液体
	tw.tween_property(colchicine_bottle_visual, "rotation", Vector3(0, 0, 1.2), 0.4)
	tw.tween_interval(0.5)  # 保持倾斜状态
	# 恢复直立
	tw.tween_property(colchicine_bottle_visual, "rotation", original_rot, 0.3)
	# 返回原位
	tw.tween_property(colchicine_bottle_visual, "position", original_pos, 0.5).set_trans(Tween.TRANS_QUAD)

	# 添加液体流动效果（创建临时液滴）
	_create_liquid_drops()

func _create_liquid_drops() -> void:
	# 创建几个液滴从瓶口流向处理容器
	for i in 5:
		await get_tree().create_timer(0.1 * i).timeout
		var drop := MeshInstance3D.new()
		drop.mesh = mk_sphere(0.04)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.58, 0.65, 0.90, 0.8)  # 蓝紫色半透明
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		drop.material_override = mat
		drop.position = Vector3(-0.5, 1.4, -0.2)
		add_child(drop)

		# 液滴下落动画
		var tw := create_tween()
		tw.tween_property(drop, "position", Vector3(-2.0, 1.0, 0.3), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(drop.queue_free)


func _start_treatment() -> void:
	growing = true

var _shown_verification: bool = false

func _show_verification_microscope() -> void:
	_shown_verification = true
	chrom_overlay.visible = true
	flash_message("染色体已从 12 条加倍为 24 条！秋水仙素处理成功！", true, 2.2, 32, Color(1.0, 0.95, 0.10), 460, 56, false)
	await get_tree().create_timer(2.0).timeout
	advance_step()

func _show_dh_plant() -> void:
	dh_plant.visible = true
	dh_plant.scale = Vector3.ZERO
	if dh_plant_lbl: dh_plant_lbl.visible = true
	var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(dh_plant, "scale", Vector3(1, 1, 1), 1.2)

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

