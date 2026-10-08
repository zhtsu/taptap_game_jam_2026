extends Control

## 制造界面（局外制造兽人）。**有两个入口，进来是两种形态**（靠 `OpenUiRequest.caller` 区分）：
##   1) 地图界面「下一步」进来（`caller = Paths.UI_MAP`）：**正常形态** ——
##      右上角是「开始」= 装配完开打（发 `START_GAME("")`，关卡是地图界面发 `SELECT_LEVEL` 记下的那一关）；
##   2) 方案界面「新建方案」进来（`caller = Paths.UI_PLAN`）：**编辑形态** ——
##      右上角是「保存」= 弹出命名弹窗，把方案写进**方案档**（`PlanSave.SLOT` → `plans.sav`），
##      「返回」回方案界面而不是主菜单。
##
## 布局：顶栏 **左「返回」+ 右「右上角动作按钮」**（文案与行为都跟来源走，见 `_apply_caller()`）；
## 下方是唯一的页面 `MakePage`：
##   - **上半（`SquareRegion`）**：4x4 网格，**只在外圈 12 格放部位槽**
##     （中间 2x2 留空）。代表"兽人身上有哪些部位可以装配"。
##   - **下半（`BottomRegion`）**：另一个网格，**陈列已有的部件**（可点的部件槽）。
##
## 弹窗（`SavePopup`）为什么自己做（而不是 `Window` / `PopupPanel` / `ConfirmationDialog`）：
## 与 `ui/warehouse` 的部件详情弹窗同一套理由 —— 本工程界面全是自定义深色 `StyleBoxFlat`，
## 引擎自带弹窗带一套默认主题的边框/标题栏，还得逐个 theme override 去压；
## 自己用 `PanelContainer` + 全屏遮罩，样式和别处一致，安卓上也没有"子窗口"那套差异。
##
## 原来是「制作 / 方案」两个 Tab，方案那一页已搬去 `ui/plan/plan.tscn`，
## 所以这里不再有 Tab（`TabButtons` / `PlanPage` / `_on_tab_toggled` 都删掉了）。
##
## 三条约定（与 ui/options、ui/credits 一致）：
##   1) 打开 / 关闭都走事件：本界面不自己 instantiate 界面、也不自己 queue_free 关闭自己，
##      关闭统一发 `Events.CLOSE_UI` + 自己的路径，由 `core/ui_root.gd` 负责记账；
##      写存档走 `Events.SAVE_REQUEST` + `Events.SAVE_FINISHED`，不直接碰 `SaveData`；
##   2) 文案一律用翻译 key，新增 key 必须在 locale 三处同步；
##   3) 节点引用用 `%唯一名`，固定信号用 .tscn 里的 `[connection]` 连。
##
## 注：部件槽（`ui/workshop/slot.tscn`）由脚本实例化，不是"打开一个界面"，
## 所以走 `Paths.UI_WORKSHOP_SLOT` + 逐格 add_child，**不经过 UiRoot 的 OPEN_UI**
## （那条路是给独立界面记账用的，槽位是页面内部组件）。

## 部位槽布局（上半外圈哪一格放哪个部位）。改 `data/resources/workshop_layout.tres` 即可调整。
@export_file("*.tres") var layout_path: String = Paths.WORKSHOP_LAYOUT

## 部件总表（仓库里陈列哪些部件）。改 `data/resources/parts_catalog.tres` 即可增减。
@export_file("*.tres") var catalog_path: String = Paths.PARTS_CATALOG

## 下半部件网格的列数
@export var parts_columns: int = 4

## 部位 id → 上半该槽的 Slot 节点。收到点击时用它反查"点的是哪个部位"。
var _slots_by_id: Dictionary = {}

## 当前**被选中**的部位 id（点上半的部位槽切换）
var _selected_slot_id: String = ""

## 当前**被选中**的部件（仓库页上半点格子切换；默认第一个）
var _selected_part: WorkshopPart = null

## 谁开的这个界面（`OpenUiRequest.caller` 由 `core/ui_root.gd` 交付）。
## 空 = 没人指定来源（按正常形态显示，这样以后多一个入口时默认是"能用"的）。
var _caller: String = ""

@onready var _grid: GridContainer = %Grid
@onready var _parts_grid: GridContainer = %PartsGrid
@onready var _make_page: Control = %MakePage
@onready var _action_button: Button = %ActionButton
@onready var _save_popup: Control = %SavePopup
@onready var _name_field: LineEdit = %NameField
@onready var _save_hint: Label = %HintLabel


