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
# 已经用显微镜看过的植株下标：四株都看过才允许进入下一步
var viewed_plants: Dictionary = {}
var verdict_lbl: Label          # 镜检界面顶部的标记对错反馈
var decided_plants: Dictionary = {}   # 已经点过“标记为单倍体”的植株（不论对错）
var round_failed: bool = false   # 本轮只要点错过一次判定按钮，整轮作废

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
const MAT_FLOOR := preload("res://materials/floor_epoxy.tres")
const MAT_BENCH := preload("res://materials/epoxy_bench.tres")
const MAT_STEEL := preload("res://materials/stainless.tres")
const MAT_LEAF := preload("res://materials/plantlet_leaf.tres")
const MAT_STEM := preload("res://materials/plantlet_stem.tres")
const MAT_MICRO := preload("res://materials/microscope_body.tres")
const MAT_MICRO_LENS := preload("res://materials/microscope_lens.tres")
const MAT_AGAR := preload("res://materials/agar.tres")

func _ready() -> void:
	scene_number = 6
	scene_title  = "倍性鉴定"
	env_preset = "indoor"
	light_focus = Vector3(0.0, 1.5, -0.2)
	light_radius = 4.0
	light_intensity = 0.38
	# 随机化（保证至少1株单倍体）
	plant_chromosomes[randi() % 4] = HAPLOID_N
	plant_chromosomes[(randi() % 3 + 1 + plant_chromosomes.find(HAPLOID_N)) % 4] = DIPLOID_2N
	super._ready()
	# 背景不再是白墙，改成中性中灰；曝光也压下来，避免整屏发白过曝
	for node in get_children():
		if node is WorldEnvironment and node.environment != null:
			node.environment.background_color = Color(0.085, 0.095, 0.115)
			node.environment.tonemap_exposure = 0.82

func _configure_camera() -> void:
	camera.position = Vector3(0.0, 2.45, 6.60)
	camera.look_at(Vector3(0.0, 1.28, 0.05))
	camera.fov = 55.0

func _setup_scene() -> void:
	_build_lab()
	_build_microscope()
	_build_plants()
	_build_microscope_overlay()

## ③ 确认鉴定结果 这一步，右下角按钮改叫"已确认"，其余步骤仍用"继续"
func _show_step(idx: int) -> void:
	super._show_step(idx)
	if is_instance_valid(next_btn):
		next_btn.text = "已确认" if idx == 3 else "继续 ▶"

## ③ 步的【已确认】：先让玩家确认，再判定标记对错
func _on_next_pressed() -> void:
	if current_step_index == 3:
		_judge_on_confirm()
		return
	super._on_next_pressed()

func _build_lab() -> void:
	var floor_mi := add_static(mk_plane(Vector2(22, 22)), Vector3.ZERO, Color.WHITE)
	# 地面单独压暗：浅色地坪在强光下一路延伸到地平线，会把画面中部烧成一片白
	var floor_mat := MAT_FLOOR.duplicate() as StandardMaterial3D
	floor_mat.albedo_color = floor_mat.albedo_color.darkened(0.18)
	floor_mi.material_override = floor_mat
	# 背景墙已去掉，背后直接是环境背景色（见 _ready 里的 background_color）

	# 台面（深色环氧）+ 不锈钢腿
	var top := add_static(mk_box(Vector3(8.4, 0.10, 3.0)), Vector3(0, 0.92, -0.4), Color.WHITE)
	top.material_override = MAT_BENCH
	for xo in [-3.9, 3.9]:
		for zo in [-1.7, 1.0]:
			var leg := add_static(mk_box(Vector3(0.09, 0.87, 0.09)), Vector3(xo, 0.435, zo), Color.WHITE)
			leg.material_override = MAT_STEEL

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
	}, Vector3(5.6, 5.6, 5.6))

	# 红色悬停提示词：文字放在镜身右侧，避开上方那条蓝色固定标签
	create_interactable("microscope",
		Vector3(0.0, 1.60, -0.55), mk_box(Vector3(1.1, 1.7, 0.95)),
		Color(0.28, 0.28, 0.32, 0.0), Color(0.55, 0.55, 0.68), "点击显微镜对不同辣椒植株进行染色体镜检")
	interactables["microscope"]["area"].get_child(0).visible = false
	# 单行、蓝色常规字重（原来是两行紫色带深色描边）
	# 字号走 font_px：add_label3d 的 size 参数会被 _font_for() 钳在 27px 上限，
	# 想再大只能直接给像素字号。位置抬到 3.33 是为了避开显微镜镜身。
	var micro_lbl := add_label3d("光学显微镜（点击观察）", Vector3(0.0, 3.44, -0.55), 52, Color.WHITE)
	micro_lbl.font_px = 40
	# 白字配深色描边，免得压在浅色背景/镜身上糊掉
	micro_lbl.outline_size = 6
	micro_lbl.outline_modulate = Color(0.05, 0.08, 0.14, 0.9)

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
		# 名字标签：下移到 2.10，字号走 font_px（size 参数会被 _font_for 钳在 27px）
		var plant_lbl := add_label3d(names[i], Vector3(x, 2.10, 1.0), 52, Color(0.25, 0.95, 0.35))
		plant_lbl.font_px = 30
		plant_lbl.outline_size = 8
		plant_lbl.outline_modulate = Color(0.0, 0.2, 0.0, 0.8)

