extends Control

## 地图界面：**全屏、背景全透明**，让常驻的 3D 星系直接透出来当背景。
##
## 布局：
##   - 顶栏：**左「返回」+ 右「下一步」**（左上角没有标题 —— 人类要求去掉）
##     「下一步」= 进**制造**界面（选完星球去装配兽人）
##   - 顶栏下方：「< 地图名称 >」—— 上一个 / 下一个地图的切换按钮 + 中间的名称
##   - **下半屏**：竖排若干信息卡片（内容从 `data/resources/map_config.tres` 读）
##   - **上半屏留空**：不铺任何底色，直接看 3D 的星球特写
##
## **"地图列表"就是星系的 `bodies` 数组**（一个天体 = 一张地图）：
##   名称取 `GalaxyBody.name_key`（翻译 key），切换 = 让镜头漫游到那颗天体，
##   下标也从这里来 —— 所以**加一颗行星就自动多一张地图**，不用再配一遍。
##   起始地图仍由 `map_config.tres` 的 `target_body_label` 决定（标签比下标稳定）。
##
## 为什么下半屏卡片不跟着切：卡片内容是一张地图的"情报"，现在是**一份占位文案**，
## 换星球时文字不变。要"一颗星球一套卡片"得先有文案，再扩配置（见报告）。
##
## 关键是"背景全透明"这件事：本场景**没有任何铺满屏幕的 ColorRect**，
## Control 默认可穿透（`mouse_filter = IGNORE` 的节点不挡鼠标），
## 所以相机特写出来的星球就在卡片后面。
##
## 相机特写 / 天体显隐**不由本界面做** —— 3D 星系是常驻背景层（`ui/galaxy/galaxy_background`），
## 本界面只发 `Events.GALAXY_FOCUS` / `Events.GALAXY_RESET`。
## 这样地图界面完全不依赖星系节点的位置，背景也不会随界面开关被销毁。

## 地图配置（起始地图 + 卡片）
@export_file("*.tres") var config_path: String = Paths.MAP_CONFIG

## 卡片尺寸（卡片是**代码建的**，所以这些不写在场景里；要调就改这几个常量）。
## 三张卡的高度统一到 `CARD_MIN_HEIGHT`，长短不一的文案不会让它们参差不齐。
const CARD_TITLE_FONT_SIZE := 56
const CARD_BODY_FONT_SIZE := 44
const CARD_MIN_HEIGHT := 240.0
const CARD_CORNER_RADIUS := 18
const CARD_PADDING_H := 44.0
const CARD_PADDING_V := 36.0
## 卡片之间的间距（`CardList` 的 separation 也设成这个值，见 `_build_cards`）
const CARD_SEPARATION := 28

@onready var _card_list: VBoxContainer = %CardList
@onready var _name_label: Label = %MapName

## 地图配置（起始下标 + 卡片）
var _config: MapConfig = null
## 星系配置：**地图列表就是它的 `bodies`**，切换时长也从它读（都是"星系相机"的事）
var _galaxy_config: GalaxyConfig = null
## 当前地图（= 星系 `bodies` 的下标）
var _index: int = 0


func _ready() -> void:
	_config = _load_config()
	_galaxy_config = _load_galaxy_config()
	var count: int = _galaxy_config.bodies.size()
	if count == 0:
		CoreSystem.logger.warning("[Map] 星系配置里一个天体都没有，地图列表是空的")
	else:
		_index = clampi(_target_body_index(_config), 0, count - 1)
	_build_cards(_config)
	_refresh_name()
	# 进地图：0 = 立即锁定（第一帧就已经在特写位）
	_focus(_galaxy_config.focus_duration)


## 上一个地图
func _on_prev_pressed() -> void:
	_step(-1)


## 下一个地图
func _on_next_pressed() -> void:
	_step(1)


## 切到相邻的一张地图（**循环**：到头再按会绕回另一端）。
## 只有一张时什么也不做 —— 按钮还在，但没有"别的"可切。
func _step(delta: int) -> void:
	var count: int = _galaxy_config.bodies.size()
	if count <= 1:
		return
	_index = wrapi(_index + delta, 0, count)
	_refresh_name()
	# 切地图：让镜头**漫游**过去（看得见镜头在飞），时长在星系配置里
	_focus(_galaxy_config.switch_duration)


## 让 3D 星系把镜头切到当前地图那颗天体。`duration` 秒（0 = 立即锁定）。
func _focus(duration: float) -> void:
	CoreSystem.event_bus.push_event(Events.GALAXY_FOCUS, [_index, duration])