func _ready() -> void:
	_build_part_slots()
	_build_warehouse()
	# 上半部位槽与下半部件槽看起来要像"同一套槽"：格子尺寸对齐。
	# 必须延迟一帧 —— 此刻布局还没算完，读到的尺寸不可用。
	_align_part_slot_size.call_deferred()
	# 弹窗默认关着（场景里也写了 visible = false，这里再兜一次：脚本说了算）
	_save_popup.visible = false
	CoreSystem.event_bus.subscribe_unique_script(Events.SAVE_FINISHED, _on_save_finished)
	# `set_caller()` 由 UiRoot 在 add_child **之后紧接着**调（同帧、还没画到屏幕上），
	# 所以这里先按默认形态摆好，来源到了再改文案 —— 玩家看不到"闪一下"。
	_apply_caller()


func _exit_tree() -> void:
	if CoreSystem == null:
		return
	CoreSystem.event_bus.unsubscribe(Events.SAVE_FINISHED, _on_save_finished)


## UiRoot 交付"谁开的这个界面"（**可选契约**，见 `core/types.gd` 的 `OpenUiRequest.caller`）。
func set_caller(caller: String) -> void:
	_caller = caller
	_apply_caller()


## 按来源调整右上角那个按钮：**一个按钮两种含义** —— 文案和行为都跟来源走。
##
## 为什么不是"方案形态就把按钮藏起来"：那条路上要做的正是"把这套装配存下来"，
## 藏掉按钮等于这屏没有任何出口（人类 2026-10-07 改的口径：改成「保存」并弹命名窗）。
## 从方案进来时也**没有选过关**（没发过 `SELECT_LEVEL`），所以这里绝不能顺手保留「开始」。
func _apply_caller() -> void:
	if _action_button == null:
		return
	if _from_plan():
		_action_button.text = "ui.plan.save"
		_action_button.tooltip_text = tr("ui.plan.save")
	else:
		_action_button.text = "ui.workshop.start"
		_action_button.tooltip_text = tr("ui.workshop.start")


## 本界面是从「方案 → 新建方案」进来的吗
func _from_plan() -> bool:
	return _caller == Paths.UI_PLAN


#region 上半：部位槽

## 建 4x4 网格并只在**外圈**格子放部件槽。
##
## 为什么由脚本建而不是在 .tscn 里摆 16 个节点：
##   "哪一格是什么部位"是数据（`WorkshopLayout`），摆成场景节点就等于把数据抄进场景，
##   以后加/减槽要手改一堆节点。这里只保留一个空 `Grid` 容器，格子由数据驱动生成。
##
## 怎么判断"外圈"：网格下标 -> (行, 列)，行或列在两端就是外圈。
## 4x4 的外圈正好 12 格；中间 2x2 用空 Control 占位 ——
## **不能不放节点**，否则后面的格子会往前挤，把网格挤成 3 列的错乱布局。
##
## 总格位 = `columns * rows`（**不是槽数**）：外圈只有 `2*(行+列)-4` 个位置，
## 用槽数当总格位会把网格压扁（4 列 + 12 槽 → 4x3、外圈只剩 10 格）。行数在布局资源里配。
func _build_part_slots() -> void:
	var layout: WorkshopLayout = _load_layout()
	var columns: int = maxi(layout.columns, 1)
	var rows: int = maxi(layout.rows, 1)
	var total: int = columns * rows
	var wanted: int = _outer_slot_count(columns, rows)
	if layout.slots.size() != wanted:
		push_warning("[Workshop] 部位表有 %d 项，但 %dx%d 网格的外圈需要 %d 项；多余的会忽略、不足的留空"
			% [layout.slots.size(), columns, rows, wanted])

	_grid.columns = columns
	_clear(_grid)
	var slot_index: int = 0
	for i in total:
		var row: int = i / columns
		var col: int = i % columns
		if _is_outer(row, col, columns, rows):
			_grid.add_child(_make_body_slot(i, slot_index, layout))
			slot_index += 1
		else:
			_grid.add_child(_make_hole())


## n x m 网格外圈的格数（= 全部 - 内部）
func _outer_slot_count(columns: int, rows: int) -> int:
	return maxi(columns * rows - maxi(columns - 2, 0) * maxi(rows - 2, 0), 0)


## 下标是否在网格外圈（行或列在两端）
func _is_outer(row: int, col: int, columns: int, rows: int) -> bool:
	return row == 0 or row == rows - 1 or col == 0 or col == columns - 1


