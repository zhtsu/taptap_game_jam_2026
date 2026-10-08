extends Node2D

## 关卡：**2D 三车道躲车**（俯视、纵向滚动 —— 从上往下滚，没有透视）。
##
## ① 世界怎么滚
##   跑者**恒在 y = 场景里摆的位置**（屏幕下方），车道虚线和车从 **+y 方向往下滚过来**
##   （`_scroll_track()` 每帧 `position.y += speed * delta`）。不连续的东西（车道虚线、
##   护栏反光条）滚过 `WRAP_NEAR` 就减一个 `WRAP_LENGTH` 回绕；**路面/护栏是连续的，不动**。
##   回绕长度必须是虚线间距 / 反光条间距的公倍数，否则接缝看得出来（`_check_wrap_is_seamless`）。
##
## ② 谁在开车：**玩家不操作**（类似自走棋 —— 角色靠身上的部件自己动）
##   1) 本关卡的**感知**每帧算三条车道的占用，且只在**状态改变**时上报：
##      `OBSTACLE_AHEAD_*`（当前车道前方有车）/ `ENEMY_LEFT_*` / `ENEMY_RIGHT_*`
##      —— 事件名与负载见 core/events.gd，成对上报是部件的设计约定（part_behavior.gd）。
##   2) 装上的部件（`PartBehavior`）收到事件后决定去哪条道，发 `Events.LANE_MOVE_REQUEST`；
##   3) 本关卡**执行**这个命令（范围校验 → 转给跑者）：**规则在玩法侧，决策在部件侧**。
##   所以"这套装配躲不躲得开"就是玩法本身 —— 没装会躲的部件，角色就一头撞上去。
##
## ③ 单位约定（**重要**）
##   关卡内部**一切用像素**（位置 / 速度 / 判定）。只在两处换算成米：
##     - 发给部件的事件负载里的 `distance`（部件的日志读起来才是"米"）
##     - HUD 的距离数字
##   换算比例是 `px_per_meter`（默认 100 像素 = 1 米，所以车道 300 像素 = 3 米）。
##
## ④ 装配从哪来
##   `loadout`（部件 id 列表）→ 在部件总表（`Paths.PARTS_CATALOG`）里查 → 每个部件一个 `PartHost`。
##   制造界面那套"每个部位装了什么"还没做（见 AGENTS 已知未完成事项），所以暂时在关卡里配。
##
## ⑤ 撞车之后
##   世界停住 + 弹面板（重新开始 / 返回主菜单）。重开发 `START_GAME(自己的 scene_file_path)`
##   —— 不写 `res://` 字面量（路径规矩），也不依赖 GameFlow 记住"上次是哪一关"。
##
## 节点引用一律走 `%唯一名`（场景里标了 unique_name_in_owner），不用长节点路径 —— 改名只在
## 运行时才报错，`%` 至少能在编辑器里就发现。

# ===== 车道 =====

## 车道数（3 = 经典三车道）
@export var lane_count: int = 3
## 单条车道宽（像素）。**只作为兜底**：正常情况下车道按场景里 `%Road` 的矩形算，
## 所以想改路面宽度直接拖那个节点就行
@export var lane_width_px: float = 300.0
## 起跑在哪条车道（0 = 最左）
@export var start_lane: int = 1

# ===== 速度 / 难度（像素/秒）=====

## 起跑速度
@export var scroll_speed_start_px: float = 1400.0
## 每秒加多少（难度爬升）
@export var scroll_speed_gain_px: float = 35.0
## 速度上限
@export var scroll_speed_max_px: float = 3400.0

# ===== 车 =====

## 出车间隔：起跑时 / 爬满难度后（秒）
@export var car_spawn_interval_start: float = 1.15
@export var car_spawn_interval_min: float = 0.55
## 车自己的迎面速度范围（像素/秒，往 +y 冲）。相对速度 = 滚动速度 + 这个值
@export var car_speed_min_px: float = 400.0
@export var car_speed_max_px: float = 1200.0
## 车在哪儿生成（屏幕上方外面）/ 滚到哪儿回收（屏幕下方外面）
@export var spawn_y: float = -500.0
@export var despawn_y: float = 2700.0
## 难度爬满需要多少秒（出车间隔按这个比例从 start 插值到 min）
@export var difficulty_ramp_seconds: float = 60.0

# ===== 感知 / 判定 =====

