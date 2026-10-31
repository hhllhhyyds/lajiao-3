#!/usr/bin/env python3
"""样板关道具建模脚本（Blender 5.x headless）。

设计约定
--------
* 单位 = 米，全部道具按真实尺寸建模（培养皿 Ø90 mm，实验台 2.4 m）。
* Blender 里用 Z 轴朝上建模，导出 GLB 时 `export_yup=True` 自动转成 Godot 的
  Y-up，所以道具在 Godot 里"底面 = y 0"。
* 每个道具的**原点放在物理底面中心**，Godot 里直接摆到台面高度即可。
* 贴图不在这里做：Blender 只负责几何，材质由 Godot 侧 `materials/*.tres`
  按节点名覆盖（浅色分离，改材质不用重新导出模型）。
* 每个道具单独导出一个 GLB 到 assets/props/。

用法
----
    /Applications/Blender.app/Contents/MacOS/Blender -b --python blender/build_props.py
"""

from __future__ import annotations

import math
import os
import sys

import bpy
from mathutils import Vector

# Blender 的 --python 不会把脚本目录加进 sys.path，手动补上
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import plant_lib  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "props")

Vec = tuple[float, float, float]

# ----------------------------------------------------------------------------- 基础工具


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def new_material(name: str, color: Vec, roughness: float,
                 metallic: float = 0.0, alpha: float = 1.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.blend_method = "BLEND"
    return mat


def finish(obj: bpy.types.Object, name: str, material: bpy.types.Material,
           smooth_angle: float = math.radians(35.0)) -> bpy.types.Object:
    obj.name = name
    obj.data.name = name
    obj.data.materials.clear()
    obj.data.materials.append(material)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    try:
        bpy.ops.object.shade_auto_smooth(angle=smooth_angle)
    except Exception:
        bpy.ops.object.shade_smooth()
    return obj


def box(name: str, size: Vec, center: Vec, material: bpy.types.Material,
        bevel: float = 0.002, segments: int = 2) -> bpy.types.Object:
    """以中心点定位的长方体；size = (X 宽, Y 深, Z 高)。"""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(30.0)
    return finish(obj, name, material)


def cylinder(name: str, radius: float, depth: float, center: Vec,
             material: bpy.types.Material, vertices: int = 64,
             bevel: float = 0.0006, cap: bool = True) -> bpy.types.Object:
    """轴向为 Z 的圆柱。"""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=center,
        end_fill_type="NGON" if cap else "NOTHING",
    )
    obj = bpy.context.object
    if bevel > 0.0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(30.0)
    return finish(obj, name, material, smooth_angle=math.radians(50.0))


def cup(name: str, radius: float, height: float, wall: float, center: Vec,
        material: bpy.types.Material, vertices: int = 48,
        with_bottom: bool = True) -> bpy.types.Object:
    """无盖杯体：侧壁 + 壁厚(Solidify) + 可选底板。center 为杯体中心。"""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=height, location=center,
        end_fill_type="NOTHING",
    )
    wall_obj = bpy.context.object

    solid = wall_obj.modifiers.new("solidify", "SOLIDIFY")
    solid.thickness = wall
    solid.offset = -1.0
    solid.use_rim = True

    bevel = wall_obj.modifiers.new("bevel", "BEVEL")
    bevel.width = min(0.0008, wall * 0.5)
    bevel.segments = 2
    bevel.limit_method = "ANGLE"

    if with_bottom:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=vertices, radius=radius - wall * 0.5, depth=wall,
            location=(center[0], center[1], center[2] - height * 0.5 + wall * 0.5),
        )
        bottom = bpy.context.object
        bpy.ops.object.select_all(action="DESELECT")
        wall_obj.select_set(True)
        bottom.select_set(True)
        bpy.context.view_layer.objects.active = wall_obj
        bpy.ops.object.join()

    return finish(wall_obj, name, material, smooth_angle=math.radians(50.0))



def apply_world_uv(objs: list[bpy.types.Object]) -> None:
    """按世界坐标做盒式投影：1 个世界单位 = 1 个 UV 单位。

    Blender 立方体默认 UV 是十字布局（每个面只占 1/4 UV 空间），
    直接用会让贴图被放大 4 倍。这里改成按面法线选取投影轴，
    这样所有道具的贴图密度一致，材质里的 uv1_scale 才有可预期的含义。
    """
    for obj in objs:
        if obj.type != "MESH":
            continue
        me = obj.data
        layer = me.uv_layers[0] if len(me.uv_layers) > 0 else me.uv_layers.new(name="UVMap")
        mw = obj.matrix_world
        for poly in me.polygons:
            normal = poly.normal
            axis = max(range(3), key=lambda i: abs(normal[i]))
            for loop_index in poly.loop_indices:
                co = mw @ me.vertices[me.loops[loop_index].vertex_index].co
                if axis == 0:
                    uv = (co.y, co.z)
                elif axis == 1:
                    uv = (co.x, co.z)
                else:
                    uv = (co.x, co.y)
                layer.data[loop_index].uv = uv


