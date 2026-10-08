class_name WorkshopLayout
extends Resource

## 车间「制作」页的**槽位布局**：哪一格放哪个部位。
##
## 为什么做成数据而不是写死在场景里：
##   界面结构（4x4 网格、外圈 12 格）在 `workshop.tscn` 里；**每格代表什么部位**在这里。
##   以后要换部位、加/减槽、调顺序，只改 `data/resources/workshop_layout.tres`，
##   不用动场景、也不用动代码。
##
## 顺序语义：`slots` 按**从左到右、从上到下**依次填进网格的格子。
## 网格是按行铺的（`columns` 个一行），所以数组顺序 = 阅读顺序。
## 【重要】槽位只填**外圈**：数值由 `_build_slots()` 计算 —— 见那里的注释。

## 网格列数
@export var columns: int = 4

## 网格行数。
## **必须单独配**，不能由 `slots.size()` 推 —— 外圈槽数是 `2*(行+列)-4`，不是 `行x列`；
## 4 列 + 12 个槽若按"总数 12"去铺，会摊成 4x3 网格、外圈只剩 10 格（踩过）。
@export var rows: int = 4

## 部位槽列表。**必须是普通 `Array`**，不要写 `Array[WorkshopSlot]`
## （带类型的数组在 .tres 里解析不了，会导致整个数组被丢掉，见 ENGINEERING_NOTES 008）
@export var slots: Array = []
