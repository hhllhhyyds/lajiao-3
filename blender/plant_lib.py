"""辣椒植株与花药建模辅助（由 build_props.py 导入）。"""

import math

import bmesh
import bpy
from mathutils import Vector


# --------------------------------------------------------------------- 基础几何

def _ortho(t: Vector):
    """给一条方向向量配一对正交基，避免与 Z 轴重合时退化。"""
    a = Vector((1.0, 0.0, 0.0))
    if abs(t.dot(a)) > 0.9:
        a = Vector((0.0, 1.0, 0.0))
    n = t.cross(a)
    n.normalize()
    b = t.cross(n)
    b.normalize()
    return n, b


def _finish(bm, name, material, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    for poly in me.polygons:
        poly.use_smooth = smooth
    me.materials.append(material)
    return obj


def tube(name: str, pts, radii, material, seg: int = 10) -> bpy.types.Object:
    """沿折线生成一段变径圆管，用于茎和枝——直圆柱拼不出植物的弯曲。"""
    bm = bmesh.new()
    angles = [2.0 * math.pi * k / seg for k in range(seg)]
    rings = []
    for i, p in enumerate(pts):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == len(pts) - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        t = Vector(t).normalized()
        n, b = _ortho(t)
        r = radii[i]
        ring = []
        for a in angles:
            ring.append(bm.verts.new(Vector(p) + n * (r * math.cos(a)) + b * (r * math.sin(a))))
        rings.append(ring)

    for i in range(len(rings) - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))

    for idx, rev in ((0, True), (len(rings) - 1, False)):
        center = bm.verts.new(pts[idx])
        ring = rings[idx]
        for k in range(seg):
            k2 = (k + 1) % seg
            if rev:
                bm.faces.new((center, ring[k2], ring[k]))
            else:
                bm.faces.new((center, ring[k], ring[k2]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, name, material)


def blade(name: str, length: float, width: float, material,
          seg_u: int = 12, seg_v: int = 6, droop: float = 0.30,
          cup: float = 0.22, pointed: float = 0.8, curl: float = 0.0):
    """叶片／花瓣共用的曲面片：沿长度下垂、横向微卷，两端收尖。"""
    bm = bmesh.new()
    rows = []
    for i in range(seg_u + 1):
        u = i / seg_u
        # 宽度包络：叶基较窄、中段最宽、叶尖收成尖
        half = width * 0.5 * (math.sin(math.pi * min(1.0, u ** pointed)) ** 0.85)
        row = []
        for j in range(seg_v + 1):
            v = (j / seg_v) * 2.0 - 1.0
            x = u * length
            y = v * half
            z = -droop * length * u * u + cup * half * (v * v)
            z += curl * length * math.sin(u * math.pi) * 0.15
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)

    for i in range(seg_u):
        for j in range(seg_v):
            bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _finish(bm, name, material)
    # 双面：叶背叶面都要有面，否则从背面看是空的
    solid = obj.modifiers.new("skin", 'SOLIDIFY')
    solid.thickness = 0.0006
    solid.offset = 0.0
    return obj


def place(obj: bpy.types.Object, location, rot_z: float = 0.0,
          rot_x: float = 0.0, rot_y: float = 0.0, scale: float = 1.0):
    obj.location = location
    obj.rotation_euler = (rot_x, rot_y, rot_z)
    obj.scale = (scale, scale, scale)


# --------------------------------------------------------------------- 植株

