class_name PlanCard
extends Resource

## 方案界面里**一张卡片**的内容：标题 + 正文，都用翻译 key。
##
## 和地图界面的 `MapPlanetInfo` 是同一个套路（标题 key + 正文 key），
## 界面上也是同一个样式（圆角半透明深色卡片）。

## 卡片标题（翻译 key）
@export var title_key: String = ""

## 卡片正文（翻译 key）。长文本会自动折行。
@export var body_key: String = ""
