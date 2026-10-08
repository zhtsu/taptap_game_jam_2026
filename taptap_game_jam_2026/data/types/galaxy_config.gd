class_name GalaxyConfig
extends Resource

## 星系界面的全部可调数据（天体表 / 自动布局 / 相机 / 光照 / 星空）。
##
## 主要编辑的是 `bodies` 数组：往里面加一项、指定场景与参数，运行时自动生成。
## 数组顺序有语义：
##   [0]        = 中央恒星（放在原点，不公转）
##   [1] 及以后  = 其余天体，**由内往外**依次生成，相邻的自动构成一圈
##
## 布局是自动算的（平方根散布，见 layout_* 字段），不用手填半径/角度；
## 想精确摆放某颗时，填它自己的 radius / angle_deg 覆盖即可。
##
## 为什么天体是独立文件（GalaxyBody）而不是这里的内部类：
##   实测 ResourceSaver 无法序列化内部类（存成空的 GDScript 子资源，加载后属性全丢），
##   必须是独立顶层脚本才能被 .tres 正常引用。

@export_group("天体表（数组顺序 = 由内往外）")
## 天体数组。[0] 是中央恒星，其余由内往外生成。
## 加一项 = 多一颗天体；删一项 = 少一颗。
## **注意**：改 bodies[0] 的 scale（恒星大小）会**连带改变所有自动轨道半径** ——
## 最内圈半径以恒星半径为基数（见 layout_base_multiplier），所以缩小恒星会让整个星系收紧。
## 实测：恒星 scale 0.48 → 0.36 时，屏幕上的恒星光晕半径 113.5 → 87.5 px，
## 最外侧行星的屏幕 X 从 1069 收到 1008（原本已贴右边框）。改完记得重新看一遍取景。
@export var bodies: Array = []

@export_group("自动布局")
## 最内圈半径 = 中央恒星半径 x 这个值。恒星越大，内圈自动跟着推远（避免被恒星挡住）
@export var layout_base_multiplier: float = 1.7
## **轨道之间的净空**（世界单位）：相邻两圈的距离 = 上一圈半径 + 上一圈星球半径
## + 本圈星球半径 + 这个净空。
## **默认 0 = 间距完全由星球尺寸决定**（这是推荐值：星球越大，轨道自动让得越开，
## 所以公转到任何角度都不会和邻圈撞在一起）。
## 填正数 = 在尺寸基础上再加固定余量；调大能把星系整体撑开（但外侧可能出框）。
@export var layout_orbit_clearance: float = 0.0
## 旧的"平方根散布"附加项，**默认 0 = 关闭**。
## 保留只为兼容老配置：>0 时会在"按尺寸算出的半径"上再加 `这个值 x sqrt(圈号)`。
@export var layout_orbit_gap: float = 0.0
## 同一条轨道上多颗天体时的错开角度（度）
@export var layout_angle_step: float = 40.0
## 每增加一圈额外错开的角度（度）。用无理数能避免不同圈的天体长期排成一条线
@export var layout_ring_phase_step: float = 137.5

@export_group("相机")
## 相机注视的目标点 X（世界坐标）。让星系在画面上左右移动就改这个
## （语义反直觉：目标往右移 → 星系在画面里往左移）
@export var camera_target_x: float = 0.0
## 相机注视的目标点 Y。**让星系在画面上上下移动就改这个**
## （目标往上移 → 星系在画面里往**下**移。想给下方 UI 让位就让星系偏上 → 填负数）
@export var camera_target_y: float = 0.0
## 相机相对目标的高差（相机 Y = target_y + 这个值）。控制俯视程度，不移动画面位置
@export var camera_position_y: float = 2300.0
## 相机到目标点的距离。**拉近/拉远改这个**
@export var camera_distance: float = 6800.0
## 相机绕 Y 轴的方位角（度）。0 = 正前方，正值绕星系转
@export_range(-360.0, 360.0) var camera_orbit_deg: float = 0.0
## 整体缩放：>1 拉远、<1 拉近
@export_range(0.3, 3.0) var camera_zoom: float = 1.0
## 俯仰角（仰角）：0 = 默认俯视；>0 相机升高（更俯视）；<0 相机降低（视角更平）。
## 非 0 时忽略 camera_position_y。
@export_range(-89.0, 89.0) var camera_pitch_deg: float = 0.0
## 视野角度（越大看到的范围越广）
@export_range(20.0, 110.0) var camera_fov: float = 55.0

## 单颗特写（地图界面用）**进入**时，镜头从当前位置漫游到特写位的时长（秒）。
## **0 = 立即锁定**（默认）：进地图的第一帧镜头就已经在特写位、天体在正中，
## 没有过渡；想恢复"漫游过去"的观感就填 1.2 之类。
## 进入特写的漫游**不走 Tween**（Tween 会和"每帧跟随"抢同一个 `global_position`，
## 见 ENGINEERING_NOTES 016），这里只是插值权重的分母。
## 调用方（地图界面）通过 `Events.GALAXY_FOCUS` 的第二个参数把实际时长传进来，
## 所以这个字段是"进地图"那一档的值。
@export_range(0.0, 20.0) var focus_duration: float = 0.0

## **在地图里切到另一颗天体**（上半屏「< 名称 >」按钮）时的漫游时长（秒）。
## 和 `focus_duration` 分开：进地图要"立刻对上"，切地图要"看得见镜头飞过去"。
@export_range(0.0, 20.0) var switch_duration: float = 1.2