func _draw_small_plant(pos: Vector3, idx: int) -> void:
	# 只留培养基（原来的玻璃培养瓶罩已去掉）
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
	view_panel.offset_left = -320; view_panel.offset_right = 320
	view_panel.offset_top = -272; view_panel.offset_bottom = 272
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.0, 0.05, 0.0)
	ps.set_border_width_all(6); ps.border_color = Color(0.3, 0.3, 0.35)
	ps.set_corner_radius_all(272)
	view_panel.add_theme_stylebox_override("panel", ps)
	micro_overlay.add_child(view_panel)

	# 染色体绘制区（用Label3D无法用，直接Label）
	chrom_display = Label.new()
	chrom_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrom_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chrom_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chrom_display.add_theme_font_size_override("font_size", 42)
	chrom_display.add_theme_color_override("font_color", Color(0.6, 0.9, 0.65))
	# 染色体符号加粗：embolden 加字重 + 同色描边再加粗一圈，
	# 细竖线在深绿底上太单薄，不这样处理几乎看不出是"染色体"
	var chrom_fv := FontVariation.new()
	chrom_fv.base_font = chrom_display.get_theme_font("font")
	chrom_fv.variation_embolden = 1.2
	chrom_display.add_theme_font_override("font", chrom_fv)
	chrom_display.add_theme_constant_override("outline_size", 5)
	chrom_display.add_theme_color_override("font_outline_color", Color(0.55, 0.88, 0.60))
	view_panel.add_child(chrom_display)

	chrom_count_lbl = Label.new()
	chrom_count_lbl.anchor_left = 0.5; chrom_count_lbl.anchor_right = 0.5
	chrom_count_lbl.anchor_top = 0.5; chrom_count_lbl.anchor_bottom = 0.5
	chrom_count_lbl.offset_left = -300; chrom_count_lbl.offset_right = 300
	chrom_count_lbl.offset_top = 284; chrom_count_lbl.offset_bottom = 336
	chrom_count_lbl.text = ""
	chrom_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chrom_count_lbl.add_theme_font_size_override("font_size", 32)
	chrom_count_lbl.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	micro_overlay.add_child(chrom_count_lbl)

	# 标记结论：点完【标记为单倍体】后在镜检界面顶部给出对错反馈
	verdict_lbl = Label.new()
	verdict_lbl.anchor_left = 0.0; verdict_lbl.anchor_right = 1.0
	verdict_lbl.anchor_top = 0.0; verdict_lbl.anchor_bottom = 0.0
	verdict_lbl.offset_top = 62; verdict_lbl.offset_bottom = 116
	verdict_lbl.text = ""
	verdict_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	verdict_lbl.add_theme_font_size_override("font_size", 34)
	verdict_lbl.add_theme_constant_override("outline_size", 6)
	verdict_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.95))
	verdict_lbl.visible = false
	micro_overlay.add_child(verdict_lbl)

	var close_btn := Button.new()
	close_btn.text = "✖  关闭显微镜视野"
	close_btn.anchor_left = 0.5; close_btn.anchor_right = 0.5
	close_btn.anchor_top = 0.5; close_btn.anchor_bottom = 0.5
	close_btn.offset_left = -180; close_btn.offset_right = 180
	close_btn.offset_top = 344; close_btn.offset_bottom = 398
	_style_button(close_btn, Color(0.22, 0.10, 0.06))
	close_btn.add_theme_font_size_override("font_size", 27)
	close_btn.pressed.connect(_close_microscope)
	micro_overlay.add_child(close_btn)

	# 两个判定按钮：蓝色=标记为单倍体，粉色=不标记为单倍体
	var mark_yes := Button.new()
	mark_yes.text = "✓  标记为单倍体植株"
	mark_yes.anchor_left = 0.5; mark_yes.anchor_right = 0.5
	mark_yes.anchor_top = 0.5; mark_yes.anchor_bottom = 0.5
	mark_yes.offset_left = -310; mark_yes.offset_right = -14
	mark_yes.offset_top = 408; mark_yes.offset_bottom = 466
	_style_button(mark_yes, Color(0.12, 0.30, 0.62))     # 蓝
	mark_yes.add_theme_font_size_override("font_size", 24)
	mark_yes.pressed.connect(func(): _decide(true))
	micro_overlay.add_child(mark_yes)

	var mark_no := Button.new()
	mark_no.text = "✗  不标记为单倍体植株"
	mark_no.anchor_left = 0.5; mark_no.anchor_right = 0.5
	mark_no.anchor_top = 0.5; mark_no.anchor_bottom = 0.5
	mark_no.offset_left = 14; mark_no.offset_right = 310
	mark_no.offset_top = 408; mark_no.offset_bottom = 466
	_style_button(mark_no, Color(0.58, 0.24, 0.44))      # 粉
	mark_no.add_theme_font_size_override("font_size", 24)
	mark_no.pressed.connect(func(): _decide(false))
	micro_overlay.add_child(mark_no)