def empty(name: str) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    return obj


def parent_all(root: bpy.types.Object, children: list[bpy.types.Object]) -> None:
    for child in children:
        child.parent = root
        child.matrix_parent_inverse = root.matrix_world.inverted()


def export(root: bpy.types.Object, filename: str) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root
    apply_world_uv([o for o in root.children_recursive if o.type == "MESH"])
    path = os.path.join(OUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    print(f"[export] {filename}  {os.path.getsize(path) / 1024:.1f} KB")


def bounds(objects: list[bpy.types.Object]) -> tuple[Vec, Vec]:
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for obj in objects:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            for i in range(3):
                lo[i] = min(lo[i], world[i])
                hi[i] = max(hi[i], world[i])
    return tuple(round(v, 4) for v in lo), tuple(round(v, 4) for v in hi)


# ----------------------------------------------------------------------------- 道具


def build_petri_dish() -> None:
    """Ø90 mm 玻璃培养皿：皿底 + 琼脂 + 皿盖。原点在皿底外表面。"""
    reset_scene()
    glass = new_material("glass", (0.94, 0.97, 0.98), 0.05)
    agar_mat = new_material("agar", (0.90, 0.90, 0.88), 0.22)

    root = empty("petri_dish")

    r_outer = 0.045          # Ø90 mm
    wall = 0.0012
    dish_h = 0.014

    bottom = cup("dish_bottom", r_outer, dish_h, wall,
                 (0.0, 0.0, dish_h * 0.5), glass)

    agar_h = 0.005
    agar = cylinder("agar", r_outer - wall - 0.0004, agar_h,
                    (0.0, 0.0, wall + agar_h * 0.5), agar_mat,
                    vertices=48, bevel=0.0004)

    # 皿盖：略大一圈，扣在皿口上，向下垂 1.5 mm
    lid_r = r_outer + 0.0012
    lid_h = 0.006
    lid = cup("dish_lid", lid_r, lid_h, wall * 0.9,
              (0.0, 0.0, dish_h + lid_h * 0.5 - 0.0015), glass, with_bottom=False)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=48, radius=lid_r - wall * 0.45, depth=wall,
        location=(0.0, 0.0, dish_h + lid_h - 0.0015 - wall * 0.5),
    )
    lid_top = bpy.context.object
    bpy.ops.object.select_all(action="DESELECT")
    lid.select_set(True)
    lid_top.select_set(True)
    bpy.context.view_layer.objects.active = lid
    bpy.ops.object.join()
    finish(lid, "dish_lid", glass, smooth_angle=math.radians(50.0))

    # 把皿底原点移到 y=0（底面）：整体下移 dish_h/2 已通过建模保证，这里只校验
    parent_all(root, [bottom, agar, lid])
    lo, hi = bounds([bottom, agar, lid])
    print(f"[dish] bounds lo={lo} hi={hi} 直径={hi[0] - lo[0]:.4f} 高={hi[2] - lo[2]:.4f}")
    export(root, "petri_dish.glb")