## 造一个**部位槽**（上半）：绑定部位 id 与部位名。
##
## 注意调用顺序：`set_placeholder` 必须在 `_ready()` 之后（入树后）调用，
## 否则 `%NameLabel` 还没解析、是 null。这里先传参、入树由调用方 add_child 完成，
## 所以 Slot 里对"还没 ready"做了保护（见 slot.gd 的 _refresh）。
func _make_body_slot(grid_index: int, slot_index: int, layout: WorkshopLayout) -> Control:
	var slot: Button = _new_slot("BodySlot%d" % grid_index)
	if slot_index < layout.slots.size():
		var def: WorkshopSlot = layout.slots[slot_index]
		if def != null:
			slot.set_meta("slot_id", def.id)
			# 空槽显示部位名，这样 12 个空格各自代表什么一目了然
			slot.set_placeholder(def.name_key)
			if not def.id.is_empty():
				_slots_by_id[def.id] = slot
	slot.pressed.connect(_on_slot_pressed.bind(slot))
	return slot


## 点某个部位槽：记下"当前选中的部位"，后续在仓库里点部件就装到这里。
## 用 meta 里的 slot_id 反查部位，父级不需要另存一份映射。
func _on_slot_pressed(slot: Button) -> void:
	var slot_id: String = str(slot.get_meta("slot_id", ""))
	if slot_id.is_empty():
		CoreSystem.logger.warning("[Workshop] 点了一个没有 slot_id 的槽（%s）" % slot.name)
		return
	_selected_slot_id = slot_id
	_refresh_selection_highlight()
	CoreSystem.logger.info("[Workshop] 选中部位：%s" % slot_id)


## 只让"当前选中的部位槽"显示选中框
func _refresh_selection_highlight() -> void:
	for id: String in _slots_by_id:
		var slot: Button = _slots_by_id[id]
		slot.set_selected(id == _selected_slot_id)

#endregion


#region 仓库页：上半陈列部件，下半显示选中部件的详情

## 仓库格子的底色。比部位槽略暗 —— 仓库区整体压暗后，格子要比区域底色亮一档才看得出来。
##
## 为什么不写在 `slot.tscn` 里：那个场景是**多处网格共用**的，各处需要不同底色，
## 所以由各自的创建方在代码里覆盖。
const PART_SLOT_COLOR: Color = Color(0.1019608, 0.1137255, 0.1372549, 1)
## 仓库格子 hover 时的底色（比常态再亮一档）
const PART_SLOT_HOVER_COLOR: Color = Color(0.1372549, 0.1529412, 0.1803922, 1)

## 建仓库页上半的部件网格：**从部件总表读**（`data/resources/parts_catalog.tres`）。
##
## 总表里加一项就多一个格子，不用改代码。每个格子显示该部件的图标与名字。
## **默认选中第一个部件**（下半详情立刻有内容，不会空着）。
func _build_warehouse() -> void:
	var catalog: PartsCatalog = _load_catalog()
	_parts_grid.columns = maxi(parts_columns, 1)
	_clear(_parts_grid)
	var shown: int = 0
	var first_part: WorkshopPart = null
	for i in catalog.parts.size():
		var part: WorkshopPart = catalog.parts[i]
		if part == null:
			push_warning("[Workshop] 部件总表第 %d 项是 null，跳过" % i)
			continue
		if first_part == null:
			first_part = part
		_parts_grid.add_child(_make_part_slot(shown, part))
		shown += 1
	if shown == 0:
		CoreSystem.logger.info("[Workshop] 部件总表里没有部件，仓库是空的")
	# 默认选中第一个（总表为空时是 null，详情显示成"未选中"）
	_select_part(first_part)


## 选中某个部件：记下来 + 更新格子高亮。
## （独立的仓库界面在 `ui/warehouse/`，那里才有"部件详情"面板。）
func _select_part(part: WorkshopPart) -> void:
	_selected_part = part
	for i in _parts_grid.get_child_count():
		var slot: Variant = _parts_grid.get_child(i)
		if slot is Button:
			(slot as Button).set_selected(
				part != null and str((slot as Button).get_meta("part_id", "")) == part.id)


