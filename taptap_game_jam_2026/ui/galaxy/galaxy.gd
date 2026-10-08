extends Node3D

## 星系场景：星空背景 + 按数据生成的一圈圈天体。
##
## 数据驱动：天体表在 GalaxyConfig（data/resources/galaxy.tres）里，本脚本不含任何
## "有几颗星球 / 每颗多大" 的硬编码。数组顺序携带语义：
##   bodies[0]     = 中央恒星（原点，不公转）
##   bodies[1..]   = 其余天体，由内往外依次生成；相邻的（或 ring_group 相同的）构成一条轨道
##
## 布局公式（想改散布形态就改 layout_* 那几个字段）：
##   第 i 条轨道半径 = 中央恒星半径 x layout_base_multiplier + layout_orbit_gap x sqrt(i)
##   角度 = i x layout_ring_phase_step + 同轨序号 x layout_angle_step
## 天体自己的 radius / angle_deg 非 0 时**覆盖**公式结果（精确摆放的逃生口）。
##
## 本场景自带 Camera3D 与 WorldEnvironment：它会被放进 MainMenu 的 SubViewport 里当背景，
## 那个 SubViewport 有自己的 World3D，不能依赖外部节点。
##
## 刻意不加 `@tool`：`_ready()` 会重建子节点，编辑器里跑会把生成物写进场景文件、越存越乱。

## 插件星球的**基准半径**（场景里网格自身烘焙的尺度），用来把"scale"换算成"实际尺寸"。
## 用途：自动布局要知道中央恒星多大才能把内圈推到它外面；轨道线要知道每颗多宽才能留缺口。
##
## 数值来源：读各 `.tscn` 里 MeshInstance3D 的 `Transform3D` 取基向量长度。
## 例：`planet_no_atmosphere.tscn` 的 `Transform3D(-44.609,0,194.962, 0,200,0, ...)`
## → 基向量长度 = 200 → 基准半径 200（配合配置 scale 0.8 → 实际 160）。
##
## **改动警告**：这份表参与布局计算（`_center_radius()`），改任何一个值都会挪动所有轨道半径。
## 曾经把 no_atmosphere / gaseous 误记成 0.5（真值是 200 / 800），
## 导致配置里的 scale 280/300 把星球放大到世界半径 5.6 万 / 24 万 —— **相机落进球体内部**，
## 球面 CULL_BACK 全被剔除，星球彻底不可见。改 scale 前先核对这张表。
##
## 为什么用 static var 而不是 const 字典：const 字典的 key 必须是常量表达式，
## 而这里的 key 要引用 Paths.PLANET_* （项目规矩：res:// 字面量只能出现在 core/paths.gd）。
## static var 支持用常量表达式初始化，且只在类加载时算一次。
static var PLUGIN_BASE_RADIUS: Dictionary = {
	Paths.PLANET_STAR: 1080.0,          # Transform3D 基向量长度 1200 × 旋转分量 ≈1080
	Paths.PLANET_TERRESTRIAL: 200.0,
	Paths.PLANET_ICE: 197.0,
	Paths.PLANET_SAND: 196.0,
	Paths.PLANET_LAVA: 189.0,
	Paths.PLANET_GASEOUS: 800.0,
	Paths.PLANET_NO_ATMOSPHERE: 200.0,
}
## 查不到基准半径时的兜底值（自定义星球场景也能用，只是自动布局按这个估）
const FALLBACK_BASE_RADIUS: float = 1.0

## 网格基准半径 → **实际可见半径** 的经验比例。## 插件球面被 shader 做顶点位移，可见范围比网格小；实测：类地 150/165≈0.91、
## 冰 148/165≈0.90、沙 137/140≈0.98、熔岩 114/162≈0.70。取偏大的 0.9，
## 宁可让轨道线的缺口宽一点，也不要让线扎进星球里。
const VISIBLE_RADIUS_RATIO: float = 0.9

## 配置文件位置。用运行时 load 而不是 preload：换配置文件只改这一行。
## 文件缺失时退回 GalaxyConfig.build_default()（见 _load_config），不会出现空星系。
@export_file("*.tres") var config_path: String = Paths.GALAXY_CONFIG

