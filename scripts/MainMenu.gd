## MainMenu.gd — 游戏主菜单
extends Node3D

var canvas: CanvasLayer
var _rot_t: float = 0.0

func _ready() -> void:
	_setup_env()
	_setup_lights()
	_build_3d_scene()
	_build_ui()

func _process(delta: float) -> void:
	_rot_t += delta * 0.4
	# 让装饰辣椒植株缓缓旋转
	var plant := get_node_or_null("DecorPlant")
	if plant:
		plant.rotation_degrees.y = rad_to_deg(_rot_t)

# =====================================================================
# 环境 & 场景
# =====================================================================
func _setup_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.10, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.40, 0.28)
	env.ambient_light_energy = 1.0
	we.environment = env
	add_child(we)

func _setup_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.2
	add_child(sun)

func _build_3d_scene() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2, 6); cam.fov = 50
	add_child(cam)
	cam.look_at(Vector3(0, 1.2, 0))

	# 地面
	var plane := PlaneMesh.new(); plane.size = Vector2(30, 30)
	_add_mesh(plane, Vector3(0, 0, 0), Color(0.10, 0.25, 0.12))

	# 装饰植株（可旋转）
	var plant := Node3D.new(); plant.name = "DecorPlant"; add_child(plant)
	_add_mesh_to(mk_cyl(0.08, 1.8), Vector3(0, 0.9, 0), Color(0.20, 0.52, 0.18), plant)
	# 叶子
	for i in 6:
		var a := i * TAU / 6
		var lp := Vector3(sin(a)*0.55, 0.5 + i*0.18, cos(a)*0.55)
		_add_mesh_to(mk_sphere(0.18), lp, Color(0.22, 0.60, 0.20), plant)
	# 红椒果实
	for i in 4:
		var a := i * TAU / 4 + 0.4
		var fp := Vector3(sin(a)*0.45, 1.2 + i*0.15, cos(a)*0.45)
		_add_mesh_to(mk_sphere(0.12), fp, Color(0.85, 0.15, 0.08), plant)
	# 花药
	for i in 3:
		var a := i * TAU / 3 + 1.0
		var bp := Vector3(sin(a)*0.38, 1.55 + i*0.08, cos(a)*0.38)
		_add_mesh_to(mk_sphere(0.07), bp, Color(0.95, 0.92, 0.60), plant)

	# 背景装饰植株
	for xi in [-3, 3]:
		var bg_plant := Node3D.new(); add_child(bg_plant)
		bg_plant.position = Vector3(xi, 0, -2)
		bg_plant.scale = Vector3(0.7, 0.7, 0.7)
		_add_mesh_to(mk_cyl(0.07, 1.6), Vector3(0, 0.8, 0), Color(0.18, 0.48, 0.16), bg_plant)
		for i in 5:
			var a := i * TAU / 5
			_add_mesh_to(mk_sphere(0.14), Vector3(sin(a)*0.4, 0.4+i*0.2, cos(a)*0.4),
				Color(0.20, 0.58, 0.18), bg_plant)

func _add_mesh(mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.8
	mi.material_override = mat; mi.position = pos; add_child(mi); return mi

func _add_mesh_to(mesh: Mesh, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.8
	mi.material_override = mat; mi.position = pos; parent.add_child(mi); return mi

func mk_cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new(); m.top_radius = r; m.bottom_radius = r; m.height = h; return m
func mk_sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = r*2; return m

# =====================================================================
# 2D UI
# =====================================================================
func _build_ui() -> void:
	canvas = CanvasLayer.new(); add_child(canvas)

	# 半透明深色背景
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	# 中央面板
	var panel := Panel.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top  = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -460; panel.offset_right = 460
	panel.offset_top  = -330; panel.offset_bottom = 330
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.14, 0.06, 0.96)
	ps.set_border_width_all(2); ps.border_color = Color(0.22, 0.65, 0.30)
	ps.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", ps)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 28; vbox.offset_right = -28
	vbox.offset_top = 24; vbox.offset_bottom = -24
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# 标题
	var title_lbl := _add_lbl(vbox, "🌶  辣椒单倍体育种流程虚拟实验平台", 46, Color.WHITE)
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	_add_spacer(vbox, 18)
	_add_lbl(vbox, "高中生物选择性必修三实验", 30, Color(0.20, 0.90, 0.90))
	_add_spacer(vbox, 8)
	_add_lbl(vbox, "☆辣椒体细胞染色体倍性 2n=24", 22, Color(0.75, 0.95, 0.78))
	_add_spacer(vbox, 30)

	_add_btn(vbox, "▶  开始实验（从第一关）", _on_start_pressed)
	_add_spacer(vbox, 10)
	_add_btn(vbox, "📋  选择关卡", _on_level_select_pressed, Color(0.12, 0.30, 0.45))
	_add_spacer(vbox, 10)
	_add_btn(vbox, "✖  退出游戏", _on_quit_pressed, Color(0.30, 0.08, 0.05))
	_add_spacer(vbox, 24)
	_add_lbl(vbox, "请点击屏幕中红色字体突出显示的对象进行实验操作\n共 7 个实验关卡，循序渐进，完成完整育种流程！", 24, Color(1.0, 0.92, 0.10))

func _add_lbl(parent: Control, text: String, fs: int, color: Color) -> Label:
	var l := Label.new(); l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l); return l

func _add_spacer(parent: Control, h: int) -> void:
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, h); parent.add_child(sp)

func _add_btn(parent: Control, text: String, cb: Callable,
		bg: Color = Color(0.10, 0.38, 0.16)) -> Button:
	var btn := Button.new(); btn.text = text
	btn.custom_minimum_size = Vector2(460, 58)
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = bg if state == "normal" else (bg.lightened(0.22) if state == "hover" else bg.darkened(0.2))
		s.set_border_width_all(1); s.border_color = Color(0.30, 0.70, 0.38)
		s.set_corner_radius_all(8)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(cb)
	parent.add_child(btn); return btn

# =====================================================================
# 按钮回调
# =====================================================================
func _on_start_pressed() -> void:
	GameManager.reset_progress()
	GameManager.go_to_level(1)

func _on_level_select_pressed() -> void:
	GameManager.go_to_level_select()

func _on_quit_pressed() -> void:
	get_tree().quit()
