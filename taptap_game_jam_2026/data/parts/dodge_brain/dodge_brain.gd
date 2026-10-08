extends PartBehavior

## 「闪避脑」：**"角色自己操作"就发生在这个部件里**。
##
## 关卡只上报状态（前方 / 左侧 / 右侧有没有车、多远），本部件负责**决定去哪条道**，
## 然后发 `Events.LANE_MOVE_REQUEST`（命令事件）让关卡执行 ——
## 部件**不持有跑者 / 关卡的引用**（见 part_behavior.gd 约定 3：不做条件判断以外的世界访问）。
## 车道数、自己在哪条道都由感知事件的 payload 带过来，所以它也不认识具体是哪一关。
##
## 决策规则故意简单（够用就好）：
##   1) 前方没车 → 什么都不做；
##   2) 前方有车 → 优先往左（左边没有车时），否则往右（右边没有车时）；
##   3) 两侧都有车 → 原地不动 —— 撞上去就是装配不够好，这是玩法的一部分。
##
## 订阅所有"进入 / 离开"事件并每次都重新决策：光看"前方进入"是不够的，
## 侧面的车开过去（离开）之后可能正好腾出一条道。

## 关心的事件：三条车道 × 进入 / 离开（成对，见 core/events.gd）
const EVENTS: Array[StringName] = [
	Events.OBSTACLE_AHEAD_ENTERED,
	Events.OBSTACLE_AHEAD_EXITED,
	Events.ENEMY_LEFT_ENTERED,
	Events.ENEMY_LEFT_EXITED,
	Events.ENEMY_RIGHT_ENTERED,
	Events.ENEMY_RIGHT_EXITED,
]

## 上一次感知报上来的距离（米）。**负数 = 那边没有车**。
var _ahead: float = -1.0
var _left: float = -1.0
var _right: float = -1.0
## 自己在哪条道 / 一共几条道（从 payload 的 `player_lane` / `lane_count` 更新）
var _lane: int = 1
var _lane_count: int = 3


func events_of_interest() -> Array[StringName]:
	return EVENTS


func on_event(slot_id: String, event: StringName, context: Dictionary) -> void:
	match event:
		Events.OBSTACLE_AHEAD_ENTERED:
			_ahead = float(context.get("distance", 0.0))
		Events.OBSTACLE_AHEAD_EXITED:
			_ahead = -1.0
		Events.ENEMY_LEFT_ENTERED:
			_left = float(context.get("distance", 0.0))
		Events.ENEMY_LEFT_EXITED:
			_left = -1.0
		Events.ENEMY_RIGHT_ENTERED:
			_right = float(context.get("distance", 0.0))
		Events.ENEMY_RIGHT_EXITED:
			_right = -1.0
		_:
			return

	# "进入"事件带车道信息，"离开"事件没有载荷 —— 所以缺什么就沿用上一次的
	_lane = int(context.get("player_lane", _lane))
	_lane_count = int(context.get("lane_count", _lane_count))

	_decide(slot_id)


## 决策：只在"前方有车"时才有动作。两侧的占用状态决定往哪边躲。
func _decide(slot_id: String) -> void:
	if _ahead < 0.0:
		return

	var target: int = _lane
	if _lane > 0 and _left < 0.0:
		target = _lane - 1
	elif _lane < _lane_count - 1 and _right < 0.0:
		target = _lane + 1

	if target == _lane:
		CoreSystem.logger.info("[闪避脑] %s 前方 %.1f 米有车，两侧都不空（左 %s / 右 %s）—— 只能硬吃"
			% [slot_id, _ahead, _describe(_left), _describe(_right)])
		return

	CoreSystem.logger.info("[闪避脑] %s 前方 %.1f 米有车 → 换到车道 %d" % [slot_id, _ahead, target])
	# 方向：部件 → 玩法。**payload 是单个 int**（不是数组，数组会被当成参数表展开）
	CoreSystem.event_bus.push_event(Events.LANE_MOVE_REQUEST, target)


## 日志里把"没有车"和"有车"写清楚
func _describe(distance: float) -> String:
	return "无车" if distance < 0.0 else "%.1f 米" % distance