var _config: GalaxyConfig = null
## { 公转轴节点: 每秒转多少度 }
var _orbit_speeds: Dictionary = {}
## 需要自转的节点（轨道上的天体 + 中央恒星）
var _spin_targets: Array[Node3D] = []
var _camera: Camera3D = null
## 生成时登记的摆放信息（轨道半径 / 角度 / 估算半径），供"轨道线留缺口"用
var _placed: Array[_Placed] = []
## 轨道节点（与 `_placed` 同下标：`_placed[0]` 是恒星，之后依次对应 `_orbits[0..]`）
var _orbits: Array[Node3D] = []
## 天体 holder 节点（与 `_placed` 同下标，用于"只看某颗"时按颗显隐）
var _holders: Array[Node3D] = []
## 轨道线：`{轨道下标: [该轨道的所有弧段节点]}`。一条轨道可能被切成多段弧，
## 所以按轨道分组存 —— "只看某颗"时要把同一轨道整条一起隐藏/恢复。
var _orbit_lines: Dictionary = {}
## 是否处于"单颗特写"状态（特写期间每帧让相机看向目标）
var _focus_target: Node3D = null
## 特写时"相机相对天体"的偏移（特写期间恒定 --- 相机跟着天体走，屏幕尺寸就固定）
var _focus_offset: Vector3 = Vector3.ZERO
## 进入特写那一刻"相机相对天体"的偏移（漫游的起点；`focus_duration = 0` 时用不到）
var _focus_rel_from: Vector3 = Vector3.ZERO
## 进入特写后过了多少秒（自己数，不用 Tween —— 见 `_apply_focus_camera` 的注释）
var _focus_elapsed: float = 0.0
## 本次特写的漫游时长（秒，0 = 立即锁定）。由调用方给（进地图 0 / 切地图 1.2），
## 不由星系配置决定 —— 同一颗天体在不同时机要不一样的手感。
var _focus_duration: float = 0.0
## 相机归位用的初始参数（进入特写前存下来，退出时恢复）
var _saved_camera: Dictionary = {}
## 相机归位动画（**只用于退出特写**；进入特写不再用 Tween）
var _camera_tween: Tween = null


## 一个天体的摆放信息。运行时用的普通类，不参与序列化
## （ENGINEERING_NOTES 008 说的"内部类不能序列化"只针对存盘 Resource，这里没这问题）。
class _Placed:
	var orbit_radius: float = 0.0
	var angle_rad: float = 0.0
	var est_radius: float = 0.0


## 一条轨道的规划结果（谁在上面、半径多大、这圈最宽的星球多宽）。
class _OrbitPlan:
	var bodies: Array[GalaxyBody] = []
	var radius: float = 0.0
	var max_radius: float = 0.0


func _ready() -> void:
	_config = _load_config()
	_build_all()


## 换配置后重新生成（运行时改完配置想立刻看效果时调）
##
## 这里刻意用 remove_child + free 而**不是 queue_free**：queue_free 是"帧末才真正删除"，
## 同一帧内立刻重建会让新节点和未删的旧节点重名，Godot 会给新节点起匿名名（@Camera3D@7），
## 于是 GetNode("GalaxyCamera") 全部失效。
func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_orbit_speeds.clear()
	_spin_targets.clear()
	_placed.clear()
	_orbits.clear()
	_holders.clear()
	_orbit_lines.clear()
	_focus_target = null
	_camera = null
	_build_all()


func _load_config() -> GalaxyConfig:
	if not config_path.is_empty() and ResourceLoader.exists(config_path):
		var loaded: Resource = load(config_path)
		if loaded is GalaxyConfig:
			return loaded
		push_warning("[Galaxy] %s 不是 GalaxyConfig，改用默认配置" % config_path)
	else:
		push_warning("[Galaxy] 配置不存在：%s，改用默认配置" % config_path)
	return GalaxyConfig.build_default()


func _build_all() -> void:
	_build_environment()
	_build_light()
	_build_camera()
	_build_bodies()
	_update_camera_viewport()


## 天体场景的基准半径（查表；查不到给兜底值并在布局里按兜底算）
func _base_radius(scene_path: String) -> float:
	return float(PLUGIN_BASE_RADIUS.get(scene_path, FALLBACK_BASE_RADIUS))


## 中央恒星的实际半径（世界单位）。自动布局的基准，缺恒星时给个保守值。
func _center_radius() -> float:
	if _config.bodies.is_empty():
		return 400.0
	var star: GalaxyBody = _config.bodies[0]
	if star == null:
		return 400.0
	return _base_radius(star.scene) * star.scale


