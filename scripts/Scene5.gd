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

# UI
var shoot_lbl: Label
var root_lbl: Label
var shoot_wait_btn: Button
var root_wait_btn: Button

func _ready() -> void:
	scene_number = 5
	scene_title  = "生芽与生根诱导"
	super._ready()

func _configure_camera() -> void:
	camera.position = Vector3(0.0, 4.2, 7.0) * 1.3
	camera.look_at(Vector3(0.0, 1.5, 0.0))
	camera.fov = 50.0

func _setup_scene() -> void:
	_build_room()
	_build_callus()
	_build_shoot_medium()
	_build_root_medium()
	_build_info_panel()

func _build_room() -> void:
	add_static(mk_plane(Vector2(22, 22)), Vector3.ZERO, Color(0.80, 0.84, 0.80))
	add_static(mk_box(Vector3(16, 4.5, 0.2)), Vector3(0, 2.25, -4.5), Color(0.88, 0.90, 0.86))
	# 实验台
	add_static(mk_box(Vector3(11.0, 0.12, 3.0)), Vector3(0, 0.94, 0.0), Color(0.88, 0.90, 0.84))
	for xo in [-5.0, 5.0]:
		for zo in [-1.2, 1.2]:
			add_static(mk_box(Vector3(0.10, 0.94, 0.10)), Vector3(xo, 0.47, zo), Color(0.55, 0.55, 0.58))

	# 透明玻璃罩（覆盖整个实验台）
	add_glass(mk_box(Vector3(11.4, 3.20, 3.4)), Vector3(0.0, 2.60, 0.0), Color(0.72, 0.88, 0.98, 0.10))

	# 顶灯（玻璃罩内部顶端）
	for i in 3:
		var lx := -3.0 + i * 3.0
		add_static(mk_box(Vector3(2.2, 0.06, 0.7)), Vector3(lx, 4.10, 0.0), Color(0.95, 0.95, 0.88))
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(1.0, 0.95, 0.60)
		lmat.emission_enabled = true
		lmat.emission = Color(1.0, 0.85, 0.20)
		var lmi := MeshInstance3D.new(); lmi.mesh = mk_box(Vector3(2.0, 0.04, 0.6))
		lmi.material_override = lmat; lmi.position = Vector3(lx, 4.08, 0.0); add_child(lmi)
		# 点光源：发出黄色光照亮场景
		var omni := OmniLight3D.new()
		omni.position = Vector3(lx, 3.90, 0.0)
		omni.light_color = Color(1.0, 0.88, 0.35)
		omni.light_energy = 2.5
		omni.omni_range = 6.0
		add_child(omni)

func _build_callus() -> void:
	# 培养皿底座（中央）
	add_static(mk_cyl(0.62, 0.10), Vector3(0.0, 1.00, 0.0), Color(0.75, 0.85, 0.72))

	# 愈伤组织节点（可整体移动）
	callus_root = Node3D.new()
	callus_root.position = Vector3(0, 1.12, 0)
	callus_root.name = "CallusRoot"
	add_child(callus_root)

	for i in 12:
		var a := i * TAU / 12
		var r := 0.10 + (i % 5) * 0.04
		var h := (i % 4) * 0.05
		var sp := MeshInstance3D.new(); sp.mesh = mk_sphere(0.09 + (i % 3) * 0.03)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35 + (i % 4) * 0.05, 0.70 + (i % 3) * 0.06, 0.32 + (i % 4) * 0.04)
		sp.material_override = mat
		sp.position = Vector3(sin(a) * r, h, cos(a) * r)
		callus_root.add_child(sp)

	create_interactable("callus",
		Vector3(0.0, 1.15, 0.0), mk_cyl(0.55, 0.28),
		Color(0.38, 0.75, 0.38, 0.0), Color(0.55, 0.95, 0.55), "愈伤组织")
	interactables["callus"]["area"].get_child(0).visible = false
	var lbl_callus := attach_label3d("callus", "愈伤组织\n（等待再分化）", Vector3(0, 0.60, 0), 38, Color(0.7, 1.0, 0.7))
	if lbl_callus: lbl_callus.outline_size = 8; lbl_callus.outline_modulate = Color(0.0, 0.2, 0.0, 0.8)

