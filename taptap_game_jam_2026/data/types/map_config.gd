class_name MapConfig
extends Resource

## 地图界面的配置：**起始是哪张地图**、以及下半竖排哪些信息卡片。
##
## **地图列表不在这个文件里**：一张地图 = 星系配置里的一个天体，
## 列表就是 `GalaxyConfig.bodies`（改 `data/resources/galaxy.tres` 加一颗行星就多一张地图），
## 名称取那个天体的 `name_key`。本文件只决定"进来时先看哪一颗"。
##
## 改 `data/resources/map_config.tres` 即可换起始天体与卡片文案，不用改代码。
## 往 `cards` 数组里加一项就多一张卡片。

## **进入地图时**特写的那颗星球，对应 `GalaxyBody.label`（星系配置里那颗的 label）。
## 进去之后可以用界面上的「< >」切到别的天体。
## 空 = 用 `target_body_index`。
@export var target_body_label: String = ""

## **进入地图时**特写的那颗星球在星系 `bodies` 数组里的下标（0 = 中央恒星）。
## 仅在 `target_body_label` 为空时使用。
@export var target_body_index: int = 1

## 下半部的卡片列表。**必须是普通 `Array`**，不要写 `Array[MapPlanetInfo]`
## （带类型的数组在 .tres 里解析不了，整个数组会被丢掉，见 ENGINEERING_NOTES 008）
@export var cards: Array = []
