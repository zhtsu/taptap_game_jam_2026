class_name RoadCar
extends Node2D

## 关卡里的**障碍车**（2D 俯视：车身 + 车顶 + 两个前灯）：只有数据 + 外观，**自己不动**。
##
## 为什么车不自己走：位置这个属性只能有一个写入者 —— 车自己 `position.y += ...`
## 的同时关卡又按"滚动速度 + 迎面速度"推它，两处会互相覆盖，表现是"车抖/卡住"且不报错
## （ENGINEERING_NOTES 016 那一类）。所以：**动它的人只有关卡一个**（`road_level.gd` 的 `_process`）。
##
## 用法（顺序不能反）：
##   ```gdscript
##   var car: RoadCar = packed.instantiate()
##   cars_root.add_child(car)          # 先入树，_ready() 才会解析 %Body 之类
##   car.configure(lane, color)        # 再定车道 / 上色
##   car.position = Vector2(x, y)      # 最后放位置
##   ```

## 车身尺寸（像素）：x = 车宽（横向），y = 车长（**沿前进方向**，屏幕上就是高度）。
## 撞车判定与感知距离都用它算车头 / 车尾，所以这是**数据**，不只是外观。
@export var size_px: Vector2 = Vector2(190.0, 420.0)
## 迎面速度（像素/秒，往 +y 冲向跑者）。0 = 停在路上（相对跑者仍在后退）
@export var oncoming_speed_px: float = 800.0

## 所在车道下标（0 = 最左）。由关卡在 `configure()` 里写入。
var lane: int = 1

@onready var _shadow: ColorRect = %Shadow
@onready var _body: ColorRect = %Body
@onready var _roof: ColorRect = %Roof
@onready var _light_l: ColorRect = %LightLeft
@onready var _light_r: ColorRect = %LightRight


## 尺寸的唯一事实来源是 `size_px`：场景里的矩形只是编辑器里的占位（编辑器不跑脚本）
func _ready() -> void:
	_apply_size()


## 关卡生成时调用：定车道 + 上色。**必须在 `add_child()` 之后调**（`%` 要 `_ready()` 才解析）。
func configure(lane_index: int, color: Color) -> void:
	lane = lane_index
	_body.color = color
	_roof.color = color.darkened(0.38)


## 按 `size_px` 摆好所有矩形（原点 = 车身中心）
func _apply_size() -> void:
	var half: Vector2 = size_px * 0.5

	_body.size = size_px
	_body.position = -half

	# 车顶：偏车头方向的反面（车头朝 +y，因为它迎着跑者开下来）
	var roof_size := Vector2(size_px.x * 0.72, size_px.y * 0.40)
	_roof.size = roof_size
	_roof.position = Vector2(-roof_size.x * 0.5, -half.y + size_px.y * 0.16)

	# 前灯：车头（+y）两侧
	var light := Vector2(size_px.x * 0.17, size_px.y * 0.085)
	_light_l.size = light
	_light_l.position = Vector2(-half.x + size_px.x * 0.13, half.y - size_px.y * 0.075 - light.y)
	_light_r.size = light
	_light_r.position = Vector2(half.x - size_px.x * 0.13 - light.x, _light_l.position.y)

	# 阴影：比车身略大一点、往下偏一点，让车"贴"在路上
	_shadow.size = size_px * Vector2(1.08, 1.05)
	_shadow.position = Vector2(-_shadow.size.x * 0.5, -half.y + 20.0)
