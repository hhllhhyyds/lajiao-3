## CinematicLab.gd — 统一的"实验室摄影棚"
##
## 七关共用的环境与布光底座。目标不是让每关长得一样，而是让它们在同一个
## 色彩与光比体系里：同样的 ACES 曲线、同样的环境光底子、同样的接触阴影与暗角。
##
## 用法（SceneBase 已经接好，场景里一般不用直接调用）：
##     CinematicLab.setup_environment(self, "lab")
##     CinematicLab.setup_lighting(self, light_focus, light_radius, "lab")
##     CinematicLab.add_vignette(canvas_layer)
##
## 预设
## ----
## "lab"     室内实验室：中性冷白环境光，瓷砖墙洗光，台面上方一片光池
## "indoor"  室内无窗／培养室：更暗更蓝，只有顶灯，适合培养箱、暗室场景
## "outdoor" 户外田块：强方向光 + 天空色环境光，无墙面洗光
##
## 坐标约定：focus 是画面主体的世界坐标，radius 是主体大致半径（米）。
## 所有灯位都按 radius 缩放，所以同一套 rig 能同时服务 1 米的培养皿台面
## 和 10 米宽的接种台。
class_name CinematicLab
extends RefCounted

# ------------------------------------------------------------------ 预设参数

const PRESETS := {
	"lab": {
		"bg": Color(0.10, 0.11, 0.115),
		"ambient": Color(0.62, 0.67, 0.74),
		"ambient_energy": 0.38,
		"exposure": 1.0,
		"key_energy": 1.05,
		"key_color": Color(1.0, 0.96, 0.90),
		"fill_energy": 0.30,
		"fill_color": Color(0.60, 0.71, 0.92),
		"wall_wash": true,
		"rim": true,
		"pool": true,
		"glow": 0.25,
	},
	"indoor": {
		"bg": Color(0.06, 0.07, 0.09),
		"ambient": Color(0.46, 0.54, 0.68),
		"ambient_energy": 0.30,
		"exposure": 1.02,
		"key_energy": 0.85,
		"key_color": Color(0.86, 0.92, 1.0),
		"fill_energy": 0.22,
		"fill_color": Color(0.45, 0.60, 0.95),
		"wall_wash": false,
		"rim": true,
		"pool": true,
		"glow": 0.35,
	},
	"outdoor": {
		"bg": Color(0.42, 0.55, 0.68),
		"ambient": Color(0.58, 0.68, 0.80),
		"ambient_energy": 0.55,
		"exposure": 0.98,
		"key_energy": 1.35,
		"key_color": Color(1.0, 0.94, 0.82),
		"fill_energy": 0.35,
		"fill_color": Color(0.55, 0.72, 1.0),
		"wall_wash": false,
		"rim": true,
		"pool": false,
		"glow": 0.18,
	},
}

# ------------------------------------------------------------------ 环境

static func setup_environment(parent: Node, preset: String = "lab") -> WorldEnvironment:
	var p: Dictionary = PRESETS.get(preset, PRESETS["lab"])

	var we := WorldEnvironment.new()
	var env := Environment.new()

	# 纯色背景：gl_compatibility 下程序化天空会退化成黑场，连带环境光一起失效
	env.background_mode = Environment.BG_COLOR
	env.background_color = p["bg"]

	# 环境光是写实感的底座，没有它竖面全黑、只剩一盏硬光
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p["ambient"]
	env.ambient_light_energy = p["ambient_energy"]

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = p["exposure"]
	env.tonemap_white = 6.0

	env.fog_enabled = false
	env.glow_enabled = true
	env.glow_strength = p["glow"]
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 0.95

	we.environment = env
	we.name = "CinematicEnv"
	parent.add_child(we)
	return we

# ------------------------------------------------------------------ 灯光

