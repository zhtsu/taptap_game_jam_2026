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
		_spawn_body(bodies_root, star_entry, "Center", Vector3.ZERO, star_entry.spin_speed)
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
	var orbits: Array[Node3D] = []
	for i in plans.size():
		var orbit := Node3D.new()
		orbit.name = "Orbit%d" % i
		bodies_root.add_child(orbit)
		orbits.append(orbit)
	for i in plans.size():
		for body: GalaxyBody in plans[i].bodies:
			_add_body_to_orbit(orbits[i], i, body, plans[i].radius)

	# 3) 轨道线：画在 bodies_root（不公转的父节点）上，避免线跟着转。
	#    半径直接用规划好的值（不依赖自转节点当帧的位置）。
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
	_spawn_body(orbit, body, holder_name, pos, body.spin_speed)
	# 按天体自己的公转速度决定整圈的转速（同轨多颗时取第一颗的）
	if not _orbit_speeds.has(orbit):
		_orbit_speeds[orbit] = body.orbit_speed
	# 登记摆放信息：轨道线要按"别的星在哪个角度"留缺口
	var info := _Placed.new()
	info.orbit_radius = radius
	info.angle_rad = angle
	info.est_radius = _visible_radius(body)
	_placed.append(info)


## 实例化一个天体到 parent 的 pos 位置，并登记自转
func _spawn_body(parent: Node3D, body: GalaxyBody, holder_name: String, pos: Vector3, spin: float) -> void:
	if not ResourceLoader.exists(body.scene):
		push_warning("[Galaxy] 天体场景不存在，已跳过：%s" % body.scene)
		return
	var packed: PackedScene = load(body.scene) as PackedScene
	if packed == null:
		push_warning("[Galaxy] 天体场景加载失败：%s" % body.scene)
		return

	var holder := Node3D.new()
	holder.name = holder_name
	holder.position = pos
	holder.scale = Vector3.ONE * body.scale
	parent.add_child(holder)

	var node: Node3D = packed.instantiate() as Node3D
	if node == null:
		push_warning("[Galaxy] 天体场景的根不是 Node3D：%s" % body.scene)
		return
	node.name = "Model"
	holder.add_child(node)
	holder.set_meta("spin_speed", spin)
	_spin_targets.append(holder)


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
