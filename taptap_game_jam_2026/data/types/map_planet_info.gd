class_name MapPlanetInfo
extends Resource

## **一张星球信息卡片**的配置（地图界面下半竖排的那些卡片）。
##
## 一个星球可以配多张卡片（比如"环境"一张、"资源"一张），界面按顺序竖排。
##
## 注意：本类不要改成内部类，也不要给数组加自定义类型标注 —— `.tres` 存不了
## （见 ENGINEERING_NOTES 008）。

@export_group("卡片")
## 卡片标题。填**翻译 key**（如 `ui.map.card.env`），三处 locale 要同步
@export var title_key: String = ""
## 卡片正文。填**翻译 key**
@export var body_key: String = ""

@export_group("所属星球")
## 这张卡片属于哪个星球 —— 对应 `GalaxyBody.label`（星系配置里那颗的 label）
@export var body_label: String = ""
## 该星球在星系 `bodies` 数组里的下标（0 = 中央恒星）。
## 和 `body_label` 二选一即可，填了 body_label 就优先按 label 找。
@export var body_index: int = -1