## 刷新顶部的"地图名称"。
## 显示名走 `GalaxyBody.name_key`（翻译 key，运行时赋值会被 Label 自动翻译）；
## 配置没填 key 时退回用 `label` 原文，至少不会显示空白。
func _refresh_name() -> void:
	if _name_label == null:
		return
	var body: GalaxyBody = _body_at(_index)
	if body == null:
		_name_label.text = ""
		return
	_name_label.text = body.name_key if not body.name_key.is_empty() else body.label


## 星系 `bodies` 里第 i 项（越界返回 null）
func _body_at(index: int) -> GalaxyBody:
	if index < 0 or index >= _galaxy_config.bodies.size():
		return null
	return _galaxy_config.bodies[index] as GalaxyBody


## 建下半的信息卡片。每张卡片 = 标题标签 + 正文标签（都用翻译 key）。
## 只建一次：卡片内容不随"当前是哪张地图"变（见文件头的说明）。
## 名称含义（关卡信息 / BOSS信息 / 玩家进度）由 `map_config.tres` 的 `title_key` 决定，
## 这里只管样式，不认识具体是哪三张。
func _build_cards(config: MapConfig) -> void:
	for child in _card_list.get_children():
		_card_list.remove_child(child)
		child.free()
	_card_list.add_theme_constant_override("separation", CARD_SEPARATION)

	for i in config.cards.size():
		var info: MapPlanetInfo = config.cards[i]
		if info == null:
			push_warning("[Map] 卡片配置第 %d 项是 null，跳过" % i)
			continue
		_card_list.add_child(_make_card(info))
	if config.cards.is_empty():
		CoreSystem.logger.info("[Map] 没配任何卡片，下半屏是空的")


## 造一张卡片：圆角半透明底 + 标题 + 正文
func _make_card(info: MapPlanetInfo) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0784314, 0.0862745, 0.1058824, 0.92)
	box.content_margin_left = CARD_PADDING_H
	box.content_margin_top = CARD_PADDING_V
	box.content_margin_right = CARD_PADDING_H
	box.content_margin_bottom = CARD_PADDING_V
	box.corner_radius_top_left = CARD_CORNER_RADIUS
	box.corner_radius_top_right = CARD_CORNER_RADIUS
	box.corner_radius_bottom_right = CARD_CORNER_RADIUS
	box.corner_radius_bottom_left = CARD_CORNER_RADIUS
	panel.add_theme_stylebox_override("panel", box)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)

	var title := Label.new()
	title.text = info.title_key
	title.add_theme_font_size_override("font_size", CARD_TITLE_FONT_SIZE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var body := Label.new()
	body.text = info.body_key
	body.add_theme_font_size_override("font_size", CARD_BODY_FONT_SIZE)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)

	return panel


## 起始地图在星系 `bodies` 数组里的下标。
## 配了 label 就按 label 在星系配置里查（label 比下标稳定，改配置顺序不会错位）。
func _target_body_index(config: MapConfig) -> int:
	if config.target_body_label.is_empty():
		return config.target_body_index
	for i in _galaxy_config.bodies.size():
		var body: GalaxyBody = _galaxy_config.bodies[i]
		if body != null and body.label == config.target_body_label:
			return i
	push_warning("[Map] 星系里找不到 label 为 '%s' 的天体，退回用下标 %d" % [
		config.target_body_label, config.target_body_index])
	return config.target_body_index


## 读地图配置。缺失或类型不对时给一份空配置（下半屏为空，但界面照常可用）。
func _load_config() -> MapConfig:
	if not config_path.is_empty() and ResourceLoader.exists(config_path):
		var loaded: Resource = load(config_path)
		if loaded is MapConfig:
			return loaded
		push_warning("[Map] %s 不是 MapConfig" % config_path)
	else:
		push_warning("[Map] 地图配置不存在：%s" % config_path)
	return MapConfig.new()


## 读星系配置（地图列表 / 名称 / 相机时长都从这里来）
func _load_galaxy_config() -> GalaxyConfig:
	if ResourceLoader.exists(Paths.GALAXY_CONFIG):
		var loaded: Resource = load(Paths.GALAXY_CONFIG)
		if loaded is GalaxyConfig:
			return loaded
		push_warning("[Map] %s 不是 GalaxyConfig" % Paths.GALAXY_CONFIG)
	return GalaxyConfig.new()


