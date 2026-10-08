extends PartBehavior

## 样例部件：**尖刺护臂**（装在左手）。
##
## 用途：把"部件钩子"这条链路跑通的**最小例子**，也当新部件的抄写模板。
## 它演示了约定里的两件事：
##   1) `events_of_interest()` 声明本部件关心哪些事件（写成静态数组，避免每次调用都新建）；
##   2) 收到"状态进入"后 `request_tick(true)` 开始持续作用，收到"离开"后停。
##
## 行为本身是**示例性质**的：前方有障碍时，按固定的每秒伤害往下扣 ——
## 真做玩法时这里换成真正的作用目标（比如调用玩家的某个方法、发一个事件让战斗系统处理）。
## 现在只记账 + 打日志，不碰任何业务状态。

## 关心的事件（`const` 而非每次新建数组：订阅发生在装配时，但保持轻量没坏处）
const EVENTS: Array[StringName] = [
	Events.OBSTACLE_AHEAD_ENTERED,
	Events.OBSTACLE_AHEAD_EXITED,
]

## 持续作用期间累计的"秒数"（示例用，真实部件不需要这个）
var _active_seconds: float = 0.0
## 最近一次事件报来的障碍距离（示例：演示 context 怎么读）
var _last_distance: float = -1.0


func events_of_interest() -> Array[StringName]:
	return EVENTS


func on_event(slot_id: String, event: StringName, context: Dictionary) -> void:
	match event:
		Events.OBSTACLE_AHEAD_ENTERED:
			# context 的键名由业务定义；用 get + 默认值，别直接下标（键不存在会抛错）
			_last_distance = float(context.get("distance", -1.0))
			_active_seconds = 0.0
			request_tick(true)
			CoreSystem.logger.info("[尖刺护臂] %s 前方出现障碍（距离 %s），开始持续作用"
				% [slot_id, _last_distance])
		Events.OBSTACLE_AHEAD_EXITED:
			request_tick(false)
			CoreSystem.logger.info("[尖刺护臂] %s 前方障碍消失，持续作用结束（共 %.2f 秒）"
				% [slot_id, _active_seconds])
		_:
			pass


func on_tick(slot_id: String, context: Dictionary, delta: float) -> void:
	_active_seconds += delta
	# 示例：每秒打一条（真实部件不要每帧打日志）
	if int(_active_seconds) > int(_active_seconds - delta):
		CoreSystem.logger.info("[尖刺护臂] %s 持续作用中：已 %.1f 秒（障碍距离 %s）"
			% [slot_id, _active_seconds, context.get("distance", _last_distance)])
