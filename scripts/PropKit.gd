## PropKit.gd — 道具装载与材质覆盖
##
## 约定（来自 blender/build_props.py）
## -------------------------------
## * 单位米，原点在物理底面中心，Godot 里直接摆到台面高度就是"放上去"。
## * GLB 里的零件按固定名字命名（dish_bottom / bottle_body / bench_top …），
##   这里按**前缀**匹配给 `material_override`，所以改材质不用重新导出模型。
##
## 用法
## ----
##     var dish := PropKit.spawn(self, DISH_SCENE, Vector3(0, 0.9, 0), Vector3.ZERO, {
##         "dish_bottom": MAT_SHELL,
##         "agar": agar_mat,
##     })
##     PropKit.contact_shadow(dish, 0.17)
class_name PropKit
extends RefCounted

const MAT_CONTACT := preload("res://materials/contact_shadow.tres")

## 实例化道具并按名字前缀覆盖材质。返回道具根节点（失败返回 null）。
static func spawn(parent: Node3D, scene: PackedScene, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO, mapping: Dictionary = {},
		scl: Vector3 = Vector3.ONE) -> Node3D:
	if scene == null:
		push_error("PropKit.spawn: PackedScene 为空")
		return null
	var node := scene.instantiate() as Node3D
	if node == null:
		push_error("PropKit.spawn: 根节点不是 Node3D")
		return null
	node.position = pos
	node.rotation_degrees = rot_deg
	node.scale = scl
	parent.add_child(node)
	if not mapping.is_empty():
		override_materials(node, mapping)
	return node

## 按节点名前缀覆盖材质（递归整棵子树）。前缀匹配按 mapping 的插入顺序进行。
static func override_materials(root: Node, mapping: Dictionary) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var key := str(child.name)
			for prefix in mapping.keys():
				if key.begins_with(prefix):
					(child as MeshInstance3D).material_override = mapping[prefix]
					break
		override_materials(child, mapping)

## 假接触阴影：贴地的一张暗斑，补上 Compatibility 后端没有的 SSAO。
## 没有这层暗角，器皿看起来是"贴"在台面上的。
static func contact_shadow(parent: Node3D, size: float,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var decal := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	decal.mesh = quad
	decal.material_override = MAT_CONTACT
	decal.rotation_degrees = Vector3(-90.0, 0.0, 0.0) + rot_deg
	decal.position = Vector3(0.0, 0.0008, 0.0)
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(decal)
	return decal

## 一个不带贴图的纯色 PBR 材质，用于少数不需要纹理的零件
static func flat_material(color: Color, roughness: float,
		metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