## 返回主菜单：先让星系退出特写（恢复所有星球与轨道、相机归位），
## 并把主菜单 UI 显回来，再关掉本界面。
##
## 顺序交给 `core/game_flow.gd`（和别的界面同一套协议）：发
## `OPEN_MAIN_MENU` + 自己的路径 → `_main_menu_open` 已为真，所以它只会关掉本界面。
func _on_back_pressed() -> void:
	_close_map()
	CoreSystem.event_bus.push_event(Events.OPEN_MAIN_MENU, Paths.UI_MAP)


## 下一步：进**「制造」界面**（选完星球 → 装配兽人 → 再进关卡）。
##
## 四步（顺序不能反）：
##   1) `SELECT_LEVEL(关卡路径)`：把"这一局打哪一关"记进 `core/game_flow.gd`
##      —— 关卡路径取自**当前天体**的 `level_scene`，没配就退回模板示例关卡（并告警）；
##   2) `_close_map()`：让星系退出特写（恢复所有星球与轨道、相机归位），
##      并把主菜单 UI 显回来 —— **这一步不能漏**：制造界面结束后会回主菜单，
##      那时主菜单要是还藏着，玩家就只看到一片星系、没有任何按钮；
##   3) `CLOSE_UI(自己的路径)`：把自己关掉（界面不自己 queue_free，记账交给 UiRoot）；
##   4) `OPEN_UI(制造)`：开制造界面。界面之间用事件开关，UiRoot 负责实例化/分层/记账。
func _on_next_step_pressed() -> void:
	var level_path: String = _level_path_of_current_map()
	CoreSystem.logger.info("[Map] 下一步：选定关卡 %s，进制造界面" % level_path)
	CoreSystem.event_bus.push_event(Events.SELECT_LEVEL, level_path)
	_close_map()
	CoreSystem.event_bus.push_event(Events.CLOSE_UI, Paths.UI_MAP)
	var request: Types.OpenUiRequest = Types.OpenUiRequest.new()
	request.path = Paths.UI_WORKSHOP
	# 来源写清楚：制造界面靠它区分"从地图来（装配完开打）"和"从方案来（只在编辑方案）"
	request.caller = Paths.UI_MAP
	CoreSystem.event_bus.push_event(Events.OPEN_UI, request)


## 当前地图（天体）对应的关卡场景。没配 `level_scene` 时退回**默认关卡**并告警
## —— 这样「下一步 → 开始」这条链路上永远有东西可进，而不是静默失败。
func _level_path_of_current_map() -> String:
	var body: GalaxyBody = _body_at(_index)
	if body != null and not body.level_scene.is_empty():
		return body.level_scene
	CoreSystem.logger.warning("[Map] 天体 '%s' 没配 level_scene，先开默认关卡" % (
		body.label if body != null else "?"))
	return Paths.GAME_ROAD_LEVEL


## 退出地图：恢复星系 + 恢复主菜单 UI。
## 两条关闭路径（点返回 / 被别处关掉）都走这里 —— 见 `_exit_tree()`。
func _close_map() -> void:
	CoreSystem.event_bus.push_event(Events.GALAXY_RESET)
	_restore_main_menu_ui()


## 把主菜单的 UI 显回来（打开地图时它被 `set_ui_visible(false)` 藏起来了）。
##
## 为什么由地图界面来恢复、而不是主菜单自己监听"地图关掉了"：
##   主张隐藏的人负责恢复最不容易漏。主菜单只提供 `restore_after_map()`，
##   不管什么时候该调 —— 关闭路径可能有多条，集中在这里处理。
##
## 为什么用"按方法名找"而不是去 UiRoot 的记账里取：
##   那要依赖 `ui_dict` 的内部结构 + 主菜单还在记账里，耦合更紧；
##   `restore_after_map()` 这个方法是主菜单独有的，按它找人不会找错，
##   而且主菜单不在场时自然什么也不做。
func _restore_main_menu_ui() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var menu: Node = _find_with_method(tree.root, &"restore_after_map")
	if menu != null:
		menu.call("restore_after_map")


## 在子树里找第一个带指定方法的节点（深度优先）
func _find_with_method(node: Node, method: StringName) -> Node:
	if node.has_method(method):
		return node
	for child in node.get_children():
		var found: Node = _find_with_method(child, method)
		if found != null:
			return found
	return null


## 离开场景树时兜底恢复 —— 无论是"点返回"还是"被别处关掉"，
## 都不能把星系留在"只有一颗星球 + 相机在特写位"的状态里，
## 也不能让主菜单 UI 一直藏着。
func _exit_tree() -> void:
	if CoreSystem == null:
		return
	_close_map()
