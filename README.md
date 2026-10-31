# 辣椒花药培养 · 单倍体育种模拟

一个 7 关的实验流程教学游戏：从配培养基一路走到染色体加倍获得 DH 系植株。
视觉方向是**写实科教纪录片**——台面、玻璃器皿、培养箱都是 Blender 参数化建模后导入的
真实模型，不是 Godot 里的基础几何体。

引擎 **Godot 4.7**（`gl_compatibility` 后端，面向 Android），美术资产用 **Blender 5.1**
脚本生成，全部源码可复现。

---

## 快速开始

```bash
# 1. 让 Godot 建立导入缓存（GLB / 贴图 / 材质都要走一遍）
Godot --headless --import

# 2. 运行
Godot --path .
```

> **第 1 步不是可选的。** 直接 `Godot --path .` 打开仓库，`assets/props/*.glb` 尚未导入，
> `preload()` 会报 `Could not preload resource file`，场景一片空白。改了任何 GLB 或
> `.tres` 之后也要重跑一次 `--import`，否则用的是旧缓存。

主场景是 `scenes/MainMenu.tscn`，规格 1440×1000。

---

## 关卡

| 关 | 场景 | 内容 |
|---|---|---|
| 1 | `Scene1` 配制诱导培养基 | 三种培养基配方配对（激素种类与比例） |
| 2 | `Scene2` 辣椒花药选取 | 挑选单核靠边期花药，放入 3–5 ℃ 低温预处理箱 |
| 3 | `Scene3` 花药消毒与接种 | 酒精 → 无菌水 → 次氯酸钠 → 无菌水 的四步消毒流程 |
| 4 | `Scene4` 愈伤组织诱导培养 | 33–37 ℃ 黑暗热激 2–10 天，再转 25 ℃ 光照培养 |
| 5 | `Scene5` 生芽与生根诱导 | 愈伤组织 → 生芽培养基 → 生根培养基 |
| 6 | `Scene6` 倍性鉴定 | 显微镜下数染色体，挑出 n=12 的单倍体 |
| 7 | `Scene7` 染色体加倍 | 秋水仙素浸泡，验证 2n=24，育成 DH 系 |

每关都走 `SceneBase.gd` 的步骤机：`_show_step(i)` 切换文案与高亮，`advance_step()` 推进，
`_complete_scene()` 收尾。交互物件由 `create_interactable()` 统一创建（透明碰撞体 +
Label3D 提示），存进 `interactables` 字典。

---

## 目录

```
scenes/            各关场景 + 主菜单 / 关卡选择 / 通关页
scripts/
  SceneBase.gd     关卡基类：步骤机、交互物件、相机、灯光入口
  CinematicLab.gd  灯光预设（indoor / outdoor）、环境、雾、轮廓光
  PropKit.gd       GLB 载入 + 按节点名前缀替换材质 + 接触阴影
  LabelProjector.gd 3D 锚点标签（避免标签叠在一起）
  Scene1..7.gd     各关的具体搭建与玩法
assets/props/      Blender 导出的 GLB
assets/textures/   程序化合成的 PBR 贴图
materials/         材质 .tres
blender/           建模与贴图生成脚本
tools/             截图 / 走关检查工具
docs/steps/        走关自动截图（已 gitignore，可随时重生成）
```

---

## 美术资产流水线

```
blender/build_textures.py   →  assets/textures/*.png   （numpy + Pillow 程序化 PBR）
blender/build_props.py      →  assets/props/*.glb      （bmesh 参数化建模）
Godot --headless --import   →  .godot/imported
```

重建：

```bash
python3 blender/build_textures.py
Blender -b --python blender/build_props.py
Godot --headless --import
```

### 约定

- **朝向**：Blender 里 −Y 是正面，`export_yup=True` 导出后对应 Godot 的 +Z。
- **原点**：所有道具原点在物理底面中心，摆放时直接给台面高度即可。
- **UV**：`apply_world_uv()` 做世界坐标盒式投影，1 世界单位 = 1 UV 单位。
- **材质替换**：Godot 侧不重新导入材质，而是 `PropKit.spawn()` 按**节点名前缀**把
  GLB 里的材质换成 `materials/*.tres`。所以 Blender 里的物体命名是有意义的
  （`bottle_body`、`media_cap`、`incubator_shelf_0` …），改名会静默失效。

### 现有模型

`reagent_bottle` `media_bottle` `beaker` `conical_flask` `petri_dish` `lab_tray`
`tube_rack` `lab_bench` `lab_room` `incubator` `plantlet` `microscope`
`pepper_plant`（371 个部件）`anther`

---

## 走关检查

`tools/walkthrough.tscn` 会自动跑完一关的每个步骤并截图，同时把每个交互物件反投影到
屏幕坐标，**报出画**：

```bash
Godot --path . res://tools/walkthrough.tscn -- \
  --scene res://scenes/Scene2.tscn --out res://docs/steps --wait 20
```

输出里 `OK` 表示在画面内，`出画` 表示屏幕坐标超出了 1440×1000，`!!` 表示找不到物件。

这一步是必需的：改机位或改布局时，交互物件很容易被推出画面，而**玩家点不到就等于卡关**。
注意它只检查坐标，最终还是要看图——`docs/steps/SceneN_stepM.png`。

单帧截图用 `tools/capture.tscn`：

```bash
Godot --path . res://tools/capture.tscn -- \
  --scene res://scenes/Scene3.tscn --out res://docs/shots/x.png --wait 40 \
  --cam=-1.4,1.55,2.4,-2.0,1.3,-0.3,34
```

---

## 已知限制

- **渲染后端**：`gl_compatibility` 没有 SSAO / SSR / DOF / 体积雾，也没有真正的折射
  透射。所以落地阴影靠 `PropKit.contact_shadow()` 的假接触阴影，玻璃靠
  `transparency + specular_mode = 2 + rim` 近似。
- **天空**：程序化天空在 compatibility 下会退化成纯黑，户外关（Scene2）用的是渐变
  背景板而不是 `WorldEnvironment` 的天空。
- **场景尺度不统一**：Scene3 是约 4 倍尺度（台面 10 m 宽、瓶子 0.7 m 高），Scene5 也是
  放大的。这是为了在近景里让器皿占满画面。相对比例自洽，所以不需要整体缩小。
- **墙面瓷砖**：`tile_wall.tres` 用的是世界坐标 UV（1 单位 = 1 m）。我加的墙面是 box，
  每个面的 UV 只有 0..1，直接套会被拉成两米一块——各关用 `_tiled(w, h)` 把密度换算回去。
- **`--check-only` 不可靠**：它不会解析 `preload` 和全局类缓存，语法过了也可能运行时炸。
  验证脚本请用 `--import` + 实际加载场景。

---

## 提交约定

一个主题一个提交，中文说明，讲清楚**改了什么、为什么改、踩了什么坑**，例如：

```
Scene3 瓶子：标签纸、液面、真实培养皿

- 每只试剂瓶加环绕标签纸 + 贴在瓶身上的文字（Label3D 不朝相机，
  朝向要设 0 而不是 180，否则文字是镜像的）
```
