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

## **常驻的银河系背景层**（entry/main.tscn 里的 `GalaxyBackground`）的路径。
##
## 为什么要由流程层切它的显隐：它是个 `CanvasLayer(-1)`，而 CanvasLayer 画在**根视口的 3D 之上**
## —— 也就是说它会盖住关卡自己的 3D 画面（"layer = -1" 只表示在所有 UI 之下，不代表在 3D 之下）。
## 主菜单 / 地图界面要它当背景，关卡不要它。**谁主张进关卡，谁负责恢复**：
## 关 = 进关卡前，开 = 回主菜单/标题时 —— 和主菜单 `set_ui_visible()` 是同一套思路。
##
## 为什么导出的是 **NodePath** 而不是 `@export var x: CanvasLayer`：后者在 `.tscn` 里同样存成
## `NodePath(...)`，但**实测不会被解析成节点引用**（赋值被静默忽略、引擎一行报错都没有），
## 症状是"背景层没被藏起来、3D 关卡被整屏盖住"。自己 `get_node_or_null()` 才可靠。
@export var galaxy_layer_path: NodePath

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
## **本局要打的那一关**（地图界面选定、制造界面开打）。
##
## 为什么状态放在流程层：地图只负责"选"，制造只负责"装配完点开始"，
## 两边都不持有对方的界面引用；这一处流程状态就是它们之间的交接点（`Events.SELECT_LEVEL` 写入）。
## 空 = 还没选过（这时 `START_GAME` 传空路径会明确报错，而不是闷声进错关卡）。
var _selected_level: String = ""
## "找不到背景层"的告警只打一次（`_set_galaxy_visible` 每次进关卡都会调）
var _warned_missing_galaxy: bool = false


func _ready() -> void:
	# 暂停时也要继续跑：ESC 的监听与本节点在同一处
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_transition()

	_bus = CoreSystem.event_bus
	_bus.subscribe_unique_script(Events.TITLE_CONFIRMED, _on_title_confirmed)
	_bus.subscribe_unique_script(Events.OPEN_MAIN_MENU, _on_open_main_menu)
	_bus.subscribe_unique_script(Events.SELECT_LEVEL, _on_select_level)
	_bus.subscribe_unique_script(Events.START_GAME, _on_start_game)
	_bus.subscribe_unique_script(Events.RETURN_TO_TITLE, _on_return_to_title)
	_bus.subscribe_unique_script(Events.PAUSE_TOGGLE, _on_pause_toggle)


func _exit_tree() -> void:
	if _bus == null:
		return
	_bus.unsubscribe(Events.TITLE_CONFIRMED, _on_title_confirmed)
	_bus.unsubscribe(Events.OPEN_MAIN_MENU, _on_open_main_menu)
	_bus.unsubscribe(Events.SELECT_LEVEL, _on_select_level)
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


## 地图界面选定了要打哪一关：先记下来，等制造界面装配完再 `START_GAME`。
## payload 是关卡场景路径（空路径会被忽略并告警）。
func _on_select_level(level_path: String) -> void:
	if level_path.is_empty():
		CoreSystem.logger.warning("[GameFlow] 选关事件带了空路径，忽略")
		return
	_selected_level = level_path
	CoreSystem.logger.info("[GameFlow] 已选定关卡：%s" % level_path)


## 开始游戏：关主菜单 → 淡黑 → 换关卡 → 淡回
##
## `level_path` 可以是**空字符串**：那表示"打刚才选定的那一关"
## （地图界面发 `SELECT_LEVEL` 记下来的，见 `_selected_level`）。
## 两者都空时明确报错，不会静默进到某个默认关卡。
func _on_start_game(level_path: String) -> void:
	if _switching:
		return
	var target: String = level_path if not level_path.is_empty() else _selected_level
	if target.is_empty():
		CoreSystem.logger.error("[GameFlow] 既没给关卡路径、也没有已选定的关卡，无法开始")
		return
	_switching = true
	# 主菜单可能本来就不在场（关卡里点「重新开始」也是走 START_GAME）—— 那就别去关它，
	# 否则 UiRoot 会打一条"UI 未打开"的告警，看起来像出了问题
	if _main_menu_open:
		CoreSystem.event_bus.push_event(Events.CLOSE_UI, Paths.UI_MAIN_MENU)
		_main_menu_open = false

	await _fade_out()
	# 黑屏之后再切背景层：否则玩家会看到"背景突然消失"（fade 已经把画面盖住了）
	_set_galaxy_visible(false)
	_free_current_level()

	var packed: PackedScene = CoreSystem.resource_manager.load_resource(target) as PackedScene
	if packed == null:
		CoreSystem.logger.error("[GameFlow] 无法加载关卡场景: %s" % target)
		await _fade_in()
		_switching = false
		return

	_current_level = packed.instantiate()
	_scene_root.add_child(_current_level)
	CoreSystem.logger.info("[GameFlow] 进入关卡: %s" % target)
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
	# 回主菜单要把银河系背景层显回来（进关卡时藏起来了）
	_set_galaxy_visible(true)

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


## 银河系背景层的显隐（进关卡藏、回主菜单显）。
##
## 为什么放在这里而不是让背景层自己监听 `START_GAME`：进关卡/离开关卡是**流程**，
## 权威是流程层；背景层不需要知道"什么时候算在关卡里"。
func _set_galaxy_visible(shown: bool) -> void:
	var layer: CanvasLayer = _galaxy_layer()
	if layer == null:
		if not galaxy_layer_path.is_empty() and not _warned_missing_galaxy:
			_warned_missing_galaxy = true
			CoreSystem.logger.warning("[GameFlow] 找不到银河系背景层：%s（3D 关卡会被它盖住）"
				% galaxy_layer_path)
		return
	if layer.visible == shown:
		return
	layer.visible = shown
	CoreSystem.logger.info("[GameFlow] 银河系背景层 → %s" % ("显示" if shown else "隐藏"))


## 按 NodePath 解析背景层节点（没配 / 找不到 = null，流程照常跑）
func _galaxy_layer() -> CanvasLayer:
	if galaxy_layer_path.is_empty():
		return null
	return get_node_or_null(galaxy_layer_path) as CanvasLayer

#endregion
