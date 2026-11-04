## Scene1.gd — 配制诱导培养基（「写实科教纪录片感」样板关）
##
## 与其余关卡的区别：3D 部分不再用运行时 primitive 拼装，改为
##   1) 加载 Blender 导出的 glTF 道具（实验台 / 培养皿 / 烧杯 / 托盘 / 房间）
##   2) 材质统一来自 materials/*.tres（贴图走路，模型只出几何）
##   3) 单独覆写环境光、灯光、相机，做电影感布光
## 交互判定、步骤文案与其余关卡完全一致，只换了"皮"。
extends SceneBase

# =====================================================================
# 关卡数据
# =====================================================================
const MEDIA := [
	{
		"key": "callus",
		"label": "诱导愈伤组织培养基",
		"color": Color(0.30, 0.63, 0.31),
		"hover": Color(0.44, 0.82, 0.45),
		"formula": "MS基本培养基 + 生长素 0.5 mg/L + 细胞分裂素 0.5 mg/L"
	},
	{
		"key": "shoot",
		"label": "诱导生芽培养基",
		"color": Color(0.17, 0.39, 0.79),
		"hover": Color(0.32, 0.56, 0.93),
		"formula": "MS基本培养基 + 细胞分裂素 6 mg/L + 生长素 1 mg/L"
	},
	{
		"key": "root",
		"label": "诱导生根培养基",
		"color": Color(0.62, 0.40, 0.14),
		"hover": Color(0.82, 0.58, 0.27),
		"formula": "MS基本培养基 + 生长素 0.5 mg/L"
	}
]

# =====================================================================
# 资产
# =====================================================================
const ROOM_SCENE  := preload("res://assets/props/lab_room.glb")
const BENCH_SCENE := preload("res://assets/props/lab_bench.glb")
const DISH_SCENE  := preload("res://assets/props/petri_dish.glb")
const CONICAL_FLASK_SCENE := preload("res://assets/props/conical_flask.glb")
const BEAKER_SCENE := preload("res://assets/props/beaker.glb")

const MAT_EPOXY := preload("res://materials/epoxy_bench.tres")
const MAT_STEEL := preload("res://materials/stainless.tres")
const MAT_TILE  := preload("res://materials/tile_wall.tres")
const MAT_FLOOR := preload("res://materials/floor_epoxy.tres")
const MAT_GLASS := preload("res://materials/glassware_clear.tres")
const MAT_SHELL := preload("res://materials/dish_shell.tres")
const MAT_CONTACT := preload("res://materials/contact_shadow.tres")
const MAT_AGAR  := preload("res://materials/agar_base.tres")

# =====================================================================
# 布局（单位：米）
# =====================================================================
const BENCH_TOP_Y := 0.9          # 台面上表面高度
const DISH_X := [-0.36, 0.0, 0.36]
const DISH_Z := 0.18
const DISH_RADIUS := 0.050
const SHOW_DISH_LID := false      # 皿盖：开着盖更利于看清培养基颜色（也是常见实验镜头）

const CAM_POS := Vector3(0.50, 1.40, 1.30)
const CAM_TARGET := Vector3(-0.05, 0.93, 0.10)
const CAM_FOV := 41.0
const CAM_BREATH := 1.0           # 手持呼吸感强度，0 = 完全静止

# =====================================================================
# 状态（沿用原关卡逻辑）
# =====================================================================
var matched: Dictionary = {}
var round_failed: bool = false   # 本轮只要选错过一次配方，整轮作废
var selected_key: String = ""
var hint_labels: Dictionary = {}   # key -> 红色"点击选择配方"提示
var formula_panel: Control
var panel_title_lbl: Label
var formula_btns: Array[Button] = []
var shuffled_formulas: Array = []
var matched_lbl: Label

var _cam_time: float = 0.0

# =====================================================================
func _ready() -> void:
	scene_number = 1
	scene_title  = "配制诱导培养基"
	# 红/绿提示框严格排队：前一条完全消失后才出下一条，不会叠在一起
	queue_toasts = true
	super._ready()
	_restyle_ui()