# --- 环境（星空背景）----------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _config.ambient_color
	env.ambient_light_energy = _config.ambient_energy
	# 星空里的亮星与发光天体加一点泛光
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 0.9

	var sky := Sky.new()
	var sky_mat: ShaderMaterial = null
	if not _config.starfield_shader.is_empty() and ResourceLoader.exists(_config.starfield_shader):
		var shader: Shader = load(_config.starfield_shader)
		if shader != null:
			sky_mat = ShaderMaterial.new()
			sky_mat.shader = shader
	else:
		push_warning("[Galaxy] 星空 shader 找不到：%s，退回程序化天空" % _config.starfield_shader)
	if sky_mat == null:
		var fallback := ProceduralSkyMaterial.new()
		fallback.sky_top_color = _config.top_color
		fallback.sky_horizon_color = _config.bottom_color
		sky.sky_material = fallback
	else:
		sky_mat.set_shader_parameter("top_color", _config.top_color)
		sky_mat.set_shader_parameter("bottom_color", _config.bottom_color)
		sky_mat.set_shader_parameter("star_color", _config.star_color)
		sky_mat.set_shader_parameter("density", _config.star_density)
		sky_mat.set_shader_parameter("brightness", _config.star_brightness)
		sky_mat.set_shader_parameter("star_size", _config.star_size)
		sky_mat.set_shader_parameter("threshold", _config.star_threshold)
		sky_mat.set_shader_parameter("nebula_strength", _config.nebula_strength)
		sky_mat.set_shader_parameter("nebula_scale", _config.nebula_scale)
		sky_mat.set_shader_parameter("nebula_color", _config.nebula_color)
		sky.sky_material = sky_mat

	env.sky = sky
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)


# --- 光照 ---------------------------------------------------------------

func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.name = "SunLight"
	light.light_energy = _config.light_energy
	# 用"从光源指向原点"的方向反推位置：light_direction 的语义是"光从哪边照过来"
	var dir: Vector3 = _config.light_direction.normalized()
	light.position = -dir * 3000.0
	add_child(light)
	# 必须**先入树再 look_at**（look_at 需要有效的 global_transform）
	light.look_at(Vector3.ZERO, Vector3.UP)


# --- 相机 ---------------------------------------------------------------

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "GalaxyCamera"
	_camera.fov = _config.camera_fov
	_camera.near = 1.0
	_camera.far = 40000.0
	# SubViewport 的宽高可能与窗口不同（本场景是竖屏），按高度保持视野不变形
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT

	# 两套模式，位置与朝向永远自洽：
	#   A) pitch = 0：绕目标的方位角环绕 + camera_position_y 的高差，然后 look_at 目标
	#   B) pitch != 0：用仰角算朝向，再从目标点沿该朝向后退 camera_distance
	# 为什么 B 不沿用 A 的位置再手动设 rotation：那样位置和朝向是两套独立数字，
	# 一改俯仰角相机就指到别处（之前踩过：改 pitch 画面全空）。
	var orbit: float = deg_to_rad(_config.camera_orbit_deg)
	var dist: float = maxf(_config.camera_distance, 1.0) * maxf(_config.camera_zoom, 0.01)
	var target := Vector3(_config.camera_target_x, _config.camera_target_y, 0.0)
	if not is_zero_approx(_config.camera_pitch_deg):
		var pitch: float = deg_to_rad(clampf(_config.camera_pitch_deg, -89.0, 89.0))
		var look_dir := Vector3(sin(orbit) * cos(pitch), -sin(pitch), cos(orbit) * cos(pitch))
		_camera.position = target - look_dir * dist
	else:
		_camera.position = target + Vector3(sin(orbit) * dist, 0.0, cos(orbit) * dist) \
			+ Vector3.UP * _config.camera_position_y
	add_child(_camera)
	_camera.look_at(target, Vector3.UP)
	_camera.make_current()


## SubViewport 渲染尺寸变化时刷新投影（否则窗口缩放后画面会被拉扁）
func _update_camera_viewport() -> void:
	if _camera == null:
		return
	var vp: Viewport = get_viewport()
	if vp is SubViewport:
		var sub: SubViewport = vp
		if not sub.size_changed.is_connected(_update_camera_viewport):
			sub.size_changed.connect(_update_camera_viewport)
	_camera.make_current()


# --- 天体与轨道 ---------------------------------------------------------