def build_pepper_plant(root, leaf_mats, stem_mat, petal_mat, calyx_mat):
    """一株盛花期的辣椒：主干 → 三级二歧分枝，枝节与枝端都长叶，枝端着花。"""
    parts = []
    rng = _Rng(20261031)

    stem_pts = [Vector((0.0, 0.0, 0.0)), Vector((0.006, 0.0, 0.16)),
                Vector((0.014, 0.004, 0.32)), Vector((0.012, 0.008, 0.48)),
                Vector((0.0, 0.006, 0.60))]
    parts.append(tube(f"{root}_stem", stem_pts,
                      [0.018, 0.016, 0.014, 0.012, 0.010], stem_mat, seg=12))

    leaf_i = 0
    node_i = 0

    def add_leaves(origin: Vector, ang: float, count: int, spread: float,
                   length_lo: float, length_hi: float):
        nonlocal leaf_i
        for k in range(count):
            a = ang + (k - (count - 1) * 0.5) * spread + rng.f(-0.1, 0.1)
            elev = rng.f(-0.10, 0.60)
            length = rng.f(length_lo, length_hi)
            width = length * rng.f(0.50, 0.64)
            leaf = blade(f"{root}_leaf_{leaf_i}", length, width,
                         leaf_mats[leaf_i % len(leaf_mats)],
                         droop=rng.f(0.22, 0.42), cup=rng.f(0.12, 0.28))
            nudge = Vector((math.cos(a) * 0.018, math.sin(a) * 0.018,
                            rng.f(-0.05, 0.04)))
            place(leaf, origin + nudge, rot_z=a, rot_y=-elev)
            parts.append(leaf)
            leaf_i += 1

    # 主干中段再抽两条侧枝，避免"一根杆顶两杈"的稀疏感
    side_tips = []
    for i, (z, ang) in enumerate(((0.30, 2.1), (0.44, 3.9))):
        base = Vector((0.0, 0.0, z))
        d = Vector((math.cos(ang) * 0.75, math.sin(ang) * 0.75, 1.0)).normalized()
        end = base + d * rng.f(0.16, 0.21)
        parts.append(tube(f"{root}_side_{i}", [base, base + d * 0.09, end],
                          [0.0075, 0.0062, 0.0050], stem_mat, seg=10))
        side_tips.append((end, ang))

    # 二歧分枝：主干顶端向四个方位发出主枝，每枝再分两级，树冠才是四周展开的
    tips = []
    node_i = [0]

    def grow(start: Vector, azimuth: float, climb: float, length: float,
             radius: float, depth: int):
        d = Vector((math.cos(azimuth) * climb, math.sin(azimuth) * climb, 1.0))
        d.normalize()
        mid = start + d * (length * 0.55)
        end = start + d * length
        parts.append(tube(f"{root}_br_{node_i[0]}", [start, mid, end],
                          [radius, radius * 0.85, radius * 0.7], stem_mat, seg=10))
        node_i[0] += 1
        add_leaves(mid, azimuth, 3, 0.5, 0.09, 0.13)
        if depth >= 3:
            add_leaves(end, azimuth, 4, 0.62, 0.10, 0.15)
            tips.append((end, azimuth))
            return
        for sgn in (-1.0, 1.0):
            grow(end, azimuth + sgn * 0.62, climb * 0.92,
                 length * 0.74, radius * 0.72, depth + 1)

    for i in range(4):
        az = math.pi * 0.25 + i * math.pi * 0.5 + rng.f(-0.12, 0.12)
        grow(Vector((0.0, 0.0, 0.56)), az, 0.62, 0.26, 0.0072, 1)

    # 花：每个枝端一至两朵
    for idx, (tip, ang) in enumerate(tips):
        for m in range(2):
            a = ang + (m - 0.5) * 0.9 + rng.f(-0.2, 0.2)
            base = tip + Vector((math.cos(a) * 0.045, math.sin(a) * 0.045, 0.03))
            parts.extend(_flower(f"{root}_fl_{idx}{m}", f"{root}_calyx_{idx}{m}",
                                 base, a, petal_mat, calyx_mat))

    return parts


def _flower(name: str, calyx_name: str, base: Vector, ang: float,
            petal_mat, calyx_mat):
    """单朵花：绿色花萼 + 5 枚白色花瓣（向外翻卷）。"""
    parts = []
    calyx = blade(calyx_name, 0.024, 0.026, calyx_mat,
                  seg_u=6, seg_v=6, droop=0.0, cup=0.5, pointed=1.0)
    place(calyx, base, rot_z=ang, rot_x=math.radians(90.0))
    parts.append(calyx)

    for p in range(5):
        pa = ang + p * (2.0 * math.pi / 5.0)
        petal = blade(f"{name}_petal_{p}", 0.042, 0.030, petal_mat,
                      seg_u=8, seg_v=6, droop=-0.18, cup=0.45, pointed=1.0,
                      curl=0.2)
        place(petal, base + Vector((0.0, 0.0, 0.004)), rot_z=pa,
              rot_y=math.radians(-52.0))
        parts.append(petal)
    return parts


class _Rng:
    """固定种子的线性同余，保证每次导出的植株形态一致。"""

    def __init__(self, seed: int):
        self.s = seed & 0x7FFFFFFF

    def next(self) -> float:
        self.s = (self.s * 1103515245 + 12345) & 0x7FFFFFFF
        return self.s / 0x7FFFFFFF

    def f(self, lo: float, hi: float) -> float:
        return lo + (hi - lo) * self.next()