## 单颗特写**退出**（返回主菜单）时，镜头归位的时长（秒）。
## 进入是硬切 / 切换是漫游，退出要"平滑飞回去"。
@export_range(0.0, 20.0) var reset_duration: float = 1.2

## 特写时把天体**在画面上抬高**多少（屏幕高的比例）。0 = 正中，0.15 = 上移 15%。
##
## 做法：相机位置不动（所以**屏幕上大小不变**），只把"看向的点"从天体中心往下挪。
## 往下挪的**世界距离**按 `相机到天体的距离` 换算（见 `_apply_focus_camera`），
## 所以不管天体离多远，抬高的**像素数恒定**（实测 1080x2400 视口下
## 0.10 ≈ 220px、0.15 ≈ 325px、0.20 ≈ 430px；不同天体因镜头俯角不同会差 ±10px）。
##
## 为什么要抬高：地图上半屏留给星球特写、下半屏是切换行 + 三张信息卡片，
## 抬高后星球落在上半屏的空档里，不会贴着下面的内容。
@export_range(0.0, 0.4) var focus_screen_raise: float = 0.20

## 单颗特写时，**相机相对天体的固定偏移长度 = 天体半径 × 这个倍数**（必须 > 1，否则相机进球体里）。
##
## 特写期间相机每帧被摆到"天体 + 这个偏移"处（跟随公转），所以：
##   - 天体永远在画面正中 → 尺寸不受"离轴放大"影响；
##   - 相机到天体的距离恒定 → **屏幕大小只由这个倍数决定**，与天体实际大小无关。
##
## 换算（屏幕直径占屏高比例）：倍数 4.5 → 约 43%；3 → 约 64%；6 → 约 32%。
@export_range(1.2, 20.0) var focus_distance_factor: float = 4.5

@export_group("轨道线")
## 给每条轨道画一条发光圆环
@export var orbit_lines_enabled: bool = true
@export var orbit_line_color: Color = Color(0.35, 0.55, 0.95, 1.0)
## 轨道线宽度（**世界单位**）。注意：屏幕像素宽会随相机距离变化 ——
## 相机拉远后这个值对应的像素宽会变小，太细时线会"一段一段消失"，所以要同步调大。
@export var orbit_line_width: float = 5.0
@export_range(0.0, 2.0) var orbit_line_energy: float = 0.55

@export_group("光照")
## 光从哪个方向照过来
@export var light_direction: Vector3 = Vector3(-0.4, -0.7, -0.55)
@export var light_energy: float = 1.25
## 环境光（保证背光面不死黑）
@export var ambient_color: Color = Color(0.11, 0.12, 0.2)
@export var ambient_energy: float = 0.5

@export_group("星空背景")
## 星空 shader（换掉这个文件即可整体换风格）
@export_file("*.gdshader") var starfield_shader: String = Paths.GALAXY_STARFIELD
## 星点格点密度：越大星越多越密
@export var star_density: float = 130.0
## 出现门槛：越大星越少
@export var star_threshold: float = 0.955
@export var star_brightness: float = 1.35
@export var star_size: float = 0.22
@export var nebula_strength: float = 0.25
@export var nebula_scale: float = 2.4
@export var top_color: Color = Color(0.01, 0.012, 0.035)
@export var bottom_color: Color = Color(0.025, 0.02, 0.05)
@export var nebula_color: Color = Color(0.18, 0.10, 0.30)
@export var star_color: Color = Color(1.0, 0.97, 0.92)


## 建一份默认配置：1 颗中央恒星 + 6 颗行星（**正好对应插件里的 7 个场景**）。
## 用途：新建配置文件、或运行时找不到配置时的兜底。
##
## **必须和 `data/resources/galaxy.tres` 保持一致**：这是兜底路径，
## 这里的星球表如果比配置多/少，缺配置时看到的就是另一个星系（ENGINEERING_NOTES 017）。
##
## scale 的取值依据（插件各场景的**基准半径** → 目标视觉半径）：
##   恒星 1080 → x0.48 ≈518   类地 200 → x0.75 =150   无大气 200 → x0.80 =160
##   熔岩 189 → x0.60 ≈113    沙 196 → x0.70 ≈137    冰 197 → x0.75 ≈148
##   气态 800 → x0.25 =200
## **不要**照抄插件场景里的烘焙 transform（恒星 ×1200、气态 ×800 等），
## 那些是被反向补偿掉的，照抄会让星球尺度差几个数量级（ENGINEERING_NOTES 010）。
static func build_default() -> GalaxyConfig:
	var cfg := GalaxyConfig.new()
	cfg.bodies = [
		_body("恒星", Paths.PLANET_STAR, 0.48, 2.0, 0.0),
		_body("类地", Paths.PLANET_TERRESTRIAL, 0.75, 10.0, 4.0),
		_body("无大气", Paths.PLANET_NO_ATMOSPHERE, 0.8, 14.0, 4.0),
		_body("熔岩", Paths.PLANET_LAVA, 0.6, 12.0, -6.0),
		_body("沙", Paths.PLANET_SAND, 0.7, 8.0, -6.0),
		_body("冰", Paths.PLANET_ICE, 0.75, 9.0, 7.0),
		_body("气态", Paths.PLANET_GASEOUS, 0.25, 7.0, 7.0),
	]
	return cfg


static func _body(label: String, scene: String, scale_value: float, spin: float, orbit: float) -> GalaxyBody:
	var b := GalaxyBody.new()
	b.label = label
	b.scene = scene
	b.scale = scale_value
	b.spin_speed = spin
	b.orbit_speed = orbit
	return b