## 造一个**部件槽**（制作页下半），显示该部件的图标与名字。
##
## **横向纵向都不扩张**（`SIZE_SHRINK_BEGIN`）：尺寸由 `_align_part_slot_size()`
## 设的最小尺寸决定（跟部位槽一样大）。
##   - 纵向若扩张：上半区域比"行数 x 格宽"高得多，行会把多余高度吃掉，格子被拉成竖长条。
##   - 横向若扩张：列宽（270）比格子边长（243）大，格子被拉成横长条（实测 270x243）。
## 两个方向都不扩张，格子才是正方形、且与部位槽一致；网格整体贴左上角对齐。
func _make_part_slot(index: int, part: WorkshopPart) -> Control:
	var slot: Button = _new_slot("PartSlot%d" % index)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_slot_color(slot, PART_SLOT_COLOR, PART_SLOT_HOVER_COLOR)
	slot.set_meta("part_index", index)
	slot.set_meta("part_id", part.id)
	# 复用 Slot 自己的显示逻辑：它读 `icon` / `name_key`，正好是 WorkshopPart 的字段名
	slot.set_part(part)
	if part.icon == null:
		# 图标还没做：用占位文字显示名字，别让格子空着看不出是什么
		slot.set_placeholder(part.name_key)
	slot.tooltip_text = tr(part.name_key)
	slot.pressed.connect(_on_part_pressed.bind(slot))
	return slot


