#!/usr/bin/env python3
"""生成样板关所需的 PBR 贴图（albedo / roughness / normal）。

不依赖 Blender，也不联网：全部用 numpy + Pillow 确定性程序化生成，
重跑结果一致（固定随机种子）。

用法：
    python3 blender/build_textures.py
输出：
    assets/textures/*.png
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "textures")
SIZE = 512

# ----------------------------------------------------------------------------- 工具


def fbm(shape: tuple[int, int], base: int = 4, octaves: int = 5,
        persistence: float = 0.5, seed: int = 0) -> np.ndarray:
    """分形噪声，返回 [0,1] 的二维数组。"""
    h, w = shape
    rng = np.random.default_rng(seed)
    total = np.zeros(shape, np.float32)
    amplitude = 1.0
    norm = 0.0
    for octave in range(octaves):
        grid = max(2, base * 2 ** octave)
        lattice = rng.random((grid, grid)).astype(np.float32)
        layer = Image.fromarray((lattice * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        total += np.asarray(layer, np.float32) / 255.0 * amplitude
        norm += amplitude
        amplitude *= persistence
    return total / norm


def smoothstep(edge0: float, edge1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def normal_from_height(height: np.ndarray, strength: float = 2.0) -> np.ndarray:
    """中心差分求法线。height 越大越高；返回 RGB uint8。"""
    dx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    dy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / length, ny / length, nz / length], axis=-1)
    return ((normal * 0.5 + 0.5) * 255.0).clip(0, 255).astype(np.uint8)


def save(name: str, rgb: np.ndarray) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    Image.fromarray(rgb.astype(np.uint8), "RGB").save(os.path.join(OUT_DIR, name), optimize=True)
    print("  ->", name)


def tint(gray: np.ndarray, color: tuple[float, float, float]) -> np.ndarray:
    """把 [0,1] 灰度映射到颜色，保留明暗层次。"""
    rgb = np.stack([gray * c for c in color], axis=-1)
    return (rgb.clip(0, 1) * 255.0).astype(np.uint8)


def grayscale(gray: np.ndarray) -> np.ndarray:
    g = (gray.clip(0, 1) * 255.0).astype(np.uint8)
    return np.stack([g, g, g], axis=-1)


# ----------------------------------------------------------------------------- 材质


def build_epoxy_bench() -> None:
    """黑色环氧树脂台面：细密颗粒 + 大尺度斑驳 + 颗粒凸起。"""
    print("epoxy bench")
    speck = fbm((SIZE, SIZE), base=64, octaves=3, seed=11)
    speck = smoothstep(0.80, 0.90, speck)                      # 稀疏的白/灰颗粒
    mottle = fbm((SIZE, SIZE), base=3, octaves=5, seed=12)
    fine = fbm((SIZE, SIZE), base=128, octaves=2, seed=13)

    base = 0.135 + 0.045 * mottle + 0.02 * fine
    albedo = tint(base, (0.98, 0.99, 1.02))
    albedo = np.clip(albedo.astype(np.float32) + speck[..., None] * 16.0, 0, 255)

    rough = 0.34 + 0.10 * (mottle - 0.5) + 0.16 * speck
    height = 0.55 * speck + 0.45 * mottle * 0.25

    save("epoxy_bench_albedo.png", albedo)
    save("epoxy_bench_roughness.png", grayscale(rough))
    save("epoxy_bench_normal.png", normal_from_height(height, 3.0))


def build_stainless() -> None:
    """拉丝不锈钢：横向纹路。"""
    print("stainless steel")
    # 横向拉丝：先在高度方向压缩，再拉伸回来
    raw = np.random.default_rng(21).random((SIZE // 8, SIZE)).astype(np.float32)
    streak = np.asarray(
        Image.fromarray((raw * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.BICUBIC), np.float32
    ) / 255.0
    streak = 0.65 * streak + 0.35 * fbm((SIZE, SIZE), base=2, octaves=4, seed=22)

    base = 0.66 + 0.08 * (streak - 0.5)
    albedo = tint(base, (1.0, 1.01, 1.03))

    rough = 0.20 + 0.10 * (streak - 0.5) + 0.04 * fbm((SIZE, SIZE), base=128, octaves=2, seed=23)
    height = streak * 0.25

    save("steel_albedo.png", albedo)
    save("steel_roughness.png", grayscale(rough))
    save("steel_normal.png", normal_from_height(height, 6.0))


def build_tile_wall() -> None:
    """实验室白瓷砖墙：100 mm 砖 + 勾缝。"""
    print("tile wall")
    tiles_per_side = 4
    tile_px = SIZE // tiles_per_side
    grout_px = 5

    albedo = np.zeros((SIZE, SIZE, 3), np.float32)
    rough = np.zeros((SIZE, SIZE), np.float32)
    height = np.ones((SIZE, SIZE), np.float32)

    rng = np.random.default_rng(31)
    for ty in range(tiles_per_side):
        for tx in range(tiles_per_side):
            shade = 0.90 + 0.055 * rng.random()
            albedo[ty * tile_px:(ty + 1) * tile_px, tx * tile_px:(tx + 1) * tile_px] = shade
            rough[ty * tile_px:(ty + 1) * tile_px, tx * tile_px:(tx + 1) * tile_px] = 0.13

    # 砖面微观起伏 + 污渍
    micro = fbm((SIZE, SIZE), base=32, octaves=4, seed=32)
    albedo *= (0.97 + 0.06 * micro)[..., None]
    rough += 0.05 * micro

    # 勾缝：换成更暗更粗糙的材质，并压低高度
    grout_mask = np.zeros((SIZE, SIZE), np.float32)
    for k in range(tiles_per_side + 1):
        i = min(k * tile_px, SIZE - 1)
        lo = max(0, i - grout_px // 2)
        hi = min(SIZE, i + grout_px // 2 + 1)
        grout_mask[lo:hi, :] = 1.0
        grout_mask[:, lo:hi] = 1.0
    # 边缘柔化，避免勾缝出现硬锯齿
    grout_soft = np.asarray(
        Image.fromarray((grout_mask * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.BICUBIC), np.float32
    ) / 255.0

    grout_dirt = 0.55 + 0.12 * fbm((SIZE, SIZE), base=16, octaves=3, seed=33)
    albedo = albedo * (1.0 - grout_soft[..., None]) + grout_dirt[..., None] * grout_soft[..., None]
    rough = rough * (1.0 - grout_soft) + 0.85 * grout_soft
    height = height * (1.0 - grout_soft) + 0.35 * grout_soft

    rgb = np.clip(albedo * np.array([1.0, 0.995, 0.975]), 0, 1) * 255.0
    save("tile_albedo.png", rgb)
    save("tile_roughness.png", grayscale(rough))
    save("tile_normal.png", normal_from_height(height, 4.0))


def build_agar() -> None:
    """琼脂培养基表面：接近白色（便于在 Godot 里按关卡染色）+ 微小气泡。"""
    print("agar")
    mottle = fbm((SIZE, SIZE), base=6, octaves=4, seed=41)
    img = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(42)
    for _ in range(70):
        cx, cy = rng.integers(0, SIZE, 2)
        r = int(rng.integers(2, 7))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=int(rng.integers(90, 200)))
    bubbles = np.asarray(img, np.float32) / 255.0
    bubbles = np.asarray(
        Image.fromarray((bubbles * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.BICUBIC), np.float32
    ) / 255.0

    base = 0.94 + 0.05 * mottle
    albedo = tint(base, (1.0, 1.0, 0.99))
    albedo = np.clip(albedo.astype(np.float32) - bubbles[..., None] * 22.0, 0, 255)

    rough = 0.16 + 0.10 * mottle - 0.06 * bubbles
    height = 0.35 * mottle + 0.5 * bubbles

    save("agar_albedo.png", albedo)
    save("agar_roughness.png", grayscale(rough))
    save("agar_normal.png", normal_from_height(height, 2.0))


def build_floor() -> None:
    """实验室环氧地坪：浅灰绿、大面积斑驳。"""
    print("floor")
    mottle = fbm((SIZE, SIZE), base=3, octaves=6, seed=51)
    fine = fbm((SIZE, SIZE), base=64, octaves=3, seed=52)

    base = 0.52 + 0.10 * mottle + 0.05 * fine
    albedo = tint(base, (0.93, 0.96, 0.93))
    rough = 0.30 + 0.12 * (mottle - 0.5)
    height = 0.6 * fine + 0.4 * mottle

    save("floor_albedo.png", albedo)
    save("floor_roughness.png", grayscale(rough))
    save("floor_normal.png", normal_from_height(height, 1.5))



def build_contact_shadow() -> None:
    """接触阴影贴图：中心不透明、边缘柔软的圆形暗斑。

    给器皿和台面之间补一层假环境遮蔽。gl_compatibility 没有 SSAO，
    没有这层暗角，器皿看起来就是「贴」在台面上的。
    """
    print("contact_shadow")
    size = 256
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cx = cy = (size - 1) / 2.0
    dist = np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2)
    alpha = (1.0 - smoothstep(0.12, 1.0, dist)) ** 1.5
    rgba = np.zeros((size, size, 4), np.uint8)
    rgba[..., 3] = (alpha * 255).clip(0, 255).astype(np.uint8)
    path = os.path.join(OUT_DIR, "contact_shadow.png")
    Image.fromarray(rgba, "RGBA").save(path, optimize=True)
    print("  ->", "contact_shadow.png")


def build_vignette() -> None:
    """暗角叠加层（RGBA，中心透明、四周变暗）。"""
    print("vignette")
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    cx = cy = (SIZE - 1) / 2.0
    dist = np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2) / np.sqrt(2.0)
    alpha = smoothstep(0.45, 1.0, dist) ** 1.4
    rgba = np.zeros((SIZE, SIZE, 4), np.uint8)
    rgba[..., 3] = (alpha * 255).clip(0, 255).astype(np.uint8)
    path = os.path.join(OUT_DIR, "vignette.png")
    Image.fromarray(rgba, "RGBA").save(path, optimize=True)
    print("  ->", "vignette.png")


def main() -> None:
    print("输出目录:", OUT_DIR)
    build_epoxy_bench()
    build_stainless()
    build_tile_wall()
    build_agar()
    build_floor()
    build_contact_shadow()
    build_vignette()
    print("完成")


if __name__ == "__main__":
    main()
