extends Control

## 主菜单（设计稿里的"星系主页"）：按钮只负责发事件，实际动作交给对应系统。
##
## 结构对应设计稿（2026TapTap聚光灯-游戏主循环.pdf 第 1 屏）：
##   右上「设置」→ 星系效果区 → 通栏「开始」→ 下面一行：方案 / 图鉴
##
## 按钮信号在 .tscn 里用 [connection] 连接，所以这里不写 `$Margin/Column/...` 这类长路径。
##
## 当前接入情况：
##   - 设置 → ui/options；方案 → ui/plan；图鉴 → ui/warehouse
##   - **开始 → ui/map（关卡选择就是地图界面）** —— 打开前先 `set_ui_visible(false)` 藏本菜单 UI
##   - **「地图」「评分」两个按钮已按人类要求移除**（2026-10-07）：
##     地图界面改由「开始」进入；评分界面与其数据已整体删除。
##     **原「制造」按钮已改成「方案」并指向新界面 `ui/plan/`**（同日）——
##     也就是说 `ui/workshop/` 这场戏**当前没有入口**了（场景保留着，等接回流程）。
##     所以下面 `set_ui_visible` / `restore_after_map` 是**在用**的（地图界面靠它），不是死代码。
##   - **背景不在这里**：银河系背景是常驻独立层 `ui/galaxy/galaxy_background.tscn`，
##     挂在 `entry/main.tscn` 上（layer = -1，在所有 UI 之下）。
##     本菜单只是"浮在它上面的 UI"，所以 `FloatingUI` 可以整个隐藏而不影响背景
##     —— 地图界面就靠这个把主菜单 UI 藏起来（见 `set_ui_visible`）。

## 主菜单的全部 UI（顶栏 + 下方按钮）。**背景不在这里**，所以隐藏它不会连背景一起藏掉。
@onready var _floating_ui: Control = %FloatingUI


## 显示 / 隐藏主菜单的 UI。
##
## 给"需要在同一份银河系背景上展示别的界面"的场景用（目前是地图界面：
## 打开时把主菜单 UI 藏起来、右上角只留地图自己的返回按钮）。
## 只动 UI 的可见性，不碰背景层 —— 这也是把背景抽成独立层的意义。
func set_ui_visible(shown: bool) -> void:
	if _floating_ui != null:
		_floating_ui.visible = shown


## 打开一个界面：填 OpenUiRequest 的样板只留在这里。
## 分层交给 UiRoot 的默认（MIDDLE）。
func _open_ui(ui_path: String) -> void:
	var request: Types.OpenUiRequest = Types.OpenUiRequest.new()
	request.path = ui_path
	CoreSystem.event_bus.push_event(Events.OPEN_UI, request)


## 开始：进**关卡选择** —— 现在就是地图界面（`ui/map/`）。
##
## 地图界面的上半屏就是"选哪一关"（「< 星球名 >」切天体 + 下半屏关卡信息卡片），
## 所以它同时充当了设计稿里的"关卡选择屏"。以后要单独做一层选关，就在
## `ui/map/` 前面再插一个界面，这里改 `Path` 即可。
##
## 打开前先把自己的 UI 藏起来（**和当初「地图」按钮同一套做法**）：
## 地图是全屏、背景透明的界面，它要的是"只有 3D 星系 + 它自己"，
## 主菜单的按钮浮在上面会穿帮。恢复由地图界面负责（它调 `restore_after_map()`）。
func _on_start_pressed() -> void:
	set_ui_visible(false)
	_open_ui(Paths.UI_MAP)


## 设置：复用现成的设置界面（它是独立场景，直接开）
func _on_settings_pressed() -> void:
	_open_ui(Paths.UI_OPTIONS)


## 方案：从「制造」界面里独立出来的一屏（原来是制造的两个 Tab 之一）
func _on_plan_pressed() -> void:
	_open_ui(Paths.UI_PLAN)


## 图鉴（warehouse）：已解锁的兽人部件总览
func _on_warehouse_pressed() -> void:
	_open_ui(Paths.UI_WAREHOUSE)


## 地图界面关闭时把 UI 显回来。
##
## 为什么由地图界面显式调、而不是本菜单去监听"地图关掉了"：
##   地图的关闭路径可能有多条（点返回、被别的系统关掉），
##   让"主张隐藏的人"负责恢复最不容易漏；本菜单只提供方法，不管什么时候该调。
func restore_after_map() -> void:
	set_ui_visible(true)
