class_name OptionsData

## 设置界面（Options）的可配置数据。
## **现在的设置项只有两样：语言 + 三路音量**（分辨率 / 按键重映射在 2026-10-07 按人类要求删掉了，
## 见 ENGINEERING_NOTES 028：删设置项要连存档字段与"应用"逻辑一起删，否则会变成
## "界面上改不了、启动时却还在悄悄生效"）。

## 语言下拉框的候选值。
## locale 是 TranslationServer 用的语言代码（对应 locale/*.po），name 是下拉框里显示的文字。
## name 用**语言自己的母语名**，不翻译（这是唯一允许写原文的地方）。
const LANGUAGES: Array[Dictionary] = [
	{"locale": "en", "name": "English"},
	{"locale": "zh_CN", "name": "简体中文"},
]

## 音量档位：滑块只允许落在这些档上（界面显示的就是档位数字）。
## 0 = 静音，VOLUME_MAX_STEP = 原始音量；每档对应 level/VOLUME_MAX_STEP 的线性音量。
## 当前是 0~10、每档间距 1。想换成不均匀档位（例如只允许 0/2/4/6/8/10）只改这一个数组，
## 界面吸附与载入自检都会跟着变。
const VOLUME_STEPS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
## 最大档位（= 线性音量 1.0）
const VOLUME_MAX_STEP: int = 10


## 档位 → 线性音量（0.0 ~ 1.0），喂给 AudioServer / 存进存档用
static func step_to_volume(step: int) -> float:
	return clampf(float(step) / float(VOLUME_MAX_STEP), 0.0, 1.0)


## 线性音量 → 最接近的档位（用于把存档里的"非档位值"吸附掉、以及界面回填）
static func volume_to_step(volume: float) -> int:
	var clamped: float = clampf(volume, 0.0, 1.0)
	var best_step: int = VOLUME_STEPS[0]
	var best_diff: float = absf(step_to_volume(best_step) - clamped)
	for step in VOLUME_STEPS:
		var diff: float = absf(step_to_volume(step) - clamped)
		if diff < best_diff:
			best_diff = diff
			best_step = step
	return best_step


## 音量那三行的界面结构：字段名 + 滑块节点名 + 显示档位的标签节点名。
## 界面按名字 find_child 拿节点（避免长节点路径）；要加一路音量就在这里加一行。
const VOLUME_WIDGETS: Array[Dictionary] = [
	{"field": "master_volume", "slider": "MasterSlider", "value_label": "MasterVolumeValue"},
	{"field": "music_volume", "slider": "MusicSlider", "value_label": "MusicVolumeValue"},
	{"field": "sfx_volume", "slider": "SfxSlider", "value_label": "SfxVolumeValue"},
]