def build_lab_bench() -> None:
    """2.4 m 实验台：环氧台面 + 不锈钢框架 + 下柜 + 层板。台面高 0.9 m。"""
    reset_scene()
    epoxy = new_material("epoxy", (0.06, 0.06, 0.07), 0.34)
    steel = new_material("steel", (0.62, 0.64, 0.66), 0.22, 1.0)
    panel = new_material("cabinet", (0.72, 0.73, 0.72), 0.45)

    root = empty("lab_bench")
    parts: list[bpy.types.Object] = []

    width, depth, height = 2.4, 0.75, 0.9
    top_t = 0.045

    # 台面（上表面正好在 z = height）
    parts.append(box("bench_top", (width, depth, top_t),
                     (0.0, 0.0, height - top_t * 0.5), epoxy, bevel=0.003, segments=3))
    # 前沿滴水线
    parts.append(box("bench_lip", (width, 0.02, 0.014),
                     (0.0, -(depth * 0.5 - 0.006), height - top_t - 0.007), epoxy, bevel=0.002))

    # 不锈钢横梁（前后各一）
    for sy in (-1, 1):
        parts.append(box("frame_rail", (width - 0.16, 0.04, 0.04),
                         (0.0, sy * (depth * 0.5 - 0.045), height - top_t - 0.02),
                         steel, bevel=0.002))
    # 四腿
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("frame_leg", (0.05, 0.05, height - top_t),
                             (sx * (width * 0.5 - 0.045), sy * (depth * 0.5 - 0.05),
                              (height - top_t) * 0.5), steel, bevel=0.002))

    # 下层板
    parts.append(box("shelf", (width - 0.12, depth - 0.1, 0.018),
                     (0.0, 0.0, 0.2), panel, bevel=0.002))

    # 柜体：两扇门 + 拉手
    door_h = 0.52
    door_w = (width - 0.18) * 0.5 - 0.004
    for sx in (-1, 1):
        parts.append(box("cabinet_door", (door_w, 0.018, door_h),
                         (sx * (door_w * 0.5 + 0.008), -(depth * 0.5 - 0.03),
                          0.2 + door_h * 0.5 + 0.009), panel, bevel=0.003))
        handle = cylinder("cabinet_handle", 0.006, 0.14,
                          (sx * 0.13, -(depth * 0.5 - 0.012), 0.2 + door_h + 0.03),
                          steel, vertices=24, bevel=0.001)
        handle.rotation_euler = (0.0, math.radians(90.0), 0.0)
        parts.append(handle)

    parent_all(root, parts)
    lo, hi = bounds(parts)
    print(f"[bench] bounds lo={lo} hi={hi}")
    export(root, "lab_bench.glb")


def build_tray() -> None:
    """不锈钢器械托盘：底板 + 四壁。"""
    reset_scene()
    steel = new_material("steel", (0.62, 0.64, 0.66), 0.22, 1.0)

    root = empty("lab_tray")
    parts: list[bpy.types.Object] = []

    tray_w, tray_d, tray_h = 0.26, 0.16, 0.018
    parts.append(box("tray_base", (tray_w, tray_d, 0.002), (0.0, 0.0, 0.001), steel, bevel=0.001))
    for sx in (-1, 1):
        parts.append(box("tray_wall_x", (0.002, tray_d, tray_h),
                         (sx * (tray_w * 0.5 - 0.001), 0.0, tray_h * 0.5), steel, bevel=0.0008))
    for sy in (-1, 1):
        parts.append(box("tray_wall_y", (tray_w, 0.002, tray_h),
                         (0.0, sy * (tray_d * 0.5 - 0.001), tray_h * 0.5), steel, bevel=0.0008))

    parent_all(root, parts)
    export(root, "lab_tray.glb")



def cone(name: str, r_bottom: float, r_top: float, depth: float, center: Vec,
         material: bpy.types.Material, vertices: int = 48) -> bpy.types.Object:
    """轴向为 Z 的圆台。"""
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=r_bottom, radius2=r_top,
        depth=depth, location=center,
    )
    obj = bpy.context.object
    return finish(obj, name, material, smooth_angle=math.radians(50.0))



# --------------------------------------------------------------------- 旋转成型
# 玻璃器皿的"精致"几乎全在剖面线上：肩部曲率、瓶口翻边、壁厚收口、锥形瓶的收腰。
# 用圆柱叠是拼不出来的，这里按 (半径, 高度) 剖面绕 Z 轴旋转成实体。

def revolve(name: str, profile: list[tuple[float, float]],
            material: bpy.types.Material, segments: int = 64,
            smooth: bool = True) -> bpy.types.Object:
    """把 (r, z) 剖面绕 Z 轴旋转成曲面。

    剖面是开放折线：两端若都落在轴上（r≈0）就自动收成极点，得到封闭实体。
    """
    import bmesh

    bm = bmesh.new()
    rings: list[list] = []
    poles: list = []
    for r, z in profile:
        if r <= 1e-6:
            rings.append([])
            poles.append(bm.verts.new((0.0, 0.0, z)))
        else:
            ring = []
            for i in range(segments):
                a = 2.0 * math.pi * i / segments
                ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
            rings.append(ring)
            poles.append(None)

    for i in range(len(profile) - 1):
        ri, rj = rings[i], rings[i + 1]
        if ri and rj:
            for s in range(segments):
                s2 = (s + 1) % segments
                bm.faces.new((ri[s], ri[s2], rj[s2], rj[s]))
        elif ri and not rj:
            for s in range(segments):
                s2 = (s + 1) % segments
                bm.faces.new((ri[s], ri[s2], poles[i + 1]))
        elif rj and not ri:
            for s in range(segments):
                s2 = (s + 1) % segments
                bm.faces.new((poles[i], rj[s2], rj[s]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    for poly in me.polygons:
        poly.use_smooth = smooth
    obj.data.materials.clear()
    obj.data.materials.append(material)
    obj.name = name
    obj.data.name = name
    return obj


def knurl(name: str, radius: float, height: float, center: Vec,
          material: bpy.types.Material, ridges: int = 24,
          ridge: float = 0.0012) -> list[bpy.types.Object]:
    """瓶盖侧面的竖纹（滚花），一点点细节就能让盖子不像塑料片。"""
    out: list[bpy.types.Object] = []
    for i in range(ridges):
        a = 2.0 * math.pi * i / ridges
        x = center[0] + math.cos(a) * (radius + ridge * 0.5)
        y = center[1] + math.sin(a) * (radius + ridge * 0.5)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, center[2]))
        obj = bpy.context.object
        obj.scale = (ridge, radius * 0.09, height)
        obj.rotation_euler = (0.0, 0.0, a)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        out.append(finish(obj, f"{name}_{i:02d}", material, smooth_angle=math.radians(30.0)))
    return out


