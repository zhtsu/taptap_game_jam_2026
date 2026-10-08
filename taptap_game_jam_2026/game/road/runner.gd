class_name RoadRunner
extends Node2D

## 关卡里的跑者（兽人）—— **2D 俯视占位图形**（身体 + 腰带 + 头）。
##
## 这里**只有外观和"别人叫我做什么"的两件事**，不做任何判断：
##   - `move_toward_x(target_x, delta)`：朝目标 x 平移（**这个属性只有本脚本写**）
##   - `crash()`：撞车后的姿态（歪倒）
## "该去哪条道"是玩法的事（`road_level.gd` 收到 `Events.LANE_MOVE_REQUEST` 后调这里）。
##
## 为什么位置逻辑在脚本里、而不在关卡里直接改节点：跑者以后要换成**装配好的兽人**
## （整个场景替换），把它自己的表现收在一个脚本里，换模型时不用动关卡的玩法代码。

## 横移速度（像素/秒）。300 像素一条车道 ≈ 0.21 秒换过去。
@export var strafe_speed_px: float = 1400.0

## 撞车后歪倒的角度（度）。视觉反馈：让"撞了"一眼看得出来。
const CRASH_TILT_DEGREES: float = -20.0
## 撞车后往后坐的距离（像素）
const CRASH_PUSH_BACK: float = 26.0

## 立绘的原点（0,0）在**身体中心**：缩放/歪倒都绕身体转，看起来才对
var _crashed: bool = false


## 朝某个 x 平移（每帧由关卡调用；关卡是唯一的调用方，不存在两个写入者）
func move_toward_x(target_x: float, delta: float) -> void:
	if _crashed:
		return
	position.x = move_toward(position.x, target_x, strafe_speed_px * delta)


## 撞车：歪倒 + 往后一点。可重复调用（已经撞了就什么都不做）
func crash() -> void:
	if _crashed:
		return
	_crashed = true
	rotation_degrees = CRASH_TILT_DEGREES
	position.y += CRASH_PUSH_BACK


func is_crashed() -> bool:
	return _crashed
