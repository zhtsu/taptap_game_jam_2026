class_name Events

## 项目所有事件名的集中管理（配合 CoreSystem.event_bus 使用）。
##
## 负载（payload）语义（下面这套规则已在引擎里实测过，不要靠推理）：
##   `push_event(name, payload)` 的 payload **就是订阅者的参数表**（内部走 callv）：
##     非数组     → 自动包成单元素参数表 → 订阅者收到 1 个参数（该对象本身）
##     单元素数组 → 订阅者收到 1 个参数：数组里那个元素本身（**不是**嵌套数组）
##     多元素数组 → 按位置展开成 N 个参数
##     空数组 []  → 0 个参数
##   因此"想传一个数组作为单个参数"就直接传该数组（`push_event(N, items)`），
##   **不要**再包一层（`[[items]]` 会让订阅者收到嵌套数组）。

## 事件没有返回值 → 一律"请求事件 + 结果事件"配对，结果里 MUST 处理 ok == false。

# ===== UI 事件 =====
const OPEN_UI: String =     "open_ui"
const CLOSE_UI: String =    "close_ui"

# ===== 游戏流程事件 =====
## **选定要打哪一关**（payload: 关卡场景路径 String）。
## 由 ui/map/map.gd 的「下一步」发出，由 core/game_flow.gd 记下来（`_selected_level`）。
## 之后制造界面点「开始」时发 `START_GAME`（路径留空 = 打刚才选的那一关）。
## 为什么要多一个事件：地图只负责"选"、制造只负责"装配完开打"，
## 两边都不持有对方的引用，这一层流程状态由流程层（GameFlow）持有。
const SELECT_LEVEL: String =     "select_level"
## 开始游戏（payload: 关卡场景路径 String，取值来自 core/paths.gd；
## **空字符串 = 打 `SELECT_LEVEL` 选定的那一关**）。
const START_GAME: String =       "start_game"
## 标题屏被玩家确认（点击 / 触摸 / 按键，无 payload）。
## 由 ui/title_screen/title_screen.gd 发出，core/game_flow.gd 收到后换成主菜单。
const TITLE_CONFIRMED: String =  "title_confirmed"
## 请求打开主菜单（无 payload）。给"设置"这类需要在关闭自己的同时回到主菜单的界面用。
## 为什么不让界面自己先 OPEN 再 CLOSE：两个事件都是异步派发，顺序不保证；
## 统一交给 core/game_flow.gd 按固定顺序先关后开（这样"同层只有一个界面"的假设才成立）。
const OPEN_MAIN_MENU: String =   "open_main_menu"
## 回到标题界面（无 payload）
const RETURN_TO_TITLE: String =  "return_to_title"
## 暂停 / 恢复切换（无 payload）。暂停状态的唯一权威是 core/game_flow.gd：
## 暂停界面上的按钮也发这个事件，而不是自己去改 get_tree().paused
const PAUSE_TOGGLE: String =     "pause_toggle"

# ===== 存档事件 =====
## 请求存档（payload: Types.SaveRequest）
const SAVE_REQUEST: String =        "save_request"
## 请求读档（payload: Types.LoadRequest）
const LOAD_REQUEST: String =        "load_request"
## 请求删除存档（payload: Types.DeleteSaveRequest）
const DELETE_SAVE_REQUEST: String = "delete_save_request"
## 请求存档列表，无 payload
const SAVE_LIST_REQUEST: String =   "save_list_request"
## 存档结束（payload: Types.SaveResult）
const SAVE_FINISHED: String =       "save_finished"
## 读档结束（payload: Types.SaveResult）
const LOAD_FINISHED: String =       "load_finished"
## 删档结束（payload: Types.SaveResult）
const DELETE_SAVE_FINISHED: String = "delete_save_finished"
## 存档列表就绪（payload: Array[Dictionary]，注意载荷是数组，订阅时收一个参数）
const SAVE_LIST_READY: String =     "save_list_ready"

# ===== 部件钩子：感知事件（"状态改变"成对上报）=====
#
# 设计约定见 data/types/part_behavior.gd：
#   **业务方只上报"状态改变"（进入 / 离开），不在状态持续期间反复发事件。**
#   需要"持续作用"的部件订阅 ENTERED 后自己进入 tick 模式，订阅 EXITED 后退出
#   （由 data/types/part_host.gd 每帧驱动 on_tick）。
#   这样事件量只跟"状态变化次数"有关，不跟帧率有关。
#
# payload 一律是 Dictionary：`push_event(N, {"distance": 3.0})`
# → 订阅者收到 **1 个参数**（那个字典本身）。**不要**传数组，数组会被当成参数表展开。

## 前方出现障碍（payload: Dictionary，键名由感知方定义，例如 {"distance": float}）
const OBSTACLE_AHEAD_ENTERED: String = "obstacle_ahead_entered"
## 前方障碍消失（无 payload，或 {}）
const OBSTACLE_AHEAD_EXITED: String =  "obstacle_ahead_exited"
## 左侧出现敌人（payload: Dictionary）
const ENEMY_LEFT_ENTERED: String =     "enemy_left_entered"
## 左侧敌人消失
const ENEMY_LEFT_EXITED: String =      "enemy_left_exited"
## 右侧出现敌人（payload: Dictionary）—— 与 `ENEMY_LEFT_*` 对称
const ENEMY_RIGHT_ENTERED: String =    "enemy_right_entered"
## 右侧敌人消失
const ENEMY_RIGHT_EXITED: String =     "enemy_right_exited"

# ===== 部件 → 玩法的**命令**事件 =====
#
# 方向与上面那组相反：上面是"玩法上报状态给部件"，这一条是"部件下令给玩法"。
# 部件**不持有世界引用**（见 data/types/part_behavior.gd 的约定 3），要动世界只能发事件；
# 执行的权威在玩法侧 —— 关卡会做范围校验，非法值忽略并告警（而不是照着执行）。
#
# payload: int 目标车道下标（0 = 最左）。**不要**改成方向（左/右）：
# "去哪条道"是决策，决策归部件；"能不能去"是规则，规则归玩法。
const LANE_MOVE_REQUEST: String = "lane_move_request"

# ===== 星系镜头控制（地图界面用）=====
#
# 地图界面是全屏 UI，3D 星系在主菜单里（共用同一份，见 ui/map/map.gd 的说明）。
# 两边不互相持有引用，只通过这些事件通信 —— 地图界面因此不依赖星系节点的位置。
#
# payload 一律**单个 int**：`push_event(N, 3)` → 订阅者收到 1 个参数（下标本身）。

## 请求把镜头漫游到某一颗天体的特写，并隐藏其它天体与轨道（payload: int 下标）
const GALAXY_FOCUS: String = "galaxy_focus"
## 请求退出特写：恢复所有天体与轨道的显隐、镜头归位（无 payload）
const GALAXY_RESET: String = "galaxy_reset"