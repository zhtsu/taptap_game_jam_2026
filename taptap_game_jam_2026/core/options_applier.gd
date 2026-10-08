extends RefCounted

## 把设置**应用到引擎**（纯函数式：不持状态、不订阅事件、不读存档、不认识事件 / 结果类型）。
##
## 约束：
##   - 只做"内存值 → 引擎状态"这一步；"什么时候应用"由 core/save_service.gd 决定
##   - **不加 class_name**：由 core/save_service.gd 经 Paths.SCRIPT_OPTIONS_APPLIER 用 preload 引用
##   - 设置项以后增加时改这里，调用方不需要动
##
## 项目特有的部分就是这里；core/ 的其它地方 SHOULD NOT 直接调 DisplayServer / TranslationServer。
##
## **只管两样：语言 + 三路音量**。分辨率与按键重映射已于 2026-10-07 删除
## （见 ENGINEERING_NOTES 028：删设置项必须连"应用"这一步一起删，否则会留下隐形设置）。

## 应用设置：音量 + 语言
static func apply(options: OptionsSave) -> void:
	if options == null:
		return

	# 音量（三条总线都在工程根的 default_bus_layout.tres 里定义）
	_apply_bus_volume(OptionsSave.BUS_MASTER, options.master_volume)
	_apply_bus_volume(OptionsSave.BUS_MUSIC, options.music_volume)
	_apply_bus_volume(OptionsSave.BUS_SFX, options.sfx_volume)

	# 语言
	if TranslationServer.get_locale() != options.language:
		TranslationServer.set_locale(options.language)


## 线性音量 0.0~1.0 → 总线分贝。0.0 直接给 -80dB（等价静音；linear_to_db(0) 是 -inf，不能直接喂）。
static func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_warning("[OptionsApplier] 音频总线 '%s' 不存在，跳过音量应用（检查 default_bus_layout.tres）" % bus_name)
		return

	var clamped: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(clamped) if clamped > 0.0 else -80.0)