func _build_shoot_medium() -> void:
	# 生芽培养基架子（左侧）
	add_static(mk_box(Vector3(2.60, 0.12, 2.40)), Vector3(-4.2, 1.00, 0.0), Color(0.72, 0.74, 0.70))

	# 锥形瓶（半透明玫瑰色，含细胞分裂素，可看到内部培养物）
	var flask := MeshInstance3D.new(); flask.mesh = mk_cyl(0.50, 0.88)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.55, 0.95, 0.32); fm.roughness = 0.12; fm.metallic = 0.05
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	flask.material_override = fm; flask.position = Vector3(-4.2, 1.50, 0.0); add_child(flask)

	var medium := MeshInstance3D.new(); medium.mesh = mk_cyl(0.44, 0.40)
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.30, 0.58, 0.92); mm.roughness = 0.6
	medium.material_override = mm; medium.position = Vector3(-4.2, 1.26, 0.0); add_child(medium)

	create_interactable("shoot_medium",
		Vector3(-4.2, 1.52, 0.0), mk_cyl(0.55, 1.00),
		Color(0.25, 0.55, 0.95, 0.0), Color(0.50, 0.75, 1.0), "诱导生芽培养基")
	interactables["shoot_medium"]["area"].get_child(0).visible = false
	var lbl_shoot := attach_label3d("shoot_medium", "诱导生芽培养基", Vector3(0, 1.38, 0), 52, Color(0.55, 0.82, 1.0))
	if lbl_shoot: lbl_shoot.outline_size = 8; lbl_shoot.outline_modulate = Color(0.0, 0.1, 0.3, 0.8)

	# 生芽植株节点（跟随愈伤组织，初始不可见）
	shoot_plant_node = Node3D.new()
	shoot_plant_node.position = Vector3(-4.2, 1.50, 0.0)
	shoot_plant_node.visible = false
	shoot_plant_node.name = "ShootPlant"
	add_child(shoot_plant_node)

func _build_root_medium() -> void:
	# 生根培养基架子（右侧）
	add_static(mk_box(Vector3(2.60, 0.12, 2.40)), Vector3(4.2, 1.00, 0.0), Color(0.72, 0.74, 0.70))

	# 锥形瓶（半透明棕褐色，含生长素，可看到内部根系）
	var flask := MeshInstance3D.new(); flask.mesh = mk_cyl(0.50, 0.88)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.72, 0.58, 0.42, 0.32); fm.roughness = 0.12; fm.metallic = 0.05
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	flask.material_override = fm; flask.position = Vector3(4.2, 1.50, 0.0); add_child(flask)

	var medium := MeshInstance3D.new(); medium.mesh = mk_cyl(0.44, 0.40)
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.78, 0.62, 0.46); mm.roughness = 0.6
	medium.material_override = mm; medium.position = Vector3(4.2, 1.26, 0.0); add_child(medium)

	create_interactable("root_medium",
		Vector3(4.2, 1.52, 0.0), mk_cyl(0.55, 1.00),
		Color(0.72, 0.58, 0.42, 0.0), Color(0.90, 0.75, 0.55), "诱导生根培养基")
	interactables["root_medium"]["area"].get_child(0).visible = false
	var lbl_root := attach_label3d("root_medium", "诱导生根培养基", Vector3(0, 1.38, 0), 52, Color(0.78, 0.52, 0.25))
	if lbl_root: lbl_root.outline_size = 8; lbl_root.outline_modulate = Color(0.2, 0.1, 0.0, 0.8)

	# 根系节点（初始不可见，位于右侧培养基）
	root_node = Node3D.new()
	root_node.position = Vector3(4.2, 1.12, 0.0)
	root_node.visible = false
	root_node.name = "RootNode"
	add_child(root_node)