## 提示条（绿=成功 / 红=失败）默认落在屏幕正中，正好压住四株植物和显微镜。
## 挪到上方空墙面：下沿约 y=264，与 y≈290 起的名字标签留出间隙。
## 字号从基类默认的 20 抬到 26，底板高度同步加高，免得文字贴边。
func flash_message(msg: String, good: bool = true, dur: float = 2.2,
		font_size: int = 20, custom_color: Color = Color(-1, -1, -1),
		half_w: int = 220, half_h: int = 40, show_prefix: bool = true,
		offset_x: float = 0.0, offset_y: float = -395.0) -> void:
	super.flash_message(msg, good, dur, maxi(font_size, 26), custom_color,
		half_w, maxi(half_h, 44), show_prefix, offset_x, offset_y)

## 悬停名牌（偏红）默认贴在物体顶端，会压住固定的名字标签。
## 抬 0.30 世界单位，让名牌落在"显微镜蓝标签(y≈235)"与"A株/B株名标签(y≈355)"之间的空档，
## 两行都不遮。
func _tooltip_offset(obj_name: String) -> Vector3:
	# 最左/最右两株的名牌会被屏幕边缘切掉，横向往画面内侧挪一点
	match obj_name:
		# 植物：红色提示词落到绿色名字标签的"下方"（偏移为负=往下）
		"plant_0": return Vector3(0.75, -0.45, 0.0)
		"plant_3": return Vector3(-0.75, -0.45, 0.0)
		"microscope": return Vector3(0.0, 0.30, 0.0)   # 蓝色标签正下方
	return Vector3(0.0, -0.45, 0.0)

## 悬停名牌字号收小：默认 39 时"点击查看 A株 染色体"太宽，最左/最右两株会被屏幕边缘切掉
func _style_tooltip(obj_name: String, lbl: Label3D) -> void:
	# 显微镜的提示词是唯一的红色高亮；文案较长，字号反而要收一点，免得横跨半个屏幕
	lbl.font_size = 34 if obj_name == "microscope" else 30

