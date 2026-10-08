class_name PartsCatalog
extends Resource

## **部件总表**：仓库里陈列的所有部件。
##
## 用法：往 `parts` 数组里加一项（一个 `WorkshopPart` 资源），仓库就多一个格子。
## 加部件不需要改任何代码 —— 和 `WorkshopLayout` 是同一套做法。
##
## 为什么单独一个"总表"而不是"遍历目录找所有 .tres"：
##   Godot 里运行时遍历 `res://` 目录在导出后的包里**不可靠**（资源会被打包/改名），
##   而且"目录里有什么就上架什么"会让临时试验的部件也自动进游戏。
##   显式列表 = 上架什么由配置说了算，也方便以后按进度过滤（解锁/未解锁）。

## 部件列表。**必须是普通 `Array`**，不要写 `Array[WorkshopPart]`
## （带类型的数组在 .tres 里解析不了，会导致整个数组被丢掉，见 ENGINEERING_NOTES 008）
@export var parts: Array = []
