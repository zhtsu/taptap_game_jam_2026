extends CanvasLayer

## **银河系背景**：一个常驻的独立层，不是 MainMenu 的一部分。
##
## 为什么单独成一层（而不是留在 MainMenu 里）：
##   主菜单和地图界面都要拿它当背景 —— 如果它挂在 MainMenu 下，
##   地图界面想用背景就得依赖"主菜单在场"，职责就乱了。
##   抽成常驻层之后，两边都只是"背景在底下"，谁也不用管谁。
##
## 层序：本节点 `layer = -1`（见 .tscn），而 UiRoot 是 CanvasLayer、
## 它的 Bottom/Middle/Top 子层按树序绘制 —— 所以本层**始终在所有 UI 之下**，
## 界面的透明背景能直接透出 3D 画面。
##
## 镜头控制：地图界面不直接持有本层的星系引用，只发
## `Events.GALAXY_FOCUS` / `Events.GALAXY_RESET`，由本脚本转给星系
## （和 MainMenu 之前的做法同源，只是搬到了这里）。

## 星系的挂载点（SubViewport 下的一个空 Node3D）
@onready var _galaxy_root: Node3D = %GalaxyRoot

## 实例化出来的星系（focus 时用；没生成出来时为 null）
var _galaxy: Node3D = null


func _ready() -> void:
	_spawn_galaxy()
	CoreSystem.event_bus.subscribe_unique_script(Events.GALAXY_FOCUS, _on_galaxy_focus)
	CoreSystem.event_bus.subscribe_unique_script(Events.GALAXY_RESET, _on_galaxy_reset)


func _exit_tree() -> void:
	if CoreSystem == null:
		return
	CoreSystem.event_bus.unsubscribe(Events.GALAXY_FOCUS, _on_galaxy_focus)
	CoreSystem.event_bus.unsubscribe(Events.GALAXY_RESET, _on_galaxy_reset)


## 把 3D 星系实例化进 SubViewport。
## 为什么用代码实例化而不是写进 .tscn：星系是独立场景（能单独 F6 预览、能换配置），
## 且它会自己生成子节点（WorldEnvironment / 星球 / 轨道线），写死在 .tscn 里保存一次就脏一次。
func _spawn_galaxy() -> void:
	if _galaxy_root == null:
		push_warning("[GalaxyBackground] 找不到 %%GalaxyRoot，跳过星系背景")
		return
	if not ResourceLoader.exists(Paths.UI_GALAXY):
		push_warning("[GalaxyBackground] 星系场景不存在：%s" % Paths.UI_GALAXY)
		return
	var packed: PackedScene = load(Paths.UI_GALAXY) as PackedScene
	if packed == null:
		push_warning("[GalaxyBackground] 星系场景加载失败：%s" % Paths.UI_GALAXY)
		return
	_galaxy = packed.instantiate() as Node3D
	_galaxy_root.add_child(_galaxy)


## 镜头漫游到某颗天体的特写。
## payload = `[天体下标, 漫游时长秒]`（时长缺省 = 0 = 立即锁定）。
func _on_galaxy_focus(body_index: int, duration: float = 0.0) -> void:
	if _galaxy == null or not is_instance_valid(_galaxy):
		CoreSystem.logger.warning("[GalaxyBackground] 星系不在场，无法执行特写")
		return
	if _galaxy.has_method("focus_on_body"):
		_galaxy.call("focus_on_body", body_index, duration)


## 退出特写：恢复所有天体与轨道、镜头归位
func _on_galaxy_reset() -> void:
	if _galaxy == null or not is_instance_valid(_galaxy):
		return
	if _galaxy.has_method("reset_focus"):
		_galaxy.call("reset_focus")