## 把 SceneBase 的荧光绿 HUD 换成中性色，和写实场景统一
func _restyle_ui() -> void:
	if is_instance_valid(scene_title_lbl):
		scene_title_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	if is_instance_valid(step_lbl):
		step_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.79))
	if is_instance_valid(dialog_title_lbl):
		dialog_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 0.97))
	if is_instance_valid(dialog_body_lbl):
		dialog_body_lbl.add_theme_color_override("font_color", Color(0.84, 0.87, 0.89))
	if is_instance_valid(hint_lbl):
		# 右下角"点击…"提示统一用亮黄，场景一别改回灰蓝
		hint_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.20))
	if is_instance_valid(next_btn):
		_style_button(next_btn, Color(0.16, 0.18, 0.21))
		# 上面的 _style_button 会把字号冲回 19，这里补回统一字号
		next_btn.add_theme_font_size_override("font_size", CONTINUE_FONT_SIZE)
	for child in canvas_layer.get_children():
		if child is Button and (child as Button).text.contains("关卡选择"):
			_style_button(child as Button, Color(0.15, 0.16, 0.18))
			# 上面的 _style_button 会把字号冲回 19，补回统一字号
			(child as Button).add_theme_font_size_override("font_size", BACK_FONT_SIZE)

## 提示条字号：绿框（成功）加大到 30，红框同步提到 26 保持层级
func flash_message(msg: String, good: bool = true, dur: float = 2.2,
		font_size: int = 20, custom_color: Color = Color(-1, -1, -1),
		half_w: int = 220, half_h: int = 40, show_prefix: bool = true,
		offset_x: float = 0.0, offset_y: float = 0.0) -> void:
	var fs := maxi(font_size, 30) if good else maxi(font_size, 26)
	super.flash_message(msg, good, dur, fs, custom_color, half_w, half_h,
		show_prefix, offset_x, offset_y)

## 覆写高亮：用"培养基自发光"提示当前可点的皿，比原版微弱灰光更容易看见
func _refresh_highlights(active_names: Array) -> void:
	for nm in interactables:
		var obj: Dictionary = interactables[nm]
		var is_active: bool = nm in active_names
		obj["enabled"] = is_active

		var area_obj = obj.get("area")
		var area: Area3D = null
		if is_instance_valid(area_obj):
			area = area_obj as Area3D
		if area != null:
			area.input_ray_pickable = is_active

		var mat_obj = obj.get("mat")
		var mat: StandardMaterial3D = null
		if is_instance_valid(mat_obj):
			mat = mat_obj as StandardMaterial3D
		if mat != null:
			if is_active:
				var base: Color = obj.get("orig_color", Color.WHITE)
				mat.emission_enabled = true
				mat.emission = base * 0.35
				mat.emission_energy_multiplier = 1.0
			else:
				mat.emission_enabled = false

## 面板统一改成中性深灰半透明（覆盖 SceneBase 的墨绿）
func _apply_panel_style(p: Panel, _color: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.075, 0.085, 0.90)
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.30, 0.32, 0.34)
	p.add_theme_stylebox_override("panel", s)


func _process(delta: float) -> void:
	# 轻微手持呼吸感：纪录片镜头很少完全静止
	_cam_time += delta
	var drift := Vector3(
		sin(_cam_time * 0.31) * 0.006,
		sin(_cam_time * 0.47 + 1.1) * 0.0035,
		cos(_cam_time * 0.27) * 0.005
	) * CAM_BREATH
	camera.position = CAM_POS + drift
	camera.look_at(CAM_TARGET + Vector3(drift.x * 0.25, drift.y * 0.4, 0.0), Vector3.UP)

## 把每个皿名投影到屏幕坐标，贴在皿的前下方
func _configure_camera() -> void:
	camera.position = CAM_POS
	camera.fov = CAM_FOV
	camera.near = 0.02
	camera.far = 60.0
	camera.look_at(CAM_TARGET, Vector3.UP)

# =====================================================================
# 渲染：环境 / 灯光
# =====================================================================
func _setup_scene() -> void:
	_build_room()
	_build_bench()
	_build_dishes()
	_build_dressing()
	_build_formula_panel()
	_build_progress_panel()