## 感知范围（像素）：车头到跑者小于这个距离才算"感知到"。
## 1600 像素 ≈ 16 米，比"屏幕顶端到跑者"的距离（约 1900）稍短 ——
## 这样部件决定换道时那辆车**已经看得见**，不会出现"角色凭空变道"。
@export var sense_range_px: float = 1600.0
## 撞车判定容差（像素）：车身半长 / 半宽再加这么多
@export var hit_y_tolerance: float = 40.0
@export var hit_x_tolerance: float = 30.0
## 1 米 = 多少像素（**只用于把距离换算成米**：事件负载 + HUD）
@export var px_per_meter: float = 100.0

# ===== 装配 =====

## 要装的部件 id（在部件总表里查）。**空 = 什么都不装 → 角色不会躲，会一头撞上去**
@export var loadout: Array[String] = ["dodge_brain"]

# ===== 赛道装饰（几何，纯外观；改这些要连着看场景里的路面尺寸）=====

## 车道虚线的尺寸（宽 x 长）与间距（像素）
const DASH_SIZE := Vector2(12.0, 200.0)
const DASH_SPACING: float = 400.0
## 护栏反光条的高度与间距（间距更密 → 速度感更强）
const MARKER_HEIGHT: float = 60.0
const MARKER_SPACING: float = 200.0
## 回绕窗口：滚过 WRAP_NEAR（屏幕底部）就减一个 WRAP_LENGTH
const WRAP_NEAR: float = 2400.0
## 回绕总长（必须是 DASH_SPACING 与 MARKER_SPACING 的公倍数，否则接缝会看出来）
const WRAP_LENGTH: float = 2800.0
## 生成时与已有车至少留出的间隔（像素）：保证同一车道不会"叠车" / 生成出躲不掉的墙
const SPAWN_MIN_GAP: float = 700.0
## 起跑时先铺几辆车 + 第一辆的位置 / 间距（像素）
const SEED_CAR_COUNT: int = 5
const SEED_FIRST_Y: float = -600.0
const SEED_SPACING: float = 1500.0

## 车的配色（关卡自己挑 —— 车不认识配色表）
const CAR_COLORS: Array[Color] = [
	Color(0.776471, 0.243137, 0.203922, 1),  # 红
	Color(0.207843, 0.454902, 0.760784, 1),  # 蓝
	Color(0.878431, 0.694118, 0.192157, 1),  # 黄
	Color(0.321569, 0.639216, 0.454902, 1),  # 绿
	Color(0.807843, 0.807843, 0.827451, 1),  # 白
]

## 车道虚线的颜色 / 反光条的颜色
const DASH_COLOR := Color(0.827451, 0.843137, 0.870588, 1)
const MARKER_COLOR := Color(0.839216, 0.854902, 0.882353, 1)

## 左侧 / 右侧的感知事件对（`[进入, 离开]`）—— 两边共用一段逻辑，避免写歪
const SIDE_EVENTS: Dictionary = {
	"left": [Events.ENEMY_LEFT_ENTERED, Events.ENEMY_LEFT_EXITED],
	"right": [Events.ENEMY_RIGHT_ENTERED, Events.ENEMY_RIGHT_EXITED],
}

# ===== 运行时状态 =====

@onready var _road: ColorRect = %Road
@onready var _barrier_left: ColorRect = %BarrierLeft
@onready var _barrier_right: ColorRect = %BarrierRight
@onready var _track: Node2D = %Track
@onready var _cars_root: Node2D = %Cars
@onready var _parts_root: Node2D = %Parts
@onready var _runner: RoadRunner = %Runner
@onready var _distance_label: Label = %DistanceLabel
@onready var _fail_panel: Control = %FailPanel
@onready var _fail_body: Label = %FailBody

## 车速（像素/秒），随 `_elapsed` 爬升
var _speed: float = 0.0
## 关卡已经跑了多久 / 跑了多远（像素）
var _elapsed: float = 0.0
var _distance: float = 0.0
## 出车计时器
var _spawn_timer: float = 0.0
## 已经撞了：世界停住、面板弹出、不再感知
var _failed: bool = false
## 每条车道的中心 x（下标 = 车道号）
var _lane_x: Array[float] = []
## 当前**目标**车道（换道途中就按"已经在新道上"算）
var _target_lane: int = 1
## 场上的车
var _cars: Array[RoadCar] = []
## 上一帧的感知状态（"状态改变才上报"用的）
var _ahead_on: bool = false
var _side_on: Dictionary = {"left": false, "right": false}
## 距离文本上一次显示的值（只在整数变了才重设文本，别每帧都翻译一次）
var _shown_distance: int = -1


