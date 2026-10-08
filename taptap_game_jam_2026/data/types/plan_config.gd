class_name PlanConfig
extends Resource

## 方案界面的数据：**竖直排下来的所有方案卡片**。
##
## 往 `cards` 数组里加一项就多一张卡片，不用改代码。
## 界面侧只认"一串卡片"，不关心它们代表什么 —— 所以以后要把"方案"换成别的东西
## （存档槽、出战预设、任务列表…），改文案 key 就够了，结构不用动。
##
## **现状**：里面是**占位文案**（方案内容还没定）。换内容只改
## `data/resources/plan_config.tres` + `locale/` 三处的翻译。

## 卡片列表（顺序 = 界面上的上下顺序）。
## **必须是普通 `Array`**，不要写 `Array[PlanCard]`
## （带类型的数组在 .tres 里解析不了，整个数组会被丢掉，见 ENGINEERING_NOTES 008）
@export var cards: Array = []