func _build_room() -> void:
	var room := PropKit.spawn(self, ROOM_SCENE, Vector3.ZERO, Vector3.ZERO, {
		"room_floor": MAT_FLOOR,
		"room_back_wall": MAT_TILE,
		"room_side_wall": MAT_TILE,
		"room_skirting": PropKit.flat_material(Color(0.26, 0.27, 0.26), 0.55)
	})
	if room == null:
		return
	for node in room.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var nm := str(mi.name)
		if nm.begins_with("room_back_wall") or nm.begins_with("room_side_wall"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_bench() -> void:
	PropKit.spawn(self, BENCH_SCENE, Vector3.ZERO, Vector3.ZERO, {
		"bench_top": MAT_EPOXY,
		"bench_lip": MAT_EPOXY,
		"frame_rail": MAT_STEEL,
		"frame_leg": MAT_STEEL,
		"cabinet_handle": MAT_STEEL,
		"shelf": PropKit.flat_material(Color(0.55, 0.56, 0.55), 0.55),
		"cabinet_door": PropKit.flat_material(Color(0.72, 0.73, 0.72), 0.42)
	})

func _build_dishes() -> void:
	for i in 3:
		var media: Dictionary = MEDIA[i]
		var area := Area3D.new()
		area.name = media["key"]
		area.position = Vector3(float(DISH_X[i]), BENCH_TOP_Y, DISH_Z)
		add_child(area)

		# 每个皿一份独立琼脂材质，才能单独染色、单独高亮
		var agar_mat: StandardMaterial3D = MAT_AGAR.duplicate()
		var tint: Color = media["color"]
		agar_mat.albedo_color = Color.from_hsv(tint.h, minf(1.0, tint.s * 1.45), tint.v * 0.72)

		# 生芽/生根培养基改成培养瓶（锥形瓶），愈伤培养基仍是培养皿
		var is_flask := i > 0
		if is_flask:
			var flask := CONICAL_FLASK_SCENE.instantiate() as Node3D
			flask.scale = Vector3.ONE * 1.35            # 约 11 cm 宽、21 cm 高
			area.add_child(flask)
			PropKit.override_materials(flask, {"flask_body": MAT_GLASS})
			# 瓶底那层琼脂
			var agar := MeshInstance3D.new()
			agar.mesh = mk_cyl(0.040, 0.028)
			agar.material_override = agar_mat
			agar.position = Vector3(0.0, 0.014, 0.0)
			area.add_child(agar)
		else:
			var dish := DISH_SCENE.instantiate() as Node3D
			area.add_child(dish)
			PropKit.override_materials(dish, {
				"dish_bottom": MAT_SHELL,
				"dish_lid": MAT_SHELL,
				"agar": agar_mat
			})
			if not SHOW_DISH_LID:
				for node in dish.find_children("*", "MeshInstance3D", true, false):
					if str(node.name).begins_with("dish_lid"):
						(node as MeshInstance3D).visible = false

		PropKit.contact_shadow(area, 0.17 if not is_flask else 0.10)

		# 碰撞：皿取皿盖外径，瓶取瓶身高度，方便点中
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		if is_flask:
			cyl.radius = 0.070
			cyl.height = 0.240
			shape.position = Vector3(0.0, 0.120, 0.0)
		else:
			cyl.radius = DISH_RADIUS
			cyl.height = 0.026
			shape.position = Vector3(0.0, 0.012, 0.0)
		shape.shape = cyl
		area.add_child(shape)

		# 字号走 font_px：add() 的 world_size 会被 _font_for 钳在 27px 上限；
		# 瓶比皿高，标签和提示词都要相应抬高，否则会压在瓶身上
		var tag_y := 0.270 if is_flask else 0.095
		var media_tag := label_projector.add(media["label"], area, Vector3(0.0, tag_y, 0.02), 40,
			Color(media["color"]).lightened(0.70))
		media_tag.font_px = 30
		media_tag.bold = true   # 三个培养基名字加粗

		# 红色突出提示词：未配对时一直亮着，配对成功后淡出收起
		var hint := Label3D.new()
		hint.text = "点击选择配方"
		hint.font_size = 40
		hint.pixel_size = 0.00068      # 6 个字要按对勾那套字号缩放，否则横跨半个屏幕
		hint.modulate = Color(0.98, 0.20, 0.16)
		hint.outline_size = 10
		hint.outline_modulate = Color(0.10, 0.0, 0.0, 0.9)
		hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hint.no_depth_test = true
		hint.position = Vector3(0.0, 0.215 if is_flask else 0.058, 0.02)
		# 默认不可见：靠 SceneBase 的 _hover_enter/_hover_exit 在鼠标靠近时才显示
		hint.visible = false
		area.add_child(hint)
		hint_labels[media["key"]] = hint

		area.mouse_entered.connect(func(): _hover_enter(media["key"], agar_mat, media["hover"], area))
		area.mouse_exited.connect(func(): _hover_exit(media["key"], agar_mat, media["color"], area))
		area.input_event.connect(func(_c, ev, _p, _n, _i): _area_input(media["key"], ev))

		interactables[media["key"]] = {
			"area": area,
			"mat": agar_mat,
			"orig_color": media["color"],
			"enabled": true
		}

func _build_dressing() -> void:
	# 陪衬道具：只留烧杯，托盘/棕色试剂瓶/试管架按需求去掉
	PropKit.spawn(self, BEAKER_SCENE, Vector3(1.02, BENCH_TOP_Y, -0.26), Vector3.ZERO, {
		"beaker_body": MAT_GLASS
	})

# 道具 / 材质工具
# =====================================================================
func _build_formula_panel() -> void:
	formula_panel = Control.new()
	formula_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	formula_panel.visible = false
	canvas_layer.add_child(formula_panel)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	formula_panel.add_child(bg)

	var panel := Panel.new()
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -500; panel.offset_right = 500
	panel.offset_top = -215; panel.offset_bottom = 215
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.09, 0.10, 0.11, 0.97)
	ps.set_border_width_all(1); ps.border_color = Color(0.40, 0.42, 0.44)
	ps.set_corner_radius_all(6)
	ps.shadow_size = 18
	ps.shadow_color = Color(0, 0, 0, 0.55)
	panel.add_theme_stylebox_override("panel", ps)
	formula_panel.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 24; vb.offset_right = -24
	vb.offset_top = 18; vb.offset_bottom = -18
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)

	panel_title_lbl = Label.new()
	panel_title_lbl.text = "请选择正确配方："
	panel_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_title_lbl.add_theme_font_size_override("font_size", 30)
	panel_title_lbl.add_theme_color_override("font_color", Color(0.88, 0.91, 0.93))
	vb.add_child(panel_title_lbl)

	var sep := HSeparator.new(); vb.add_child(sep)

	# 打乱配方顺序，每次游戏不同
	shuffled_formulas.clear()
	for m in MEDIA:
		shuffled_formulas.append(m["formula"])
	shuffled_formulas.shuffle()

	formula_btns.clear()
	for i in 3:
		var btn := Button.new()
		btn.text = shuffled_formulas[i]
		btn.custom_minimum_size = Vector2(920, 66)
		_style_button(btn, Color(0.14, 0.16, 0.18))
		btn.add_theme_font_size_override("font_size", 26)
		var fi := i
		btn.pressed.connect(func(): _on_formula_chosen(shuffled_formulas[fi]))
		vb.add_child(btn)
		formula_btns.append(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "✖ 取消选择"
	cancel_btn.custom_minimum_size = Vector2(150, 38)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(cancel_btn, Color(0.22, 0.09, 0.08))
	cancel_btn.add_theme_font_size_override("font_size", 24)
	cancel_btn.pressed.connect(_close_formula_panel)
	vb.add_child(cancel_btn)

func _build_progress_panel() -> void:
	var pp := Panel.new()
	pp.anchor_right = 1.0
	pp.offset_left = -310; pp.offset_right = -10
	pp.offset_top = 70; pp.offset_bottom = 165
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.09, 0.10, 0.92)
	ps.set_border_width_all(1); ps.border_color = Color(0.42, 0.44, 0.46)
	ps.set_corner_radius_all(6)
	pp.add_theme_stylebox_override("panel", ps)
	canvas_layer.add_child(pp)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10; vb.offset_right = -10
	vb.offset_top = 8; vb.offset_bottom = -8
	pp.add_child(vb)

	var h := Label.new(); h.text = "🧪  配对进度"
	h.add_theme_font_size_override("font_size", 18)
	h.add_theme_color_override("font_color", Color(0.80, 0.84, 0.86))
	vb.add_child(h)

	matched_lbl = Label.new()
	matched_lbl.text = "已配对：0 / 3"
	matched_lbl.add_theme_font_size_override("font_size", 16)
	matched_lbl.add_theme_color_override("font_color", Color(0.86, 0.89, 0.90))
	vb.add_child(matched_lbl)

