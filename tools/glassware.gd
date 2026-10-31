## glassware.gd — 玻璃器皿检查台
##
## 只给开发用：把四种瓶型按真实比例摆一排，配和游戏内一致的光照，
## 用来检查剖面、瓶盖、壁厚这些近距离细节。不影响正式场景。
##
## 运行：
##   Godot --path . res://tools/glassware.tscn -- --out res://docs/shots/g.png --wait 30
extends Node3D

const BOTTLE := preload("res://assets/props/reagent_bottle.glb")
const MEDIA := preload("res://assets/props/media_bottle.glb")
const BEAKER := preload("res://assets/props/beaker.glb")
const FLASK := preload("res://assets/props/conical_flask.glb")

const MAT_AMBER := preload("res://materials/amber_glass.tres")
const MAT_CLEAR := preload("res://materials/clear_bottle.tres")
const MAT_THIN_GLASS := preload("res://materials/glassware_clear.tres")
const MAT_WHITE := preload("res://materials/white_bottle.tres")
const MAT_CAP := preload("res://materials/cap_black.tres")
const MAT_CAP_BLUE := preload("res://materials/cap_blue.tres")
const MAT_BENCH := preload("res://materials/epoxy_bench.tres")
const MAT_TILE := preload("res://materials/tile_wall.tres")

var camera: Camera3D

func _ready() -> void:
	CinematicLab.setup_environment(self, "lab")
	CinematicLab.setup_lighting(self, Vector3(0.0, 0.10, 0.0), 0.45, "lab", 0.85)

	var bench := MeshInstance3D.new()
	var top := BoxMesh.new()
	top.size = Vector3(1.6, 0.04, 0.9)
	bench.mesh = top
	bench.material_override = MAT_BENCH
	bench.position = Vector3(0.0, -0.02, 0.0)
	add_child(bench)

	var wall := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.2, 1.4)
	wall.mesh = plane
	wall.material_override = MAT_TILE
	wall.position = Vector3(0.0, 0.68, -0.45)
	add_child(wall)

	_spawn(BOTTLE, Vector3(-0.42, 0.0, 0.0), {
		"reagent_bottle_body": MAT_AMBER,
		"reagent_bottle_cap": MAT_CAP,
		"reagent_bottle_cap_rib": MAT_CAP,
		"reagent_bottle_cap_thread": MAT_CAP,
	})
	_spawn(MEDIA, Vector3(-0.14, 0.0, 0.0), {
		"media_bottle_body": MAT_CLEAR,
		"media_bottle_cap": MAT_CAP_BLUE,
		"media_bottle_cap_rib": MAT_CAP_BLUE,
		"media_bottle_cap_thread": MAT_CAP_BLUE,
	})
	_spawn(BEAKER, Vector3(0.14, 0.0, 0.0), {"beaker_body": MAT_THIN_GLASS, "beaker_mark": MAT_THIN_GLASS})
	_spawn(FLASK, Vector3(0.40, 0.0, 0.0), {"flask_body": MAT_THIN_GLASS})

	camera = Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.01
	add_child(camera)
	camera.position = Vector3(0.0, 0.30, 1.38)
	camera.look_at(Vector3(-0.01, 0.10, 0.0), Vector3.UP)

func _spawn(scene: PackedScene, pos: Vector3, mapping: Dictionary) -> void:
	PropKit.spawn(self, scene, pos, Vector3.ZERO, mapping)
