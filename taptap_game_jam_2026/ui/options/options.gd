extends Control

## 设置界面：**改动即存**，而且**只有两样设置：语言 + 三路音量**。
##
## 下拉框 / 音量滑块任何一处改动，都会立刻发 `Events.SAVE_REQUEST` 写进设置档
## （槽位 `OptionsSave.SLOT`）；SaveService 写完会立即把设置应用到引擎（音量 / 语言），
## 所以"界面显示 = 实际生效"。没有 Apply / Cancel 这层缓冲。
##
## 音量滑块是**分档**的（档位定义在 `OptionsData.VOLUME_STEPS`，当前 0~10、每档 1）：
## 滑块自带 step 吸附，脚本里还按档位去重 —— 只有"档位真的变了"才写档，
## 同一档内的拖动不会反复落盘。
##
## **历史**：分辨率与按键重映射两行已于 2026-10-07 按人类要求删除。
## 删设置项时**连存档字段（`OptionsSave`）与"应用到引擎"（`OptionsApplier`）一起删**，
## 并提升存档版本 + 写迁移 —— 只删界面会留下"改不了、却还在启动时生效"的隐形设置
## （见 ENGINEERING_NOTES 028）。
##
## 节点引用一律用「场景唯一名」`%Name` 或按名字 `find_child`（名字表在 OptionsData 里），
## 不写长节点路径；滑块信号用 .tscn 的 `[connection]` 连。

## 下拉候选列表的字号（跟按钮文字一样大；PopupMenu 不继承按钮的 theme override）
const POPUP_FONT_SIZE: int = 44

@onready var _language_option: OptionButton = %LanguageOption

## 音量：字段名 → 滑块 / 显示档位的标签
var _volume_sliders: Dictionary = {}
var _volume_labels: Dictionary = {}
## 字段名 → 已经写进存档的档位（用来"只在档位变化时保存"）
var _saved_steps: Dictionary = {}


func _ready() -> void:
	_collect_volume_widgets()
	_fill_options()
	# 弹出的候选列表是引擎内部建的 PopupMenu，字号得单独设 ——
	# 不设的话按钮上是 44 的大字、展开的列表却是默认小字
	_language_option.get_popup().add_theme_font_size_override("font_size", POPUP_FONT_SIZE)
	# 只连一次：_fill_options() 在翻译变化时还会被调用，连在这里就不会重复连接
	_language_option.item_selected.connect(_on_language_selected)


## 切语言后 Godot 会发这个通知：重填一遍下拉框。
## _fill_options 读的是内存里的当前值，所以不会丢掉用户刚改的设置。
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _language_option != null:
		_fill_options()


## 返回：发 CLOSE_UI 事件交给 UiRoot 关闭自己
## （UiRoot 按路径记账，所以这里传打开时用的同一个路径 Paths.UI_OPTIONS）
func _on_back_pressed() -> void:
	CoreSystem.event_bus.push_event(Events.CLOSE_UI, Paths.UI_OPTIONS)


#region 改动 → 立刻写进设置档

func _on_language_selected(_index: int) -> void:
	var options: OptionsSave = SaveData.current.options if SaveData.current else null
	if options == null:
		return
	# metadata 的类型由 OptionsData 决定（语言是 locale 字符串），与字段类型一致
	options.language = _language_option.get_selected_metadata()
	_save_options()


func _on_master_volume_changed(value: float) -> void:
	_set_volume("master_volume", value)


func _on_music_volume_changed(value: float) -> void:
	_set_volume("music_volume", value)


func _on_sfx_volume_changed(value: float) -> void:
	_set_volume("sfx_volume", value)


## 音量滑块回调：value 就是档位（滑块 step 已吸附）。
## **只有档位变化才写档** —— 同一档内的拖动只刷新显示，不落盘。
func _set_volume(field: String, step_value: float) -> void:
	var step: int = int(round(step_value))
	_update_volume_label(field, step)

	if int(_saved_steps.get(field, -1)) == step:
		return

	var options: OptionsSave = SaveData.current.options if SaveData.current else null
	if options == null:
		return
	options.set(field, OptionsData.step_to_volume(step))
	_saved_steps[field] = step
	_save_options()


## 把当前内存里的设置写进设置档。
## 写盘成功后 SaveService 会立即应用（音量 / 语言），所以调用方不需要自己再去碰引擎状态。
func _save_options() -> void:
	var request: Types.SaveRequest = Types.SaveRequest.new()
	request.slot = OptionsSave.SLOT
	request.reason = "options"
	CoreSystem.event_bus.push_event(Events.SAVE_REQUEST, request)

#endregion


#region 填充

## 按 OptionsData 的候选值填充语言下拉框，并把三路音量回填成内存里的当前档位
func _fill_options() -> void:
	var saved: OptionsSave = SaveData.current.options if SaveData.current else null

	# 语言：metadata 存 locale 代码
	_language_option.clear()
	for index in OptionsData.LANGUAGES.size():
		var language: Dictionary = OptionsData.LANGUAGES[index]
		_language_option.add_item(language["name"])
		_language_option.set_item_metadata(index, language["locale"])
	if _language_option.item_count > 0:
		_language_option.select(0)
	if saved and not _select_by_metadata(_language_option, saved.language):
		# 存档里的语言不在候选表里（旧档 / 手改过）：补一条进去，
		# 这样界面显示的是真实值，下次改动也不会被兜底值悄悄覆盖
		_add_item_with_metadata(_language_option, saved.language, saved.language)

	# 音量：把内存里的线性值换算成档位回填。
	# set_value_no_signal：否则会触发 value_changed → 反过来又写一次档
	if saved != null:
		for entry in OptionsData.VOLUME_WIDGETS:
			var field: String = entry["field"]
			var slider: HSlider = _volume_sliders.get(field)
			if slider == null:
				continue
			var step: int = OptionsData.volume_to_step(float(saved.get(field)))
			slider.set_value_no_signal(float(step))
			_saved_steps[field] = step
			_update_volume_label(field, step)

#endregion


#region 小工具

## 按 OptionsData.VOLUME_WIDGETS 收集三路音量的滑块与数值标签
func _collect_volume_widgets() -> void:
	for entry in OptionsData.VOLUME_WIDGETS:
		var field: String = entry["field"]
		var slider: HSlider = find_child(entry["slider"], true, false) as HSlider
		var label: Label = find_child(entry["value_label"], true, false) as Label
		if slider == null or label == null:
			push_warning("[Options] 音量控件缺失：%s" % str(entry))
			continue
		_volume_sliders[field] = slider
		_volume_labels[field] = label


## 刷新某一路音量旁边显示的档位数字
func _update_volume_label(field: String, step: int) -> void:
	var label: Label = _volume_labels.get(field)
	if label != null:
		label.text = str(step)


## 补一条候选项并选中（用于"存档里的值不在候选表里"的情况）
func _add_item_with_metadata(option: OptionButton, text: String, value: Variant) -> void:
	option.add_item(text)
	option.set_item_metadata(option.item_count - 1, value)
	option.select(option.item_count - 1)


## 找出 metadata == value 的那一项并选中；返回是否找到
## （程序调用 select 不会触发 item_selected，所以填充时不会反过来触发写档）
func _select_by_metadata(option: OptionButton, value: Variant) -> bool:
	for index in option.item_count:
		if option.get_item_metadata(index) == value:
			option.select(index)
			return true
	return false

#endregion