## 把 bodies 数组变成场景里的天体：
##   [0] 放原点当中央恒星；其余按"圈"分组，逐圈生成并挂到会公转的轴上。
func _build_bodies() -> void:
	if _config.bodies.is_empty():
		push_warning("[Galaxy] bodies 为空，没有任何天体")
		return

	var bodies_root := Node3D.new()
	bodies_root.name = "Bodies"
	add_child(bodies_root)

	# 1) 中央恒星（数组第一项）
	var star_entry: GalaxyBody = _config.bodies[0]
	if star_entry != null and not star_entry.scene.is_empty():
		var star_holder: Node3D = _spawn_body(bodies_root, star_entry, "Center", Vector3.ZERO, star_entry.spin_speed)
		_holders.append(star_holder)
		# 恒星也要登记：它半径大，内侧的轨道线得从它前面绕开
		var star_info := _Placed.new()
		star_info.orbit_radius = 0.0
		star_info.angle_rad = 0.0
		star_info.est_radius = _visible_radius(star_entry)
		_placed.append(star_info)
	else:
		push_warning("[Galaxy] bodies[0] 为空或没填场景，中央恒星缺失")

	# 2) 先说清楚"哪些天体同圈、每圈半径多少"。
	#    半径**按星球尺寸累加**算出来（见 _plan_orbits），这样任何公转角度下
	#    相邻两圈的星球都不会互相叠住 —— 写死间距做不到这点。
	var plans: Array[_OrbitPlan] = _plan_orbits()
	for i in plans.size():
		var orbit := Node3D.new()
		orbit.name = "Orbit%d" % i
		bodies_root.add_child(orbit)
		_orbits.append(orbit)
	for i in plans.size():
		for body: GalaxyBody in plans[i].bodies:
			_add_body_to_orbit(_orbits[i], i, body, plans[i].radius)

	# 3) 轨道线：画在 bodies_root（不公转的父节点）上，避免线跟着转。
	#    半径直接用规划好的值（不依赖自转节点当帧的位置）。
	#    每条线可能被切成多段弧（见 _add_orbit_line），所以按"轨道下标"分组存起来，
	#    这样"只看某一颗"时能把别的轨道整条隐藏。
	for i in plans.size():
		_add_orbit_line(bodies_root, i, plans[i].radius)


## 规划每条轨道：谁在上面、半径多少。
##
## 半径规则：`layout_base_multiplier` 只决定最内圈（相对恒星大小，避免被恒星吞掉）；
## 之后**每一圈的半径 = 上一圈半径 + 上一圈最大半径 + 本圈最大半径 + 净空**。
## 这样"轨道间距"是按星球实际尺寸推出来的，不是常数 ——
## 否则大星球公转到相邻轨道附近就会和另一颗撞在一起（用户反馈 2026-10-04）。
## 天体自己填了 `radius` 的，用它的值并把它当作新的基准（精确摆放的逃生口）。
func _plan_orbits() -> Array[_OrbitPlan]:
	var plans: Array[_OrbitPlan] = []
	var group_of: Dictionary = {}
	var auto_group: int = 0
	for i in range(1, _config.bodies.size()):
		var body: GalaxyBody = _config.bodies[i]
		if body == null or body.scene.is_empty():
			continue
		var g: int = body.ring_group
		if g == 0:
			# 独占一圈：每颗给一个不会撞车的组值（用递减的负数避开手动填的正数）
			auto_group -= 1
			g = auto_group
		var idx: int = int(group_of.get(g, -1))
		if idx < 0:
			idx = plans.size()
			group_of[g] = idx
			plans.append(_OrbitPlan.new())
		plans[idx].bodies.append(body)
		plans[idx].max_radius = maxf(plans[idx].max_radius, _visible_radius(body))

	var star_band: float = 0.0
	if not _config.bodies.is_empty():
		var star: GalaxyBody = _config.bodies[0]
		if star != null and not star.scene.is_empty():
			star_band = _visible_radius(star)
	var clearance: float = maxf(_config.layout_orbit_clearance, 0.0)
	var prev_radius: float = 0.0
	var prev_band: float = star_band
	for i in plans.size():
		var explicit: float = -1.0
		for b: GalaxyBody in plans[i].bodies:
			if b.radius > 0.0:
				explicit = b.radius
				break
		var band: float = maxf(plans[i].max_radius, 1.0)
		if explicit > 0.0:
			plans[i].radius = explicit
		else:
			# 其余圈：上一圈半径 + 上一圈星球半径 + 本圈星球半径 + 净空
			var by_size: float = prev_radius + prev_band + band + clearance
			# 写死的平方根散布（默认 0 = 关闭），只为兼容老配置
			var spread: float = maxf(_config.layout_orbit_gap, 0.0) * sqrt(float(i))
			if i == 0:
				# 最内圈：恒星半径 × 倍数，保证不被恒星吞掉
				var inner: float = star_band * maxf(_config.layout_base_multiplier, 0.0) + band + clearance
				plans[i].radius = maxf(inner, by_size)
			else:
				plans[i].radius = by_size + spread
		prev_radius = plans[i].radius
		prev_band = band
	return plans


## 某个天体的**可见半径**（世界单位）。自动布局与轨道线缺口都用它。
func _visible_radius(body: GalaxyBody) -> float:
	return _base_radius(body.scene) * body.scale * VISIBLE_RADIUS_RATIO


## 按自动布局公式算第 index 条轨道的半径（天体自己填了 radius 就不用这个）
func _auto_orbit_radius(index: int) -> float:
	var base: float = _center_radius() * _config.layout_base_multiplier
	return base + _config.layout_orbit_gap * sqrt(float(index))


