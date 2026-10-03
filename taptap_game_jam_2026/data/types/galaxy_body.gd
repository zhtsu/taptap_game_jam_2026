class_name GalaxyBody
extends Resource

## 星系里的一个天体（GalaxyConfig.bodies 数组的一项）。
##
## 数组顺序携带语义：
##   [0]          = 中央恒星（放在原点，不公转）
##   [1] 及以后    = 其余天体，**由内往外**依次生成；相邻的构成一圈
##
## 最常用的是 4 个字段：scene / scale / spin_speed / orbit_speed。
## radius / angle 留 0 就交给自动布局算（想精确摆放某颗时才填）。

@export_group("外观")
## 显示用名字（只作文档用途，便于在编辑器里认人）
@export var label: String = ""
## 星球场景（插件的 naejimer_3d_planet_generator 场景，或任何以 Node3D 为根的场景）
@export_file("*.tscn") var scene: String = ""
## 尺寸缩放。**它乘的是插件里该场景的基准半径**（各星球基准差 1700 倍：
## 气态/无大气 ≈0.5，类地/冰 ≈220，沙 ≈200，熔岩 ≈270，恒星 ≈865），
## 所以不同种类的 scale 数值差异很大，这是正常的。
@export var scale: float = 1.0
## 自转速度（度/秒）
@export var spin_speed: float = 8.0

@export_group("轨道")
## 公转速度（度/秒）。0 = 不公转；负值反向（相邻圈反向会更有层次）。
## 第一项（中央恒星）会忽略这个字段。
@export var orbit_speed: float = 5.0
## 同轨分组：**填相同值的天体共用一条轨道**（做双行星 / 小行星带用）。
## 0 = 每颗独占一圈（默认行为，数组里相邻的自动构成一圈）。
@export var ring_group: int = 0

@export_group("精确摆放（留 0 = 自动）")
## 轨道半径。0 = 由自动布局公式算（平方根散布）
@export var radius: float = 0.0
## 在轨道上的角度（度）。0 = 自动按顺序均分 + 黄金角错开
@export var angle_deg: float = 0.0
## 相对环平面的高度偏移（正负都可以，做"悬浮层次"）
@export var height: float = 0.0
