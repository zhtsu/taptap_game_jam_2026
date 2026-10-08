class_name Paths

## 项目所有资源路径的集中管理。
## 所有脚本都应从这里引用路径，禁止散落硬编码的 "res://..." 字符串。

# ===== UI 场景 =====
const UI_TITLE_SCREEN: String = "res://ui/title_screen/title_screen.tscn"
const UI_MAIN_MENU: String =   "res://ui/main_menu/main_menu.tscn"
const UI_OPTIONS: String =     "res://ui/options/options.tscn"
const UI_PAUSE_MENU: String =  "res://ui/pause_menu/pause_menu.tscn"
const UI_CREDITS: String =     "res://ui/credits/credits.tscn"
const UI_WORKSHOP: String =    "res://ui/workshop/workshop.tscn"
## 方案界面（原「制造」界面里的方案页，2026-10-07 独立成屏）—— 从主菜单的「方案」按钮打开
const UI_PLAN: String =        "res://ui/plan/plan.tscn"
## 方案界面的配置（竖直排下来的所有方案卡片）—— 往数组里加一项就多一张卡片
const PLAN_CONFIG: String =    "res://data/resources/plan_config.tres"
## 图鉴界面（已解锁的部件总览；**显示名「图鉴」**，代码里叫 warehouse）—— 从主菜单的「图鉴」按钮打开
const UI_WAREHOUSE: String =   "res://ui/warehouse/warehouse.tscn"
## 地图界面（全屏、背景透明 + 星球特写 + 信息卡片）
## —— **当前没有入口**：主菜单上的「地图」按钮已按人类要求移除（2026-10-07），
## 场景与配置都保留着，等接进流程（比如「开始」后面的关卡选择）。
const UI_MAP: String =         "res://ui/map/map.tscn"
## 制造界面里的部件槽（放进 4x4 网格的 12 个格子里，可点击）
const UI_WORKSHOP_SLOT: String = "res://ui/workshop/slot.tscn"
## 制造界面「制作」页的槽位布局（哪一格放哪个部位）—— 改这个文件即可换部位/加减槽
const WORKSHOP_LAYOUT: String = "res://data/resources/workshop_layout.tres"
## 部件总表（图鉴里陈列的所有部件）—— 往数组里加一项即可多一个部件
const PARTS_CATALOG: String = "res://data/resources/parts_catalog.tres"
## 地图界面的配置（特写哪颗星球 + 下半排哪些信息卡片）
const MAP_CONFIG: String = "res://data/resources/map_config.tres"
## 主菜单背景的 3D 星系（星空 shader + 环上的星球）
const UI_GALAXY: String =      "res://ui/galaxy/galaxy.tscn"
## 星系的全部可调数据（天体表 / 布局 / 相机 / 光照 / 星空）—— 改这个文件即可自定义星系
const GALAXY_CONFIG: String =  "res://data/resources/galaxy.tres"
## 星空的 sky shader
const GALAXY_STARFIELD: String = "res://ui/galaxy/starfield.gdshader"

# ===== 关卡场景 =====
## 关卡（3D 三车道躲车：相机 45° 俯视、纵向滚动）。
## 玩家**不能操作** —— 角色靠身上装的部件自己躲（感知事件 → 部件发 `LANE_MOVE_REQUEST`）。
const GAME_ROAD_LEVEL: String = "res://game/road/road_level.tscn"
## 关卡里的跑者（兽人**占位模型** + 换道；等装配好的兽人接进来再换）
const GAME_ROAD_RUNNER: String = "res://game/road/runner.tscn"
## 关卡里的障碍车（纯数据 + 外观，位置由关卡统一推进）
const GAME_ROAD_CAR: String = "res://game/road/car.tscn"

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