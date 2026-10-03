class_name Paths

## 项目所有资源路径的集中管理。
## 所有脚本都应从这里引用路径，禁止散落硬编码的 "res://..." 字符串。

# ===== UI 场景 =====
const UI_TITLE_SCREEN: String = "res://ui/title_screen/title_screen.tscn"
const UI_MAIN_MENU: String =   "res://ui/main_menu/main_menu.tscn"
const UI_OPTIONS: String =     "res://ui/options/options.tscn"
const UI_PAUSE_MENU: String =  "res://ui/pause_menu/pause_menu.tscn"
const UI_CREDITS: String =     "res://ui/credits/credits.tscn"
## 主菜单背景的 3D 星系（星空 shader + 环上的星球）
const UI_GALAXY: String =      "res://ui/galaxy/galaxy.tscn"
## 星系的全部可调数据（天体表 / 布局 / 相机 / 光照 / 星空）—— 改这个文件即可自定义星系
const GALAXY_CONFIG: String =  "res://data/resources/galaxy.tres"
## 星空的 sky shader
const GALAXY_STARFIELD: String = "res://ui/galaxy/starfield.gdshader"

# ===== 关卡场景（模板自带的最小示例；游戏项目在这里换成自己的关卡）=====
const GAME_EXAMPLE_LEVEL: String = "res://game/example_level.tscn"

# ===== 测试场景（test/ 下，不参与游戏流程，只在编辑器里手动跑）=====
const TEST_PLANET_PREVIEW: String = "res://test/planet_preview/planet_preview.tscn"
## 第三方插件 naejimer_3d_planet_generator 的 7 个星球场景，供预览场景实例化。
## 数组顺序 = 预览网格里的摆放顺序（前 4 个一行、后 3 个一行）。
const TEST_PLANET_SCENES: Array[String] = [
	"res://addons/naejimer_3d_planet_generator/scenes/planet_terrestrial.tscn",   # 0 类地（带云层）
	"res://addons/naejimer_3d_planet_generator/scenes/planet_ice.tscn",           # 1 冰（带云层）
	"res://addons/naejimer_3d_planet_generator/scenes/planet_lava.tscn",          # 2 熔岩
	"res://addons/naejimer_3d_planet_generator/scenes/planet_sand.tscn",          # 3 沙
	"res://addons/naejimer_3d_planet_generator/scenes/planet_gaseous.tscn",       # 4 气态
	"res://addons/naejimer_3d_planet_generator/scenes/planet_no_atmosphere.tscn", # 5 无大气
	"res://addons/naejimer_3d_planet_generator/scenes/star.tscn",                 # 6 恒星
]

# ===== 第三方插件星球（按用途命名的别名，给星系配置用）=====
## 插件 naejimer_3d_planet_generator 的 7 个星球场景。
## 星系默认配置（GalaxyConfig.build_default）从这里取路径，避免在 data/ 下散落 res:// 字面量。
const PLANET_TERRESTRIAL: String = "res://addons/naejimer_3d_planet_generator/scenes/planet_terrestrial.tscn"
const PLANET_ICE: String =         "res://addons/naejimer_3d_planet_generator/scenes/planet_ice.tscn"
const PLANET_LAVA: String =        "res://addons/naejimer_3d_planet_generator/scenes/planet_lava.tscn"
const PLANET_SAND: String =        "res://addons/naejimer_3d_planet_generator/scenes/planet_sand.tscn"
const PLANET_GASEOUS: String =     "res://addons/naejimer_3d_planet_generator/scenes/planet_gaseous.tscn"
const PLANET_NO_ATMOSPHERE: String = "res://addons/naejimer_3d_planet_generator/scenes/planet_no_atmosphere.tscn"
const PLANET_STAR: String =        "res://addons/naejimer_3d_planet_generator/scenes/star.tscn"

# ===== 脚本（刻意不加 class_name，用 preload 引用；脚本路径同样只写在本文件里）=====
const SCRIPT_SAVE_STORAGE: String =    "res://core/save_storage.gd"
const SCRIPT_OPTIONS_APPLIER: String = "res://core/options_applier.gd"