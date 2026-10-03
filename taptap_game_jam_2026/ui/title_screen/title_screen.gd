extends Control

## 标题屏：显示背景图 + 有呼吸效果的"点击任意区域开始"。
##
## 职责边界（和 main_menu 一样）：**只负责"玩家已确认"这一件事**，
## 后续"关掉自己 → 打开主菜单"由 core/game_flow.gd 编排 —— 本脚本不自己 queue_free()
## （那会绕过 UiRoot 的 ui_dict 记账，留悬挂引用，见 AGENTS.md 硬规则 2）。
##
## 呼吸效果为什么用 tween 而不是 AnimationPlayer：这里只要一个循环的 alpha 动画，
## tween 几行就够，也不用在 .tscn 里塞 Animation 资源。`set_loops()` 由 Tween 自己持有，
## 不需要保存引用，节点释放时会被一起回收。
##
## 交互：点击（鼠标左键）/ 触摸 / 任意键（回车、空格…）都算"确认"。
## 用 `_gui_input` 吃鼠标与触摸（根 Control 的 mouse_filter 是 STOP，全屏可点），
## 键盘另走 `_unhandled_input` —— 两者都收敛到 _confirm()，所以不会重复触发。

## 呼吸动画参数：alpha 往复一次 2.4 秒
const BREATH_MIN_ALPHA: float = 0.35
const BREATH_MAX_ALPHA: float = 1.0
const BREATH_HALF_CYCLE: float = 1.2

## 玩家是否已经确认过（防止淡出过程中重复派发）
var _confirmed: bool = false

@onready var _hint: Label = %TapToStart


func _ready() -> void:
	_start_breathing()


## 给 core/game_flow.gd 用：淡出期间收到的重复输入直接忽略
func is_confirmed() -> bool:
	return _confirmed


func _start_breathing() -> void:
	if _hint == null:
		return
	_hint.modulate.a = BREATH_MAX_ALPHA
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(_hint, "modulate:a", BREATH_MIN_ALPHA, BREATH_HALF_CYCLE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_hint, "modulate:a", BREATH_MAX_ALPHA, BREATH_HALF_CYCLE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _gui_input(event: InputEvent) -> void:
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event != null and button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_confirm()


func _unhandled_input(event: InputEvent) -> void:
	# 鼠标左键已在 _gui_input 里处理；这里只管键盘，避免同一次点击触发两遍
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_confirm()


## 确认：只置位并广播，界面收尾交给 GameFlow
func _confirm() -> void:
	if _confirmed:
		return
	_confirmed = true
	CoreSystem.event_bus.push_event(Events.TITLE_CONFIRMED)
