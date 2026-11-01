## SceneBase.gd
## 所有实验场景的基类，提供通用的3D环境、UI和交互系统
class_name SceneBase
extends Node3D

# ===== 颜色主题 =====
const C_BG_GREEN     := Color(0.04, 0.12, 0.06)
const C_PANEL_DARK   := Color(0.03, 0.10, 0.04, 0.93)
const C_ACCENT_GREEN := Color(0.25, 0.85, 0.35)
const C_TEXT_LIGHT   := Color(0.88, 0.95, 0.88)
const C_TEXT_TITLE   := Color(0.30, 1.00, 0.45)
## UI 文字整体放大系数（对话框、HUD、提示条都走 _style_label）
const UI_TEXT_SCALE := 1.10
const C_HIGHLIGHT    := Color(1.00, 0.90, 0.15)
const C_CORRECT      := Color(0.20, 0.90, 0.30)
const C_WRONG        := Color(0.95, 0.25, 0.15)
const C_BORDER       := Color(0.20, 0.55, 0.25)

# ===== UI 节点 =====
var canvas_layer: CanvasLayer
var hud_panel: Panel
var scene_title_lbl: Label
var step_lbl: Label
var dialog_panel: Panel
var dialog_title_lbl: Label
var dialog_body_lbl: Label
var next_btn: Button
var hint_lbl: Label

# ===== 步骤系统 =====
var current_step_index: int = 0
var steps: Array = []          # Array of Dictionaries
var scene_completed: bool = false

# ===== 交互对象登记 =====
# name -> {area, mat, orig_color, enabled}
var interactables: Dictionary = {}

# ===== 相机 =====
var camera: Camera3D

# ===== 场景元数据 (子类设置) =====
var scene_number: int = 0
var scene_title: String = ""

# ===== 公共层参数（子类可在 super._ready() 之前覆盖）=====
var env_preset: String = "lab"                     # lab / indoor / outdoor
var light_focus: Vector3 = Vector3(0.0, 1.2, 0.0)  # 画面主体的世界坐标
var light_radius: float = 3.0                      # 主体大致半径（米）
var light_intensity: float = 1.0                   # 场景越亮（材质越白）调得越低
var light_key_yaw: float = 34.0                    # 主光水平方位（度）
var label_projector: LabelProjector

# =====================================================================
func _ready() -> void:
	get_viewport().physics_object_picking = true
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_setup_ui()
	_setup_scene()
	_define_steps()
	if steps.size() > 0:
		_show_step(0)

# ----- 子类实现 -----
func _setup_scene() -> void:
	pass

func _define_steps() -> void:
	pass

func _on_interactable_clicked(_obj_name: String) -> void:
	pass

func _configure_camera() -> void:
	camera.position = Vector3(4.0, 3.5, 6.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	camera.fov = 50.0

# =====================================================================
# 环境 & 灯光
# =====================================================================
func _setup_environment() -> void:
	CinematicLab.setup_environment(self, env_preset)

func _setup_lighting() -> void:
	CinematicLab.setup_lighting(self, light_focus, light_radius, env_preset,
		light_intensity, light_key_yaw)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)   # must be in tree before look_at()
	_configure_camera()

# =====================================================================
# UI
# =====================================================================
func _setup_ui() -> void:
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	CinematicLab.add_vignette(canvas_layer)
	_create_hud()
	_create_dialog()
	_create_back_button()
	label_projector = LabelProjector.new()
	label_projector.name = "LabelProjector"
	add_child(label_projector)
	label_projector.setup(camera, canvas_layer)