static func setup_lighting(parent: Node, focus: Vector3, radius: float,
		preset: String = "lab", intensity: float = 1.0) -> void:
	var p: Dictionary = PRESETS.get(preset, PRESETS["lab"])
	var r: float = maxf(radius, 0.2)
	var k: float = maxf(intensity, 0.0)

	# 主光：唯一投影的灯，负责明暗结构
	var key := DirectionalLight3D.new()
	key.name = "CinematicKey"
	key.rotation_degrees = Vector3(-46.0, 34.0, 0.0)
	key.light_color = p["key_color"]
	key.light_energy = float(p["key_energy"]) * k
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	key.directional_shadow_max_distance = maxf(r * 12.0, 12.0)
	key.shadow_blur = 1.5
	key.light_angular_distance = 0.6
	key.shadow_bias = 0.02
	key.shadow_normal_bias = 1.0
	parent.add_child(key)

	# 补光：冷色，从另一侧压住暗部
	var fill := DirectionalLight3D.new()
	fill.name = "CinematicFill"
	fill.rotation_degrees = Vector3(-12.0, -125.0, 0.0)
	fill.light_color = p["fill_color"]
	fill.light_energy = float(p["fill_energy"]) * k
	fill.shadow_enabled = false
	parent.add_child(fill)

	# 墙面洗光：让背景墙读成"房间"而不是黑幕
	if p.get("wall_wash", false):
		var wash := DirectionalLight3D.new()
		wash.name = "CinematicWallWash"
		wash.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
		wash.light_color = Color(0.86, 0.90, 0.95)
		wash.light_energy = 0.07
		wash.shadow_enabled = false
		parent.add_child(wash)

	# 轮廓光：从主体左后上方勾边
	if p.get("rim", false):
		var rim := SpotLight3D.new()
		rim.name = "CinematicRim"
		rim.position = focus + Vector3(-0.45, 0.7, -1.05) * r
		rim.look_at(focus + Vector3(0.0, 0.15 * r, 0.0))
		rim.light_color = Color(0.80, 0.88, 1.0)
		rim.light_energy = 2.6 * k
		rim.spot_range = r * 5.0
		rim.spot_angle = 34.0
		rim.spot_angle_attenuation = 0.8
		rim.shadow_enabled = false
		parent.add_child(rim)

	# 光池：宽角聚光从上方压下来，深色台面才有明暗梯度
	if p.get("pool", false):
		var pool := SpotLight3D.new()
		pool.name = "CinematicPool"
		pool.position = focus + Vector3(0.05, 1.45, 0.2) * r
		pool.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		pool.light_color = Color(1.0, 0.97, 0.92)
		pool.light_energy = 2.4 * k
		pool.spot_range = r * 4.5
		pool.spot_angle = 58.0
		pool.spot_angle_attenuation = 0.55
		pool.shadow_enabled = false
		parent.add_child(pool)

	# 相机侧柔光：把主体正面提亮一档
	var front := OmniLight3D.new()
	front.name = "CinematicFront"
	front.position = focus + Vector3(0.35, 0.35, 0.85) * r
	front.light_color = Color(1.0, 0.97, 0.92)
	front.light_energy = 0.45 * k
	front.omni_range = r * 3.5
	front.shadow_enabled = false
	parent.add_child(front)

# ------------------------------------------------------------------ 暗角

## 屏幕暗角：把注意力压到画面中心，也顺手压掉边角的穿帮
static func add_vignette(canvas: CanvasLayer) -> TextureRect:
	var tex := load("res://assets/textures/vignette.png") as Texture2D
	if tex == null:
		return null
	var rect := TextureRect.new()
	rect.name = "Vignette"
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)
	return rect

# ------------------------------------------------------------------ 相机

## 极其轻微的呼吸感。幅度按机位距离缩放，远了自动变小，避免大场景里晃得明显。
static func breathe(camera: Camera3D, base_pos: Vector3, target: Vector3,
		time: float, amount: float = 1.0) -> void:
	if amount <= 0.0:
		camera.position = base_pos
		camera.look_at(target, Vector3.UP)
		return
	var dist := base_pos.distance_to(target)
	var amp: float = clampf(dist * 0.0009, 0.0006, 0.012) * amount
	var drift := Vector3(
		sin(time * 0.37) * amp,
		sin(time * 0.53 + 1.1) * amp * 0.55,
		cos(time * 0.29) * amp * 0.6
	)
	camera.position = base_pos + drift
	camera.look_at(target + Vector3(drift.x * 0.25, drift.y * 0.4, 0.0), Vector3.UP)