def screw_cap(name: str, r_top: float, r_base: float, z0: float, height: float,
              material: bpy.types.Material, ribs: int = 24,
              rib_depth: float = 0.0012) -> list:
    """螺纹盖：带倒角的盖身 + 一圈竖滚花 + 底部螺纹环。

    盖子是玻璃器皿上最容易被认出来的零件，做成光溜溜的圆柱立刻就"塑料感"。
    """
    parts = []
    z1 = z0 + height

    parts.append(revolve(f"{name}_body", [
        (0.0000, z0),
        (r_base * 0.92, z0),
        (r_base, z0 + height * 0.10),
        (r_base, z0 + height * 0.20),
        (r_top, z0 + height * 0.78),
        (r_top * 0.97, z1 - 0.0008),
        (r_top * 0.86, z1),
        (0.0000, z1),
    ], material, segments=64))

    # 竖纹：沿圆周均匀排布，凸出盖面 1 mm 左右，近距离能看出细齿
    rib_h = height * 0.60
    rib_z = z0 + height * 0.26 + rib_h * 0.5
    r_mid = (r_base + r_top) * 0.5
    for i in range(ribs):
        ang = 2.0 * math.pi * i / ribs
        x = math.cos(ang) * (r_mid + rib_depth * 0.5)
        y = math.sin(ang) * (r_mid + rib_depth * 0.5)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, rib_z))
        obj = bpy.context.object
        obj.scale = (rib_depth, 2.0 * math.pi * r_mid / ribs * 0.55, rib_h)
        obj.rotation_euler = (0.0, 0.0, ang)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        parts.append(finish(obj, f"{name}_rib_{i:02d}", material,
                            smooth_angle=math.radians(25.0)))

    # 螺纹环：盖底与瓶颈之间的那圈台阶
    parts.append(revolve(f"{name}_thread", [
        (0.0000, z0 - 0.0032),
        (r_base * 0.84, z0 - 0.0032),
        (r_base * 0.90, z0 - 0.0016),
        (r_base * 0.90, z0),
        (0.0000, z0),
    ], material, segments=64))
    return parts


def assemble_bottle(root_name: str, file_name: str, body_profile: list,
                    body_mat, cap_r_top: float, cap_r_base: float, cap_z: float,
                    cap_h: float, cap_mat) -> None:
    root = empty(root_name)
    parts = [revolve(f"{root_name}_body", body_profile, body_mat)]
    parts += screw_cap(f"{root_name}_cap", cap_r_top, cap_r_base, cap_z, cap_h, cap_mat)
    parent_all(root, parts)
    export(root, file_name)


def build_reagent_bottle() -> None:
    """500 mL 棕色试剂瓶：圆角瓶底 + 弧线肩部 + 瓶口翻边 + 螺纹盖。"""
    reset_scene()
    amber = new_material("amber", (0.30, 0.11, 0.02), 0.16)
    cap_mat = new_material("cap_black", (0.03, 0.03, 0.035), 0.45)

    profile = [
        (0.0000, 0.0000), (0.0280, 0.0000), (0.0330, 0.0022), (0.0358, 0.0062),
        (0.0372, 0.0120), (0.0375, 0.0200), (0.0375, 0.1060), (0.0374, 0.1110),
        (0.0368, 0.1160), (0.0355, 0.1235), (0.0334, 0.1305), (0.0300, 0.1375),
        (0.0258, 0.1440), (0.0216, 0.1488), (0.0182, 0.1516), (0.0158, 0.1536),
        (0.0146, 0.1560), (0.0142, 0.1600), (0.0142, 0.1728), (0.0150, 0.1740),
        (0.0168, 0.1752), (0.0168, 0.1788), (0.0150, 0.1800), (0.0142, 0.1812),
        (0.0140, 0.1830), (0.0000, 0.1830),
    ]
    assemble_bottle("reagent_bottle", "reagent_bottle.glb", profile, amber,
                    0.0162, 0.0166, 0.1815, 0.0145, cap_mat)