func _build_info_panel() -> void:
	var info_panel := Panel.new()
	info_panel.anchor_top = 1.0; info_panel.anchor_bottom = 1.0
	info_panel.anchor_right = 0.55
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
	shoot_lbl.add_theme_font_size_override("font_size", 24)
	shoot_lbl.add_theme_color_override("font_color", Color(0.40, 0.75, 1.0))
	shoot_lbl.add_theme_constant_override("outline_size", 2)
	shoot_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.1, 0.3, 0.7))
	vb.add_child(shoot_lbl)

	shoot_wait_btn = Button.new(); shoot_wait_btn.text = "⏩ 加速生芽培养"
	shoot_wait_btn.custom_minimum_size = Vector2(0, 68)
	shoot_wait_btn.visible = false
	_style_button(shoot_wait_btn, Color(0.08, 0.22, 0.50))
	shoot_wait_btn.add_theme_font_size_override("font_size", 24)
	shoot_wait_btn.add_theme_constant_override("outline_size", 2)
	shoot_wait_btn.add_theme_color_override("font_outline_color", Color(0.0, 0.1, 0.3, 0.6))
	shoot_wait_btn.pressed.connect(func():
		shoot_timer_running = true
		shoot_wait_btn.disabled = true)
	vb.add_child(shoot_wait_btn)

	root_lbl = Label.new(); root_lbl.text = "🌱 生根进度：等待转移"
	root_lbl.add_theme_font_size_override("font_size", 24)
	root_lbl.add_theme_color_override("font_color", Color(0.72, 0.48, 0.22))
	root_lbl.add_theme_constant_override("outline_size", 2)
	root_lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0, 0.7))
	vb.add_child(root_lbl)

	root_wait_btn = Button.new(); root_wait_btn.text = "⏩ 加速生根培养"
	root_wait_btn.custom_minimum_size = Vector2(0, 68)
	root_wait_btn.visible = false
	_style_button(root_wait_btn, Color(0.45, 0.26, 0.10))
	root_wait_btn.add_theme_font_size_override("font_size", 24)
	root_wait_btn.add_theme_constant_override("outline_size", 2)
	root_wait_btn.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0, 0.6))
	root_wait_btn.pressed.connect(func():
		root_timer_running = true
		root_wait_btn.disabled = true)
	vb.add_child(root_wait_btn)

func _define_steps() -> void:
	steps = [
		{
			"title": "📖  生芽与生根诱导",
			"body": "愈伤组织具有全能性，可以在含有不同生长素和细胞分裂素配比"
					+ "的器官诱导培养基中先后实现诱导生芽和诱导生根的器官发育"
					+ "诱导，最终长成具有完整根、茎、叶器官的植株",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "① 将愈伤组织转入生芽培养基",
			"body": "点击中央的【愈伤组织】，再点击左侧的【生芽诱导培养基】完成转移。",
			"click_to_advance": false,
			"active_objects": ["callus", "shoot_medium"]
		},
		{
			"title": "② 等待芽的分化发育",
			"body": "愈伤组织在生芽培养基上逐渐分化出嫩绿色的芽。\n"
				+ "点击【⏩ 加速生芽培养】按钮，观察芽的发育过程。\n"
				+ "通常需要 2–4 周，芽才能发育到可转移的大小。",
			"click_to_advance": false,
			"active_objects": []
		},
		{
			"title": "③ 将带芽幼苗转入生根培养基",
			"body": "芽已发育成幼苗！现在将带芽幼苗转移到右侧的【诱导生根培养基】。\n"
				+ "点击右侧生根培养基完成转移。",
			"click_to_advance": false,
			"active_objects": ["root_medium"],
			"correct_object": "root_medium",
			"correct_message": "幼苗已转入生根培养基"
		},
		{
			"title": "④ 等待根系发育",
			"body": "在生根培养基上，幼苗基部会逐渐长出白色根系。\n"
				+ "点击【⏩ 加速生根培养】按钮，观察根的发育过程。\n"
				+ "根系发育完善后，辣椒幼苗即可进行后续染色体倍性鉴定。",
			"click_to_advance": false,
			"active_objects": [],
			"completion_text": "生芽与生根完成！\n愈伤组织已成功分化为具有完整根、茎、叶结构的辣椒幼苗！这体现了植物细胞的全能性：即每个细胞都携带完整遗传信息，在合适条件下可发育成完整个体。\n接下来需要鉴定辣椒幼苗的染色体倍性，筛选出真正的单倍体植株。"
		},
	]

var _callus_transferred: bool = false

func _on_interactable_clicked(obj_name: String) -> void:
	match current_step_index:
		1:
			if obj_name == "callus":
				flash_message("已取愈伤组织，请点击左侧生芽培养基", true)
				_callus_transferred = true
				_refresh_highlights(["shoot_medium"])
			elif obj_name == "shoot_medium":
				if not _callus_transferred:
					flash_message("请先点击愈伤组织取出！", false)
					return
				flash_message("愈伤组织正在转移至生芽培养基…", true)
				# 隐藏愈伤组织标签
				var callus_area := interactables.get("callus", {}).get("area") as Area3D
				if callus_area:
					for ch in callus_area.get_children():
						if ch is Label3D:
							ch.visible = false
				# 动画：愈伤组织飞向左侧锥形瓶
				_animate_callus_to_shoot()
				await get_tree().create_timer(1.0).timeout
				shoot_plant_node.visible = true
				advance_step()
				shoot_wait_btn.visible = true
		3:
			if obj_name == "root_medium":
				flash_message("带芽幼苗正在转移至生根培养基…", true)
				# 动画：幼苗从左侧飞向右侧
				_animate_shoot_to_root()
				await get_tree().create_timer(1.0).timeout
				root_node.visible = true
				_build_root_strands()
				advance_step()
				root_wait_btn.visible = true
		_: pass

