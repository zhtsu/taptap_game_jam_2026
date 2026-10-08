class_name WorkshopPart
extends Resource

## 一个兽人**部件**的配置：身份信息 + 指向它的行为脚本。
##
## 三层分工（和 `PartBehavior` / `PartHost` 配合）：
##   - **本类**：配置。数值、图标、属于哪个部位、行为场景在哪 —— 策划在 Inspector 里改。
##   - `PartBehavior`：行为。钩子写在**脚本**里（见那里的约定）。
##   - `PartHost`：运行时把一个部件装进一个部位，负责订阅事件与驱动 tick。
##
## **本类刻意不存"关心哪些事件"**：事件名单写在行为脚本的 `events_of_interest()` 里。
## 理由：事件名按项目规矩只能写在 `core/events.gd`，存成字符串既容易打错、
## 打错了还是**静默失效**（没有任何报错）。逻辑和订阅绑在一起更安全。
##
## 注意：本类不要改成内部类，也不要给数组加自定义类型标注 —— `.tres` 存不了
## （见 ENGINEERING_NOTES 008）。

@export_group("身份")
## 部件标识（代码里用，不要翻译、不要改）
@export var id: String = ""
## 显示名。填**翻译 key**（如 `ui.part.xxx`），三处 locale 要同步
@export var name_key: String = ""
## 图标（格子/仓库里显示）
@export var icon: Texture2D
## 稀有度档位（0 起。具体含义由界面决定）
@export var rarity: int = 0
## 造价 / 消耗（制造用；具体语义由玩法决定）
@export var cost: int = 0
## 属于哪个部位 —— 对应 `WorkshopSlot.id`（如 `hand_l`）。
## 空 = 不限部位（任何部位都能装）。
@export var slot_id: String = ""

@export_group("行为")
## 行为场景（根节点必须是 `PartBehavior` 子类）。
## 运行时由 `PartHost` 实例化 —— 每个部件一份实例，互不共享状态。
@export_file("*.tscn") var behavior_scene: String = ""