def build_media_bottle() -> None:
    """250 mL 广口培养瓶：矮胖瓶身 + 大螺纹盖，装无菌水/培养基。"""
    reset_scene()
    glass = new_material("clear_glass", (0.88, 0.94, 0.96), 0.10)
    cap_mat = new_material("cap_blue", (0.10, 0.22, 0.38), 0.40)

    profile = [
        (0.0000, 0.0000), (0.0300, 0.0000), (0.0350, 0.0022), (0.0378, 0.0064),
        (0.0392, 0.0120), (0.0396, 0.0200), (0.0396, 0.0780), (0.0394, 0.0830),
        (0.0386, 0.0880), (0.0368, 0.0930), (0.0338, 0.0975), (0.0300, 0.1008),
        (0.0266, 0.1030), (0.0248, 0.1046), (0.0242, 0.1064), (0.0240, 0.1080),
        (0.0000, 0.1080),
    ]
    assemble_bottle("media_bottle", "media_bottle.glb", profile, glass,
                    0.0266, 0.0270, 0.1064, 0.0170, cap_mat)


def build_beaker() -> None:
    """250 mL 烧杯：真实壁厚 + 圆角杯底 + 卷边杯口 + 刻度线。"""
    reset_scene()
    glass = new_material("clear_glass", (0.90, 0.95, 0.97), 0.08)

    root = empty("beaker")
    parts = []

    parts.append(revolve("beaker_body", [
        (0.0000, 0.0038), (0.0290, 0.0038), (0.0316, 0.0062), (0.0322, 0.0900),
        (0.0332, 0.0946), (0.0352, 0.0952), (0.0352, 0.0890), (0.0344, 0.0042),
        (0.0322, 0.0010), (0.0280, 0.0000), (0.0000, 0.0000),
    ], glass))

    for i, z in enumerate((0.030, 0.055, 0.080)):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0338, 0.0, z))
        obj = bpy.context.object
        obj.scale = (0.0006, 0.012 if i < 2 else 0.018, 0.0008)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        parts.append(finish(obj, f"beaker_mark_{i}", glass, smooth_angle=math.radians(20.0)))

    parent_all(root, parts)
    export(root, "beaker.glb")


def build_flask() -> None:
    """250 mL 锥形瓶：收腰锥体 + 细颈 + 卷边口。"""
    reset_scene()
    glass = new_material("clear_glass", (0.90, 0.95, 0.97), 0.08)

    root = empty("conical_flask")
    parts = []

    parts.append(revolve("flask_body", [
        (0.0000, 0.0000), (0.0330, 0.0000), (0.0400, 0.0030), (0.0418, 0.0080),
        (0.0420, 0.0140), (0.0390, 0.0300), (0.0340, 0.0520), (0.0286, 0.0740),
        (0.0232, 0.0900), (0.0188, 0.1010), (0.0150, 0.1090), (0.0132, 0.1130),
        (0.0128, 0.1180), (0.0128, 0.1440), (0.0138, 0.1458), (0.0150, 0.1470),
        (0.0150, 0.1504), (0.0138, 0.1518), (0.0128, 0.1526), (0.0126, 0.1540),
        (0.0000, 0.1540),
    ], glass))

    parent_all(root, parts)
    export(root, "conical_flask.glb")



def build_pepper_plant() -> None:
    """盛花期辣椒植株：主干、二歧分枝、叶片、白花。"""
    reset_scene()
    leaf_mats = [
        new_material("leaf_a", (0.10, 0.22, 0.06), 0.55),
        new_material("leaf_b", (0.13, 0.26, 0.08), 0.60),
        new_material("leaf_c", (0.08, 0.19, 0.05), 0.52),
    ]
    stem_mat = new_material("stem", (0.16, 0.24, 0.09), 0.60)
    petal_mat = new_material("petal", (0.94, 0.94, 0.88), 0.48)
    calyx_mat = new_material("calyx", (0.22, 0.34, 0.10), 0.55)

    root = empty("pepper_plant")
    parts = plant_lib.build_pepper_plant(root.name, leaf_mats, stem_mat,
                                         petal_mat, calyx_mat)

    # 下垂的叶片会低于地面，整体抬到 z=0，保证"原点在土面"
    lo0, _hi = bounds(parts)
    if lo0[2] < 0.0:
        for part in parts:
            part.location.z -= lo0[2]

    parent_all(root, parts)
    lo, hi = bounds(parts)
    print(f"[plant] bounds lo={lo} hi={hi}  parts={len(parts)}")
    export(root, "pepper_plant.glb")