# =====================================================================
# 步骤 / 交互逻辑（与原版一致）
# =====================================================================
func _define_steps() -> void:
	steps = [
		{
			"title": "📖  配制诱导培养基",
			"body": "三种诱导培养基均以 MS基本培养基配方 为基础：\n"
				+ "• 愈伤诱导：促进花药脱分化\n"
				+ "• 生芽诱导：诱导分化出嫩芽\n"
				+ "• 生根诱导：诱导基部长出根系\n"
				+ "规律：细胞分裂素/生长素比值高→促芽，低→促根，接近1→促愈伤。",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "🧪  配对：点击培养基瓶，选择其正确配方",
			"body": "点击培养皿选择配方，三皿全部配对正确即可通关。",
			"click_to_advance": false,
			"active_objects": ["callus", "shoot", "root"]
		},
		{
			"title": "✅  三种培养基配方全部正确！",
			"body": "三种培养基均已正确配制：\n"
				+ "• 愈伤：生长素 0.5 + 细胞分裂素 0.5 mg/L\n"
				+ "• 生芽：细胞分裂素 6 mg/L > 生长素 1 mg/L\n"
				+ "• 生根：仅生长素 0.5 mg/L\n"
				+ "规律：两者比例决定分化方向。",
			"click_to_advance": true,
			"active_objects": [],
			"completion_text": "培养基配制完成！\n愈伤：生长素与细胞分裂素各 0.5 mg/L\n生芽：细胞分裂素 6 mg/L > 生长素 1 mg/L\n生根：仅生长素 0.5 mg/L\n下一步：田间选取花药材料。"
		},
	]

