## LabelProjector.gd — 2D 投影标签
##
## 为什么不用 Label3D：近距离会被深度裁切成重影、远一点又糊，字号与 pixel_size
## 怎么调都不稳。改成把世界坐标 `unproject_position` 到屏幕，用普通 Label 画，
## 任何距离都是原生分辨率。
##
## 场景里的 `add_label3d()` / `attach_label3d()` 已经走这里，返回的 TagLabel
## 保留了 `text` / `font_size` / `outline_size` / `outline_modulate` /
## `modulate` / `visible` / `position` 这些属性，所以老的调用代码不用改。
class_name LabelProjector
extends Node

## 3D 标签字号（40~50 那套）到 2D 像素字号的粗略映射
const FONT_SCALE := 0.50
const FONT_MIN := 15
const FONT_MAX := 27

var camera: Camera3D
var canvas: CanvasLayer
var _tags: Array[TagLabel] = []

func setup(cam: Camera3D, cv: CanvasLayer) -> void:
	camera = cam
	canvas = cv

## 加一个跟随 anchor 的标签（anchor 失效后停在最后一帧的位置）
func add(text: String, anchor: Node3D, offset: Vector3,
		world_size: int = 44, color: Color = Color.WHITE) -> TagLabel:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", _font_for(world_size))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 0.9))
	lbl.add_theme_color_override("font_color", color)
	canvas.add_child(lbl)
	lbl.reset_size()

	var tag := TagLabel.new(self, lbl, anchor, offset)
	_tags.append(tag)
	return tag

## 加一个固定在某个世界坐标上的标签
func add_at(text: String, world: Vector3,
		world_size: int = 44, color: Color = Color.WHITE) -> TagLabel:
	var tag := add(text, null, Vector3.ZERO, world_size, color)
	tag._fixed = world
	return tag

static func _font_for(world_size: int) -> int:
	return int(clampf(float(world_size) * FONT_SCALE, FONT_MIN, FONT_MAX))

func _process(_delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	for tag in _tags:
		tag._sync(camera)


# =====================================================================
# 单个标签
# =====================================================================
class TagLabel extends RefCounted:
	var _label: Label
	var _anchor: Node3D
	var _offset: Vector3
	var _fixed: Vector3
	var _wanted_visible: bool = true

	func _init(_projector: LabelProjector, label: Label, anchor: Node3D,
			offset: Vector3) -> void:
		_label = label
		_anchor = anchor
		_offset = offset

	func _sync(camera: Camera3D) -> void:
		if not is_instance_valid(_label):
			return
		var world := _fixed
		if is_instance_valid(_anchor):
			world = _anchor.global_position + _offset
			_fixed = world
		if camera.is_position_behind(world):
			_label.visible = false
			return
		_label.visible = _wanted_visible
		var screen := camera.unproject_position(world)
		_label.position = screen - Vector2(_label.size.x * 0.5, _label.size.y * 0.5)

	# ---------------------------------------------------------- 兼容 Label3D 的接口
	var text: String:
		set(value):
			_label.text = value
			_label.reset_size()
		get:
			return _label.text

	var font_size: int:
		set(value):
			_label.add_theme_font_size_override("font_size",
				LabelProjector._font_for(value))
			_label.reset_size()

	## 直接给像素字号，绕开 _font_for 的上下限（个别标题用）
	var font_px: int:
		set(value):
			_label.add_theme_font_size_override("font_size", value)
			_label.reset_size()

	## 加粗：用 FontVariation 的 embolden，不依赖额外字体文件
	var bold: bool:
		set(value):
			if value:
				var fv := FontVariation.new()
				fv.base_font = _label.get_theme_font("font")
				fv.variation_embolden = 1.1
				_label.add_theme_font_override("font", fv)
			else:
				_label.remove_theme_font_override("font")
			_label.reset_size()

	var outline_size: int:
		set(value):
			_label.add_theme_constant_override("outline_size", value)

	var outline_modulate: Color:
		set(value):
			_label.add_theme_color_override("font_outline_color", value)

	var modulate: Color:
		set(value):
			_label.add_theme_color_override("font_color", value)

	var visible: bool:
		set(value):
			_wanted_visible = value
			_label.visible = value
		get:
			return _wanted_visible

	var position: Vector3:
		set(value):
			_offset = value
			if not is_instance_valid(_anchor):
				_fixed = value
		get:
			return _offset
