extends Button

## 车间里的**部件槽**：一个可点击的方形格子，用来放一个兽人部件。
##
## 设计约定（职责边界）：
##   - 本脚本**不知道自己排在第几格、也不知道当前选中了谁** —— 那些属于制造页的状态。
##     它只做两件事：显示一个部件、被点击时发 `pressed`（Button 自带信号）。
##   - 因此"格子 → Slot"的映射由父级（制造页 / 网格）持有；父级收到 `pressed` 后
##     从自己的映射里反查是哪个 Slot，再决定后续动作。
##
## 空槽与选中态：
##   - `set_part(null)` = 空槽：图标隐藏、名字清空、画一个淡叉标记。
##   - 选中框**没有做成子节点**，而是本脚本 `_draw()` 里画 ——
##     Button 自带 normal/hover/pressed/focus 四个状态，再加一个子节点去叠框容易打架；
##     画在自绘层则与按钮状态完全解耦，改配色只动 `SELECTED_COLOR`。
##
## 为什么继承 Button 而不是 Control + 自己处理输入：
##   天然有点击、hover/pressed/focus 状态，键盘与手柄也能聚焦（focus_mode = FOCUS_ALL），
##   而且无障碍/触屏都不用另外接线。代价只是要覆盖它自带的 StyleBox（已在 .tscn 里覆盖）。

## 被点击。Button 自带的 `pressed` 信号就是；这里再声明一个同语义的别名没有意义，
## 所以**直接用 Button 的 `pressed`**，父级连它即可。

## 选中框颜色。改选中样式只需要动这里。
const SELECTED_COLOR: Color = Color(1.0, 0.72, 0.30, 1.0)
const SELECTED_WIDTH: float = 6.0

## 当前显示的部件（可能为 null = 空槽）。
## 刻意**不加类型标注**：部件类型定下来之后再收紧成 `WorkshopPart`，
## 这样在部件数据表还没建之前，这个场景也能单独实例化、单独 F6 预览。
var _part: Variant = null

## 空槽时显示的文字（翻译 key）。由父级用 `set_placeholder()` 给 —— 通常是部位名，
## 这样 12 个空槽能一眼看出各自代表哪个部位，而不是长得一模一样。
var _placeholder_key: String = ""

## 是否选中（只影响自绘的选中框）
var _selected: bool = false

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel


func _ready() -> void:
	_refresh()


## 设置"空槽时显示的文字"（翻译 key）。装上部件的槽会显示部件名，忽略这个。
func set_placeholder(name_key: String) -> void:
	_placeholder_key = name_key
	_refresh()


## 显示某个部件。传 `null` = 空槽。
##
## 读 `icon` / `name_key` 两个属性用 `get()` 而不是直接 `part.icon`：
## 部件类型（WorkshopPart）还没建，现在用 duck typing 可以先把界面跑起来；
## 等数据表建好后把参数标注收紧即可，调用方不用改。
func set_part(part: Variant) -> void:
	_part = part
	_refresh()


## 设置选中态（父级在"选中变了"时调用）
func set_selected(on: bool) -> void:
	if _selected == on:
		return
	_selected = on
	queue_redraw()


## 当前是否有部件
func has_part() -> bool:
	return _part != null


## 取当前部件（父级需要读数据时用）
func get_part() -> Variant:
	return _part


## 把 `_part` 显示出来。没有部件时退回显示占位文字（部位名）。
##
## **允许在入树前被调用**：父级常见写法是 `instantiate()` → `set_placeholder()` → `add_child()`，
## 那时 `%Icon` / `%NameLabel` 还没解析（是 null）。所以这里判空跳过 ——
## 真正的刷新由 `_ready()` 补一次，不会丢状态（`_part` / `_placeholder_key` 已经存好了）。
func _refresh() -> void:
	if _icon == null or _name_label == null:
		return
	var part: Variant = _part
	if part == null:
		_icon.texture = null
		_name_label.text = tr(_placeholder_key) if not _placeholder_key.is_empty() else ""
	else:
		_icon.texture = part.get("icon") as Texture2D
		var key: String = str(part.get("name_key"))
		# 空 key 时 tr("") 会返回空串，不会把 key 原样显示出来
		_name_label.text = tr(key) if not key.is_empty() else ""
	queue_redraw()


## 自绘：只画选中框。
##
## 空槽**不再画淡叉**了：部位名现在居中大字显示，本身已经说明"这格是空的、属于哪个部位"，
## 再叠一个叉会在文字上穿过去。画在按钮自身样式之上，和按钮状态互不干扰。
func _draw() -> void:
	if _selected:
		draw_rect(Rect2(Vector2.ZERO, size), SELECTED_COLOR, false, SELECTED_WIDTH)
