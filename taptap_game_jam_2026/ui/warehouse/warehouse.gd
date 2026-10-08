extends Control

## 图鉴界面（已解锁的部件总览）。从主菜单的「图鉴」按钮打开。
##
## **界面显示名是「图鉴」，代码里叫 warehouse**（目录 / 场景 / 翻译 key 都用 warehouse；
## key 是稳定标识，显示名跟着语言走 —— 见 `locale/zh_CN.po` 的 `ui.warehouse.title`）。
##
## 布局（2026-10-07 按人类要求改过）：
##   - 整屏**只有一个部件网格**（`GridContainer`，外面套 `ScrollContainer` 以便部件变多时滚动）
##     —— 不再有"上半网格 + 下半详情"那种上下分区。
##   - **点某个部件 → 弹出详情弹窗**（名称 + 稀有度 + 造价 + 部位），
##     关掉方式：点「关闭」按钮，或点弹窗外的半透明遮罩。
##
## 弹窗为什么自己做（而不是 `Window` / `PopupPanel`）：本工程所有界面都是自定义深色
## `StyleBoxFlat`，引擎自带弹窗会带一套默认主题的边框/标题栏，还得逐个 theme override 去压；
## 自己用一个 `PanelContainer` + 全屏遮罩，样式和别处一致，安卓上也没有"子窗口"那套差异。
##
## 三条约定（与 ui/options、ui/credits、ui/workshop 一致）：
##   1) 打开 / 关闭都走事件：本界面不自己 queue_free 关闭自己，
##      关闭统一发事件 + 自己的路径，由 `core/ui_root.gd` 负责记账；
##   2) 文案一律用翻译 key，新增 key 必须在 locale 三处同步；
##   3) 节点引用用 `%唯一名`，固定信号用 .tscn 里的 `[connection]` 连。
##
## 注：部件槽（`ui/workshop/slot.tscn`）由脚本实例化，不是"打开一个界面"，
## 所以走 `Paths.UI_WORKSHOP_SLOT` + 逐格 add_child，**不经过 UiRoot 的 OPEN_UI**。

## 部件总表（图鉴陈列哪些部件）。改 `data/resources/parts_catalog.tres` 即可增减。
@export_file("*.tres") var catalog_path: String = Paths.PARTS_CATALOG

## 网格列数
@export var columns: int = 4

@onready var _grid: GridContainer = %PartsGrid
@onready var _popup: Control = %PartPopup
@onready var _popup_title: Label = %PopupTitle
@onready var _popup_rarity: Label = %RarityRow
@onready var _popup_cost: Label = %CostRow
@onready var _popup_slot: Label = %SlotRow


func _ready() -> void:
	_popup.visible = false
	_build_grid()
	_align_cell_size.call_deferred()


## 建部件网格：从总表读，逐格 add_child。
func _build_grid() -> void:
	var catalog: PartsCatalog = _load_catalog()
	_grid.columns = maxi(columns, 1)
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.free()

	var shown: int = 0
	for i in catalog.parts.size():
		var part: WorkshopPart = catalog.parts[i]
		if part == null:
			push_warning("[Warehouse] 部件总表第 %d 项是 null，跳过" % i)
			continue
		_grid.add_child(_make_slot(shown, part))
		shown += 1
	if shown == 0:
		CoreSystem.logger.info("[Warehouse] 部件总表里没有部件，图鉴是空的")


## 造一个部件槽，显示该部件的图标与名字。
##
## **横向纵向都不扩张**（`SIZE_SHRINK_BEGIN`）：尺寸由 `_align_cell_size()` 设的最小尺寸决定。
## 扩张的话格子会被容器拉成长方块（纵向超高的区域会把行拉长、横向列宽比格子大也会拉宽）。
func _make_slot(index: int, part: WorkshopPart) -> Control:
	var packed: PackedScene = load(Paths.UI_WORKSHOP_SLOT) as PackedScene
	var slot: Button = packed.instantiate()
	slot.name = "PartSlot%d" % index
	slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	slot.set_meta("part_id", part.id)
	# 复用 Slot 自己的显示逻辑：它读 `icon` / `name_key`，正好是 WorkshopPart 的字段名
	slot.set_part(part)
	if part.icon == null:
		# 图标还没做：用占位文字显示名字，别让格子空着看不出是什么
		slot.set_placeholder(part.name_key)
	slot.tooltip_text = tr(part.name_key)
	slot.pressed.connect(_on_slot_pressed.bind(slot))
	return slot