## 把天体挂到某条轨道上。半径由 _plan_orbits 算好（**必须传入**：
## 那个值是按各颗星球尺寸累加出来的，不能在这里重新推一遍）。
func _add_body_to_orbit(orbit: Node3D, orbit_index: int, body: GalaxyBody, radius: float) -> void:
	var order_in_ring: int = orbit.get_child_count()
	var angle_deg: float = body.angle_deg
	if is_zero_approx(angle_deg):
		angle_deg = orbit_index * _config.layout_ring_phase_step + order_in_ring * _config.layout_angle_step
	var angle: float = deg_to_rad(angle_deg)
	var pos := Vector3(cos(angle) * radius, body.height, sin(angle) * radius)
	var holder_name: String = "%s_%d" % [body.label if not body.label.is_empty() else "Body", orbit_index]
	var holder: Node3D = _spawn_body(orbit, body, holder_name, pos, body.spin_speed)
	_holders.append(holder)
	# 按天体自己的公转速度决定整圈的转速（同轨多颗时取第一颗的）
	if not _orbit_speeds.has(orbit):
		_orbit_speeds[orbit] = body.orbit_speed
	# 登记摆放信息：轨道线要按"别的星在哪个角度"留缺口
	var info := _Placed.new()
	info.orbit_radius = radius
	info.angle_rad = angle
	info.est_radius = _visible_radius(body)
	_placed.append(info)


## 实例化一个天体到 parent 的 pos 位置，并登记自转。
## 返回 holder 节点（失败时 null）—— 调用方要拿它登记，供"只看某颗"按颗显隐。
func _spawn_body(parent: Node3D, body: GalaxyBody, holder_name: String, pos: Vector3, spin: float) -> Node3D:
	if not ResourceLoader.exists(body.scene):
		push_warning("[Galaxy] 天体场景不存在，已跳过：%s" % body.scene)
		return null
	var packed: PackedScene = load(body.scene) as PackedScene
	if packed == null:
		push_warning("[Galaxy] 天体场景加载失败：%s" % body.scene)
		return null

	var holder := Node3D.new()
	holder.name = holder_name
	holder.position = pos
	holder.scale = Vector3.ONE * body.scale
	parent.add_child(holder)

	var node: Node3D = packed.instantiate() as Node3D
	if node == null:
		push_warning("[Galaxy] 天体场景的根不是 Node3D：%s" % body.scene)
		return null
	node.name = "Model"
	holder.add_child(node)
	holder.set_meta("spin_speed", spin)
	_spin_targets.append(holder)
	return holder


## 轨道线在世界里的宽度（直接用 `orbit_line_width` 的世界单位值）。
##
## **注意**：世界单位换算成屏幕像素是随相机距离变的 —— 相机拉远后 5 世界单位只有约 1 像素宽，
## 细到亚像素时像素格点盖不到就会"一段一段消失"。所以调这个值时要连带看相机距离：
## 拉远相机后要相应调大它。（曾试过把配置值改成"屏幕像素"来彻底解耦，被要求复原。）
func _orbit_line_world_width() -> float:
	return maxf(_config.orbit_line_width, 0.1)


## 画一条轨道线。半径显式传入（**不能从轨道节点反推** —— 轨道会自转，读到的角度是当帧的）。
##
## 画成**弧**而不是整圈，并在**会穿过其它天体的角度处留缺口**：
## 行星自身半径不小，整圈线必然会横穿好几颗别的星（用户反馈 2026-10-04）。
## 判据：某天体自身半径是否覆盖到本线半径（径向相交），是则按它的角宽留缺口。
func _add_orbit_line(parent: Node3D, line_index: int, radius: float) -> void:
	if not _config.orbit_lines_enabled:
		return
	if radius <= 0.0:
		return

	var width: float = _orbit_line_world_width()
	var mat := StandardMaterial3D.new()
	var color: Color = _config.orbit_line_color
	mat.albedo_color = Color(color.r, color.g, color.b, 0.65)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = _config.orbit_line_energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for seg: PackedFloat32Array in _orbit_arcs(radius):
		var line := MeshInstance3D.new()
		line.name = "OrbitLine%d" % line_index
		line.mesh = _make_flat_arc(radius, width, seg[0], seg[1])
		line.material_override = mat
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.position.y = 0.0
		parent.add_child(line)
		# 登记：一条轨道可能有多段弧，"只看某颗"时要把同一轨道的所有段一起隐藏
		if not _orbit_lines.has(line_index):
			_orbit_lines[line_index] = []
		(_orbit_lines[line_index] as Array).append(line)


