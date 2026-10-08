class_name OptionsSave
extends SaveSection

## 设置界面里选中的项。候选列表（能选哪些）在 `core/options_data.gd`，这里只存"选了哪个"。
##
## **只有语言 + 三路音量**（分辨率 / 按键重映射已于 2026-10-07 按人类要求删除，
## 详见 ENGINEERING_NOTES 028 —— 删设置项时必须连字段和 `OptionsApplier` 里的应用逻辑一起删，
## 不然会出现"界面上改不了、启动时却还在悄悄生效"的隐形设置）。

## 这些设置单独占一个存档槽位，不和游戏进度混在一起
const SLOT: String = "options"

## 语言兜底值。与 project.godot 的 `internationalization/locale/fallback`（zh_CN）保持一致 ——
## 两处不一致时，"存档值非法 → 回退" 与 "翻译缺 key → fallback" 会落到不同语言，界面上看起来像 bug。
const DEFAULT_LANGUAGE: String = "zh_CN"

## 音量兜底值（线性 0.0~1.0）。三条总线的布局见工程根的 default_bus_layout.tres。
const DEFAULT_VOLUME: float = 1.0
## 音量字段 → 音频总线名（options_applier 用它把设置喂给 AudioServer）
const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"

## 选中的语言代码，对应 locale/*.po（如 "en" / "zh_CN"）
var language: String = DEFAULT_LANGUAGE
## 音量（线性 0.0 ~ 1.0，不是分贝）
var master_volume: float = DEFAULT_VOLUME
var music_volume: float = DEFAULT_VOLUME
var sfx_volume: float = DEFAULT_VOLUME


## 自检：语言必须在支持列表里；三路音量必须落在候选档位上。
## 存档被改坏 / 候选表被改过时，这里会把非法值改回默认，避免把垃圾值喂给引擎。
func validate() -> void:
	if not _is_supported_language(language):
		push_warning("[OptionsSave] 语言 '%s' 不受支持，改回默认 '%s'" % [language, DEFAULT_LANGUAGE])
		language = DEFAULT_LANGUAGE

	# 音量必须落在候选档位上（OptionsData.VOLUME_STEPS）：越界值先夹到 0~1，非档位值吸附到最近档
	master_volume = _snap_volume_to_step(master_volume, "master_volume")
	music_volume = _snap_volume_to_step(music_volume, "music_volume")
	sfx_volume = _snap_volume_to_step(sfx_volume, "sfx_volume")


## 把音量吸附到最近的候选档位；值不是档位时告警 —— 静默改值会让人以为"设置没生效"
func _snap_volume_to_step(value: float, field: String) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	var step: int = OptionsData.volume_to_step(clamped)
	# 变量别叫 snapped：那是内置函数名，会触发 SHADOWED_GLOBAL_IDENTIFIER
	var snapped_volume: float = OptionsData.step_to_volume(step)
	if not is_equal_approx(snapped_volume, clamped):
		push_warning("[OptionsSave] 音量字段 '%s' 的值 %.3f 不是候选档位，已吸附到 %d 档（%.2f）"
			% [field, value, step, snapped_volume])
	return snapped_volume


func _is_supported_language(locale: String) -> bool:
	for entry in OptionsData.LANGUAGES:
		if str(entry.get("locale", "")) == locale:
			return true
	return false