func _create_hud() -> void:
	hud_panel = Panel.new()
	hud_panel.anchor_right = 1.0
	hud_panel.offset_bottom = 72.0
	_apply_panel_style(hud_panel, Color(0.03, 0.10, 0.05, 0.92))
	canvas_layer.add_child(hud_panel)

	scene_title_lbl = Label.new()
	scene_title_lbl.position = Vector2(20, 14)
	scene_title_lbl.size = Vector2(800, 44)
	scene_title_lbl.text = "场景 %d：%s" % [scene_number, scene_title]
	_style_label(scene_title_lbl, 28, C_TEXT_TITLE)
	hud_panel.add_child(scene_title_lbl)

	step_lbl = Label.new()
	step_lbl.anchor_left = 1.0
	step_lbl.anchor_right = 1.0
	step_lbl.offset_left = -260.0
	step_lbl.offset_right = -14.0
	step_lbl.offset_top = 16.0
	step_lbl.offset_bottom = 56.0
	step_lbl.text = "步骤 1 / 1"
	step_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(step_lbl, 22, Color(0.75, 0.90, 0.78))
	hud_panel.add_child(step_lbl)

func _create_dialog() -> void:
	dialog_panel = Panel.new()
	dialog_panel.anchor_top = 1.0
	dialog_panel.anchor_bottom = 1.0
	dialog_panel.anchor_right = 1.0
	dialog_panel.offset_top = -320.0
	dialog_panel.offset_bottom = 0.0
	_apply_panel_style(dialog_panel, C_PANEL_DARK)
	canvas_layer.add_child(dialog_panel)

	dialog_title_lbl = Label.new()
	dialog_title_lbl.position = Vector2(24, 14)
	dialog_title_lbl.size = Vector2(1050, 50)
	_style_label(dialog_title_lbl, 28, C_TEXT_TITLE)
	dialog_panel.add_child(dialog_title_lbl)

	var sep := HSeparator.new()
	sep.position = Vector2(18, 70)
	sep.size = Vector2(1244, 3)
	dialog_panel.add_child(sep)

	dialog_body_lbl = Label.new()
	dialog_body_lbl.position = Vector2(24, 82)
	dialog_body_lbl.size = Vector2(1160, 210)
	dialog_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(dialog_body_lbl, 21, C_TEXT_LIGHT)
	dialog_panel.add_child(dialog_body_lbl)

	next_btn = Button.new()
	next_btn.anchor_left = 1.0
	next_btn.anchor_right = 1.0
	next_btn.anchor_top = 0.5
	next_btn.anchor_bottom = 0.5
	next_btn.offset_left = -260.0
	next_btn.offset_right = -18.0
	next_btn.offset_top = -48.0
	next_btn.offset_bottom = 48.0
	next_btn.text = "继续 ▶"
	next_btn.visible = false
	_style_button(next_btn, Color(0.12, 0.45, 0.18))
	next_btn.add_theme_font_size_override("font_size", 31)
	next_btn.pressed.connect(_on_next_pressed)
	dialog_panel.add_child(next_btn)

	hint_lbl = Label.new()
	hint_lbl.anchor_left = 1.0
	hint_lbl.anchor_right = 1.0
	hint_lbl.anchor_top = 0.5
	hint_lbl.anchor_bottom = 0.5
	hint_lbl.offset_left = -246.0
	hint_lbl.offset_right = -18.0
	hint_lbl.offset_top = -34.0
	hint_lbl.offset_bottom = 34.0
	hint_lbl.text = "← 点击红色高亮的物体继续"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(hint_lbl, 22, Color(0.82, 0.72, 1.0))
	hint_lbl.add_theme_constant_override("outline_size", 1)
	hint_lbl.add_theme_color_override("font_outline_color", Color(0.82, 0.72, 1.0))
	hint_lbl.visible = false
	dialog_panel.add_child(hint_lbl)

func _create_back_button() -> void:
	var btn := Button.new()
	btn.text = "← 关卡选择"
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.offset_left = -172.0
	btn.offset_right = -10.0
	btn.offset_top = 10.0
	btn.offset_bottom = 58.0
	_style_button(btn, Color(0.22, 0.10, 0.04))
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(GameManager.go_to_level_select)
	canvas_layer.add_child(btn)

# =====================================================================
# 步骤系统
# =====================================================================
func _show_step(idx: int) -> void:
	current_step_index = idx
	if idx >= steps.size():
		return

	var step: Dictionary = steps[idx]
	step_lbl.text = "步骤 %d / %d" % [idx + 1, steps.size()]
	dialog_title_lbl.text = step.get("title", "")
	_fit_title_width()
	dialog_body_lbl.text  = step.get("body", "")
	_fit_dialog_height()

	var auto_adv: bool = step.get("click_to_advance", false)
	next_btn.visible = auto_adv
	hint_lbl.visible = not auto_adv

	_refresh_highlights(step.get("active_objects", []))