## 算出某条轨道线上可以画的角度区段（弧度对 [起, 止]）。
## 不相交时返回整圈；相交时把每个"会挡住线的天体"的角度范围挖掉。
func _orbit_arcs(radius: float) -> Array[PackedFloat32Array]:
	# 缺口区间 [起, 止]（弧度，可能超出 [0, TAU]，统一归一化处理）
	var starts: Array[float] = []
	var ends: Array[float] = []
	for p: _Placed in _placed:
		var band: float = p.est_radius
		# 径向是否相交：本线半径落在这颗星的 [R-r, R+r] 内？
		if radius < p.orbit_radius - band or radius > p.orbit_radius + band:
			continue
		# 角宽：自身半径在该轨道半径处张开的角度 + 半个线宽（线自身也有宽度）
		var half: float = asin(clampf(band / maxf(radius, 1.0), 0.0, 1.0))
		half += 0.5 * _orbit_line_world_width() / maxf(radius, 1.0)
		half = clampf(half, 0.02, PI)
		starts.append(p.angle_rad - half)
		ends.append(p.angle_rad + half)
	return _complement_arcs(starts, ends)


## 从整圈 [0, TAU] 里挖掉若干角度区间，返回剩下的弧段。
## 缺口统一平移到 [0, TAU]；跨 0 度的缺口会把首尾两段合成一段绕回来的弧。
func _complement_arcs(starts: Array[float], ends: Array[float]) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	if starts.is_empty():
		var full := PackedFloat32Array()
		full.append(0.0)
		full.append(TAU)
		out.append(full)
		return out

	# 把每个区间拆成落在 [0, TAU] 内的碎片
	var fs: Array[float] = []
	var fe: Array[float] = []
	for i in starts.size():
		var s: float = starts[i]
		var e: float = ends[i]
		# 平移到 [0, TAU)
		while s < 0.0:
			s += TAU
			e += TAU
		while s >= TAU:
			s -= TAU
			e -= TAU
		if e <= TAU:
			fs.append(s)
			fe.append(e)
		else:
			# 跨 0 度 → 两段
			fs.append(s)
			fe.append(TAU)
			fs.append(0.0)
			fe.append(e - TAU)

	# 按起点排序后合并重叠
	var order: Array[int] = []
	for i in fs.size():
		order.append(i)
	order.sort_custom(func(a, b): return fs[a] < fs[b])

	var ms: Array[float] = []
	var me: Array[float] = []
	for idx: int in order:
		var s: float = fs[idx]
		var e: float = fe[idx]
		if not ms.is_empty() and s <= me[me.size() - 1] + 0.0001:
			me[me.size() - 1] = maxf(me[me.size() - 1], e)
		else:
			ms.append(s)
			me.append(e)

	# 相邻缺口之间就是可画区间
	var count: int = ms.size()
	var wraps: bool = ms[0] <= 0.0001 and me[count - 1] >= TAU - 0.0001
	for i in count:
		var cur_end: float = me[i]
		var next_start: float = ms[(i + 1) % count] + (TAU if i == count - 1 else 0.0)
		if i == count - 1 and not wraps:
			# 末尾到整圈结束
			if cur_end < TAU - 0.0001:
				var tail := PackedFloat32Array()
				tail.append(cur_end)
				tail.append(TAU)
				out.append(tail)
			continue
		if next_start > cur_end + 0.0001:
			var seg := PackedFloat32Array()
			seg.append(cur_end)
			seg.append(next_start)
			out.append(seg)
	return out


## 用 ArrayMesh 拼一段水平圆弧带（比用 TorusMesh 灵活：任意起止角）。
func _make_flat_arc(radius: float, width: float, a0: float, a1: float) -> ArrayMesh:
	var inner: float = maxf(radius - width * 0.5, 0.1)
	var outer: float = radius + width * 0.5
	var steps: int = maxi(int(ceil(rad_to_deg(a1 - a0) / 3.0)), 2)
	var verts := PackedVector3Array()
	for i in steps + 1:
		var a: float = lerpf(a0, a1, float(i) / float(steps))
		var ca: float = cos(a)
		var sa: float = sin(a)
		verts.append(Vector3(ca * inner, 0.0, sa * inner))
		verts.append(Vector3(ca * outer, 0.0, sa * outer))
	var indices := PackedInt32Array()
	for i in steps:
		var i0: int = i * 2
		indices.append(i0)
		indices.append(i0 + 1)
		indices.append(i0 + 2)
		indices.append(i0 + 1)
		indices.append(i0 + 3)
		indices.append(i0 + 2)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 公转 + 自转。星系在 MainMenu 里是背景，所以用 _process 而不是物理帧。