def build_anther() -> None:
    """单枚花药：裂片状药室 + 细花丝。Scene2 里放大当作各发育期的标本。"""
    reset_scene()
    anther_mat = new_material("anther_body", (0.86, 0.62, 0.12), 0.42)
    filament_mat = new_material("anther_filament", (0.72, 0.78, 0.42), 0.55)

    root = empty("anther")
    parts = []

    # 药室：沿中轴变径的管，压扁成裂片
    body = plant_lib.tube("anther_body", [
        Vector((0.0, 0.0, 0.0)), Vector((0.0004, 0.0, 0.0025)),
        Vector((0.0006, 0.0, 0.0050)), Vector((0.0004, 0.0, 0.0072)),
        Vector((0.0, 0.0, 0.0084)),
    ], [0.0007, 0.0021, 0.0024, 0.0018, 0.0006], anther_mat, seg=16)
    body.scale = (1.0, 0.62, 1.0)
    parts.append(body)

    # 花丝：从药室基部向下
    parts.append(plant_lib.tube("anther_filament", [
        Vector((0.0, 0.0, -0.0004)), Vector((0.0, 0.0, -0.006)),
        Vector((0.0002, 0.0, -0.012)),
    ], [0.0005, 0.00042, 0.00035], filament_mat, seg=8))

    parent_all(root, parts)
    export(root, "anther.glb")



def build_incubator() -> None:
    """培养箱：钢板箱体 + 内胆 + 三层隔板 + 玻璃门 + 控制条。
    原点在底面中心，正面朝 -Y（导出后 +Z）。"""
    reset_scene()
    shell = new_material("inc_shell", (0.80, 0.82, 0.82), 0.32, 0.25)
    inner = new_material("inc_inner", (0.92, 0.94, 0.95), 0.42)
    steel = new_material("inc_steel", (0.62, 0.64, 0.66), 0.24, 1.0)
    glass = new_material("inc_glass", (0.70, 0.82, 0.90), 0.06, 0.0)
    glass.blend_method = "BLEND"
    dark = new_material("inc_dark", (0.04, 0.06, 0.08), 0.15)

    root = empty("incubator")
    parts = []

    W, D, H = 1.20, 0.78, 1.95
    t = 0.022

    # 箱体做成五面板而不是实心块，否则门后面是一堵墙，内腔根本看不到
    parts.append(box("incubator_back", (W, t, H), (0.0, D * 0.5 - t * 0.5, H * 0.5), shell))
    parts.append(box("incubator_side_l", (t, D, H), (-W * 0.5 + t * 0.5, 0.0, H * 0.5), shell))
    parts.append(box("incubator_side_r", (t, D, H), (W * 0.5 - t * 0.5, 0.0, H * 0.5), shell))
    parts.append(box("incubator_top", (W, D, t), (0.0, 0.0, H - t * 0.5), shell))
    parts.append(box("incubator_bottom", (W, D, t), (0.0, 0.0, t * 0.5), shell))

    # 内胆：贴在背板前面的浅色板，让内腔有层次
    parts.append(box("incubator_recess", (W - 0.06, 0.012, H - 0.10),
                     (0.0, D * 0.5 - t - 0.008, H * 0.5), inner))

    # 隔板
    for i, z in enumerate((0.34, 0.86, 1.38)):
        parts.append(box(f"incubator_shelf_{i}", (W - 0.08, D - 0.08, 0.014),
                         (0.0, 0.0, z), steel))

    # 门框（贴在正面开口四周）
    ow, oh = W - 0.10, H - 0.22
    fw = 0.030
    z0 = 0.11
    parts.append(box("incubator_frame_t", (ow + fw * 2, 0.030, fw),
                     (0.0, -D * 0.5, z0 + oh), steel))
    parts.append(box("incubator_frame_b", (ow + fw * 2, 0.030, fw),
                     (0.0, -D * 0.5, z0), steel))
    parts.append(box("incubator_frame_l", (fw, 0.030, oh),
                     (-ow * 0.5 - fw * 0.5, -D * 0.5, z0 + oh * 0.5), steel))
    parts.append(box("incubator_frame_r", (fw, 0.030, oh),
                     (ow * 0.5 + fw * 0.5, -D * 0.5, z0 + oh * 0.5), steel))

    # 玻璃门
    parts.append(box("incubator_glass", (ow, 0.010, oh),
                     (0.0, -D * 0.5 - 0.006, z0 + oh * 0.5), glass))

    # 把手
    handle = cylinder("incubator_handle", 0.013, 0.26,
                      (ow * 0.5 - 0.05, -D * 0.5 - 0.045, z0 + oh * 0.5),
                      steel, vertices=20)
    handle.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    parts.append(handle)

    # 顶部控制条
    parts.append(box("incubator_panel", (W - 0.10, 0.09, 0.09),
                     (0.0, -D * 0.5 + 0.05, H - 0.06), dark))

    # 底脚
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            parts.append(cylinder(f"incubator_foot_{sx:+.0f}{sy:+.0f}", 0.03, 0.05,
                                  (sx * (W * 0.5 - 0.08), sy * (D * 0.5 - 0.08), 0.025),
                                  steel, vertices=16))

    parent_all(root, parts)
    export(root, "incubator.glb")


