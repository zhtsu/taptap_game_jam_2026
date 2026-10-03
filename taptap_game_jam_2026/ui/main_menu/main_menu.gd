extends Control

## 主菜单（设计稿里的"星系主页"）：按钮只负责发事件，实际动作交给对应系统。
##
## 结构对应设计稿（2026TapTap聚光灯-游戏主循环.pdf 第 1 屏）：
##   右上「设置」→ 星系效果区（占位）→ 通栏「开始」→ 2×2 网格：车间 / 仓库 / 地图 / 评分
##
## 按钮信号在 .tscn 里用 [connection] 连接，所以这里不写 `$Margin/Column/...` 这类长路径。
##
## 当前接入情况：
##   - 设置 → 现成的设置界面（ui/options）
##   - 开始 / 车间 / 仓库 / 地图 / 评分 → **目标界面尚未实现**，按下暂不做任何事（见下方 TODO）
##   - 背景：GalaxyViewport/SubViewport 里挂 3D 星系（ui/galaxy/galaxy.tscn），
##     参数在 data/resources/galaxy.tres 里调（路径见 Paths.GALAXY_CONFIG）—— 本脚本只负责把它实例化进去

## 星系场景的挂载点（SubViewport 下的一个空 Node3D）
@onready var _galaxy_root: Node3D = %GalaxyRoot


func _ready() -> void:
	_spawn_galaxy()


## 把 3D 星系实例化到 SubViewport 里当背景。
## 为什么在这里实例化而不是直接写进 .tscn：星系是独立场景（能单独 F6 预览、能换配置），
## 且它会自己生成子节点（WorldEnvironment / Rings / 星球），写死在 .tscn 里保存一次就脏一次。
func _spawn_galaxy() -> void:
	if _galaxy_root == null:
		push_warning("[MainMenu] 找不到 %%GalaxyRoot，跳过星系背景")
		return
	if not ResourceLoader.exists(Paths.UI_GALAXY):
		push_warning("[MainMenu] 星系场景不存在：%s" % Paths.UI_GALAXY)
		return
	var packed: PackedScene = load(Paths.UI_GALAXY) as PackedScene
	if packed == null:
		push_warning("[MainMenu] 星系场景加载失败：%s" % Paths.UI_GALAXY)
		return
	_galaxy_root.add_child(packed.instantiate())


## 开始：设计稿的目标是"关卡选择屏"（带星系旋转缩放到具体星球的过渡）
func _on_start_pressed() -> void:
	_not_implemented("关卡选择")


## 设置：复用现成的设置界面（它是独立场景，直接开）
func _on_settings_pressed() -> void:
	var request: Types.OpenUiRequest = Types.OpenUiRequest.new()
	request.path = Paths.UI_OPTIONS
	CoreSystem.event_bus.push_event(Events.OPEN_UI, request)


## 车间：局外制造兽人
func _on_workshop_pressed() -> void:
	_not_implemented("车间")


## 仓库：已解锁的兽人部件总览
func _on_warehouse_pressed() -> void:
	_not_implemented("仓库")


## 地图：已解锁的关卡和 BOSS
func _on_map_pressed() -> void:
	_not_implemented("地图")


## 评分：游戏内评分记录
func _on_score_pressed() -> void:
	_not_implemented("评分")


## 目标界面还没做时的统一出口：**只记一条日志，不打开任何东西**。
## 为什么不自己弹提示/建占位界面：那是界面层的决定，等人来决定；
## 这里保持"按下不做事"，界面上不会出现来路不明的中间页。
func _not_implemented(feature: String) -> void:
	CoreSystem.logger.info("[MainMenu] 「%s」的目标界面尚未实现，暂不跳转" % feature)