func _process(delta: float) -> void:
	for orbit: Node3D in _orbit_speeds.keys():
		if not is_instance_valid(orbit):
			continue
		orbit.rotate_y(deg_to_rad(float(_orbit_speeds[orbit]) * delta))
	for holder: Node3D in _spin_targets:
		if not is_instance_valid(holder):
			continue
		var spin: Variant = holder.get_meta("spin_speed", null)
		if spin != null:
			holder.rotate_y(deg_to_rad(float(spin) * delta))
	# 特写期间每帧把相机摆到"天体 + 固定偏移"，并看向天体。
	#
	# 为什么必须每帧摆位：天体在**公转**，位置一直在动；相机若只算一次绝对位置就会跟丢。
	# 保持"相对天体的偏移"不变，于是：
	#   ① 天体永远在画面正中（`look_at`）→ 不会有时偏左时偏右；
	#   ② 相机到天体的距离恒定 = 偏移长度 → **屏幕上的大小就固定**，与天体大小无关。
	if _focus_target != null and is_instance_valid(_focus_target):
		_focus_elapsed += delta
		_apply_focus_camera()


## 把相机摆到特写位：位置 = 天体位置 + 当前该用的相对偏移，朝向 = 看向天体。
##
## **特写相机的唯一写入者**就是这里（`_process` 每帧调一次 + 进入特写时立刻调一次）。
## 为什么不再用 `create_tween()` 做"漫游过去"：Tween 和"每帧跟随"写的是同一个
## `global_position`，同一帧里谁后写谁赢 —— 实测表现是**瞬移到位 → 卡住不动约 1.2 秒
## （这段时间天体照常公转、在画面里漂到一边）→ 再猛地跳回来**，
## 看上去就是"进地图后要等两秒镜头才对准星球"（ENGINEERING_NOTES 016）。
## 改成一个写入者之后，镜头每帧都在天体正中，不再有漂移和回跳。
##
## `focus_duration > 0` 时这里顺便负责"从当前位置漫游到特写位"：
## 起点是**进入瞬间相机相对天体的偏移**（`_focus_rel_from`），
## 这样漫游过程中天体也始终在画面正中，只是距离由远及近。
##
## （"正中"指相对**看向的点**而言；`focus_screen_raise` 会把看向的点往下挪，
## 于是天体整体在画面上抬高 —— 位置不动，只改朝向，所以屏幕尺寸不受影响。）
func _apply_focus_camera() -> void:
	if _camera == null or _focus_target == null or not is_instance_valid(_focus_target):
		return
	var duration: float = maxf(_focus_duration, 0.0)
	var weight: float = 1.0
	if duration > 0.0:
		weight = _ease_cubic_in_out(clampf(_focus_elapsed / duration, 0.0, 1.0))
	var rel: Vector3 = _focus_rel_from.lerp(_focus_offset, weight)
	_camera.global_position = _focus_target.global_position + rel
	_camera.look_at(_focus_target.global_position + _focus_aim_offset(rel.length()), Vector3.UP)


## 特写"看向的点"相对天体中心的偏移（世界向量）。
##
## 抬高量要按**距离**换算成世界距离，屏幕上的偏移才是恒定的：
## 距离 d 处，视口半高 = `d x tan(fov/2)`；想要屏幕高的 `raise` 倍，
## 世界距离就是 `raise x 2 x d x tan(fov/2)`。
## 朝向是**世界下方** —— 看向天体下方 = 天体出现在画面中心**上方**。
func _focus_aim_offset(distance: float) -> Vector3:
	var raise: float = maxf(_config.focus_screen_raise, 0.0)
	if raise <= 0.0:
		return Vector3.ZERO
	var half_fov: float = deg_to_rad(maxf(_camera.fov, 1.0)) * 0.5
	return Vector3.DOWN * (raise * 2.0 * maxf(distance, 0.0) * tan(half_fov))


