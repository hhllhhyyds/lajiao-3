## capture.gd — 独立的开发截图工具（不侵入任何游戏脚本）
## 用法：
##   Godot --path . res://tools/capture.tscn --log-file ./.logs/cap.log \
##         -- --scene res://scenes/Scene1.tscn --out res://docs/shots/x.png --wait 40
extends Node

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := "res://scenes/Scene1.tscn"
	var out_path := "res://docs/shots/shot.png"
	var wait := 40
	for i in args.size():
		match args[i]:
			"--scene":
				if i + 1 < args.size(): scene_path = args[i + 1]
			"--out":
				if i + 1 < args.size(): out_path = args[i + 1]
			"--wait":
				if i + 1 < args.size(): wait = int(args[i + 1])

	var cam_override := ""
	for i in args.size():
		if args[i] == "--cam" and i + 1 < args.size():
			cam_override = args[i + 1]
		elif args[i].begins_with("--cam="):
			cam_override = args[i].substr(6)

	var dump := args.has("--dump")

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("场景加载失败: " + scene_path)
		get_tree().quit(1)
		return
	add_child(packed.instantiate())

	if dump:
		await get_tree().process_frame
		_dump(get_tree().root)
		get_tree().quit()
		return

	if cam_override != "":
		await get_tree().process_frame
		_apply_cam(cam_override)

	for _i in wait:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out_path)
	print("SHOT_SAVED ", out_path, " ", img.get_size(), " err=", err)
	get_tree().quit()

func _dump(node: Node, depth: int = 0) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var mat_path := "(内置)"
			if mi.material_override != null:
				var rp := mi.material_override.resource_path
				mat_path = rp.get_file() if rp != "" else "(内联)"
			var g := mi.global_transform.origin
			print("  ".repeat(depth), mi.name, " | mat=", mat_path,
				" | pos=", g.snapped(Vector3(0.01, 0.01, 0.01)), " | vis=", mi.visible,
				" | aabb_y=", mi.get_aabb().size.y)
		elif child is Area3D:
			print("  ".repeat(depth), "[Area] ", child.name, " pos=", (child as Area3D).position)
		_dump(child, depth + 1)

## --cam x,y,z,tx,ty,tz,fov  —— 覆盖机位，方便拍特写检查模型细节
func _apply_cam(spec: String) -> void:
	var parts := spec.split(",")
	if parts.size() < 6:
		push_warning("--cam 需要 6 个分量")
		return
	var pos := Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	var target := Vector3(float(parts[3]), float(parts[4]), float(parts[5]))
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		push_warning("场景里没有 Camera3D")
		return
	cam.position = pos
	cam.look_at(target, Vector3.UP)
	if parts.size() >= 7:
		cam.fov = float(parts[6])
