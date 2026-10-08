class_name WorkshopSlot
extends Resource

## 车间里的一个**部位槽**定义（纯数据，不含界面逻辑）。
##
## 为什么单独一个类而不是用字典：`.tres` 里字典也能存，但字段名写错会被**静默忽略**
## （见 ENGINEERING_NOTES 008 一类问题）；用 Resource 子类有 `@export` 约束，
## 编辑器里能补全、能校验，也不会因为打错字悄悄丢数据。
##
## 注意：本类**不要**改成内部类或给数组加 `Array[WorkshopSlot]` 标注 ——
## 那两种写法 `.tres` 都存不了（ENGINEERING_NOTES 008）。

## 部位标识（代码里用来判断"这是哪个部位"，不要翻译、不要改）
@export var id: String = ""
## 部位显示名。填**翻译 key**（如 `ui.workshop.slot.head`），三处 locale 要同步
@export var name_key: String = ""
