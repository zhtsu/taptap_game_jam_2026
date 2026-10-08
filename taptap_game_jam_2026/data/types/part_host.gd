class_name PartHost
extends Node

## **部件宿主**：把一个部件装进一个部位。
##
## 职责只有三件事，**不做任何条件判断**（"前方有没有障碍"是业务的事）：
##   1) 实例化部件的行为节点（来自 `WorkshopPart.behavior_scene`）；
##   2) 按行为声明的事件（`events_of_interest()`）**订阅 / 退订**事件总线；
##   3) 事件到达时转发给行为；行为请求了持续钩子就每帧驱动 `on_tick()`。
##
## 为什么订阅/退订归这里、不归行为脚本自己：
##   部件的生效范围就是"装着它的这段时间"。订阅跟着**装备生命周期**走，
##   卸下时 `teardown()` 一调就全部退订 —— 行为脚本自己订阅的话，
##   漏一次退订就留下悬挂订阅（界面/关卡都换掉了还在收事件）。
##
## 生命周期：
##   ```gdscript
##   var host := PartHost.new()
##   add_child(host)               # 先入树，再 setup（setup 会 load + instantiate 行为场景）
##   host.setup(part_resource, "hand_l")
##   ...
##   host.teardown()               # 卸下部件：退订 + 释放行为节点
##   ```

## 一个事件到达时转发出去（便于调试 / 别的系统旁听）
signal event_forwarded(slot_id: String, event: StringName, context: Dictionary)
## 部件请求了持续钩子（true = 开始，false = 停止）
signal tick_state_changed(slot_id: String, ticking: bool)

## 当前装着的部件（null = 空）
var _part: WorkshopPart = null
## 部件所属的部位 id（对应 `WorkshopSlot.id`）
var _slot_id: String = ""
## 行为节点（`PartBehavior` 的实例）
var _behavior: PartBehavior = null
## 已经订阅的事件：`{事件名: 订阅时用的那个 Callable}`。
## **必须存 Callable**：`bind()` 每次调用都产生新对象，退订时现取现退是退不掉的
## （订阅会一直留着 → 悬挂订阅）。
var _subscribed: Dictionary = {}
## 最近一次事件带来的上下文。持续钩子每帧都要一个 context，
## 复用它而不是每帧新建字典（也避免部件在 tick 里拿不到"上次事件的载荷"）。
var _last_context: Dictionary = {}


## 装上部件。传 null 或不带行为场景 = 只记身份、不装行为。
##
## 必须在**入树之后**调用（内部要 `add_child` 行为节点）。
func setup(part: WorkshopPart, slot_id: String) -> void:
	teardown()
	_part = part
	_slot_id = slot_id
	if part == null:
		return
	if part.behavior_scene.is_empty():
		CoreSystem.logger.warning("[PartHost] 部件 '%s' 没配行为场景，只有数据没有行为" % part.id)
		return

	var packed: PackedScene = load(part.behavior_scene) as PackedScene
	if packed == null:
		CoreSystem.logger.error("[PartHost] 行为场景加载失败：%s" % part.behavior_scene)
		return
	var node: Node = packed.instantiate()
	if not (node is PartBehavior):
		CoreSystem.logger.error("[PartHost] 行为场景的根节点不是 PartBehavior：%s" % part.behavior_scene)
		node.free()
		return

	_behavior = node
	_behavior.name = "Behavior"
	add_child(_behavior)
	_behavior.tick_request_changed.connect(_on_tick_request_changed)

	for event_name: StringName in _behavior.events_of_interest():
		if _subscribed.has(event_name):
			continue
		# 把事件名 bind 进回调 —— 事件总线的订阅回调收不到"事件名"，
		# 而一个部件可能订阅多个事件，必须知道这次是哪个。
		# 订阅用的 Callable **原样存下来**，退订要用同一个（bind 每次都是新对象）。
		var cb: Callable = _forward_event.bind(event_name)
		CoreSystem.event_bus.subscribe(String(event_name), cb)
		_subscribed[event_name] = cb
		# "发了事件但没人听"是最难查的一类问题，装的时候就报出来
		if CoreSystem.event_bus.get_subscriber_count(String(event_name)) <= 1:
			CoreSystem.logger.warning(
				"[PartHost] 事件 '%s' 目前只有本部件订阅 —— 确认业务侧会不会发它" % event_name)

	_sync_process()


## 卸下部件：退订全部事件 + 释放行为节点。
## 可以重复调用（没装部件时是空操作）。
func teardown() -> void:
	for event_name: StringName in _subscribed:
		CoreSystem.event_bus.unsubscribe(String(event_name), _subscribed[event_name])
	_subscribed.clear()
	_last_context.clear()

	if _behavior != null:
		_behavior.tick_request_changed.disconnect(_on_tick_request_changed)
		# 用 remove_child + free 而**不是 queue_free**：queue_free 要等帧末才真删，
		# 同一帧内重新 setup 会让新旧行为节点重名/并存，钩子被调两次。
		remove_child(_behavior)
		_behavior.free()
		_behavior = null

	_part = null
	_slot_id = ""
	set_process(false)


#region 查询

## 当前装着的部件
func get_part() -> WorkshopPart:
	return _part


## 当前部件所属的部位 id
func get_slot_id() -> String:
	return _slot_id


## 行为节点（用于测试 / 访问部件自定义方法；空槽时为 null）
func get_behavior() -> PartBehavior:
	return _behavior

#endregion


#region 内部

## 事件转发。`event_name` 是订阅时 `bind` 进来的 —— 事件总线的回调拿不到事件名，
## 而一个部件可能订阅多个事件，必须知道这次是哪个。
func _forward_event(context: Variant, event_name: StringName) -> void:
	if _behavior == null:
		return
	var ctx: Dictionary = context if context is Dictionary else {}
	_last_context = ctx
	_behavior.on_event(_slot_id, event_name, ctx)
	event_forwarded.emit(_slot_id, event_name, ctx)


## 行为请求了持续钩子 → 决定本节点要不要每帧跑 `_process`
func _on_tick_request_changed(on: bool) -> void:
	tick_state_changed.emit(_slot_id, on)
	_sync_process()


## 有任意一个"当前请求了 tick"的行为时，本节点才开 `_process`
## （没有部件需要持续作用时零开销）。
func _sync_process() -> void:
	set_process(_behavior != null and _behavior.is_ticking())


func _process(delta: float) -> void:
	# 防御：行为可能在别处被释放（虽然 teardown 是唯一入口）
	if _behavior == null:
		set_process(false)
		return
	# 复用最近一次事件的上下文：tick 里通常要读"障碍还有多远"这类载荷，
	# 每帧新建字典既浪费又拿不到信息。
	_behavior.on_tick(_slot_id, _last_context, delta)

#endregion
