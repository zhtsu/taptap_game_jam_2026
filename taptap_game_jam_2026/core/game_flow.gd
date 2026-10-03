extends Node

## 游戏流程（常驻壳架构）：
##   boot（entry/main.tscn，本节点所在场景）
##     → title_screen（标题屏：背景图 + "点击任意区域开始"，UiRoot 的 MIDDLE 层）
##     → title（主菜单，UiRoot 的 MIDDLE 层）
##     → gameplay（关卡场景挂进自己的 SceneRoot）
##     → pause（暂停界面，UiRoot 的 TOP 层；`get_tree().paused = true`）
##
## 标题屏与主菜单是**两个界面**：标题屏只负责"玩家确认"这一件事（发 TITLE_CONFIRMED），
## 换界面的编排在本节点；主菜单才是功能入口（开始 / 设置 / 制作人员 / 退出）。
## 注意：从关卡"返回标题"回到的是**主菜单**而不是标题屏 —— 标题屏是开机门面，每次回到主菜单
## 都强制再看一遍"点击开始"会很烦。
##
## 为什么不是"整场景切换"：本节点与 UiRoot / SaveService 一起挂在 entry/main.tscn 上，
## 切关卡只替换 SceneRoot 里的内容 —— 存档状态、已打开的界面都不受切场景影响。
## 框架的 `CoreSystem.scene_manager` 是"替换 current_scene"的用法（会把这层壳一起 queue_free），
## 所以这里不用它的切换逻辑；但**转场动画复用了它的 `FadeTransition`**，没有自己重写一遍 tween。
##
## 两条与暂停有关的硬要求：
##   1) 本节点 `process_mode = ALWAYS` —— 否则暂停后收不到 ESC，就再也恢复不了；
##   2) 暂停界面自身也要在暂停中可交互（见 ui/pause_menu/pause_menu.tscn 的 process_mode）。
##
## 暂停状态的**唯一权威是本节点**：暂停界面上的按钮只发事件，不自己改 `get_tree().paused`。

## 与 project.godot 的 [input] 段同名（改按键或做重映射时两处要一起动）
const ACTION_PAUSE: String = "pause"
## 转场时长（秒）
const FADE_DURATION: float = 0.25

## 关卡场景的挂载点（entry/main.tscn 里的节点，用场景唯一名引用）
@onready var _scene_root: Node = %SceneRoot
## 转场遮罩矩形（entry/main.tscn 里的 GameFlow/TransitionLayer/FadeRect）
@onready var _transition_rect: ColorRect = %FadeRect

var _bus: Node = null
var _transition: BaseTransition = null
## 当前关卡实例（没有 = 在标题界面）
var _current_level: Node = null
## 主菜单是否开着（`_on_open_main_menu` 用来避免重复打开）
var _main_menu_open: bool = false
## 转场动画期间为 true，用来挡住重复的切换请求
var _switching: bool = false


func _ready() -> void:
	# 暂停时也要继续跑：ESC 的监听与本节点在同一处
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_transition()

	_bus = CoreSystem.event_bus
	_bus.subscribe_unique_script(Events.TITLE_CONFIRMED, _on_title_confirmed)
	_bus.subscribe_unique_script(Events.OPEN_MAIN_MENU, _on_open_main_menu)
	_bus.subscribe_unique_script(Events.START_GAME, _on_start_game)
	_bus.subscribe_unique_script(Events.RETURN_TO_TITLE, _on_return_to_title)
	_bus.subscribe_unique_script(Events.PAUSE_TOGGLE, _on_pause_toggle)


func _exit_tree() -> void:
	if _bus == null:
		return
	_bus.unsubscribe(Events.TITLE_CONFIRMED, _on_title_confirmed)
	_bus.unsubscribe(Events.OPEN_MAIN_MENU, _on_open_main_menu)
	_bus.unsubscribe(Events.START_GAME, _on_start_game)
	_bus.unsubscribe(Events.RETURN_TO_TITLE, _on_return_to_title)
	_bus.unsubscribe(Events.PAUSE_TOGGLE, _on_pause_toggle)


## ESC 在这里统一处理：发事件而不是直接改状态，保持"暂停权威只有一处"
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_PAUSE):
		get_viewport().set_input_as_handled()
		_bus.push_event(Events.PAUSE_TOGGLE)


#region 流程动作

## 标题屏被确认：关标题屏 → 淡黑 → 打开主菜单 → 淡回。
## 只是界面换场，不动 `_current_level`（此时本来就没有关卡）。
func _on_title_confirmed() -> void:
	if _switching:
		return
	_switching = true

	await _fade_out()
	CoreSystem.event_bus.push_event(Events.CLOSE_UI, Paths.UI_TITLE_SCREEN)
	_open_ui(Paths.UI_MAIN_MENU, Types.UiLayer.MIDDLE)
	_main_menu_open = true
	CoreSystem.logger.info("[GameFlow] 标题屏已确认，进入主菜单")

	await _fade_in()
	_switching = false


