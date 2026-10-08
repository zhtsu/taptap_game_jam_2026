class_name PartBehavior
extends Node

## 持续钩子的请求状态变化时发出。Host 连它来决定要不要开 `_process`
## （PartHost 是唯一知道"当前帧该不该驱动 tick"的角色）。
signal tick_request_changed(on: bool)

## 是否已请求持续钩子
var _ticking: bool = false

## 部件**行为基类**：兽人部件（`WorkshopPart`）的钩子接口。
##
## 用法：一个部件 = 一个脚本 `extends PartBehavior`，只重写自己关心的那几个钩子。
## 具体部件放在 `data/parts/<部件名>/`，和它的 `.tscn` / `.tres` 同目录。
##
## 设计约定（三条，都是和人确认过的）：
##
## 1) **事件只报"状态改变"**（成对：ENTERED / EXITED），不在状态持续期间反复发事件。
##    所以"持续作用"的写法是：收到 ENTERED → `request_tick(true)`；收到 EXITED → `request_tick(false)`。
##    好处：事件量只跟"状态变化次数"有关，不跟帧率有关。
##
## 2) **订阅哪些事件写在脚本里**（`events_of_interest()`），不写在 Resource 里。
##    逻辑和订阅绑在一起，改部件不用碰 `.tres`。
##
## 3) **本类不做条件判断**。"前方有没有障碍"是业务（感知模块）的事 ——
##    它判断完只上报结果，部件只管"收到之后做什么"。
##    这样部件不需要访问世界，也不会出现"部件各自去查感知"的重复开销。
##
## 谁负责订阅：`PartHost`。它按 `events_of_interest()` 订阅/退订，
## 并把事件转发到本类的 `on_event()`。**子类不要自己订阅事件总线** ——
## 那会让"卸下部件"漏掉退订，留下悬挂订阅。

## 本部件关心哪些事件。返回空数组 = 不关心任何事件（纯被动 / 只靠 tick）。
##
## 事件名一律取自 `core/events.gd`（项目规矩：事件名字符串只能写在那个文件里）。
func events_of_interest() -> Array[StringName]:
	return []


## 事件到达时调一次。`event` 是实际发生的事件名（便于一个部件订阅多个事件）。
##
## `context` 是业务方给的载荷字典 —— 键名由业务定义，本基类不做规定。
## 拿不到就用 `context.get("xxx", 默认值)`，不要直接 `context["xxx"]`（会抛错）。
func on_event(_slot_id: String, _event: StringName, _context: Dictionary) -> void:
	pass


## 持续钩子：**只在 `request_tick(true)` 之后、`request_tick(false)` 之前**被调。
##
## `delta` 是距离上一次调用的秒数。默认实现是空 ——
## 不需要持续作用的部件既不用重写它，也不会有任何开销（Host 在没有部件请求 tick 时
## 会把自己 `set_process(false)`）。
func on_tick(_slot_id: String, _context: Dictionary, _delta: float) -> void:
	pass


## 请求开始 / 停止持续钩子。由**部件自己**在收到状态进出事件时调用。
##
## 为什么状态进出由部件自己管、而不是 Host 代管：
##   同一个事件对不同部件可能是"开始"也可能是"结束"（例如"敌人进入左侧"对攻击部件是开始、
##   对逃跑部件也可能是开始但条件不同）。让部件自己判断最直接，也避免 Host 里长出一套
##   隐式状态机。
func request_tick(on: bool) -> void:
	if _ticking == on:
		return
	_ticking = on
	tick_request_changed.emit(on)


## 当前是否请求了持续钩子
func is_ticking() -> bool:
	return _ticking
