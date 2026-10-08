class_name PlanSave
extends SaveSection

## 玩家自己保存的「方案」（局外制造里装配好的兽人配置）。
##
## **单独占一个存档文件**（`SLOT` = `plans` → `plans.sav`），和游戏进度、机器级设置都分开：
##   - 方案是**跨局复用**的（换一局游戏方案还在），所以不能跟着某一局的游戏存档跑；
##   - 但它属于玩家数据、不是机器级设置，所以也不塞进 `options.sav`。
## 落盘时写哪些分段由 `core/save_service.gd` 的 `_payload_for()` 决定（一张表管三类文件），
## 列存档时也要把它排除（`GLOBAL_SLOTS`）。

## 方案档的槽位 ID
const SLOT: String = "plans"

## 最多保存多少条方案（超出直接截断并告警 —— 界面是竖排卡片，条数不设上限会拖垮列表）
const MAX_PLANS: int = 50

## 已保存的方案。**数组顺序 = 界面上的显示顺序**（新的放最前面）。
##
## 每条是一份**纯数据字典**，目前只有 `{"name": String}`。
## **装配内容（每个部位装了什么部件）现在还没有数据模型**（`PartHost` 未接），
## 以后往条目里加键时：**MUST** 同时提升 `SaveData.version` 并在 `migrate()` 里写迁移
## （旧档缺键就补默认值，照 v3 → v4 的样子）。
var plans: Array = []


## 自检：丢掉形状不对的条目（存档被改坏 / 手改过），只留下"有名字的字典"。
##
## 注意这里**保留字典里其它键**（只把 name 规整一下），不重建字典 ——
## 以后条目里加了装配内容却忘了改这里时，重建字典会把那些字段静默清掉。
func validate() -> void:
	var cleaned: Array = []
	for i in plans.size():
		var entry: Variant = plans[i]
		if not (entry is Dictionary):
			push_warning("[PlanSave] 第 %d 条方案不是字典（%s），已丢弃" % [i, type_string(typeof(entry))])
			continue

		var entry_dict: Dictionary = entry
		var plan_name: String = str(entry_dict.get("name", "")).strip_edges()
		if plan_name.is_empty():
			push_warning("[PlanSave] 第 %d 条方案没有名字，已丢弃" % i)
			continue

		entry_dict["name"] = plan_name
		cleaned.append(entry_dict)

	if cleaned.size() > MAX_PLANS:
		push_warning("[PlanSave] 方案有 %d 条，超过上限 %d，多余的已丢弃" % [cleaned.size(), MAX_PLANS])
		cleaned.resize(MAX_PLANS)

	if cleaned.size() != plans.size():
		plans = cleaned