func _define_steps() -> void:
	steps = [
		{
			"title": "📖  倍性鉴定——筛选真正的单倍体",
			"body": "花药中不同区域细胞所含有的染色体数不同：\n"
				+ "• 小孢子（花粉）：n = 12\n"
				+ "• 花药壁、药隔细胞：2n = 24\n"
				+ "• 也可能出现含有多个染色体组的细胞\n"
				+ "须用【显微镜染色体计数】鉴定，才能筛出真正的单倍体植株。",
			"click_to_advance": true,
			"active_objects": []
		},
		{
			"title": "① 激活显微镜",
			"body": "点击显微镜激活观察模式，随后逐株观察根尖细胞染色体数。",
			"click_to_advance": false,
			"active_objects": ["microscope"],
			"correct_object": "microscope",
			"correct_message": "显微镜已激活！"
		},
		{
			"title": "② 观察各植株染色体，标记单倍体",
			"body": "单倍体 n = 12，二倍体 2n = 24。\n"
				+ "点击每株观察染色体数，再用蓝/粉按钮判断；四株都看完并判断后点【已确认】。",
			"click_to_advance": false,
			"active_objects": ["plant_0", "plant_1", "plant_2", "plant_3"]
		},
		{
			"title": "③ 确认鉴定结果",
			"body": "确认已正确标记单倍体植株。",
			"click_to_advance": true,
			"active_objects": [],
			"completion_text": "倍性鉴定完成！已通过显微镜计数筛出单倍体植株（n = 12）。\n※实际还可用流式细胞仪、SSR 标记快速鉴定。\n※下一步：用秋水仙素溶液对单倍体植株幼苗的茎尖进行染色体加倍处理，获得纯合二倍体植株（DH 系）。"
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
	viewed_plants[plant_idx] = true   # 记一笔“这株看过了”
	if verdict_lbl:
		verdict_lbl.text = ""
		verdict_lbl.visible = false
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
	# 是否要判定由 _check_can_advance 自己决定：一轮没走完就安静返回
	_check_can_advance()

## 玩家用蓝/粉两个按钮做出的判断（true = 标记为单倍体）
func _decide(claim_haploid: bool) -> void:
	if current_viewed_plant < 0:
		return
	var idx := current_viewed_plant
	var n := plant_chromosomes[idx]
	var plant_names := ["A株", "B株", "C株", "D株"]
	var truth := n == HAPLOID_N
	selected_plants[idx] = claim_haploid
	if claim_haploid != truth:
		# 点错即整轮作废：之后就算改点对的按钮也算出错
		round_failed = true
	decided_plants[idx] = true
	if verdict_lbl:
		verdict_lbl.visible = true
		if claim_haploid == truth:
			verdict_lbl.text = "✓  判断正确：%s %s" % [plant_names[idx],
				"是单倍体（n=12）" if truth else "不是单倍体（%d 条染色体）" % n]
			verdict_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
		else:
			verdict_lbl.text = "✗  判断错误：%s 实际%s" % [plant_names[idx],
				"是单倍体（n=12）" if truth else "不是单倍体（%d 条染色体）" % n]
			verdict_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.32))

## 每次关闭镜检都会走这里：
## ① 还有植株没看 → 提示剩余哪些没观察
## ② 都看过但还没全部标记 → 提示剩余哪些还没标记
## 一轮走完 → 进入「③ 确认鉴定结果」，此时**还不判定**；
## 判定发生在玩家点右下角【已确认】时（见 _on_next_pressed → _judge_on_confirm）
func _check_can_advance() -> void:
	if current_step_index != 2:
		return
	var plant_names := ["A株", "B株", "C株", "D株"]

	var unviewed := PackedStringArray()
	var undecided := PackedStringArray()
	for i in 4:
		if not viewed_plants.has(i):
			unviewed.append(plant_names[i])
		elif not decided_plants.has(i):
			undecided.append(plant_names[i])
	if not unviewed.is_empty():
		flash_message("还有 %s 没有观察，请继续镜检" % "、".join(unviewed),
			false, 2.0, 26, Color(1.0, 0.85, 0.25))
		return
	if not undecided.is_empty():
		flash_message("还有 %s 还没有做出标记判断" % "、".join(undecided),
			false, 2.0, 26, Color(1.0, 0.85, 0.25))
		return

	# 四株都观察并判断完 → 先进入确认步骤
	advance_step()
	_refresh_highlights([])

## 玩家在「③ 确认鉴定结果」点【已确认】时才真正判定
func _judge_on_confirm() -> void:
	var plant_names := ["A株", "B株", "C株", "D株"]
	var unmarked := PackedStringArray()
	var wrong := PackedStringArray()
	for i in 4:
		var is_haploid := plant_chromosomes[i] == HAPLOID_N
		if is_haploid and not selected_plants[i]:
			unmarked.append(plant_names[i])
		elif not is_haploid and selected_plants[i]:
			wrong.append(plant_names[i])
	if round_failed or not unmarked.is_empty() or not wrong.is_empty():
		flash_message("由于刚才对于单倍体植株的标记过程存在错误，请重新对植株A-D进行镜检并重新标记单倍体植株",
			false, 3.5, 22, Color(1.0, 0.85, 0.25), 620, 44)
		# 判错 → 清空本轮记录，退回第 ② 步重来
		viewed_plants.clear()
		decided_plants.clear()
		round_failed = false   # 新一轮开始，重新计
		for i in 4:
			selected_plants[i] = false
		_show_step(2)
		_refresh_highlights(["plant_0", "plant_1", "plant_2", "plant_3"])
		return
	flash_message("标记正确，可以进入下一关", true, 2.2, 26, Color(0.55, 1.0, 0.60))
	await get_tree().create_timer(1.0).timeout
	advance_step()