def build_plantlet() -> None:
    """组培苗：短茎、几片小叶、下方根系。原点是琼脂面（根颈处）。"""
    reset_scene()
    leaf_a = new_material("pl_leaf_a", (0.18, 0.36, 0.12), 0.58)
    leaf_b = new_material("pl_leaf_b", (0.22, 0.42, 0.15), 0.55)
    stem_m = new_material("pl_stem", (0.42, 0.58, 0.26), 0.60)
    root_m = new_material("pl_root", (0.88, 0.90, 0.82), 0.55)

    root = empty("plantlet")
    parts = []

    parts.append(plant_lib.tube("plantlet_stem", [
        Vector((0.0, 0.0, 0.0)), Vector((0.002, 0.0, 0.012)),
        Vector((0.001, 0.001, 0.024)), Vector((0.0, 0.002, 0.034)),
    ], [0.0022, 0.0019, 0.0016, 0.0013], stem_m, seg=8))

    mats = [leaf_a, leaf_b]
    for i in range(7):
        az = i * (2.0 * math.pi / 7.0) + 0.3
        z = 0.008 + i * 0.0042
        elev = math.radians(18.0 + i * 4.0)
        length = 0.020 + (0.006 if i % 2 else 0.0)
        leaf = plant_lib.blade(f"plantlet_leaf_{i}", length, length * 0.62,
                               mats[i % 2], droop=0.30, cup=0.20)
        plant_lib.place(leaf, Vector((0.0, 0.0, z)), rot_z=az, rot_y=-elev)
        parts.append(leaf)

    # 根系：四条朝下的细丝
    for i in range(4):
        az = i * (2.0 * math.pi / 4.0) + 0.6
        r = 0.016
        parts.append(plant_lib.tube(f"plantlet_root_{i}", [
            Vector((0.0, 0.0, 0.0)),
            Vector((math.cos(az) * r * 0.35, math.sin(az) * r * 0.35, -0.012)),
            Vector((math.cos(az) * r * 0.7, math.sin(az) * r * 0.7, -0.026)),
            Vector((math.cos(az) * r, math.sin(az) * r, -0.040)),
        ], [0.0011, 0.0009, 0.0007, 0.0004], root_m, seg=6))

    parent_all(root, parts)
    export(root, "plantlet.glb")