# ── 动画：愈伤组织 → 生芽培养基（左侧） ──
func _animate_callus_to_shoot() -> void:
	if not callus_root: return
	# callus_root 跟随移动到左侧培养基位置
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(callus_root, "position",
		Vector3(-4.2, 1.55, 0.0), 0.75)
	# 同步移动 callus 交互区域（让突出显示的不留在原位）
	var area := interactables.get("callus", {}).get("area") as Area3D
	if area:
		tw.parallel().tween_property(area, "position",
			Vector3(-4.2, 1.55, 0.0), 0.75)
	# 到达后缩小（放入培养基）
	tw.tween_property(callus_root, "scale", Vector3(0.5, 0.5, 0.5), 0.25)

# ── 动画：带芽幼苗 → 生根培养基（右侧） ──
func _animate_shoot_to_root() -> void:
	if not shoot_plant_node: return
	var target := Vector3(4.2, 1.50, 0.0)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# 先抬起再平移（弧形路径效果）
	tw.tween_property(shoot_plant_node, "position",
		shoot_plant_node.position + Vector3(0, 1.2, 0), 0.35)
	tw.tween_property(shoot_plant_node, "position", target + Vector3(0, 1.2, 0), 0.40)
	tw.tween_property(shoot_plant_node, "position", target, 0.25)

# ── 生芽植株：逐帧重建（progress 0→1） ──
func _build_shoot_plant(progress: float) -> void:
	for ch in shoot_plant_node.get_children():
		ch.queue_free()
	if progress <= 0.0: return
	var h := progress * 1.0
	# 茎
	var stem := MeshInstance3D.new(); stem.mesh = mk_cyl(0.04, h)
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.20, 0.58, 0.24)
	stem.material_override = sm; stem.position = Vector3(0, h * 0.5, 0)
	shoot_plant_node.add_child(stem)
	# 叶片（随进度增加）
	var leaf_count := int(progress * 5) + 1
	for i in leaf_count:
		var a := i * TAU / leaf_count + i * 0.5
		var lh := h * (0.25 + i * 0.15)
		var ls := 0.07 + progress * 0.07
		var leaf := MeshInstance3D.new(); leaf.mesh = mk_sphere(ls)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.22, 0.68 + progress * 0.12, 0.26)
		leaf.material_override = lm
		leaf.position = Vector3(sin(a) * (0.14 + progress * 0.08), lh, cos(a) * (0.14 + progress * 0.08))
		shoot_plant_node.add_child(leaf)

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

func _build_root_strands() -> void:
	root_strands.clear()
	for rd in _root_defs:
		var a: float = rd["a"]
		var r: float = rd["r"]
		var len: float = rd["len"]
		var rx: float = rd["rx"]
		var mi := MeshInstance3D.new()
		mi.mesh = mk_cyl(0.018, len)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.92, 0.90, 0.82)
		mi.material_override = mat
		# 位置：根从植株底部向外向下延伸
		mi.position = Vector3(sin(a) * r, -len * 0.5, cos(a) * r)
		mi.rotation_degrees = Vector3(rx, rad_to_deg(a), 0)
		mi.scale = Vector3.ZERO   # 初始不可见，待动画放大
		root_node.add_child(mi)
		root_strands.append(mi)

# =====================================================================
# _process：生芽 + 生根 动画
# =====================================================================
func _process(delta: float) -> void:
	# 生芽阶段
	if shoot_timer_running:
		shoot_growth += delta * 0.55
		shoot_growth = minf(shoot_growth, 1.0)
		shoot_lbl.text = "🌿 生芽进度：%.0f%%" % (shoot_growth * 100)
		_build_shoot_plant(shoot_growth)
		if shoot_growth >= 1.0:
			shoot_timer_running = false
			shoot_lbl.text = "🌿 生芽完成 ✓"
			flash_message("芽已充分发育为幼苗！", true)
			shoot_wait_btn.visible = false
			await get_tree().create_timer(1.5).timeout
			advance_step()
			_refresh_highlights(["root_medium"])

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
			flash_message("根系发育完善！单倍体植株培育成功！", true)
			root_wait_btn.visible = false
			await get_tree().create_timer(1.5).timeout
			advance_step()