## 覆盖一个槽的底色（四个状态一起换，避免 hover 时突然跳回 `slot.tscn` 的默认色）
func _apply_slot_color(slot: Button, normal: Color, hover: Color) -> void:
	for state in ["normal", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = normal
		sb.content_margin_left = 24.0
		sb.content_margin_top = 24.0
		sb.content_margin_right = 24.0
		sb.content_margin_bottom = 24.0
		slot.add_theme_stylebox_override(state, sb)
	var hb := StyleBoxFlat.new()
	hb.bg_color = hover
	hb.content_margin_left = 24.0
	hb.content_margin_top = 24.0
	hb.content_margin_right = 24.0
	hb.content_margin_bottom = 24.0
	slot.add_theme_stylebox_override("hover", hb)


## 点某个部件槽：选中它并刷新详情。
##
## **真正装到兽人身上（`PartHost.setup`）还没接** —— 那需要"每个部位当前装了什么、
## 能不能替换"这套玩法数据。仓库页现在只负责"陈列 + 看详情"。
func _on_part_pressed(slot: Button) -> void:
	var part: WorkshopPart = _find_part(str(slot.get_meta("part_id", "")))
	if part == null:
		CoreSystem.logger.warning("[Workshop] 部件槽 %s 找不到对应部件" % slot.name)
		return
	_select_part(part)
	CoreSystem.logger.info("[Workshop] 选中部件：%s" % part.id)


## 按 id 在总表里找部件（不缓存查找表：总表很小，且这样不会和"改配置后重建"不同步）
func _find_part(part_id: String) -> WorkshopPart:
	if part_id.is_empty():
		return null
	var catalog: PartsCatalog = _load_catalog()
	for p: Variant in catalog.parts:
		if p is WorkshopPart and (p as WorkshopPart).id == part_id:
			return p
	return null

#endregion


#region 尺寸对齐

## 把仓库格子的**最小尺寸对齐到部位槽的实际宽度**。
##
## 为什么要这一步：两个网格的列宽算出来不一样 ——
##   上半 `Grid` 占满 1080 宽，4 列每列 270；
##   而格子自身不扩张（`SIZE_SHRINK_BEGIN`），靠这里的"最小尺寸"决定边长。
## 读部位槽的实际宽度当边长，把仓库每个格子也设成"边长 x 边长"，
## 于是两处格子是同一尺寸的正方形。
##
## 必须**延迟一帧**调用：`_ready()` 里布局还没算完，此刻读到的尺寸是 0。
func _align_part_slot_size() -> void:
	var reference: float = 0.0
	for c in _grid.get_children():
		if c is Button:
			reference = (c as Control).size.x
			break
	if reference <= 0.0:
		return
	for c in _parts_grid.get_children():
		(c as Control).custom_minimum_size = Vector2(reference, reference)

#endregion


#region 公共小工具

## 实例化一个槽（上半部位槽 / 下半部件槽共用）
func _new_slot(node_name: String) -> Button:
	var scene: PackedScene = load(Paths.UI_WORKSHOP_SLOT) as PackedScene
	var slot: Button = scene.instantiate()
	slot.name = node_name
	return slot


## 清空容器。用 remove_child + free 而**不是 queue_free**：queue_free 要等帧末才真删，
## 同一帧内重建会让新旧节点重名（Godot 给新节点起匿名名），后面按名字找就全失效。
## 同理**不能用 await** —— 那会把调用它的函数变成异步，调用方不等它就往下走了。
func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()


## 网格里的空位（不显示任何东西，只为占住格位）
func _make_hole() -> Control:
	var hole := Control.new()
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hole


## 读部件总表。缺失或类型不对时返回一个**空表**（仓库为空，但界面其它部分照常工作）。
##
## 为什么这里不 push 一份"内置默认部件"：兜底造出来的部件没有真实行为场景，
## 点上去只会报错。宁可仓库空着（有日志），也不要摆一堆点了没反应的东西。
func _load_catalog() -> PartsCatalog:
	if not catalog_path.is_empty() and ResourceLoader.exists(catalog_path):
		var loaded: Resource = load(catalog_path)
		if loaded is PartsCatalog:
			return loaded
		push_warning("[Workshop] %s 不是 PartsCatalog" % catalog_path)
	else:
		push_warning("[Workshop] 部件总表不存在：%s" % catalog_path)
	return PartsCatalog.new()


## 读部位布局。缺失或类型不对时退回一份内置默认（保证界面不会整页空掉）。
func _load_layout() -> WorkshopLayout:
	if not layout_path.is_empty() and ResourceLoader.exists(layout_path):
		var loaded: Resource = load(layout_path)
		if loaded is WorkshopLayout:
			return loaded
		push_warning("[Workshop] %s 不是 WorkshopLayout，改用内置默认布局" % layout_path)
	else:
		push_warning("[Workshop] 布局不存在：%s，改用内置默认布局" % layout_path)
	return _default_layout()


## 兜底布局：4 列 + 12 个无名部位槽（只保证网格形状对，不保证部位名）
##
## 注意：这里**只补数量不补 id** —— 兜底路径下点槽位拿不到 slot_id，
## 这是有意的：宁可少功能，也不要凭空造出错误的部位名让人以为配置生效了。
func _default_layout() -> WorkshopLayout:
	var layout := WorkshopLayout.new()
	layout.columns = 4
	layout.rows = 4
	var list: Array = []
	for i in _outer_slot_count(layout.columns, layout.rows):
		list.append(WorkshopSlot.new())
	layout.slots = list
	return layout

#endregion


## 右上角那个按钮（**一个按钮两种含义**，文案在 `_apply_caller()` 里按来源切换）：
##   - 从地图来 = 「开始」→ 进关卡；
##   - 从方案来 = 「保存」→ 弹命名弹窗。
func _on_action_pressed() -> void:
	if _from_plan():
		_open_save_popup()
		return
	_start_selected_level()


## 开始（从地图来的正常形态）：装配完了，进关卡。
##
## 两步（顺序不能反）：
##   1) `CLOSE_UI(自己的路径)`：先把自己关掉（界面不自己 queue_free，记账交给 UiRoot）
##      —— 关卡会挂在 `GameFlow/SceneRoot` 上，本界面留在场上的话会盖在关卡上面；
##   2) `START_GAME(空路径)`：**空 = 打地图界面选定的那一关**
##      （`Events.SELECT_LEVEL` 记在 `core/game_flow.gd` 的 `_selected_level`），
##      由它负责淡黑 → 换关卡 → 淡回。没选过 / 没配关卡时它会给明确报错。
func _start_selected_level() -> void:
	CoreSystem.logger.info("[Workshop] 开始：进选定的关卡")
	CoreSystem.event_bus.push_event(Events.CLOSE_UI, Paths.UI_WORKSHOP)
	CoreSystem.event_bus.push_event(Events.START_GAME, "")


## 返回：
##   - **从方案进来**：回方案界面（从哪来回哪去）；
##   - 其它（从地图进来 / 没指定来源）：回主菜单，交给 `core/game_flow.gd` 编排
##     （它会先关掉本界面再打开主菜单，顺序固定在一处，避免同层出现两个界面）。
##
## 用 `OPEN_MAIN_MENU` + 自己的路径，和 `ui/options` 的返回是同一个协议 ——
## `game_flow._on_open_main_menu(from_path)` 里 `_main_menu_open` 为真时只关本界面、
## 不重复打开主菜单，所以从主菜单进来的界面这样写是对的。
func _on_back_pressed() -> void:
	if _from_plan():
		CoreSystem.logger.info("[Workshop] 返回：回方案界面（来源是方案）")
		_close_to_plan()
		return
	CoreSystem.event_bus.push_event(Events.OPEN_MAIN_MENU, Paths.UI_WORKSHOP)


## 回方案界面：关自己 → 开方案。
## 顺序不能反（同地图界面「下一步」的写法）：先开的话同层会同时存在两个全屏界面。
func _close_to_plan() -> void:
	CoreSystem.event_bus.push_event(Events.CLOSE_UI, Paths.UI_WORKSHOP)
	var request: Types.OpenUiRequest = Types.OpenUiRequest.new()
	request.path = Paths.UI_PLAN
	CoreSystem.event_bus.push_event(Events.OPEN_UI, request)


#region 保存方案弹窗

## 打开「保存方案」弹窗。
## 每次都从空白开始：留着上次输入的名字，容易让人以为"已经存过了"。
func _open_save_popup() -> void:
	_name_field.text = ""
	_save_hint.visible = false
	_save_popup.visible = true
	# 直接聚焦输入框：PC 上能立刻打字，安卓上会带出软键盘
	_name_field.grab_focus()
	CoreSystem.logger.info("[Workshop] 打开保存方案弹窗")


func _close_save_popup() -> void:
	_save_popup.visible = false


## 「取消」：只关弹窗，什么都不写（还在制造界面里，可以接着改）
func _on_save_cancel_pressed() -> void:
	CoreSystem.logger.info("[Workshop] 取消保存方案")
	_close_save_popup()


## 点遮罩（弹窗外那片半透明黑）也当取消。
## 只看"鼠标左键按下"和"触摸按下"，免得拖动/滚轮把它关掉（与图鉴弹窗同一套）。
func _on_save_dim_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_close_save_popup()
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_close_save_popup()


## 输入框里按回车 = 点「确定」
func _on_name_submitted(_text: String) -> void:
	_on_save_confirm_pressed()


## 「确定」：名字不能空（空就只提示，不写档、不关弹窗），然后**发存档请求**。
##
## 写档只能发事件（硬规则）：本界面不直接改 `SaveData`，也不自己写文件 ——
## 落盘、元数据、结果事件都归 `core/save_service.gd`；结果回到 `_on_save_finished`。
func _on_save_confirm_pressed() -> void:
	var plan_name: String = _name_field.text.strip_edges()
	if plan_name.is_empty():
		_show_save_hint("ui.plan.name_empty")
		return

	var request: Types.SaveRequest = Types.SaveRequest.new()
	request.slot = PlanSave.SLOT
	request.reason = "plan"
	# 补丁路径 = 分段名 → 字段名：把"新方案 + 现有列表"整份写回
	request.data = {"plans": {"plans": _plans_with(plan_name)}}
	CoreSystem.logger.info("[Workshop] 保存方案：%s" % plan_name)
	CoreSystem.event_bus.push_event(Events.SAVE_REQUEST, request)


## 新方案 + 当前已有的方案（新的放**最前面**：方案界面按数组顺序从上往下显示）。
##
## **同名视为覆盖**：旧的那条先剔掉 —— 否则同一个名字能存出一堆一模一样的卡片，
## 而且方案名是玩家区分方案的唯一标识。
func _plans_with(plan_name: String) -> Array:
	var merged: Array = [{"name": plan_name}]
	if SaveData.current != null:
		for entry: Variant in SaveData.current.plans.plans:
			if entry is Dictionary and str((entry as Dictionary).get("name", "")) != plan_name:
				merged.append(entry)
	return merged


## 显示一行提示（红字），文案是翻译 key（Label 会自己翻译）
func _show_save_hint(hint_key: String) -> void:
	_save_hint.text = hint_key
	_save_hint.visible = true


## 存档结果：**只认方案档**（设置档等别的存档结果不归这里管）。
## 成功 → 关弹窗 + 回方案界面（列表里立刻能看到刚存的那条）；失败 → 留在弹窗里给提示，
## 玩家还能改名字重试（不能"看着像存好了"却什么都没写进去）。
func _on_save_finished(result: Types.SaveResult) -> void:
	if result == null or result.slot != PlanSave.SLOT:
		return
	if not result.ok:
		CoreSystem.logger.error("[Workshop] 方案保存失败：%s" % result.error)
		_show_save_hint("ui.plan.save_failed")
		return
	CoreSystem.logger.info("[Workshop] 方案已写入方案档，回方案界面")
	_close_save_popup()
	_close_to_plan()

#endregion