func _ready() -> void:
	_build_lane_x()
	_target_lane = clampi(start_lane, 0, lane_count - 1)
	_speed = scroll_speed_start_px
	_check_wrap_is_seamless()
	_build_track()
	# 跑者吸附到目标车道的中心（y 由场景摆好，是"玩家在屏幕上的位置"）
	_runner.position.x = _lane_x[_target_lane]
	_fail_panel.visible = false
	_seed_traffic()
	_equip_loadout()
	CoreSystem.event_bus.subscribe_unique_script(Events.LANE_MOVE_REQUEST, _on_lane_move_request)
	CoreSystem.logger.info("[RoadLevel] 开始：%d 条道，速度 %.0f 像素/秒，装配=%s"
		% [lane_count, _speed, loadout])


func _exit_tree() -> void:
	if CoreSystem == null:
		return
	CoreSystem.event_bus.unsubscribe(Events.LANE_MOVE_REQUEST, _on_lane_move_request)


func _process(delta: float) -> void:
	if _failed:
		return

	_elapsed += delta
	_speed = minf(scroll_speed_start_px + scroll_speed_gain_px * _elapsed, scroll_speed_max_px)
	_distance += _speed * delta

	_scroll_track(delta)
	_move_cars(delta)
	_spawn_cars(delta)
	_move_runner(delta)
	_refresh_distance_label()

	# 顺序：先把世界推到这一帧的位置，再感知、再判定 —— 这样上报的"距离"和撞的是同一帧的画面
	_sense()
	_check_hit()


#region 车道

## 车道中心 x：**按场景里 `%Road` 的矩形算**（想改路面宽度/位置直接拖那个节点）。
## 读不到宽度时（极端情况下锚点还没解析）退回用 `lane_width_px` 配置值，并告警。
func _build_lane_x() -> void:
	var left: float = _road.position.x
	var width: float = _road.size.x
	if width <= 1.0:
		push_warning("[RoadLevel] 路面宽度读出来是 %s，改用 lane_width_px 配置值算车道" % width)
		width = lane_width_px * float(lane_count)
	_lane_x.clear()
	for i in lane_count:
		_lane_x.append(left + width * (float(i) + 0.5) / float(lane_count))


## 跑者朝目标车道平移。**这是 position.x 的唯一写入者**（车/别的都不碰跑者的 x）。
func _move_runner(delta: float) -> void:
	_runner.move_toward_x(_lane_x[_target_lane], delta)


## 部件请求换道（`Events.LANE_MOVE_REQUEST`，payload = 目标车道下标）。
##
## 这里是**规则**所在：越界忽略并告警（不照着执行、也不崩），
## 已经在那条道上是空操作（部件可能重复请求，不该刷日志）。
func _on_lane_move_request(target_lane: int) -> void:
	if _failed:
		return
	if target_lane < 0 or target_lane >= lane_count:
		CoreSystem.logger.warning("[RoadLevel] 忽略换道请求：车道 %d 不存在（共 %d 条）"
			% [target_lane, lane_count])
		return
	if target_lane == _target_lane:
		return
	CoreSystem.logger.info("[RoadLevel] 换道 %d → %d" % [_target_lane, target_lane])
	_target_lane = target_lane
	# 换道后旧的感知结论立刻作废：作废时会补发"离开"事件，
	# 否则部件会拿着上一条车道的旧结论，刚换过去又往回调（左右横跳）。
	_reset_sense_state()


## 把"感知状态"清零，并**补发离开事件**（换道 / 以后其它让结论失效的场合都走这里）。
## 下一帧 `_sense()` 会按新的车道重新上报"进入"。
func _reset_sense_state() -> void:
	if _ahead_on:
		_ahead_on = false
		_push(Events.OBSTACLE_AHEAD_EXITED, {})
	for side in _side_on:
		if _side_on[side]:
			_side_on[side] = false
			_push(SIDE_EVENTS[side][1], {})

#endregion


#region 赛道 / 滚动