## 请求回主菜单（由设置这类界面发出）：先关掉请求方，再打开主菜单。
## 顺序固定在这里，避免"界面自己先开后关"导致同层出现两个界面。
## 主菜单已经开着时只关请求方、不重复打开。
func _on_open_main_menu(from_path: String = "") -> void:
	if not from_path.is_empty():
		CoreSystem.event_bus.push_event(Events.CLOSE_UI, from_path)
	if _main_menu_open:
		return

	await _fade_out()
	_open_ui(Paths.UI_MAIN_MENU, Types.UiLayer.MIDDLE)
	_main_menu_open = true
	CoreSystem.logger.info("[GameFlow] 打开主菜单")
	await _fade_in()


## 从设置界面返回主菜单
func _on_options_back() -> void:
	CoreSystem.event_bus.push_event(Events.OPEN_MAIN_MENU, Paths.UI_OPTIONS)


## 从设置界面打开制作人员：先关设置、再开制作人员，顺序固定在这里
func _on_options_credits() -> void:
	CoreSystem.event_bus.push_event(Events.CLOSE_UI, Paths.UI_OPTIONS)
	_open_ui(Paths.UI_CREDITS, Types.UiLayer.MIDDLE)


## 开始游戏：关主菜单 → 淡黑 → 换关卡 → 淡回
func _on_start_game(level_path: String) -> void:
	if _switching:
		return
	_switching = true
	CoreSystem.event_bus.push_event(Events.CLOSE_UI, Paths.UI_MAIN_MENU)
	_main_menu_open = false

	await _fade_out()
	_free_current_level()

	var packed: PackedScene = CoreSystem.resource_manager.load_resource(level_path) as PackedScene
	if packed == null:
		CoreSystem.logger.error("[GameFlow] 无法加载关卡场景: %s" % level_path)
		await _fade_in()
		_switching = false
		return

	_current_level = packed.instantiate()
	_scene_root.add_child(_current_level)
	CoreSystem.logger.info("[GameFlow] 进入关卡: %s" % level_path)
	await _fade_in()
	_switching = false


## 回到标题：恢复暂停 → 关暂停界面 → 淡黑 → 释放关卡 → 打开主菜单 → 淡回
func _on_return_to_title() -> void:
	if _switching:
		return
	_switching = true

	if get_tree().paused:
		get_tree().paused = false
		CoreSystem.event_bus.push_event(Events.CLOSE_UI, Paths.UI_PAUSE_MENU)

	await _fade_out()
	_free_current_level()

	var request: Types.OpenUiRequest = Types.OpenUiRequest.new()
	request.path = Paths.UI_MAIN_MENU
	request.ui_layer = Types.UiLayer.MIDDLE
	CoreSystem.event_bus.push_event(Events.OPEN_UI, request)
	CoreSystem.logger.info("[GameFlow] 回到标题")

	await _fade_in()
	_switching = false


## 暂停 / 恢复。ESC 与暂停界面上的按钮都走到这里。
func _on_pause_toggle() -> void:
	# 不在关卡里（标题界面）或正在切场景时，ESC 不生效
	if _current_level == null or _switching:
		return

	var will_pause: bool = not get_tree().paused
	get_tree().paused = will_pause

	if will_pause:
		var request: Types.OpenUiRequest = Types.OpenUiRequest.new()
		request.path = Paths.UI_PAUSE_MENU
		request.ui_layer = Types.UiLayer.TOP
		CoreSystem.event_bus.push_event(Events.OPEN_UI, request)
		CoreSystem.logger.info("[GameFlow] 已暂停")
	else:
		CoreSystem.event_bus.push_event(Events.CLOSE_UI, Paths.UI_PAUSE_MENU)
		CoreSystem.logger.info("[GameFlow] 已继续")

#endregion


#region 内部实现

## 打开一个界面：填 OpenUiRequest 的样板只留在这里（界面实例化/分层/记账都归 UiRoot）
func _open_ui(ui_path: String, ui_layer: int = Types.UiLayer.MIDDLE) -> void:
	var request: Types.OpenUiRequest = Types.OpenUiRequest.new()
	request.path = ui_path
	request.ui_layer = ui_layer
	CoreSystem.event_bus.push_event(Events.OPEN_UI, request)


## 转场动画：借框架的 FadeTransition（只借动画，不用它那套整场景切换）。
## 遮罩矩形本身是 entry/main.tscn 里的 GameFlow/TransitionLayer/FadeRect —— 编辑器里可见可调，
## 锚定全屏所以不用跟着视口尺寸改 size。
func _setup_transition() -> void:
	_transition = FadeTransition.new()
	_transition.init(_transition_rect)


## 变黑（切场景前）
func _fade_out() -> void:
	_transition_rect.visible = true
	await _transition.start(FADE_DURATION)


## 变亮（切场景后）
func _fade_in() -> void:
	await _transition.end(FADE_DURATION)
	_transition_rect.visible = false


func _free_current_level() -> void:
	if _current_level == null:
		return
	_current_level.queue_free()
	_current_level = null

#endregion