## 子类可覆盖：悬停名称牌相对"物体顶端 + 0.35"的额外偏移，
## 用来避开场景里已有的固定标签
func _tooltip_offset(_obj_name: String) -> Vector3:
	return Vector3.ZERO

## 子类可覆盖：悬停名称牌的字号/颜色/描边
func _style_tooltip(_obj_name: String, _lbl: Label3D) -> void:
	pass

func _refresh_highlights(active_names: Array) -> void:
	for nm in interactables:
		var obj := interactables[nm] as Dictionary
		var is_active: bool = nm in active_names
		obj["enabled"] = is_active
		var area_raw = obj.get("area")
		var area := (area_raw as Area3D) if is_instance_valid(area_raw) else null
		if area:
			area.input_ray_pickable = is_active
		var mat_raw = obj.get("mat")
		var mat := (mat_raw as StandardMaterial3D) if is_instance_valid(mat_raw) else null
		if mat:
			if is_active:
				mat.emission_enabled = true
				mat.emission = Color(0.06, 0.06, 0.06)
			else:
				mat.emission_enabled = false
				mat.emission = Color.BLACK

func advance_step() -> void:
	current_step_index += 1
	if current_step_index >= steps.size():
		_complete_scene()
	else:
		_show_step(current_step_index)

func _on_next_pressed() -> void:
	advance_step()

func _complete_scene() -> void:
	if scene_completed:
		return
	scene_completed = true
	_refresh_highlights([])
	dialog_title_lbl.text = "✓  恭喜完成本关！"
	dialog_body_lbl.text = (
		steps[-1].get("completion_text",
		"太棒了！你已成功完成本实验步骤。\n单倍体育种是现代生物技术育种的重要方法，你刚才模拟了真实实验的关键操作。")
	)
	next_btn.text = "进入下一关 →"
	next_btn.visible = true
	hint_lbl.visible = false
	if next_btn.pressed.is_connected(_on_next_pressed):
		next_btn.pressed.disconnect(_on_next_pressed)
	next_btn.pressed.connect(func(): GameManager.complete_level(scene_number))

	# 庆祝动画
	var tween := create_tween().set_loops(3)
	tween.tween_property(dialog_panel, "modulate", Color(1.4, 1.4, 0.9, 1.0), 0.25)
	tween.tween_property(dialog_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)

# =====================================================================
# 交互对象创建
# =====================================================================
func create_interactable(
		obj_name: String,
		pos: Vector3,
		mesh: Mesh,
		color: Color,
		hover_color: Color = Color(1.0, 0.88, 0.18),
		tooltip: String = "") -> Area3D:

	var area := Area3D.new()
	area.position = pos
	area.name = obj_name
	add_child(area)

	# 外观
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.65
	mat.metallic = 0.05
	mi.material_override = mat
	area.add_child(mi)

	# 碰撞
	var col := CollisionShape3D.new()
	col.shape = _mesh_to_shape(mesh)
	area.add_child(col)

	# 工具提示
	if tooltip != "":
		var lbl := Label3D.new()
		lbl.text = tooltip
		lbl.font_size = 39
		lbl.modulate = Color(1.0, 0.55, 0.55)
		lbl.outline_size = 6
		lbl.outline_modulate = Color(0.3, 0.0, 0.0, 0.8)
		_style_tooltip(obj_name, lbl)
		lbl.position = Vector3(0.0, _mesh_top(mesh) + 0.35, 0.0) + _tooltip_offset(obj_name)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.visible = false
		area.add_child(lbl)

	# 信号
	area.mouse_entered.connect(func(): _hover_enter(obj_name, mat, hover_color, area))
	area.mouse_exited.connect(func():  _hover_exit(obj_name, mat, color, area))
	area.input_event.connect(func(_c, ev, _p, _n, _i): _area_input(obj_name, ev))

	interactables[obj_name] = {
		"area": area, "mat": mat,
		"orig_color": color, "enabled": true
	}
	return area