## 生成"不连续"的东西：车道虚线 + 护栏反光条。它们会回绕，所以能看出速度。
func _build_track() -> void:
	var left: float = _road.position.x
	var width: float = _road.size.x
	if width <= 1.0:
		width = lane_width_px * float(lane_count)

	# 车道虚线：放在**车道之间**（3 条道 → 2 条虚线）
	var dash_count: int = int(WRAP_LENGTH / DASH_SPACING)
	for i in range(1, lane_count):
		var x: float = left + width * float(i) / float(lane_count)
		for k in dash_count:
			_track.add_child(_make_rect("Dash_%d_%d" % [i, k], DASH_SIZE, DASH_COLOR,
				Vector2(x - DASH_SIZE.x * 0.5, -WRAP_LENGTH * 0.5 + float(k) * DASH_SPACING
					+ DASH_SPACING * 0.5)))

	# 护栏反光条：贴在两条护栏上（两侧各一列）
	var marker_count: int = int(WRAP_LENGTH / MARKER_SPACING)
	for barrier in [_barrier_left, _barrier_right]:
		var size := Vector2(minf(barrier.size.x, 40.0), MARKER_HEIGHT)
		var x: float = barrier.position.x + (barrier.size.x - size.x) * 0.5
		for k in marker_count:
			_track.add_child(_make_rect("%s_Marker_%d" % [barrier.name, k], size, MARKER_COLOR,
				Vector2(x, -WRAP_LENGTH * 0.5 + float(k) * MARKER_SPACING + MARKER_SPACING * 0.5)))