## 与 Tween 的 `TRANS_CUBIC` + `EASE_IN_OUT` 同形的缓动（0→0，1→1，两端慢中间快）。
## 自己写是因为漫游不再走 Tween（见 `_apply_focus_camera`），要自己算插值权重。
func _ease_cubic_in_out(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	var rest: float = -2.0 * t + 2.0
	return 1.0 - rest * rest * rest / 2.0


# --- 单颗特写（地图界面用）----------------------------------------------

## 只看某一颗天体：隐藏**其它所有天体**和**全部轨道线**，镜头切到它的特写。
##
## `body_index` 是 `bodies` 数组的下标（0 = 中央恒星）。
## `duration` 是这次镜头的漫游时长（秒）：**0 = 立即锁定**（进地图用），
## > 0 = 从这里开始一段"漫游"到特写位（在地图里切天体用）——
## 漫游期间天体**全程在画面正中**，只是距离由远及近。
## 返回是否成功（下标越界 / 该天体没生成出来时返回 false）。
##
## **自转与公转都会继续**：这里不动 `_orbit_speeds` / `_spin_targets`，
## 只改显隐与相机。这是有意为之 —— 特写要能看到星球在转。
## 星球位置每帧在变，所以镜头靠 `_process` 里每帧 `look_at` 跟住它。
##
## 特写时**轨道线全隐藏**（不是"只留目标那条"）：特写的主体是星球本身，
## 一条穿过画面的大圆环只会碍事。
func focus_on_body(body_index: int, duration: float = 0.0) -> bool:
	if body_index < 0 or body_index >= _holders.size():
		CoreSystem.logger.warning("[Galaxy] 特写下标越界：%d" % body_index)
		return false
	var target: Node3D = _holders[body_index]
	if target == null or not is_instance_valid(target):
		CoreSystem.logger.warning("[Galaxy] 特写目标天体不存在：下标 %d" % body_index)
		return false
	if _camera == null:
		return false

	# 1) 记下当前相机状态，退出特写时原样恢复
	if _saved_camera.is_empty():
		_saved_camera = {
			"position": _camera.global_position,
			"rotation": _camera.global_rotation,
		}

	# 2) 显隐：只留目标那颗，轨道线全隐藏
	for i in _holders.size():
		var h: Node3D = _holders[i]
		if h != null and is_instance_valid(h):
			h.visible = (i == body_index)
	for orbit_index: int in _orbit_lines:
		for seg: Node3D in _orbit_lines[orbit_index]:
			if is_instance_valid(seg):
				seg.visible = false

	# 3) 相机：记下"相对天体的偏移方向"，之后每帧跟着天体走。
	#    方向取当前镜头方向（镜头从这个方向逼近 → 天体正面朝着观众，
	#    不会因为换到背面看而"过去之后一片黑"），
	#    长度 = 天体半径 × 倍数（倍数固定 → 屏幕上大小固定）。
	var radius: float = _placed[body_index].est_radius if body_index < _placed.size() else 100.0
	# 可见半径系数：自动估算是**网格半径**，实际可见尺寸因星球而异
	# （带大气壳的大、裸球小）。
	var body_def: GalaxyBody = _config.bodies[body_index] if body_index < _config.bodies.size() else null
	if body_def != null:
		radius *= maxf(body_def.focus_radius_scale, 0.01)

	var dir: Vector3 = _camera.global_position - target.global_position
	if dir.length() < 0.001:
		dir = Vector3(0.0, 0.3, 1.0)
	_focus_offset = dir.normalized() * (maxf(radius, 1.0) * maxf(_config.focus_distance_factor, 1.2))
	# 漫游起点 = 进入瞬间"相机相对天体"的偏移（不是绝对位置：天体在动，
	# 存绝对位置会让漫游路径跟着天体跑偏）。
	_focus_rel_from = _camera.global_position - target.global_position
	_focus_target = target
	_focus_elapsed = 0.0
	_focus_duration = maxf(duration, 0.0)
	# 跟随靠 `_process` —— 确保它是开着的（本节点默认就开，这里只是显式声明依赖，
	# 免得以后有人为了省开销把它关掉、结果特写不跟随了）
	set_process(true)

	# 退出特写的归位 Tween 可能还在跑（快速开关地图），它会写同一个 `global_position`，
	# 必须先杀掉，否则又要变成"两个写入者抢属性"。
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	# 立刻摆一次（不等下一帧）：否则"进地图"的第一帧渲染的还是全景。
	# `duration = 0` 时这一步就是最终位置 —— 镜头**当场锁定**，没有过渡。
	_apply_focus_camera()
	CoreSystem.logger.info("[Galaxy] 特写天体下标 %d：半径 %.0f（含系数），镜头相对偏移 %.0f（= %.1f 倍半径），漫游时长 %.2fs" % [
		body_index, radius, _focus_offset.length(),
		_focus_offset.length() / maxf(radius, 0.0001), _focus_duration])
	return true


## 退出特写：恢复所有天体与轨道线的显隐，相机动画回到进入特写前的位置与朝向。
func reset_focus() -> void:
	_focus_target = null
	for h: Node3D in _holders:
		if h != null and is_instance_valid(h):
			h.visible = true
	for orbit_index: int in _orbit_lines:
		for seg: Node3D in _orbit_lines[orbit_index]:
			if is_instance_valid(seg):
				seg.visible = true

	if _camera == null or _saved_camera.is_empty():
		return
	var pos: Vector3 = _saved_camera["position"]
	var rot: Vector3 = _saved_camera["rotation"]
	_saved_camera.clear()
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_camera, "global_position", pos, _config.reset_duration)
	_camera_tween.parallel().tween_property(_camera, "global_rotation", rot, _config.reset_duration)
	CoreSystem.logger.info("[Galaxy] 退出特写，相机归位")
