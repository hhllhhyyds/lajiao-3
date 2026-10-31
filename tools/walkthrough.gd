## walkthrough.gd — 自动走关检查
##
## 逐步骤推进一个关卡，每一步截一张图，并把该步的交互物投影到屏幕坐标，
## 检查是否还在可视范围内。只看首帧会漏掉"物件移动后出画""某步根本没有可点对象"
## 这类问题。
##
## 用法：
##   Godot --path . res://tools/walkthrough.tscn -- \
##       --scene res://scenes/Scene2.tscn --out res://docs/steps --wait 20
##
## 输出：
##   <out>/<scene>_step0.png …              每步一张
##   <out>/<scene>_stepN_after.png          该步点击后的状态（有 correct_object 时）
##   终端打印每步的 active_objects / 屏幕位置 / 是否出画
extends Node

var _scene_path := ""
var _out_dir := "res://docs/steps"
var _wait := 20
var _scene: Node = null
var _tick := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var a := args[i]
		if a == "--scene" and i + 1 < args.size():
			_scene_path = args[i + 1]
		elif a.begins_with("--scene="):
			_scene_path = a.substr(8)
		elif a == "--out" and i + 1 < args.size():
			_out_dir = args[i + 1]
		elif a.begins_with("--out="):
			_out_dir = a.substr(6)
		elif a == "--wait" and i + 1 < args.size():
			_wait = int(args[i + 1])
		elif a.begins_with("--wait="):
			_wait = int(a.substr(7))

	if _scene_path == "":
		push_error("walkthrough: 需要 --scene")
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))

	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("walkthrough: 场景加载失败 %s" % _scene_path)
		get_tree().quit(1)
		return
	_scene = packed.instantiate()
	add_child(_scene)

	_run()


func _run() -> void:
	await _frames(30)

	var steps: Array = _scene.get("steps")
	if steps.is_empty():
		push_warning("walkthrough: 该场景没有 steps")
		await _shot("0")
		_finish()
		return

	var idx: int = 0
	var guard := 0
	while idx < steps.size() and guard < 40:
		guard += 1
		_scene._show_step(idx)
		await _frames(_wait)
		# 入场动画（镊子抬起、培养皿移动等）通常 0.5~0.8 s，
		# 不等它稳住就截图，拍到的还是上一帧的姿势
		await get_tree().create_timer(1.9).timeout

		var step: Dictionary = steps[idx]
		print("\n[step %d] %s" % [idx, str(step.get("title", "")).left(40)])
		print("   active: ", step.get("active_objects", []))
		_report_visibility(step.get("active_objects", []))

		await _shot("step%d" % idx)

		var before: int = idx
		if step.has("correct_object"):
			_scene._on_interactable_clicked(step["correct_object"])
			# 场景内部有 1~2 秒的动画 await，抢跑会把它的 advance_step 顶掉，
			# 表现就是"下一步被跳过"。这里等它自己推进。
			var waited := 0.0
			while int(_scene.get("current_step_index")) <= before and waited < 4.0:
				await get_tree().create_timer(0.1).timeout
				waited += 0.1
			await _frames(_wait)
			await _shot("step%d_after" % idx)
		else:
			_scene.advance_step()
			await _frames(_wait)

		idx = int(_scene.get("current_step_index"))
		if idx <= before and idx < steps.size():
			_scene.advance_step()
			await _frames(_wait)
			idx = int(_scene.get("current_step_index"))

	await _frames(_wait)
	await _shot("complete")
	_finish()


## 把交互物投影到屏幕，越界就报出来
func _report_visibility(names: Array) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		print("   !! 没有相机")
		return
	var vp := get_viewport().get_visible_rect().size
	for nm in names:
		var area: Area3D = _scene.interactables.get(nm, {}).get("area")
		if area == null:
			print("   !! %s 不存在" % nm)
			continue
		var world: Vector3 = area.global_position
		if cam.is_position_behind(world):
			print("   !! %s 在相机背后 (%.2f, %.2f, %.2f)" % [nm, world.x, world.y, world.z])
			continue
		var sp: Vector2 = cam.unproject_position(world)
		var on := sp.x >= 0.0 and sp.x <= vp.x and sp.y >= 0.0 and sp.y <= vp.y
		var flag := "OK " if on else "出画"
		print("   %s %-22s screen=(%.0f, %.0f)  世界=(%.2f, %.2f, %.2f)" % [flag, nm, sp.x, sp.y, world.x, world.y, world.z])


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [_out_dir, _scene_path.get_file().get_basename(), tag]
	img.save_png(ProjectSettings.globalize_path(path))
	print("   [shot] %s" % path)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _finish() -> void:
	print("\n[walkthrough] 完成")
	get_tree().quit(0)