## 造一个赛道装饰件（虚线段 / 反光条）：一个纯色矩形，不是可点的控件
func _make_rect(node_name: String, size: Vector2, color: Color, at: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = at
	return rect


## 赛道装饰件往下滚，滚过 `WRAP_NEAR`（屏幕底）就减一个 `WRAP_LENGTH` 回到上面。
## 路面 / 护栏是连续的，不参与回绕（看不出滚动，也不需要）。
func _scroll_track(delta: float) -> void:
	var step: float = _speed * delta
	for child in _track.get_children():
		var rect := child as ColorRect
		rect.position.y += step
		if rect.position.y > WRAP_NEAR:
			rect.position.y -= WRAP_LENGTH


## 回绕长度不是间距的公倍数时，接缝处会出现一段"双倍空档" —— 这是**静默**的视觉 bug，
## 所以启动时直接断言，别等有人盯着路面看半天。
func _check_wrap_is_seamless() -> void:
	for spacing in [DASH_SPACING, MARKER_SPACING]:
		if absf(fmod(WRAP_LENGTH, spacing)) > 0.001:
			push_warning("[RoadLevel] 回绕长度 %.1f 不是间距 %.1f 的整数倍，路面接缝会看出来"
				% [WRAP_LENGTH, spacing])

#endregion


#region 车

## 到点就出一辆车（间隔随难度从 start 插值到 min）
func _spawn_cars(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var progress: float = clampf(_elapsed / maxf(difficulty_ramp_seconds, 0.001), 0.0, 1.0)
	_spawn_timer = lerpf(car_spawn_interval_start, car_spawn_interval_min, progress)
	_spawn_car()


## 起跑时先铺几辆车（间隔按"生成器出车的疏密"来，形成连续车流）：
## 不然第一辆车要等生成点开到玩家面前，前几秒路面是空的，看起来像关卡没动。
func _seed_traffic() -> void:
	for i in SEED_CAR_COUNT:
		_spawn_car_at(SEED_FIRST_Y - float(i) * SEED_SPACING)


## 在常规生成点出一辆车
func _spawn_car() -> void:
	_spawn_car_at(spawn_y)


## 在指定的 y 上出一辆车（起跑铺车用）。
##
## 两道保险：
##   1) **一行最多一辆车**（跨车道检查，见 `_is_spot_free`）—— 保证任何时刻至少有两条道是空的，
##      不然随机生成会造出"躲不掉的墙"（实测：相邻两条道同时来车，部件无路可走）；
##   2) 位置被占就这次不出（宁可少一辆，也不要叠车）。
func _spawn_car_at(y: float) -> void:
	if not _is_spot_free(y):
		return

	var lane: int = randi() % lane_count
	var packed: PackedScene = load(Paths.GAME_ROAD_CAR) as PackedScene
	if packed == null:
		CoreSystem.logger.error("[RoadLevel] 车场景加载失败：%s" % Paths.GAME_ROAD_CAR)
		return

	var car: RoadCar = packed.instantiate()
	# 顺序不能反：先入树（_ready 解析 % 节点）→ 再 configure（定车道 + 上色）→ 最后放位置
	_cars_root.add_child(car)
	car.configure(lane, CAR_COLORS[randi() % CAR_COLORS.size()])
	car.oncoming_speed_px = randf_range(car_speed_min_px, car_speed_max_px)
	car.position = Vector2(_lane_x[lane], y)
	_cars.append(car)


## `at_y` 这一行有没有车（**横跨所有车道**：一行只允许一辆 —— 见 `_spawn_car_at`）
func _is_spot_free(at_y: float) -> bool:
	for car in _cars:
		if absf(car.position.y - at_y) < SPAWN_MIN_GAP:
			return false
	return true


## 推车：滚动速度 + 车自己的迎面速度。**车自己不动**，只有一个写入者（这里）。
func _move_cars(delta: float) -> void:
	var step: float = _speed * delta
	for car in _cars.duplicate():
		var node := car as RoadCar
		node.position.y += step + node.oncoming_speed_px * delta
		if node.position.y > despawn_y:
			_cars.erase(node)
			_cars_root.remove_child(node)
			node.queue_free()

#endregion


#region 感知（上报状态改变）

## 三条车道的占用情况 → 状态改变时发事件。
## **"当前车道"用的是 `_target_lane`**（换道刚下令就算已经在新道上）：
## 否则换道途中那几帧会反复上报"前方有障碍"，部件会来回抽。
func _sense() -> void:
	var lane: int = _target_lane

	var ahead: float = _nearest_ahead(lane)
	if ahead >= 0.0 and not _ahead_on:
		_ahead_on = true
		_push(Events.OBSTACLE_AHEAD_ENTERED, _payload(ahead, lane))
	elif ahead < 0.0 and _ahead_on:
		_ahead_on = false
		_push(Events.OBSTACLE_AHEAD_EXITED, {})

	_sense_side(lane - 1, "left")
	_sense_side(lane + 1, "right")


## 一侧的感知。那一侧**没有车道**时也当成"没有敌人"（会补一条离开事件，
## 免得部件记着上一帧的"左边有车"，换道后永远不敢往左走）。
func _sense_side(lane_index: int, side: String) -> void:
	var events: Array = SIDE_EVENTS[side]
	var on_now: bool = _side_on[side]

	var distance: float = -1.0
	if lane_index >= 0 and lane_index < lane_count:
		distance = _nearest_ahead(lane_index)

	if distance >= 0.0 and not on_now:
		_side_on[side] = true
		_push(events[0], _payload(distance, lane_index))
	elif distance < 0.0 and on_now:
		_side_on[side] = false
		_push(events[1], {})


## 某条车道上"前方最近的一辆车"的车头到跑者的距离（**像素**）。返回负数 = 这条道前方没有车。
##
## **车尾还在跑者前面（或正压在跑者身上）才算"这条道有车"** —— 不能只判"车头在跑者上方"：
## 车压到身上那几十像素里，部件会以为这条道空了、正好换进来撞上（实测踩过这个坑）。
func _nearest_ahead(lane_index: int) -> float:
	var best: float = -1.0
	for car in _cars:
		if car.lane != lane_index:
			continue
		# 车尾（-y 端）已经跑到跑者下方 → 这辆车跟"前方"无关了
		if car.position.y - car.size_px.y * 0.5 > _runner.position.y + hit_y_tolerance:
			continue
		# 压在跑者身上时距离算 0（仍然算"有车"）
		var gap: float = maxf(0.0, _runner.position.y - (car.position.y + car.size_px.y * 0.5))
		if gap > sense_range_px:
			continue
		if best < 0.0 or gap < best:
			best = gap
	return best


## 感知事件的负载。键名由**上报方**（这里）定义，部件用 `get()` 读（见 part_behavior.gd）。
##   distance    到车头的距离（**米**，由像素换算 —— 部件看到的单位是"米"）
##   lane        本条事件说的是哪条车道（`OBSTACLE_AHEAD_*` 就是自己那条）
##   player_lane 上报时跑者在哪条道 —— 部件要靠它算"往左还是往右"
##   lane_count  一共几条道（部件不认识具体关卡，范围从这儿来）
func _payload(distance_px: float, event_lane: int) -> Dictionary:
	return {
		"distance": distance_px / maxf(px_per_meter, 0.001),
		"lane": event_lane,
		"player_lane": _target_lane,
		"lane_count": lane_count,
	}


## payload 是**字典**（不是数组）→ 订阅者收到 1 个参数（那个字典）。
## 传数组会被当成参数表展开，所以这里绝不能包成 `[{...}]`。
func _push(event_name: String, payload: Dictionary) -> void:
	CoreSystem.event_bus.push_event(event_name, payload)

#endregion


#region 撞车 / 失败

## 撞车判定：车身范围与跑者当前位置（**用真实 x**，所以换道换到一半被撞也算撞）重叠。
func _check_hit() -> void:
	for car in _cars:
		if absf(car.position.y - _runner.position.y) > car.size_px.y * 0.5 + hit_y_tolerance:
			continue
		if absf(car.position.x - _runner.position.x) > car.size_px.x * 0.5 + hit_x_tolerance:
			continue
		_fail(car)
		return


## 撞了：世界停住（`_process` 直接 return）+ 跑者歪倒 + 面板弹出。
## 不自己重开、也不自己回菜单 —— 两个按钮分别发 `START_GAME` / `RETURN_TO_TITLE`，
## 换场景这件事只由 `core/game_flow.gd` 编排。
func _fail(car: RoadCar) -> void:
	if _failed:
		return
	_failed = true
	_runner.crash()
	_fail_body.text = tr("ui.game.fail_body") % int(_distance / maxf(px_per_meter, 0.001))
	_fail_panel.visible = true
	CoreSystem.logger.info("[RoadLevel] 撞车：车道 %d，跑了 %.0f 米"
		% [car.lane, _distance / maxf(px_per_meter, 0.001)])


## 重新开始：用**自己的场景路径**（运行时值，不是 `res://` 字面量）重开这一关
func _on_restart_pressed() -> void:
	CoreSystem.logger.info("[RoadLevel] 重新开始：%s" % scene_file_path)
	CoreSystem.event_bus.push_event(Events.START_GAME, scene_file_path)


## 返回主菜单：交给 GameFlow（它会淡黑 → 释放关卡 → 打开主菜单）
func _on_menu_pressed() -> void:
	CoreSystem.event_bus.push_event(Events.RETURN_TO_TITLE)


## 距离显示（**米**；只在整数变了才重设文本）
func _refresh_distance_label() -> void:
	var shown: int = int(_distance / maxf(px_per_meter, 0.001))
	if shown == _shown_distance:
		return
	_shown_distance = shown
	_distance_label.text = tr("ui.game.distance") % shown

#endregion


#region 装配

## 按 `loadout` 把部件装进 `%Parts`：一个部件一个 `PartHost`（订阅 / 退订都归它）。
func _equip_loadout() -> void:
	if loadout.is_empty():
		CoreSystem.logger.info("[RoadLevel] 没配装配：角色不会自己躲，会一头撞上去")
		return
	var catalog: PartsCatalog = _load_catalog()
	for part_id in loadout:
		var part: WorkshopPart = _find_part(catalog, part_id)
		if part == null:
			CoreSystem.logger.warning("[RoadLevel] 部件总表里没有 '%s'，跳过" % part_id)
			continue
		var host := PartHost.new()
		host.name = "PartHost_%s" % part.id
		# 必须先入树：setup() 里要 add_child 行为节点（@onready 之类要 _ready 才解析）
		_parts_root.add_child(host)
		host.setup(part, part.slot_id)
		CoreSystem.logger.info("[RoadLevel] 装上部件：%s（部位 %s）" % [part.id, part.slot_id])


func _find_part(catalog: PartsCatalog, part_id: String) -> WorkshopPart:
	for p: Variant in catalog.parts:
		if p is WorkshopPart and (p as WorkshopPart).id == part_id:
			return p
	return null


## 读部件总表。缺失或类型不对时返回**空表**（等于没装部件），不造"内置默认部件"
## —— 兜底造出来的部件没有真实行为场景，装上去只会报错。
func _load_catalog() -> PartsCatalog:
	if ResourceLoader.exists(Paths.PARTS_CATALOG):
		var loaded: Resource = load(Paths.PARTS_CATALOG)
		if loaded is PartsCatalog:
			return loaded
		push_warning("[RoadLevel] %s 不是 PartsCatalog" % Paths.PARTS_CATALOG)
	else:
		push_warning("[RoadLevel] 部件总表不存在：%s" % Paths.PARTS_CATALOG)
	return PartsCatalog.new()

#endregion