func _hover_enter(nm: String, mat: StandardMaterial3D, hc: Color, area: Area3D) -> void:
	if not interactables.get(nm, {}).get("enabled", false):
		return
	mat.albedo_color = hc
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	for ch in area.get_children():
		if ch is Label3D:
			if ch.get_meta("static_label", false):
				ch.visible = false  # 固定标签悬停时隐藏
			else:
				ch.visible = true   # tooltip 悬停时显示

func _hover_exit(nm: String, mat: StandardMaterial3D, oc: Color, area: Area3D) -> void:
	mat.albedo_color = oc
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	for ch in area.get_children():
		if ch is Label3D:
			if ch.get_meta("static_label", false):
				ch.visible = true   # 固定标签离开时恢复显示
			else:
				ch.visible = false  # tooltip 离开时隐藏

func _area_input(nm: String, event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		if interactables.get(nm, {}).get("enabled", false):
			_on_interactable_clicked(nm)

func _mesh_to_shape(mesh: Mesh) -> Shape3D:
	if mesh is SphereMesh:
		var s := SphereShape3D.new(); s.radius = mesh.radius; return s
	elif mesh is BoxMesh:
		var b := BoxShape3D.new(); b.size = mesh.size; return b
	elif mesh is CylinderMesh:
		var c := CylinderShape3D.new()
		c.radius = maxf(mesh.top_radius, mesh.bottom_radius)
		c.height = mesh.height; return c
	elif mesh is CapsuleMesh:
		var cap := CapsuleShape3D.new()
		cap.radius = mesh.radius; cap.height = mesh.height; return cap
	var fb := BoxShape3D.new(); fb.size = Vector3(0.5, 0.5, 0.5); return fb

func _mesh_top(mesh: Mesh) -> float:
	if mesh is SphereMesh:   return mesh.radius
	elif mesh is BoxMesh:    return mesh.size.y * 0.5
	elif mesh is CylinderMesh: return mesh.height * 0.5
	elif mesh is CapsuleMesh:  return mesh.height * 0.5
	return 0.5

# =====================================================================
# 静态网格辅助
# =====================================================================
## 在两点间绘制细圆柱连线
func add_segment(p1: Vector3, p2: Vector3, radius: float = 0.025,
		color: Color = Color(0.22, 0.52, 0.20)) -> MeshInstance3D:
	var diff := p2 - p1
	var length := diff.length()
	if length < 0.001:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mk_cyl(radius, length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = (p1 + p2) * 0.5
	var dir := diff.normalized()
	mi.transform.basis = Basis.looking_at(dir, Vector3.RIGHT).rotated(Vector3.RIGHT, PI * 0.5)
	add_child(mi)
	return mi
## 半透明玻璃材质网格（用于培养箱/容器外壳）
func add_glass(mesh: Mesh, pos: Vector3, color: Color,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.10
	mat.metallic = 0.06
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi

## 将网格材质设置为最上层渲染（忽略深度测试）
func set_top_layer(mi: MeshInstance3D) -> void:
	var mat := mi.material_override as StandardMaterial3D
	if mat:
		mat.no_depth_test = true
		mat.render_priority = 2

func add_static(mesh: Mesh, pos: Vector3, color: Color,
		rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color; mat.roughness = 0.75
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	(parent if parent else self).add_child(mi)
	return mi

func mk_sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2.0; return m

func mk_box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new(); m.size = s; return m

func mk_cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r; m.bottom_radius = r; m.height = h; return m

func mk_plane(s: Vector2) -> PlaneMesh:
	var m := PlaneMesh.new(); m.size = s; return m

func mk_capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new(); m.radius = r; m.height = h; return m

func mk_prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new(); m.size = size; return m

# 世界坐标处的标签（2D 投影，见 LabelProjector——Label3D 会糊、会被深度裁切）
func add_label3d(text: String, pos: Vector3, size: int = 44,
		color: Color = Color.WHITE) -> LabelProjector.TagLabel:
	return label_projector.add_at(text, pos, size, color)

# 跟随指定 interactable 的标签（2D 投影）
func attach_label3d(obj_name: String, text: String, offset: Vector3,
		size: int = 44, color: Color = Color.WHITE) -> LabelProjector.TagLabel:
	var area := interactables.get(obj_name, {}).get("area") as Area3D
	if not area:
		return null
	return label_projector.add(text, area, offset, size, color)

# =====================================================================
# 临时消息
# =====================================================================
func flash_message(msg: String, good: bool = true, dur: float = 2.2, font_size: int = 20, custom_color: Color = Color(-1, -1, -1), half_w: int = 220, half_h: int = 40, show_prefix: bool = true) -> void:
	var use_custom := custom_color.r >= 0.0
	var fg_color := custom_color if use_custom else (C_CORRECT if good else C_WRONG)
	var bg := Panel.new()
	bg.anchor_left = 0.5; bg.anchor_right = 0.5
	bg.anchor_top  = 0.5; bg.anchor_bottom = 0.5
	bg.offset_left = -half_w; bg.offset_right = half_w
	bg.offset_top  = -half_h;  bg.offset_bottom = half_h
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.03, 0.14, 0.05, 0.95) if good else Color(0.18, 0.04, 0.02, 0.95)
	sty.set_border_width_all(2)
	sty.border_color = fg_color
	sty.set_corner_radius_all(8)
	bg.add_theme_stylebox_override("panel", sty)
	canvas_layer.add_child(bg)

	var lbl := Label.new()
	lbl.text = (("✓  " if good else "✗  ") if show_prefix else "") + msg
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_style_label(lbl, font_size, fg_color)
	bg.add_child(lbl)

	# 底板按文字实际宽度撑开：字号放大后，"配方不对！请仔细对比……" 这种
	# 长句会直接顶出固定 440px 的框
	var f := lbl.get_theme_font("font")
	var fs := int(lbl.get_theme_font_size("font_size"))
	var text_w := f.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box_w := maxf(half_w * 2.0, text_w + 56.0)
	bg.offset_left = -box_w * 0.5
	bg.offset_right = box_w * 0.5

	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(bg.queue_free)

# =====================================================================
# 样式助手
# =====================================================================
func _apply_panel_style(p: Panel, color: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_width_bottom = 1; s.border_width_top = 1
	s.border_color = C_BORDER
	p.add_theme_stylebox_override("panel", s)

## 对话框高度跟着正文走：短文案不该顶着一块 320px 的空板子
func _fit_dialog_height() -> void:
	if dialog_panel == null or dialog_body_lbl == null:
		return
	# 不能用 reset_size()：会把 autowrap 标签的宽度重置掉，正文变成一行一个字
	var body_h := dialog_body_lbl.get_minimum_size().y
	var need := 106.0 + body_h + 24.0
	dialog_panel.offset_top = -clampf(need, 210.0, 330.0)

## 标题按字宽自适应：字号放大后，Scene2 那种长标题会顶出屏幕
func _fit_title_width() -> void:
	if dialog_title_lbl == null:
		return
	var f := dialog_title_lbl.get_theme_font("font")
	var fs := int(dialog_title_lbl.get_theme_font_size("font_size"))
	var avail := 1330.0
	var w := f.get_string_size(dialog_title_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > avail and w > 0.0:
		dialog_title_lbl.add_theme_font_size_override("font_size",
			maxi(int(floor(fs * avail / w)), 20))

func _style_label(lbl: Label, fs: int, color: Color) -> void:
	lbl.add_theme_font_size_override("font_size", int(round(fs * UI_TEXT_SCALE)))
	lbl.add_theme_color_override("font_color", color)

func _style_button(btn: Button, bg: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		match state:
			"normal":   s.bg_color = bg
			"hover":    s.bg_color = bg.lightened(0.22)
			"pressed":  s.bg_color = bg.darkened(0.18)
		s.set_border_width_all(1)
		s.border_color = C_BORDER.lightened(0.1)
		s.set_corner_radius_all(6)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", Color.WHITE)