## 点某个部件槽：弹出它的详情
func _on_slot_pressed(slot: Button) -> void:
	var part: WorkshopPart = _find_part(str(slot.get_meta("part_id", "")))
	if part == null:
		CoreSystem.logger.warning("[Warehouse] 部件槽 %s 找不到对应部件" % slot.name)
		return
	_show_popup(part)
	CoreSystem.logger.info("[Warehouse] 弹出部件详情：%s" % part.id)


## 弹出详情弹窗。**标题就是部件名**（所以没有"名称："那一行，避免和标题重复）。
func _show_popup(part: WorkshopPart) -> void:
	_popup_title.text = tr(part.name_key)
	_popup_rarity.text = "%s%s" % [tr("ui.warehouse.rarity"), str(part.rarity)]
	_popup_cost.text = "%s%s" % [tr("ui.warehouse.cost"), str(part.cost)]
	_popup_slot.text = "%s%s" % [tr("ui.warehouse.slot"), _slot_display_name(part.slot_id)]
	_popup.visible = true


## 关掉弹窗（「关闭」按钮 / 点遮罩 / 以后可能加的手势都走这里）
func _hide_popup() -> void:
	_popup.visible = false


func _on_close_pressed() -> void:
	_hide_popup()


## 点遮罩（弹窗外那片半透明黑）也关掉弹窗。
## 只看"鼠标左键按下"和"触摸按下"，免得拖动/滚轮也把它关掉。
func _on_dim_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_hide_popup()
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_hide_popup()


## 按 id 在总表里找部件
func _find_part(part_id: String) -> WorkshopPart:
	if part_id.is_empty():
		return null
	for p: Variant in _load_catalog().parts:
		if p is WorkshopPart and (p as WorkshopPart).id == part_id:
			return p
	return null


## 部位 id → 显示名（在部位布局里查 name_key）。查不到就显示原 id。
func _slot_display_name(slot_id: String) -> String:
	if slot_id.is_empty():
		return tr("ui.warehouse.na")
	var layout: WorkshopLayout = _load_layout()
	for s: Variant in layout.slots:
		if s is WorkshopSlot and (s as WorkshopSlot).id == slot_id:
			return tr((s as WorkshopSlot).name_key)
	return slot_id


## 让格子保持正方形：边长 = 可用宽度 / 列数（减掉缝隙）。
##
## 为什么不用 `custom_minimum_size` 写死：格子要能跟着容器宽度自适应；
## 这里只在布局算完之后把"边长"写进最小尺寸，格子就不再被拉伸了。
## 必须**延迟一帧**调用 —— `_ready()` 里布局还没算完，读到的宽度是 0。
func _align_cell_size() -> void:
	var available: float = _grid.size.x
	if available <= 0.0:
		return
	var sep: float = float(_grid.get_theme_constant("h_separation"))
	var side: float = (available - sep * float(maxi(columns, 1) - 1)) / float(maxi(columns, 1))
	if side <= 0.0:
		return
	for child in _grid.get_children():
		(child as Control).custom_minimum_size = Vector2(side, side)


## 读部件总表。缺失或类型不对时返回**空表**（图鉴为空但有日志），
## 不造"内置默认部件" —— 那样造出来的部件没有真实行为场景，点上去只会报错。
func _load_catalog() -> PartsCatalog:
	if not catalog_path.is_empty() and ResourceLoader.exists(catalog_path):
		var loaded: Resource = load(catalog_path)
		if loaded is PartsCatalog:
			return loaded
		push_warning("[Warehouse] %s 不是 PartsCatalog" % catalog_path)
	else:
		push_warning("[Warehouse] 部件总表不存在：%s" % catalog_path)
	return PartsCatalog.new()


## 读部位布局（只用来把 slot_id 翻成显示名）
func _load_layout() -> WorkshopLayout:
	if ResourceLoader.exists(Paths.WORKSHOP_LAYOUT):
		var loaded: Resource = load(Paths.WORKSHOP_LAYOUT)
		if loaded is WorkshopLayout:
			return loaded
	return WorkshopLayout.new()


## 返回主菜单：交给 `core/game_flow.gd` 编排（先关本界面再打开主菜单，
## 顺序固定在一处，避免同层出现两个界面）。
func _on_back_pressed() -> void:
	CoreSystem.event_bus.push_event(Events.OPEN_MAIN_MENU, Paths.UI_WAREHOUSE)