func _on_interactable_clicked(obj_name: String) -> void:
	if current_step_index != 1:
		return
	if matched.get(obj_name, false):
		flash_message("该培养基已配对完成", true)
		return
	selected_key = obj_name
	for m in MEDIA:
		if m["key"] == obj_name:
			panel_title_lbl.text = "请为【%s】选择正确配方：" % m["label"]
			break
	formula_panel.visible = true

func _on_formula_chosen(formula_text: String) -> void:
	if selected_key.is_empty():
		return
	var expected := ""
	for m in MEDIA:
		if m["key"] == selected_key:
			expected = m["formula"]
			break
	if formula_text != expected:
		# 选错即本轮作废：哪怕之后改对，也必须三种全部重配
		round_failed = true
		flash_message("配方不对！请仔细对比各培养基的激素种类和比例。", false)
		return

	matched[selected_key] = true
	_pulse_matched(selected_key)
	_close_formula_panel()
	_update_progress()

	var remain := PackedStringArray()
	for m in MEDIA:
		if not matched.has(m["key"]):
			remain.append(String(m["label"]))
	if not remain.is_empty():
		# 只发这一条：直接说清还差哪几个，不再先播"配方配对正确"
		flash_message("已配对 %d 种，还剩 %s 未选择" % [matched.size(), "、".join(remain)],
			true, 2.0, 24, Color(1.0, 0.92, 0.55))
		return

	if round_failed:
		# 清掉队列里还没播的提示，让判错提示立刻出现
		_toast_queue.clear()
		if is_instance_valid(_last_toast):
			_last_toast.queue_free()
			_last_toast = null
		_toast_skip = true
		flash_message("由于培养基配方匹配过程中出现过错误，请重新完成三种培养基的匹配",
			false, 3.5, 22, Color(1.0, 0.85, 0.25), 620, 44)
		# 等排队中的提示播完，再清空配对，确保玩家看到判错提示
		await get_tree().create_timer(2.0).timeout
		_reset_matching()
		return

	flash_message("三种培养基全部配对正确！", true, 1.2)
	await get_tree().create_timer(0.8).timeout
	advance_step()

## 三种培养基全部重配：清空配对状态、恢复琼脂亮度与红色提示词
func _reset_matching() -> void:
	matched.clear()
	round_failed = false
	_update_progress()
	for m in MEDIA:
		var key: String = m["key"]
		var mat := interactables.get(key, {}).get("mat") as StandardMaterial3D
		if mat:
			mat.emission_enabled = false
		var hint := hint_labels.get(key) as Label3D
		if is_instance_valid(hint):
			hint.modulate.a = 1.0
	_refresh_highlights(["callus", "shoot", "root"])

func _pulse_matched(key: String) -> void:
	var area := interactables.get(key, {}).get("area") as Area3D
	if not area: return
	var tw := create_tween()
	tw.tween_property(area, "scale", Vector3(1.12, 1.12, 1.12), 0.15)
	tw.tween_property(area, "scale", Vector3(1.0, 1.0, 1.0), 0.15)

	# 配对成功的皿要"看得出来"：琼脂自发光 + 红色提示词淡出
	var mat := interactables[key].get("mat") as StandardMaterial3D
	if mat:
		mat.emission_enabled = true
		mat.emission = mat.albedo_color * 0.55
	var hint := hint_labels.get(key) as Label3D
	if is_instance_valid(hint):
		var fade := create_tween()
		fade.tween_property(hint, "modulate:a", 0.0, 0.25)
		# 配对完成后直接销毁，免得之后再悬停又冒出来
		fade.tween_callback(func(): hint.queue_free())
		hint_labels.erase(key)

func _close_formula_panel() -> void:
	formula_panel.visible = false
	selected_key = ""

func _update_progress() -> void:
	if matched_lbl:
		matched_lbl.text = "已配对：%d / 3" % matched.size()