def build_microscope() -> None:
    """显微镜：底座、弯臂、载物台、物镜转盘、目镜、调焦旋钮。原点底面中心，正面 -Y。"""
    reset_scene()
    body = new_material("ms_body", (0.13, 0.14, 0.16), 0.30, 0.35)
    metal = new_material("ms_metal", (0.66, 0.68, 0.70), 0.22, 1.0)
    lens = new_material("ms_lens", (0.06, 0.10, 0.14), 0.08, 0.0)
    stage_m = new_material("ms_stage", (0.20, 0.21, 0.23), 0.35, 0.20)

    root = empty("microscope")
    parts = []

    # 底座（马蹄形用圆角长方体近似）
    parts.append(box("micro_base", (0.22, 0.26, 0.045), (0.0, 0.01, 0.0225), body, bevel=0.02, segments=4))

    # 立柱
    parts.append(box("micro_pillar", (0.055, 0.05, 0.30), (0.0, 0.10, 0.02 + 0.15), body))

    # 弯臂（从立柱顶弯向前）
    parts.append(plant_lib.tube("micro_arm", [
        Vector((0.0, 0.10, 0.31)), Vector((0.0, 0.085, 0.345)),
        Vector((0.0, 0.055, 0.360)), Vector((0.0, 0.030, 0.358)),
    ], [0.026, 0.024, 0.022, 0.020], body, seg=14))

    # 载物台
    parts.append(box("micro_stage", (0.16, 0.15, 0.012), (0.0, 0.005, 0.175), stage_m))
    parts.append(box("micro_stage_hole", (0.035, 0.035, 0.014), (0.0, -0.01, 0.176), lens))

    # 物镜转盘 + 三个物镜
    parts.append(cylinder("micro_nosepiece", 0.045, 0.022, (0.0, 0.005, 0.232), metal, vertices=32))
    for i, ang in enumerate((0.0, 2.094, 4.188)):
        parts.append(plant_lib.tube(f"micro_objective_{i}", [
            Vector((math.cos(ang) * 0.028, math.sin(ang) * 0.028 + 0.005, 0.226)),
            Vector((math.cos(ang) * 0.028, math.sin(ang) * 0.028 + 0.005, 0.196)),
        ], [0.011, 0.008], metal, seg=12))

    # 镜筒 + 目镜
    parts.append(cylinder("micro_tube", 0.020, 0.075, (0.0, 0.030, 0.335), body, vertices=24))
    parts.append(cylinder("micro_eyepiece", 0.016, 0.030, (0.0, 0.030, 0.385), metal, vertices=24))

    # 调焦旋钮
    for sx in (-1.0, 1.0):
        knob = cylinder(f"micro_knob_{sx:+.0f}", 0.022, 0.016,
                        (sx * 0.035, 0.10, 0.115), metal, vertices=24)
        knob.rotation_euler = (0.0, math.radians(90.0), 0.0)
        parts.append(knob)

    parent_all(root, parts)
    export(root, "microscope.glb")


def build_tube_rack() -> None:
    """试管架：底板 + 两侧壁 + 6 支试管。"""
    reset_scene()
    steel = new_material("steel", (0.62, 0.64, 0.66), 0.25, 1.0)
    plastic = new_material("tube_plastic", (0.90, 0.93, 0.92), 0.22)

    root = empty("tube_rack")
    parts: list[bpy.types.Object] = []

    rack_w, rack_d, base_h = 0.19, 0.075, 0.010
    parts.append(box("rack_base", (rack_w, rack_d, base_h), (0.0, 0.0, base_h * 0.5),
                     steel, bevel=0.0015))
    for sy in (-1, 1):
        parts.append(box("rack_wall", (rack_w, 0.004, 0.055),
                         (0.0, sy * (rack_d * 0.5 - 0.002), 0.0275), steel, bevel=0.001))

    tube_h = 0.075
    for i in range(6):
        x = -0.070 + i * 0.028
        parts.append(cylinder(f"tube_{i}", 0.0065, tube_h,
                              (x, 0.0, base_h + tube_h * 0.5), plastic,
                              vertices=20, bevel=0.0005))

    parent_all(root, parts)
    export(root, "tube_rack.glb")


def build_room() -> None:
    """房间壳体：地面 + 后墙 + 两侧墙 + 踢脚线。"""
    reset_scene()
    floor_mat = new_material("floor", (0.55, 0.57, 0.55), 0.30)
    wall_mat = new_material("wall", (0.88, 0.88, 0.86), 0.12)
    skirting = new_material("skirting", (0.35, 0.36, 0.35), 0.5)

    root = empty("lab_room")
    parts: list[bpy.types.Object] = []

    width, depth, height = 4.2, 3.2, 2.7
    parts.append(box("room_floor", (width, depth, 0.02), (0.0, 0.0, -0.01), floor_mat, bevel=0.0))
    parts.append(box("room_back_wall", (width, 0.04, height),
                     (0.0, depth * 0.5, height * 0.5), wall_mat, bevel=0.0))
    for sx in (-1, 1):
        parts.append(box("room_side_wall", (0.04, depth, height),
                         (sx * width * 0.5, 0.0, height * 0.5), wall_mat, bevel=0.0))
    parts.append(box("room_skirting", (width, 0.02, 0.1),
                     (0.0, depth * 0.5 - 0.045, 0.05), skirting, bevel=0.002))

    parent_all(root, parts)
    export(root, "lab_room.glb")


def main() -> None:
    build_petri_dish()
    build_lab_bench()
    build_tray()
    build_reagent_bottle()
    build_media_bottle()
    build_beaker()
    build_flask()
    build_tube_rack()
    build_pepper_plant()
    build_incubator()
    build_plantlet()
    build_microscope()
    build_anther()
    build_room()
    print("完成")


if __name__ == "__main__":
    main()
