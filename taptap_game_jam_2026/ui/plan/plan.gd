extends Control

## 方案界面：从「制造」界面里**独立出来的一屏**（原来它是制造的两个 Tab 之一）。
##
## 布局（2026-10-07 按人类要求改过）：
##   - 顶栏：**只有左上的「方案」标题**，没有按钮（返回不在顶栏里）
##   - **左下「返回」**（回主菜单）、**右下「新建方案」**（进 `ui/workshop` 制造界面去装配）
##   - 下面**只有一个竖直盒子**（`VBoxContainer`）装所有方案卡片，**不再分上下两块区域**；
##     卡片多了整列纵向滚动（外面套了 `ScrollContainer`）。
##
## 卡片从两处来，**先已保存的、后配置的**：
##   1) **玩家自己保存的方案**（存档里的方案档 `plans.sav`，数组顺序 = 新的在最上面）
##      —— 在制造界面点「保存」并输入名字就存进这里；
##   2) `data/resources/plan_config.tres` 里的卡片（**现在还是占位文案**）：
##      往那个数组里加一项就多一张卡片，不用改代码。
## 这里**只读**存档（`SaveData.current`），写它走 `Events.SAVE_REQUEST`（归 `core/save_service.gd`）。
##
## 三条约定（与 ui/options、ui/workshop、ui/warehouse 一致）：
##   1) 打开 / 关闭都走事件：本界面不自己 instantiate、也不自己 queue_free 关闭自己，
##      关闭统一发 `Events.OPEN_MAIN_MENU`（返回）/ `Events.CLOSE_UI`（切界面）+ 自己的路径，
##      由 `core/game_flow.gd` / `core/ui_root.gd` 编排；
##   2) 文案一律用翻译 key，新增 key 必须在 locale 三处同步；
##   3) 节点引用用 `%唯一名`，固定信号用 .tscn 里的 `[connection]` 连。

## 卡片外观（和地图界面的信息卡片同一套：整宽的圆角半透明深色卡片）
const CARD_TITLE_FONT_SIZE := 56
const CARD_BODY_FONT_SIZE := 44
const CARD_MIN_HEIGHT := 240.0
const CARD_CORNER_RADIUS := 18
const CARD_PADDING_H := 44.0
const CARD_PADDING_V := 36.0

## 方案配置
@export_file("*.tres") var config_path: String = Paths.PLAN_CONFIG

@onready var _list: VBoxContainer = %PlanList


func _ready() -> void:
	_build_cards()


## 按配置建卡片：一个竖直盒子从上到下排开。
##
## 顺序：**先放玩家自己保存的方案**（来自方案档 `plans.sav`，数组顺序 = 新的在前），
## 再放 `plan_config.tres` 里的卡片（目前是占位文案）。刚存的方案因此排在最上面。
func _build_cards() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()

	var saved: Array = _saved_plans()
	for i in saved.size():
		var entry: Variant = saved[i]
		if not (entry is Dictionary):
			continue
		_list.add_child(_make_saved_card(str((entry as Dictionary).get("name", ""))))

	var config: PlanConfig = _load_config()
	for i in config.cards.size():
		var card: PlanCard = config.cards[i]
		if card == null:
			push_warning("[Plan] 配置第 %d 项是 null，跳过" % i)
			continue
		_list.add_child(_make_card(card))
	if saved.is_empty() and config.cards.is_empty():
		CoreSystem.logger.info("[Plan] 既没保存过方案、也没配任何方案卡片，这屏是空的")


## 玩家保存过的方案列表（**只读**；写它走 `Events.SAVE_REQUEST`，归 `core/save_service.gd`）。
## `SaveData.current` 由 SaveService 在启动时指过来；拿不到就当作"没有方案"。
func _saved_plans() -> Array:
	if SaveData.current == null:
		return []
	return SaveData.current.plans.plans


## 造一张"已保存方案"的卡片。和配置卡片同一套样式，区别只有一个：
## **标题是玩家输入的名字，不是翻译 key** —— 所以必须关掉这个 Label 的自动翻译
## （`AutoTranslateMode.DISABLED`），否则名字会被拿去当 msgid 查一次翻译表。
func _make_saved_card(plan_name: String) -> Control:
	var column: VBoxContainer = _make_card_column()

	var title := Label.new()
	title.text = plan_name
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.add_theme_font_size_override("font_size", CARD_TITLE_FONT_SIZE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var body := Label.new()
	body.text = "ui.plan.saved.body"
	body.add_theme_font_size_override("font_size", CARD_BODY_FONT_SIZE)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)

	return column.get_parent()


## 造一张方案卡片：圆角半透明底 + 标题 + 正文（形式和地图界面一致）
func _make_card(card: PlanCard) -> Control:
	var column: VBoxContainer = _make_card_column()

	var title := Label.new()
	title.text = card.title_key
	title.add_theme_font_size_override("font_size", CARD_TITLE_FONT_SIZE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var body := Label.new()
	body.text = card.body_key
	body.add_theme_font_size_override("font_size", CARD_BODY_FONT_SIZE)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)

	return column.get_parent()


## 卡片的"外壳"：圆角半透明底 + 一个竖直内容列；返回那个列，调用方往里塞标题/正文。
## 两种卡片（配置的 / 已保存的）共用这一段样式，免得到时候改样式漏一处。
func _make_card_column() -> VBoxContainer:
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

	return column


## 读方案配置。缺失或类型不对时给一份空配置（这屏为空，但界面照常可用）
func _load_config() -> PlanConfig:
	if not config_path.is_empty() and ResourceLoader.exists(config_path):
		var loaded: Resource = load(config_path)
		if loaded is PlanConfig:
			return loaded
		push_warning("[Plan] %s 不是 PlanConfig" % config_path)
	else:
		push_warning("[Plan] 方案配置不存在：%s" % config_path)
	return PlanConfig.new()


## 返回主菜单：和别的全屏界面同一个协议
## （`game_flow._on_open_main_menu(from_path)` 里主菜单已经在场时只会关掉本界面）。
func _on_back_pressed() -> void:
	CoreSystem.event_bus.push_event(Events.OPEN_MAIN_MENU, Paths.UI_PLAN)


## 新建方案（右下角）：去**「制造」界面**装配兽人（`ui/workshop`）。
##
## 两步（顺序不能反，和地图界面「下一步」→ 制造的写法一致）：
##   1) `CLOSE_UI(自己的路径)`：先把自己关掉 —— 界面不自己 queue_free，记账交给 UiRoot，
##      否则两个全屏界面同层叠着，下面那个会穿帮 / 抢输入；
##   2) `OPEN_UI(制造)`：界面之间一律用事件开关。
##
## **注意这里是"从方案直接进制造"**：没经过地图界面的选关（没发过 `SELECT_LEVEL`），
## 所以制造里点「开始」时 `core/game_flow.gd` 没有已选定的关卡 ——
## 那条路要么先回地图选关，要么给它一个兜底关卡（待人类决定，见报告）。
func _on_new_plan_pressed() -> void:
	CoreSystem.logger.info("[Plan] 新建方案：进制造界面")
	CoreSystem.event_bus.push_event(Events.CLOSE_UI, Paths.UI_PLAN)
	var request: Types.OpenUiRequest = Types.OpenUiRequest.new()
	request.path = Paths.UI_WORKSHOP
	# **把来源带上**：制造界面据此变成"方案形态"（隐藏「开始」、返回回本界面），
	# 而不是地图那条路上的"装配完就开打"形态。
	request.caller = Paths.UI_PLAN
	CoreSystem.event_bus.push_event(Events.OPEN_UI, request)
