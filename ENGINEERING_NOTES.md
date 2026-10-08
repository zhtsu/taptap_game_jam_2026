# 工程笔记（问题记录 / 模板回流清单）

记录本项目里**踩过的坑、修过的错、以及设计架构上的问题**。

两个用途：

1. **变更溯源**：某个文件为什么是现在这样 —— 写清楚*现象 / 原因 / 改法*，别让下一个人（或下一个 AI）
   再把同一处改回去。
2. **回流模板**：`taptap_game_jam_2026/` 是从 `godot-template` 模板起手改的。这里记下的每一条，
   都标注它**是否值得合并回项目模板**，以及怎么合并 —— 逐条攒着，别每次从零重踩。

> 面向 AI/协作者的硬约束在 `AGENTS.md`；本文件不重复那些规则，只记**具体事件与教训**。

## 怎么用这份文档

**什么时候写**：

- 修掉了一个**初级错误**（语言/引擎层面的坑，比如命名冲突、API 用错、类型静默转换）；
- 发现或处理了一个**设计/架构问题**（分层被绕过、契约被违反、约定靠人记）；
- 验证过程中发现的**稳定异常现象**（哪怕这次没修）。

**新增一条时**：

- 在下面 `## 索引` 的表格里加一行（ID 自增，`类型` 只用 `初级错误` / `架构` / `工程实践` 三类）；
- 在 `## 条目` 里按模板补一节，**ID 必须一致**；
- `是否回流模板` **必须**二选一填死：`是（怎么改）` / `否（为什么）` —— 空着等于没记录。

**条目模板**：

```markdown
### NNN 一句话标题

- **日期**：YYYY-MM-DD
- **类型**：初级错误 | 架构 | 工程实践
- **严重度**：阻断级（跑不起来） | 功能级（能跑但行为不对） | 噪声级（只是报错/告警刷屏）
- **位置**：`路径:行`
- **状态**：已修 | 待修 | 待讨论 | 仅记录
- **是否回流模板**：是 | 否（理由）

**现象**：引擎/运行时给出的**原文**报错，一行不差地抄下来。

**原因**：为什么会这样。如果和"什么时候才报"有关（编辑器 vs headless、首次 vs 二次），一定写清楚。

**改动**：改了什么（改名前 → 改名后 / 加了什么）。

**验证**：用什么命令验证的、判据是什么、结果如何。**没验证过的改动不许标"已修"**。

**教训 / 回流做法**：一句话的通用结论。回流模板的话，写清"改成什么样"。
```

## 索引

| ID | 日期 | 一句话 | 类型 | 严重度 | 状态 | 回流模板 |
|---|---|---|---|---|---|---|
| [001](#001-局部变量名-snapped-撞上内置函数-snapped) | 2026-10-01 | 局部变量名 `snapped` 撞上内置函数 `snapped()` | 初级错误 | 噪声级 | 已修 | 是（加静态检查 + 编辑器导入冒烟） |
| [002](#002-探针脚本残留进仓库) | 2026-10-01 | 探针脚本 `_probe_reset_key.gd` 残留进仓库 | 工程实践 | 噪声级 | 已修（已删除） | 是（脚本兜底清理） |
| [003](#003-编辑器报-unrecognized-uid工程整目录搬迁的副作用) | 2026-10-01 | 编辑器报 `Unrecognized UID`（工程整目录搬迁的副作用） | 架构 | 噪声级 | 待讨论 | 待定（先写进模板的搬迁说明） |
| [004](#004-基线文件记录的是已经不存在的工程路径) | 2026-10-01 | 基线文件记录的是已经不存在的工程路径 | 工程实践 | 噪声级 | 待修 | 是（自动探测工程 + 路径变更重登） |
| [005](#005-int-直接赋给-enum-类型属性缺-as-key-转型) | 2026-10-01 | `int` 直接赋给 `enum` 类型属性（缺 `as Key`） | 初级错误 | 噪声级 | 已修 | 是（同 001，lint 加枚举转型规则） |
| [006](#006-第三方插件-shader-里的-modx-00-除零) | 2026-10-02 | 第三方插件 shader 里的 `mod(x, 0.0)` 除零 | 初级错误 | 功能级 | 已修（改了 addons） | 否（第三方补丁，随插件版本走） |
| [007](#007-删掉一个事件常量却漏改引用导致整工程编译失败) | 2026-10-02 | 删掉一个事件常量却漏改引用，导致整工程编译失败 | 初级错误 | 阻断级 | 已修 | 是（lint 加常量引用完整性检查） |
| [008](#008-资源里存内部类与带类型数组tres-静默丢数据) | 2026-10-03 | 资源里存内部类 + 带类型数组，`.tres` 静默丢数据 | 初级错误 | 功能级 | 已修 | 是（AGENTS.md 加一条序列化约束） |
| [009](#009-lint-脚本用-project-传相对路径allow-列表全失配误报-43-条) | 2026-10-03 | lint 脚本用 `-Project` 传相对路径，allow 列表全失配、误报 43 条 | 工程实践 | 阻断级 | 已修 | 是（门禁脚本自身也要能被门禁） |
| [010](#010-拿静态-aabb-量插件星球半径量出的数字全错) | 2026-10-03 | 拿静态 AABB 量插件星球半径，量出的数字全错 | 初级错误 | 功能级 | 已修（改用渲染实测） | 是（AGENTS.md 加"渲染类结论必须实测"） |
| [011](#011-网格行数从槽数推导4x4-被压成-4x3) | 2026-10-04 | 网格行数从槽数推导，4x4 被压成 4x3 | 初级错误 | 功能级 | 已修 | 是（AGENTS.md 加"外圈格数"结论） |
| [012](#012-入树前调用-setter-setter-里-@onready-还是-null) | 2026-10-04 | 入树前调用 setter，setter 里 `@onready` 还是 null | 初级错误 | 阻断级 | 已修 | 是（AGENTS.md 加"组件 setter 要容忍未就绪"） |
| [013](#013-门禁盲区孤儿-key-检查没扫-tres) | 2026-10-04 | 门禁盲区：孤儿 key 检查没扫 `.tres` | 工程实践 | 阻断级 | 已修 | 是（lint 扫描补 `.tres`） |
| [014](#014-button-的-font_size-覆盖不会传给子-label) | 2026-10-04 | Button 的 ont_size 覆盖不会传给子 Label（字体没放大却以为成功了） | 初级错误 | 功能级 | 已修 | 是（AGENTS.md 加一条） |
| [015](#015-容器里的子节点不加-size_flags-就不会被撑开) | 2026-10-04 | 容器里的子节点不加 `size_flags` 就不会被撑开（格子停在最小尺寸） | 初级错误 | 功能级 | 已修 | 是（AGENTS.md 加一条） |
| [016](#016-tween-与每帧跟随抢同一个属性瞬移--卡住--回跳) | 2026-10-07 | Tween 与"每帧跟随"抢同一个属性：瞬移 → 卡住 → 回跳 | 初级错误 | 功能级 | 已修 | 是（AGENTS.md 加一条） |
| [017](#017-兜底默认配置与-tres-实际配置不一致) | 2026-10-07 | 兜底默认配置与 `.tres` 实际配置不一致（缺配置时是另一个星系） | 架构 | 功能级 | 已修 | 是（AGENTS.md 加一条） |
| [018](#018-量星球在屏幕上多大这件事量法本身会骗人) | 2026-10-07 | 量"星球在屏幕上多大"这件事，量法本身会骗人 | 工程实践 | 功能级 | 已修（尺寸）；光照角度仅记录 | 是（AGENTS.md 的视觉验证补测量配方） |
| [019](#019-scrollcontainer-抄上-mouse_filter--ignore滚动直接静默死掉) | 2026-10-07 | `ScrollContainer` 抄上 `mouse_filter = IGNORE`，滚动直接静默死掉 | 初级错误 | 功能级 | 已修（上线前拦下） | 是（AGENTS.md 加一条） |
| [020](#020-引用了不存在的翻译-key界面直接把-key-原文显示出来) | 2026-10-07 | 引用了不存在的翻译 key，界面直接把 key 原文显示出来 | 初级错误 | 功能级 | 已修（并补了门禁规则） | 是（lint 加 `locale_missing` + AGENTS.md 加一条） |
| [021](#021-同一场景里两个节点重名find_child-取到哪个看树序) | 2026-10-07 | 同一场景里两个节点重名，`find_child` / `%` 取到哪个看树序 | 初级错误 | 功能级 | 已修（改名去歧义） | 是（AGENTS.md 加一条） |
| [022](#022-多入口界面把返回写死成回主菜单从第二个入口进来就丢了上下文) | 2026-10-07 | 多入口界面把「返回」写死成回主菜单，从第二个入口进来就丢了上下文 | 架构 | 功能级 | 已修 | 是（`OpenUiRequest.caller` + AGENTS.md 硬规则 2 补一句） |
| [023](#023-给存档加分段时文件与分段的对应关系没有单一事实来源) | 2026-10-07 | 给存档加分段时，"哪个文件装哪些分段"没有单一事实来源 | 架构 | 功能级 | 已修 | 是（AGENTS.md 存档契约写清一张表） |
| [024](#024-任何一次存档都会顺手-validate-掉别的分段) | 2026-10-07 | 任何一次存档都会顺手 `validate` 掉别的分段（保存方案改掉分辨率） | 工程实践 | 噪声级 | 仅记录 | 是（AGENTS.md 存档契约补一句） |
| [025](#025-tscn-里手写-transform3d-行列顺序搞反相机朝天看) | 2026-10-07 | `.tscn` 里手写 `Transform3D` 行列顺序搞反：相机朝天看 | 初级错误 | 功能级 | 已修 | 是（AGENTS.md Godot 坑加一条） |
| [026](#026-subviewport-默认和根视口共享-world3d星系的环境漏进关卡) | 2026-10-07 | `SubViewport` 默认和根视口共享 World3D，星系的环境漏进关卡 | 架构 | 功能级 | 已修 | 是（AGENTS.md 加一条 + 背景层说明） |
| [027](#027-挂在-node2d-下的-control锚点等于没写尺寸就是-offset-的差) | 2026-10-07 | 挂在 `Node2D` 下的 `Control`：锚点等于没写，尺寸就是 offset 的差 | 初级错误 | 功能级 | 已修 | 是（AGENTS.md Godot 坑加一条） |
| [028](#028-删设置项不能只删界面字段应用逻辑日志引用都得一起删) | 2026-10-07 | 删设置项不能只删界面：字段、应用逻辑、日志引用都得一起删 | 架构 | 功能级 | 已修 | 是（AGENTS.md 存档契约 + 已知未完成事项写清清单） |

## 条目

### 001 局部变量名 snapped 撞上内置函数 snapped()

- **日期**：2026-10-01
- **类型**：初级错误
- **严重度**：噪声级（不影响运行，但每次脚本重载都刷一条告警）
- **位置**：`taptap_game_jam_2026/save_data/options_save.gd:58`（`_snap_volume_to_step()` 内）
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：

```
W 0:00:01:538   GDScript::reload: The variable "snapped" has the same name as a built-in function.
  <GDScript 错误> SHADOWED_GLOBAL_IDENTIFIER
  <GDScript 源文件>options_save.gd:58 @ GDScript::reload()
```

**原因**：

`snapped()` 是 Godot 的**内置全局函数**（把值吸附到步长）。脚本里声明 `var snapped` 会遮蔽这个全局
标识符，GDScript 报 `SHADOWED_GLOBAL_IDENTIFIER`。

**关键点（容易误判为"没改对"）**：这条告警**只在脚本重载时**产生 —— 也就是**编辑器加载/导入**
（`--editor`）路径；普通 headless 运行（`--quit-after N` 冒烟）**不会**报。所以：

- 拿 `verify-engine.ps1` 的默认冒烟去验这条修复，**会看到"没有这条告警"而误以为已经修好**（改动前也看不到）；
- 同理，改动后冒烟仍然通过，**也不能证明**改对了。

验证这类问题必须走 `--editor --quit` 或者真实打开编辑器。

**改动**：`options_save.gd` 里局部变量 `snapped` → `snapped_volume`（3 处引用同步改），
并在声明上方加一行注释说明为什么不能叫 `snapped`：

```gdscript
	# 变量别叫 snapped：那是内置函数名，会触发 SHADOWED_GLOBAL_IDENTIFIER
	var snapped_volume: float = OptionsData.step_to_volume(step)
	if not is_equal_approx(snapped_volume, clamped):
		push_warning("[OptionsSave] 音量字段 '%s' 的值 %.3f 不是候选档位，已吸附到 %d 档（%.2f）"
			% [field, value, step, snapped_volume])
	return snapped_volume
```

纯改名，**语义与行为完全不变**（吸附逻辑、告警文案、返回类型都没动）。

**验证**：

```powershell
# 1) 复现路径：编辑器加载会重载全部脚本，残留的遮蔽告警会在这里现形
& 'C:\portable\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless `
  --path 'C:\repos\taptap_game_jam_2026\taptap_game_jam_2026' --editor --quit --quit-after 3
# 判据：输出中不再出现 SHADOWED / snapped（改前该路径会报）

# 2) 常规两道门禁（注意本仓库工程在子目录，脚本默认值指向已不存在的 godot-template/，必须传 -Project）
pwsh scripts/godot-lint.ps1    -Project 'C:\repos\taptap_game_jam_2026\taptap_game_jam_2026'   # error=0
pwsh scripts/verify-engine.ps1 -Project 'C:\repos\taptap_game_jam_2026\taptap_game_jam_2026' `
     -Scenario res://entry/main.tscn                                                          # 无新增 ERROR/WARNING
```

结果：编辑器路径的 `SHADOWED` 消失；lint `error=0`；冒烟与主场景实例化 exit=0 且相对基线**无新增行**。
（冒烟输出里多了 2 行 `[SaveService] 已读入并应用设置存档` 的 INFO，是 `user://` 下已有设置存档带来的
机器相关输出，与本次改动无关。）

**教训 / 回流做法**：

- **通用结论**：GDScript 里给变量起名要避开内置全局函数。除了 `snapped()`，同类高频雷还有
  `clamp()` / `lerp()` / `sign()` / `abs()` / `min()` / `max()` / `range()` / `hash()` / `str()` /
  `print()` / `load()` / `preload()` / `type_string()` 等。
  **特别反直觉的一条**：`snapped` 这种"看起来像名词"的其实也是函数名（"吸附后的值" 很自然会被写成
  `snapped`，本项目就是这么中的招）。
- **回流模板（可执行的三件事）**：
  1. `scripts/godot-lint.ps1` 加一条 `shadowed_builtin` 规则：扫 `var <name>` / `func <name>(` /
     `const <name>` / 参数名，命中内置函数名表就报 **error**。"靠人记"的约定要变成可执行检查，
     这正是 lint 存在的意义。
  2. `scripts/verify-engine.ps1` 增加一个**编辑器导入**步骤（`--editor --quit --quit-after N`），
     把这类"只在脚本重载时出现"的告警纳入采集，而不是只跑 headless 冒烟。
  3. `AGENTS.md` 的「Godot 坑」节补一条：*遮蔽内置函数名的告警只在编辑器导入/脚本重载时出现，
     普通 headless 冒烟看不到* —— 避免下一个人用错判据。

### 002 探针脚本残留进仓库

- **日期**：2026-10-01
- **类型**：工程实践
- **严重度**：噪声级
- **位置**：`taptap_game_jam_2026/_probe_reset_key.gd`、`taptap_game_jam_2026/_probe_reset_key.gd.uid`
- **状态**：已修（清理完成，2026-10-01）
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：`pwsh scripts/godot-lint.ps1` 报 1 条 warn：

```
[WARN] temp_files     taptap_game_jam_2026/_probe_reset_key.gd
        > _probe_reset_key.gd
        临时脚本/资源，交付前必须删除
```

**原因**：上一轮会话用一次性探针排查「恢复默认按键重映射」时留下的，没在收尾删掉（`.uid` 也一起留下）。
`AGENTS.md` 里写明「探针脚本不要留在仓库里」，但这条**只靠人记**，lint 只给 warn 不阻断。

**改动**：**已删除**（人类明确要求"把探针之类多余文件清理掉"）：

- `taptap_game_jam_2026/_probe_reset_key.gd`（4575 字节，sha256 `0089CF2F…C03E4D`）
- `taptap_game_jam_2026/_probe_reset_key.gd.uid`（19 字节，sha256 `766790B4…DF8472`）

删前记了摘要，万一要找回同一个探针，可按上面哈希确认。同批检查过：`_probe_saves/` 目录、
保存临时文件（`.tmp`）、仓库根下的散落文件都没残留。

**验证**：

- 删除前：该文件与配套 `.uid` 都实实在在躺在工程目录里（未被任何忽略规则覆盖）；`godot-lint.ps1` 的 `temp_files` 规则命中。
- 删除后：`godot-lint.ps1` 报 **`error=0  warn=0`**（与 `AGENTS.md` 里"存量 warn 已清零"一致）；
  `verify-engine.ps1 -Project ... -Scenario res://entry/main.tscn` 退出码 0、**无新增 ERROR/WARNING**；
  `--headless --editor --quit` 无任何脚本类告警（顺带确认它没给别人留下编译期引用）。

**教训 / 回流做法**：

- 回流模板：**让规则自己兜底**，别指望收尾时记得住 ——
  1. 在工程根加忽略规则，覆盖 `_*` 探针（`_probe*` / `_*_probe*`）与配套的 `.uid`，
     让残留**不会进版本库**；
  2. 把 `temp_files` 从 warn 提升为 **error**（探针是"用完即弃"的东西，残留即失败），
     或在 `verify-engine.ps1` 结尾扫一遍 `_*` 并让退出码非 0；
  3. `AGENTS.md` 里把「探针约定」从"记得删"改成"**探针一律放工程外**"——
     例如统一放到 `res://.probe/`（整个目录加进忽略规则），用完连同目录一起删，不会有半删状态。

### 003 编辑器报 Unrecognized UID（工程整目录搬迁的副作用）

- **日期**：2026-10-01
- **类型**：架构
- **严重度**：噪声级（仅编辑器导入路径报；headless 运行与场景加载都正常）
- **位置**：`taptap_game_jam_2026/project.godot:15`、`taptap_game_jam_2026/entry/main.tscn:1`
- **状态**：待讨论（与 001 无关，非本次引入）
- **是否回流模板**：待定 —— 先写进模板的「项目搬迁」说明，确认成因后再决定是否加检查

**现象**：`--headless --editor --quit` 时输出：

```
ERROR: Unrecognized UID: "uid://cc28skn5h7aup".
```

该 UID 在两处出现且**指向主场景本身**：

```
project.godot:15   run/main_scene="uid://cc28skn5h7aup"
entry/main.tscn:1  [gd_scene format=3 uid="uid://cc28skn5h7aup"]
```

**原因**（推断，未最终确认）：工程目录被整体从 `godot-template/` 搬到 `taptap_game_jam_2026/`。
`uid://` 与路径的映射缓存在 `.godot/` 里，搬迁后缓存与磁盘实际对不上，编辑器查不到这个 UID 就报错。
**但这不影响实际加载** —— headless 冒烟、`-Scenario res://entry/main.tscn` 都是 exit=0，主场景正常起来。

**改动**：无（登记待办）。**注意**：这类"重新导入/重建缓存"的动作会改仓库状态，
按 `AGENTS.md` 属于需要人类明确许可的操作，不应由 agent 自作主张（例如删 `.godot/` 重新导入）。

**验证**：

```powershell
pwsh scripts/verify-engine.ps1 -Project 'C:\repos\taptap_game_jam_2026\taptap_game_jam_2026' `
     -Scenario res://entry/main.tscn      # exit=0，无新增 ERROR/WARNING
```

**教训 / 回流做法**：

- 这是「**工程整目录搬迁**」这一类操作的典型副作用，值得在模板文档里写一句：
  *搬工程后如果编辑器报 `Unrecognized UID`，先让编辑器完整重导入一次（或清 `.godot/`），
  再用 `verify-engine.ps1 -Scenario res://entry/main.tscn` 确认主场景仍能加载。*
- 是否回流检查项待定：这条报错**只在 `--editor` 路径出现**，和 001 是同一个盲区 ——
  两者一起说明「只跑 headless 冒烟会漏掉一整类问题」（见 001 回流做法第 2 条）。
- **设计层面更值得记的一点**：`project.godot` 的 `run/main_scene` 用的是 **UID** 而不是 `res://` 路径。
  UID 对改名友好、对**搬迁**不友好。模板目前把 UID 和路径两套引用混着用，出现了"两处指向同一场景、
  但只有一处能被解析"的尴尬状态；后续如果要做"模板 + 项目分层"，这条要纳入考虑（优先用路径引用，
  或保证搬迁后跑一次重导入）。

### 004 基线文件记录的是已经不存在的工程路径

- **日期**：2026-10-01
- **类型**：工程实践
- **严重度**：噪声级（不影响判据，但元数据是错的，且默认参数指向不存在的目录）
- **位置**：`scripts/engine-baseline.json`（`project` 字段）、`scripts/godot-lint.ps1:34`、`scripts/verify-engine.ps1:54`
- **状态**：待修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：

- `scripts/engine-baseline.json` 的 `project` 字段仍写着 `C:\repos\godot-template\godot-template`（该目录已不存在）；
- 两个脚本的 `-Project` **默认值**都是 `<仓库根>/godot-template`，因此默认运行会直接 `exit 2`：

```
ERROR: ...\godot-template 下没有 project.godot；用 -Project 指定工程目录。
```

必须显式传 `-Project 'C:\repos\taptap_game_jam_2026\taptap_game_jam_2026'` 才能跑（本次所有验证都是这么跑的）。

**原因**：模板仓库本来是「仓库根 = `godot-template/` 一层」，本项目把它换成了
「仓库根 = 项目子目录 `taptap_game_jam_2026/`」，但**基线里的路径元数据和两个脚本的默认值没跟着改**。

**改动**：无（登记待办）。特意**没有**跑 `-UpdateBaseline` 重写它 —— 因为当前实测的**问题行**与基线 5 行
完全一致（diff 报「无新增 ERROR/WARNING」），**只差 `project` 这个元数据字段**；为了改一个路径字段就
重刷整个基线，会把 `SmokeLines` 一起重写、掩盖"真的没变"这个有用信息。改动要单独做、单独说清理由。

**验证**：不带 `-Project` 跑两个脚本会报上面对错并 `exit 2`；带 `-Project` 后 lint `error=0`、
引擎验证「无新增 ERROR/WARNING（基线 5 行）」。

**教训 / 回流做法**：

- **通用结论**：**任何写死了工程目录的配置，在工程挪位置后都会静默失效** —— 这里表现成"脚本默认跑不了"
  和"基线元数据撒谎"，两个都不会让现有判据失败，属于典型的"绿色但已经坏了"。
- **回流模板（三件事）**：
  1. `-Project` 默认值改成**自动探测**：从 `$repoRoot` 起找第一个含 `project.godot` 的目录
     （`$repoRoot` 本身优先），而不是硬编码 `godot-template`。两个脚本共用；找不到再报错。
  2. `engine-baseline.json` 增加一致性自检：运行时不比对 `project` 字段与当前 `$Project`，
     不一致就**警告**（而不是默默按行比对），并提示"换了工程目录，确认后 `-UpdateBaseline`"。
  3. `README.md` / `AGENTS.md` 里所有 `scripts/*.ps1` 的示例命令去掉对 `godot-template/` 的隐含假设，
     改成"在仓库根跑"即可 —— 让文档与自动探测后的行为一致。

### 005 int 直接赋给 enum 类型属性（缺 as Key 转型）

- **日期**：2026-10-01
- **类型**：初级错误
- **严重度**：噪声级（不影响运行，但每次脚本重载都刷一条告警）
- **位置**：`taptap_game_jam_2026/core/options_applier.gd:75`（`_apply_input_bindings()` 内）
- **状态**：已修
- **是否回流模板**：是 —— 与 [001](#001-局部变量名-snapped-撞上内置函数-snapped) 同一类盲区，见下方「回流做法」

**现象**：

```
W 0:00:01:603   GDScript::reload: Integer used when an enum value is expected. If this is intended, cast the integer to the enum type using the "as" keyword.
  <GDScript 错误> INT_AS_ENUM_WITHOUT_CAST
  <GDScript 源文件>options_applier.gd:75 @ GDScript::reload()
```

**原因**：

`InputEventKey.physical_keycode` 的**静态类型是 `Key` 枚举**，而按键重映射表里的键码是从存档读出来的
`int`（`OptionsSave.input_bindings` 的 value）。往 `Key` 属性里塞 `int` 需要显式转型。

**这不是"随手写漏了转型"，而是存档契约的必然结果**：`var_to_bytes()` / `bytes_to_var()` **只存变体类型、
不存枚举信息** —— 就算写档时 value 是 `Key`，读回来也一定是 `int`。所以这个转型在"从存档来的键码"
这条路上**永远**是必需的。（探针里实测过：往返后 `typeof` = `TYPE_INT`。）

**关键点（同 001）**：`INT_AS_ENUM_WITHOUT_CAST` 也**只在脚本重载 / 编辑器导入时**产生，普通 headless 冒烟
不报 —— 不要用 `verify-engine.ps1` 的默认冒烟来验这类修复。

**改动**：`options_applier.gd` 第 75 行加转型 + 注释说明为什么不能省：

```gdscript
		# 用物理键码：同一个物理键在不同键盘布局下位置一致，玩家按的还是那个键。
		# `as Key` 不能省：physical_keycode 的静态类型是 Key 枚举，而存档里取出来的是 int
		# （var_to_bytes 只存变体类型、不存枚举，读回来必然是 int），
		# 不转型会报 INT_AS_ENUM_WITHOUT_CAST。
		event.physical_keycode = keycode as Key
```

**纯转型，运行时行为不变** —— 但这一点必须验证，不能靠"看起来没变"。

**验证**：

```powershell
# 1) 复现路径：编辑器加载会重载全部脚本
& 'C:\portable\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless `
  --path 'C:\repos\taptap_game_jam_2026\taptap_game_jam_2026' --editor --quit --quit-after 3
# 判据：输出中不再出现 INT_AS_ENUM / SHADOWED（改前该路径会报）

# 2) 行为验证：一次性探针（用完即删，不在仓库里留）
pwsh scripts/verify-engine.ps1 -Project 'C:\repos\taptap_game_jam_2026\taptap_game_jam_2026' `
     -Probe res://_probe_keycode_cast.gd
```

探针覆盖三条现实路径，**3/3 PASS**（并证明了转型没有改变行为）：

| 断言 | 结果 |
|---|---|
| 源码里 `bindings["pause"] = 81`（int）→ 应用后 pause 绑定 `KEY_Q(81)` | PASS |
| `var_to_bytes` → `bytes_to_var` 往返后键码**仍是 int**（81）→ 所以 `as Key` 是必需的 | PASS |
| 应用空表 → pause 回到出厂绑定（`keycode=4194305 physical=0`，与改动前一致） | PASS |

顺带两道门禁：lint `error=0`（warn 只剩 002 那条存量探针），
`verify-engine.ps1 -Scenario res://entry/main.tscn` 退出码 0 且**无新增 ERROR/WARNING**。

**踩到的两个坑（写探针时，值得记）**：

1. **`OptionsApplier` 的"出厂绑定"快照只抓一次（`static var _default_bindings`）**：探针里先改绑到 Q、
   再应用空表，那时抓到的"出厂快照"已经是空的 → 断言必然失败。要验"恢复默认"，必须**在做任何改动之前**
   自己先存一份基准。（生产环境没这个问题：快照在进程启动、第一次 apply 时抓，此时还没人改过。）
2. **`project.godot` 里 pause 的出厂事件只填了 `keycode`，`physical_keycode` 是 0**；
   而重映射写入的是 `physical_keycode`。所以"恢复默认"的断言**不能只比物理键码**，
   要连 `keycode` 一起比 —— 第一版探针就是只比物理键码，误报了 FAIL（看起来像代码 bug，其实是断言写错）。

**教训 / 回流做法**：

- **通用结论**：**从"纯数据存档"里取出来的枚举值，一定会退化成 `int`**。凡是把它赋给枚举类型属性 /
  参数的地方，都要显式转型。本工程已知会踩的位置：`InputEventKey.keycode` / `physical_keycode`
  （本项目已修）、`DisplayServer.window_set_mode()` 的 `WindowMode`、
  `DisplayServer.window_set_flag()` 的 `WindowFlags`、`TileMap` 的 `TileSet` 枚举等。
- **回流模板**：
  1. 与 001 合并做**一条** lint 规则即可：`shadowed_builtin` 管命名遮蔽，另加 `int_to_enum` 管
     "`int` 变量直接赋给已知枚举类型属性" —— 后者可先退一步做成"提示级"清单：
     `physical_keycode` / `keycode` / `window_set_mode` / `window_set_flag` 等已知枚举位点，
     发现赋值源是 `int(bool)` 变量就报。
  2. **`AGENTS.md` 的「Godot 坑」补两条**（这两条是本次真正学到的东西）：
     - *枚举转型告警与命名遮蔽告警一样，只在编辑器导入/脚本重载时出现，headless 冒烟看不到*；
     - *`var_to_bytes()` 不保存枚举类型，读回来是 `int` —— 存档里的枚举值必须 `as` 转型*。
  3. **存档契约那节补一句**：分段字段里可以放枚举（落盘就是 int），但**读档后必须按 int 处理**，
     别假设它还是枚举类型。这条对"以后往存档里加枚举"的人很重要。

### 006 第三方插件 shader 里的 mod(x, 0.0) 除零

- **日期**：2026-10-02
- **类型**：初级错误
- **严重度**：功能级（不报错、不崩溃，但滚动动画与云层**静默失效**）
- **位置**：`addons/naejimer_3d_planet_generator/shaders/body.gdshader:29`、
  `shaders/clouds.gdshader:11`、`:12`
- **状态**：已修
- **是否回流模板**：否 —— 这是**改 `addons/` 里的第三方插件**（插件随包引入，不是模板的一部分）；
  按 `AGENTS.md` 的要求在此单独说明改动理由

**现象**：没有任何报错。气态行星 / 恒星的"纹理流动"看不见效果，挂了 `next_pass` 的两个场景
（`planet_terrestrial`、`planet_ice`）**云层完全不正常**。

**原因**：三处都写成 `mod(<坐标> + TIME * <速度>, 0.0)`。GLSL 的 `mod(x, y)` 定义为
`x - y * floor(x / y)`，除数为 `0.0` → 除零 → 结果是 **NaN**；拿 NaN 当 UV 去 `texture()` 采样，
结果未定义（通常表现为黑/边缘色）。**Shader 里的除零不会报错**，所以只表现为"效果没了"。

**为什么会有这个写法（推断，不是定论）**：`body.gdshader` 头部注释指向 2020 年的 Godot 3 时代
reddit 帖，而 Godot 3 的 `mod()` 吃 `vec2`（原文大概率是 `mod(x, vec2(1.0))`）；
移植到 Godot 4 时参数被改成了标量 `0.0`，`1.0` 丢了。没能拿到上游 shader 原文做逐行 diff，
所以"移植引入"是依据注释年代的推断。

**改动**：三处 `mod(..., 0.0)` → `fract(...)`，并各加一行注释说明为什么不写 `mod`：

```glsl
// body.gdshader: 改前 mod(position + TIME * 2.5 * noise_gaseous_speed / 10.0, 0.0)
position = fract(position + TIME * 2.5 * noise_gaseous_speed / 10.0);
// clouds.gdshader: 两层同理
vec4 noise_1 = texture(noise_texture, fract(UV + TIME * 2.5 * speed / 10.0));
vec4 noise_2 = texture(noise_texture, fract(UV + TIME * (2.5 + fluffiness * 3.0) * speed / 10.0));
```

**为什么选 `fract()` 而不是 `mod(x, 1.0)`**：这三处意图就是"取小数部分"，`fract()` 语义直白、
少一次除法；且 `TIME` 变大后 `mod` 会有精度损失（滚动抖动），`fract` 没有。

**验证**：shader 编译错误在 headless 下**不一定暴露**（惰性编译），所以不能只看"场景跑起来没报错"。
用探针强制触发解析 —— `Shader.get_shader_uniform_list()` 拿不到 uniform 列表就说明没编译成功：

```
[OK] body.gdshader       模式=0  uniform 数=17
[OK] clouds.gdshader     模式=0  uniform 数=5
[OK] atmosphere.gdshader 模式=0  uniform 数=6
```

外加 `godot-lint.ps1` `error=0 warn=0`、`verify-engine.ps1` 无新增 ERROR/WARNING。
**外观没做像素级验证**（headless 不栅格化）—— 云层/流动是否真的出现必须开窗口看。

**教训 / 回流做法**：

- **通用结论**：`mod(x, 0.0)` 是 shader 里的"静默失效"写法 —— 不报错、不崩溃，只是效果没了。
  要"取小数部分"就直接写 `fract()`。
- **通用结论（验证手法）**："场景能加载"不等于"shader 编译通过"。
  用 `get_shader_uniform_list()` 探针（或真开窗口）确认；headless 冒烟在这件事上没有证明力。
- **回流模板：否**。但 `AGENTS.md` 的「Godot 坑」值得补一条：*shader 编译错误在 headless 下不暴露*。

### 007 删掉一个事件常量却漏改引用，导致整工程编译失败

- **日期**：2026-10-02
- **类型**：初级错误
- **严重度**：阻断级（`core/game_flow.gd` / `ui/options/options.gd` 全部 Parse Error，游戏起不来）
- **位置**：`core/events.gd`（删 `OPEN_CREDITS`）→ `core/game_flow.gd`、`ui/options/options.gd`
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：改主菜单时一度决定"制作人员也走占位界面"，于是删掉了 `Events.OPEN_CREDITS` 常量。
下一次跑引擎验证直接炸：

```
SCRIPT ERROR: Parse Error: Cannot find member "OPEN_CREDITS" in base "Events".
ERROR: Failed to load script "res://core/game_flow.gd" with error "Parse error".
ERROR: Failed to load script "res://ui/options/options.gd" with error "Parse error".
```

**原因**：**所有引用 `Events.*` 的脚本都会在编译期解析常量**，某个常量被删就会让**每一个引用它的脚本**
整体编译失败 —— 不是"运行时取不到"，而是整个脚本加载不了。当时有 4 处引用散在 2 个文件里，肉眼没扫干净。

**改动**：把 `OPEN_CREDITS` 加回去（事件驱动比"流程层猜是谁点的"更清晰），
`game_flow` 订阅它并打开制作人员占位界面；`options.gd` 的引用保持不变。

**验证**：主菜单链路探针 **8/8 PASS**：6 个按钮齐全 → 车间打开占位界面且标题翻译正确 →
设置界面打开 → 点"制作人员"后**设置已关闭、占位界面带正确标题打开**（同层不叠两个界面）。
外加 lint `error=0 warn=0`、引擎验证无新增行。

**教训 / 回流做法**：

- **通用结论**：删/改 `Events`、`Paths`、`Types` 里的常量，**必须全仓搜一遍引用**再动手。
  这类"集中常量"的代价就是**改名即全局编译失败**（好处也在这：不会静默出错）。
- **回流模板（可执行的）**：`scripts/godot-lint.ps1` 加一条 `const_ref` 检查 ——
  扫描 `Events.<NAME>` / `Paths.<NAME>` / `Types.<NAME>` 的引用，与三个集中文件里真实声明的常量求差集，
  引用不存在的常量就报 **error**。这样"漏改引用"在静态阶段就拦住，不用等引擎编译。
- 另记一条**环境层面的坑**：**Godot 编辑器开着某个场景**时，用文件工具重写那个 `.tscn`
  可能被编辑器的保存覆盖回去 —— 表现为"写入成功但内容变回旧版"。
  判断方法：写入后**立刻比对哈希/行数**；必要时先让编辑器关掉那个场景再改。

### 008 资源里存内部类与带类型数组，.tres 静默丢数据

- **日期**：2026-10-03
- **类型**：初级错误
- **严重度**：功能级（不报错、不崩溃，但数据全丢 —— 星系配置读回来是空的）
- **位置**：`ui/galaxy/galaxy_config.gd`（内部类 + `Array[自定义类型]`）→ `ui/galaxy/galaxy.tres`
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：`galaxy.tres` 里明明有 3 个环、7 颗星球，代码里 `_config.rings.size()` 却是 **0**；
把数组改成不带类型后环数对了（3），但每个环的 `radius` / `planets` 全是 **null**。
全程**没有任何报错或警告**。

**原因**（两个独立的坑叠在一起）：

1. **内部类无法被序列化**。原来写成：

   ```gdscript
   class_name GalaxyConfig
   extends Resource
   class PlanetEntry: extends Resource   # ← 内部类
   class Ring: extends Resource          # ← 内部类
   @export var rings: Array[Ring] = []
   ```

   `ResourceSaver.save()` 存出的 `.tres` 里，内部类的脚本被写成**空的**：

   ```
   [sub_resource type="GDScript" id="GDScript_x47ex"]     ← 没有 path、没有 source_code
   [sub_resource type="Resource" id="Resource_r4pn2"]
   script = SubResource("GDScript_x47ex")                ← 指向空脚本
   label = "恒星"
   ```

   加载回来这些 Resource 是**没有脚本的空对象**，自定义属性取不到（返回 null）。
   文件里数值都在，就是绑不上去。

2. **带类型的数组在 `.tres` 里解析不了**。`@export var rings: Array[Ring]` 会被存成：

   ```
   rings = Array[SubResource("GDScript_x47ex")]([SubResource("Resource_rkct8"), ...])
   ```

   元素类型位置写的是**子资源引用**而不是类型名 —— 资源解析器不认这种写法，
   于是**整个数组被丢掉**（不报错），`rings` 回到默认的 `[]`。

**改动**：

- 新增 `ui/galaxy/galaxy_ring.gd` / `ui/galaxy/galaxy_planet.gd`：把两个内部类提成
  **独立顶层脚本**（各自 `class_name`），`galaxy_config.gd` 里删掉 class 定义、
  改用 `GalaxyRing` / `GalaxyPlanet`；
- 两个数组声明去掉类型（`Array` 而不是 `Array[Ring]`）—— 元素类型仍由 `.tres` 里
  各元素自己的 `script` 决定，不受影响；
- 改完后 `.tres` 变成用 **ext_resource** 正常引用三个脚本，数组也变成普通 `[...]` 语法。

**验证**（改完必须**读回断言**，不能只看文件内容）：

| 检查 | 结果 |
|---|---|
| `rings.size()` | 3 |
| 每个环的 radius / planets | 320/2、820/3、1500/2（不再是 null） |
| 场景里实际生成的星球 | 7 颗，位置半径与配置逐一相符 |
| 主菜单里星系实例化 | GalaxyRoot 1 个子节点、7 颗星球、相机 `is_current()=true` |

外加 lint `error=0`、`verify-engine.ps1 -Scenario res://ui/galaxy/galaxy.tscn` 无新增 ERROR/WARNING。

**教训 / 回流做法**：

- **通用结论**：用自定义 `Resource` 存配置（`.tres`）时，**不要用内部类**、
  **不要给导出数组写元素类型**。两个坑都是"静默丢数据"，靠日志发现不了，
  只能靠断言（本例是"文件里 3 个环、代码读到 0 个"暴露的）。
  可用形式：独立顶层脚本 + `@export var items: Array = []`。
- **通用结论（验证手法）**：**写完 `.tres` 必须读回来断言字段值**。
  只检查"文件里有这些行"完全不够。`ResourceSaver.save()` 返回 OK 只说明写成功，不代表能读回。
- **回流模板**：`AGENTS.md` 值得加一条：*自定义 Resource 配置里不要用内部类、
  不要用 `Array[自定义类型]`；存完必须读回断言*。这条和"存档分段只放纯数据类型"是同一类约束
  （都是序列化边界的坑）。
- **后续**：本条涉及的两个脚本后来按 `data/` 分层约定挪到 `data/types/galaxy_body.gd`
  和 `data/types/galaxy_config.gd`；结论不变。

### 009 lint 脚本用 -Project 传相对路径，allow 列表全失配、误报 43 条

- **日期**：2026-10-03
- **类型**：工程实践
- **严重度**：阻断级（`error=43`，退出码 1，门禁直接红；但工程本身是好的）
- **位置**：`scripts/godot-lint.ps1:34`（`-Project` 参数解析）
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：跑

```powershell
pwsh scripts/godot-lint.ps1 -Project taptap_game_jam_2026   # 相对路径
```

得到 `error=43 warn=6`，其中 **26 条 `paths` + 15 条 `events`**，报的全是
`core/paths.gd` 和 `core/events.gd` 自身 —— 也就是**本该被 allow 掉的那两个文件**。
把参数换成绝对路径 `-Project C:\repos\...\taptap_game_jam_2026`，立刻变成 `error=0`。

**原因**：allow 列表按**工程相对路径**写（`core/paths.gd`），比对函数是

```powershell
function Get-ProjectRelPath { param([string]$FullName)
    return ($FullName.Substring($Project.Length).TrimStart('\', '/') -replace '\\', '/') }
```

`$FullName` 恒为**绝对路径**，而 `$Project` 是调用方原样传进来的字符串。
脚本从没用 `Resolve-Path` 归一化过 `$Project`，所以传相对路径时
`Substring($Project.Length)` 切的是"绝对路径去掉 22 个字符"，得到一个**永不匹配**的垃圾串，
`$pathsAllow -contains $prel` 与 `$eventsAllow -contains $prel` 全部为假 → 全量误报。

顺带一个同源问题：脚本默认值是写死的 `Join-Path $repoRoot 'godot-template'`，
而工程目录早已改名为 `taptap_game_jam_2026` → **不带 `-Project` 直接报"没有 project.godot"**。

**改动**：

- 参数校验之后补一行归一化：
  `$Project = (Resolve-Path -LiteralPath $Project).Path`；
- 默认值改成**自动探测**：扫仓库根下含 `project.godot` 的子目录，按名字排序取第一个，
  多个时打印提示；一个都没有才报错退出。

**验证**：

| 调用方式 | 结果 |
|---|---|
| `pwsh scripts/godot-lint.ps1`（不带参数） | `error=0 warn=6` |
| `-Project taptap_game_jam_2026`（相对） | `error=0 warn=6` |
| `-Project taptap_game_jam_2026\`（带尾斜杠） | `error=0 warn=6` |
| `-Project C:\repos\...\taptap_game_jam_2026`（绝对） | `error=0 warn=6` |

**教训 / 回流做法**：

- **通用结论**：脚本里凡是"拿两个路径做字符串相减 / 前缀比对"的地方，
  参数入口**必须先 `Resolve-Path` 归一化**，否则相对路径会静默产生垃圾结果 ——
  这类 bug 不报错，只是**结论反了**（本该 0 条变成 43 条），比崩溃更难发现。
- **通用结论**：把目录名写进脚本默认值是技术债。工程改名 / 换层时脚本不会一起改，
  表现是"静默扫错目录"或"直接报找不到"。默认值应**探测**而不是**写死**。
- **通用结论（元）**：**门禁脚本本身没有门禁**。43 条误报如果被当成"存量噪声"接受下来，
  真正的违规就会被埋掉。改动门禁脚本后，要**用几种参数形态各跑一遍**确认结论稳定，
  别只跑自己习惯的那一种。
- **回流模板**：`scripts/godot-lint.ps1` / `verify-engine.ps1` 都补上
  `Resolve-Path` 归一化 + 工程目录自动探测。

### 010 拿静态 AABB 量插件星球半径，量出的数字全错

- **日期**：2026-10-03
- **类型**：初级错误
- **严重度**：功能级（不会崩，但会**推导出完全错误的结论并据此改参数**）
- **位置**：`ui/galaxy/galaxy.gd` 的调参与验证过程（探针里用 `MeshInstance3D.get_aabb()`）
- **状态**：已修（改用渲染实测）
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：为了排"星球太大 / 太小 / 出框"，写探针量每个插件的**基准半径**，得到：

| 场景 | 静态 AABB 量出的"基准半径" | 按此推算的"世界半径"（乘配置 `scale`） |
|---|---|---|
| star | 1080 | 518 |
| terrestrial | 353 | 265 |
| no_atmosphere | 173 | **48 461**（`scale=280`） |
| gaseous | 720 | **215 997**（`scale=300`） |

于是得出"两颗行星半径 21 万，把整个星系吞了"的结论，并准备大改配置。
**但真开窗口渲一张图，画面是正常的**：金色恒星、轨道环、若干大小合理的行星圆盘，
那两颗"21 万半径"的气态 / 无大气行星**就是普通大小的圆盘**。

**原因**（两层）：

1. 这些场景的 `MeshInstance3D` **自身就烘焙了极大的 transform**（`star.tscn` 是 ×1200，
   `planet_gaseous.tscn` 是 ×800），而配置里的 `scale`（0.48 / 300）是在**反向补偿**它 ——
   所以星体之间真正的**可见**半径彼此接近（肉眼估 250~460 世界单位），
   根本不是 AABB 乘出来那种数量级。
2. 插件的 `body.gdshader` / `atmosphere.gdshader` 做**顶点位移与菲涅尔外壳**，
   实际画出来的球面**不落在网格 AABB 上**；而 `get_aabb()` 的语义在"是否已含节点缩放"
   上还会随 `MeshInstance3D` / 网格资源而变，用 `Transform3D` 手动变换 AABB 时再乘一次
   `basis.get_scale()` 就会**重复计入缩放**。我先后写出过三种算法，得到三组互相矛盾的数字
   （0.7 / 518 / 48 461），**没有一组对得上画面**。

**改动**：

- 放弃用 AABB 推导任何"看起来多大"的结论；
- 改成**渲染实测**：非 headless 起窗口 → 把 `galaxy.tscn` 挂进离屏 `SubViewport`
  → `get_texture().get_image().save_png()` 存图 → **读图**（人眼）+ 对像素做
  **连通域统计**（采样步长 2、亮度阈值 0.30、面积 ≥ 24 采样点）数出画面上真正可见的
  天体个数与屏幕坐标。

**验证**（这才是可信的判据）：

| 检查 | 结果 |
|---|---|
| 静态 AABB 结论"两颗行星半径 21 万" | **与画面矛盾，判定为错** |
| 渲染图肉眼 | 恒星 + 轨道环 + 正常大小的行星圆盘，构图合理 |
| 连通域统计 | 恒星 1 个（屏幕半径 ≈ 196px）、**行星只找到 5 个**（4 个完整 + 1 个贴右边缘被裁） |
| 扫 `camera_pitch_deg` = 0/20/30/40 | 0° 最好（5 个），抬高反而降到 3~4 个 |
| 扫 `camera_distance` = 6800→13000 | 拉远不增反减（缩成团互相重叠，仍 4 个）；拉近边缘被裁 |

**教训 / 回流做法**：

- **通用结论**：**涉及"渲染出来是什么样"的结论，只能靠渲染实测**（存图 + 读图 /
  像素统计）。网格的 AABB、节点的 `scale`、场景文件里的 transform 都**不能**推出可见尺寸，
  尤其当材质带顶点位移、外壳、菲涅尔时。
- **通用结论**：同一个量用不同算法量出**三组矛盾数字**时，说明**度量方法本身是错的**，
  此时继续调参数等于在错的地基上施工 —— 应当立刻换成"能对上现象的"度量
  （本例：直接看图 + 数像素）。
- **通用结论**：`headless` 下渲染结果无效，验证视觉必须**非 headless** 起窗口
  （`verify-engine.ps1 -Probe` 恒为 headless，只能用来跑逻辑；视觉要自己调
  `& $godot --path <proj> --script res://_probe.gd`）。
- **回流模板**：`AGENTS.md` 的「Godot 坑」补一条：*不要用 `get_aabb()` / 节点 `scale`
  推断插件的可见尺寸；视觉结论必须非 headless 渲染实测*。并把"离屏 SubViewport 存 PNG"
  的探针写法收进模板，作为视觉验证的标准手法。

### 011 网格行数从槽数推导，4x4 被压成 4x3

- **日期**：2026-10-04
- **类型**：初级错误
- **严重度**：功能级（界面出来了，但网格少一行、外圈少 2 格）
- **位置**：`ui/workshop/workshop.gd` 的 `_build_slots()`
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：车间「制作」页要 4x4 网格、只在外圈放 12 个部件槽。实测出来是 **4 列 3 行**：
外圈只有 **10** 个 Slot，中间 2 个空位，和部位表 12 项对不上。

**原因**：我把"总格位数"算成了 `max(slots.size(), columns)` —— 因为**外圈槽数刚好等于部位表项数（12）**，
于是总格位 = 12，`12 / 4 = 3` 行。
但外圈格数是 `2*(行+列) - 4`（4x4 → 12），**不等于行 x 列**；用槽数当总格位数必然压扁网格。

**改动**：
- `WorkshopLayout` 加 `@export var rows: int = 4`，**行数单独配**，不再从槽数推；
- `_build_slots()` 用 `total = columns * rows` 铺格位；
- 新增 `_outer_slot_count(columns, rows)` 算外圈应有几个，与部位表项数**比对并告警**
  （`部位表有 N 项，但 4x4 网格的外圈需要 12 项`）—— 配置写错时能立刻看见，而不是默默少放几个槽。

**验证**：探针打印 16 个格位，得到 `S S S S / S · · S / S · · S / S S S S`，
**部件槽 12 / 空占位 4**，每格 270x270，与部位表 12 项一一对应。

**教训 / 回流做法**：

- **通用结论**：网格的**行数/列数必须显式配置**，不要用"子节点数量"去推 ——
  只有"满格矩形"时两者才恰好相等，一旦网格缺格（外圈、L 形、洞），推导就错。
- **通用结论**：配置项的**数量**和它要填的**位置数**是两个独立概念，
  代码里应当**断言两者相等并告警**，而不是拿其中一个去当另一个用。
- **回流模板**：`AGENTS.md` 的 UI 约定加一条：*网格布局的行列数写进配置，
  不要从子节点数推导；数量不匹配要 push_warning*。

### 012 入树前调用 setter，setter 里 @onready 还是 null

- **日期**：2026-10-04
- **类型**：初级错误
- **严重度**：阻断级（每建一个槽报一次脚本错误，且整段函数中断）
- **位置**：`ui/workshop/slot.gd` 的 `_refresh()`（被 `set_placeholder()` 调用）
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：父级批量造槽时报 10+ 次：
```
SCRIPT ERROR: Invalid assignment of property or key 'texture' with value of type 'Nil' on a base object of type 'Nil'.
       [3] _build_slots (res://ui/workshop/workshop.gd:72)
```
（报在父级的行号上，因为调用栈是父级 → setter；真正的锅在 Slot 里。）

**原因**：父级的常见写法是
```gdscript
var slot := scene.instantiate()
slot.set_placeholder(def.name_key)   # ← 此刻还没 add_child
add_child(slot)
```
`instantiate()` 出来的节点**还没入树**，`@onready var _name_label: Label = %NameLabel`
要等 `_ready()` 才赋值 —— 所以 setter 里访问它是一个 **null**。

**改动**：`_refresh()` 开头判空直接返回：
```gdscript
if _icon == null or _name_label == null:
    return
```
状态（`_part` / `_placeholder_key`）**照常存下来**，由 `_ready()` 补一次 `_refresh()`，
所以"先设值后入树"和"先入树后设值"两种调用顺序结果一致。

**验证**：修复后同样的探针，12 个槽的中文名（头部/左肩/…/右脚）全部正确显示，
无脚本错误；渲染图确认外圈 12 个槽都有部位名。

**教训 / 回流做法**：

- **通用结论**：**组件的 setter 必须容忍"还没入树"**。
  父级 `instantiate() → 配置 → add_child()` 是很自然的写法，
  组件不该要求调用方必须先入树。做法：`@onready` 字段用前判空 + 存住状态 + `_ready()` 补刷新。
- **通用结论**：报错行号在**调用方**（父级）时，别急着改父级 ——
  看调用栈里被调用的那个函数，问题通常在组件自己的 setter 里。
- **回流模板**：`AGENTS.md` 的 Godot 坑加一条：*可复用组件的 setter 要容忍未入树
  （`@onready` 此时为 null）；状态存下来、`_ready()` 补刷新*。

### 013 门禁盲区：孤儿 key 检查没扫 .tres

- **日期**：2026-10-04
- **类型**：工程实践
- **严重度**：阻断级（`error=1 warn=12`，门禁直接红；但工程本身是好的）
- **位置**：`scripts/godot-lint.ps1` 的规则 5（`locale_orphan`）
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：把 12 个部位名的翻译 key 放进 `data/resources/workshop_layout.tres`（`name_key` 字段）后，
lint 报 **12 条 `locale_orphan`**：说这些 key"三处都有但没人引用"。
但它们明明被 `.tres` 引用了。

**原因**：该规则的"引用来源"只拼了 `.gd` 与 `.tscn`：
```powershell
$referenceBlob = (Get-ScanFiles -Dirs $scanDirs -Extensions @('.gd', '.tscn') | ...
```
**没有 `.tres`**。而本项目**刻意**把可配置数据（含翻译 key）放在 `data/resources/*.tres`，
所以只要配置里写翻译 key，就必然被误判成孤儿。

**改动**：扫描扩展名补上 `.tres`：
```powershell
Get-ScanFiles -Dirs $scanDirs -Extensions @('.gd', '.tscn', '.tres')
```
（其它规则不受影响：`scene_tree` 只扫 `.gd`，其它规则有自己的扩展名列表。）

**验证**：改前 `error=1 warn=12`（12 条孤儿 + 1 条汇总），改后 `error=0 warn=0`，
且 12 个 key 在 `.tres` 里被正确识别为"已引用"。

**教训 / 回流做法**：

- **通用结论**：**"引用"的判定必须覆盖所有可能写引用的文件类型**。
  本项目把配置放进 `.tres`，那么 key/路径的引用来源就**必须包含 `.tres`** ——
  否则每加一类"配置里带翻译 key"的数据，门禁都会误报。
- **通用结论**：门禁报"没人引用"时，先确认**它扫了哪些文件**，再怀疑自己的配置。
  这次是规则的盲区，不是配置的问题 —— 改配置去迁就门禁会走错方向。
- **回流模板**：`scripts/godot-lint.ps1` 的 orphan 规则补 `.tres`；
  模板里加一句注释说明"翻译 key 可以写在配置资源里"。

### 014 Button 的 font_size 覆盖不会传给子 Label

- **日期**：2026-10-04
- **类型**：初级错误
- **严重度**：功能级（不报错、界面正常，但**字号没生效** —— 最坏的一种：看起来改了其实没改）
- **位置**：`ui/workshop/slot.tscn`（字号原设在 Button 上，Label 是子节点）
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：给部件槽的 Label 放大字号，`.tscn` 里写了
`Slot(Button)` 节点上 `theme_override_font_sizes/font_size = 44`，
用探针读 `label.get_theme_font_size("font_size")` 得到 **44**，看着是对的。
但**实际渲染出来的字很小**：实测文字笔画包围盒只有 **31x16 px**，
而 44 号字两个汉字应该约 86x43 px。

**原因**：**主题覆盖不会沿树往下传**。`theme_override_font_sizes/font_size` 是设在
**Button 自己**的主题链上的；Label 是子节点，它查 `font_size` 时走的是**自己**的链
（自己 → 祖先的 `theme` 资源 → 项目默认主题），**不会去读父节点上的同名 override**。
所以那次设置等价于没设，Label 用的是默认 16 号。

**为什么差点漏掉**：`get_theme_font_size()` 这个 API **不报错也不校验**，
它只是"沿着主题链查到这个值就返回"。设在父节点上时它照样返回 44 ——
**API 的返回值 ≠ 子节点实际用的值**。是"量渲染像素"才把问题挖出来的。

受控对比（同一段代码，只改字号设在哪）：

| 写法 | 实测笔画 | 结论 |
|---|---|---|
| 字号设在**父 Button** 上 | 31x16 | ❌ 不生效 |
| 字号设在 **Label** 上 | 86x43 | ✅ 生效 |
| 都不设（默认） | 31x16 | 与第一种相同，证明前者等于没设 |

**改动**：把 `theme_override_font_sizes/font_size = 44` 从 `Slot` 节点
**移到 `NameLabel` 节点**上。

**验证**：`_probe_style.gd` 实测文字笔画中心与格子中心偏差 **0.5px / 1.0px**（居中），
文字到左右边缘各 92 / 93 px（对称）；渲染图确认部位名明显变大且居中。

**教训 / 回流做法**：

- **通用结论**：**主题 override 只作用于该节点自己，不会继承给子节点**。
  要给子节点设字号/颜色，就设在**子节点**上；想全局生效就用 `Theme` 资源挂到共同祖先。
- **通用结论（验证手法）**：**"设了"和"生效了"是两件事**。
  凡是通过主题/继承生效的样式，**必须量渲染结果**（像素包围盒 / 取色），
  不能只信 `get_theme_*()` 的返回值 —— 它反映的是"查得到什么"，不是"子节点用什么"。
- **通用结论**：这类"静默不生效"和 `.tscn` 里属性名写错是同一类问题 ——
  引擎不报错，只能靠**实测现象**发现。凡是视觉属性，改完都要渲一张图核对。
- **回流模板**：`AGENTS.md` 的 Godot 坑加一条：*`theme_override_*` 不继承给子节点；
  样式类改动的判据是渲染实测，不是 `get_theme_*()` 的返回值*。

### 015 容器里的子节点不加 size_flags 就不会被撑开

- **日期**：2026-10-04
- **类型**：初级错误
- **严重度**：功能级（界面能看，但网格只占左上角一小块）
- **位置**：`ui/workshop/slot.tscn`（Slot 根节点没有 `size_flags`）+ `workshop.tscn` 的 `Grid`
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：为了让 12 个格子"彼此分开、变小留缝"，把 `GridContainer` 的
`h_separation` / `v_separation` 从 0 改成 16，并给 Slot 设了
`custom_minimum_size = 120x120`。结果实测：

```
SquareRegion size=1080x1080
Grid         size=1080x1080
[0,0] Slot0  x[0..120]   size=120x120
[0,1] Slot1  x[136..256] <- 缝 16
4 格 + 3 缝 = 528（容器宽 1080）
```

网格是有 1080 大，但**格子全挤在左上角 528x528 的区域**，右边和下面空着。

**原因**：**`GridContainer` 只有在子节点带 `size_flags = EXPAND`（值为 3）时，
才会把多余空间分给格子**。`custom_minimum_size` 只决定**下限**，不会让节点变大。
我只设了下限、没设 EXPAND，所以每列宽 = 该列子节点的最小宽（120），4 列 + 3 缝 = 528。

（`GridContainer` 对**行**也看 `size_flags_vertical & SIZE_EXPAND`，两个方向都要设。）

**改动**：Slot 根节点加两个标志，并把最小尺寸抬到 160（格子实际会有 258，最小尺寸只在下限时生效）：
```
size_flags_horizontal = 3
size_flags_vertical = 3
```

**验证**：同样的探针，改后：

| 检查 | 结果 |
|---|---|
| 每格 | **258x258**（正方形） |
| 横向缝隙 | 16 / 16 / 16 |
| 4 格 + 3 缝 | **1080 = 容器宽**（正好铺满，没撑出） |
| 网格超出容器 | false |

**教训 / 回流做法**：

- **通用结论**：**`custom_minimum_size` ≠ 会被撑开**。
  容器里的子节点要"填满可用空间"，必须给 `size_flags_horizontal / vertical = SIZE_EXPAND_FILL(3)`；
  只给最小尺寸的话，节点就停在最小尺寸上，容器多出来的空间全空着。
- **通用结论**：调容器布局时，**验证要量"实际矩形"**（每格的位置与尺寸 + 总和是否等于容器），
  不能只看"容器自己有 1080 大"就以为内容铺满了 —— 容器尺寸对、内容挤在角落，是很常见的错。
- **回流模板**：`AGENTS.md` 的 UI 约定加一条：*容器里的子件要填满空间必须设 `size_flags = 3`；
  `custom_minimum_size` 只是下限*。

### 016 Tween 与"每帧跟随"抢同一个属性：瞬移 → 卡住 → 回跳

- **日期**：2026-10-07
- **类型**：初级错误
- **严重度**：功能级（能跑，但进地图后的镜头行为完全不是想要的）
- **位置**：`ui/galaxy/galaxy.gd` 的 `focus_on_body()` / `_process()`
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**（用户原话）："我在进入地图后，有一个 2 秒的延迟，摄像机才会聚焦到星球上"。

引擎没有任何报错。实测（非 headless 截图 + `unproject_position` 投影实测，每 0.05~0.6 秒采一次）：

```
01_first  相机=(-884,198,364)   距离=648  投影中心=(540,1200)   <- 第一帧就已经在特写位
02_t0.30  相机=(-867,198,376)   距离=648  投影中心=(540,1200)
```
等等 —— 上面是**修好之后**。修之前是：

```
01_t0.05  相机=(-941,199,314)  距离=648  投影中心=(540,1200)
02_t0.30  相机=(-942,199,313)  距离=666  投影中心=(494,1180)   <- 相机卡住不动
03_t0.70  相机=(-949,199,308)  距离=700  投影中心=(413,1146)
04_t1.10  相机=(-950,199,307)  距离=728  投影中心=(348,1121)   <- 星球已经飘到左上方
05_t1.50  相机=(-845,199,390)  距离=648  投影中心=(540,1200)   <- 猛地跳回来
```

也就是：**瞬移到位 → 相机在世界坐标里卡住约 1.2 秒（星球照常公转，于是在画面里越飘越远）→ 再突然跳回正中**。
用户看到的"延迟两秒才聚焦"，就是这 1.2 秒的卡住 + 回跳。

**原因**：进入特写时同时存在**两个写入者**，写的是同一个属性 `Camera3D.global_position`：

1. `focus_on_body()` 里 `create_tween()` 的 `tween_property(_camera, "global_position", dest, focus_duration)`；
2. `_process()` 里"每帧把相机摆到 `天体位置 + 固定偏移`"（跟随公转必须每帧写）。

同一帧内谁后写谁赢。`Tween` 的初始值是**第一次 step 时才取的**，而那时 `_process` 已经把相机
写到了终点，于是这个 Tween 的"起点 = 终点"，它每帧都往同一个位置写 ——
1.2 秒内持续覆盖掉 `_process` 的正确跟随值（表现为卡住），Tween 一结束覆盖消失，
`_process` 的值立刻生效（表现为回跳）。

**改动**：

- **进入特写的漫游不再用 Tween**，改成自己插值：新增 `_focus_rel_from`（进入瞬间"相机相对天体"
  的偏移）、`_focus_elapsed`（自己数秒）、`_apply_focus_camera()`（**唯一的写入者**），
  `_process` 每帧只调这一个函数；`focus_on_body()` 末尾也立刻调一次（否则进地图的第一帧还是全景）。
  `_ease_cubic_in_out()` 自己实现了 `TRANS_CUBIC + EASE_IN_OUT` 同形的缓动。
- 相机插值的起点用**相对天体的偏移**而不是绝对坐标：天体在公转，存绝对位置会让漫游路径跟着跑偏。
- `focus_duration` 默认改成 **0 = 立即锁定**（用户要"进去就对上"）；退出特写的回程另开一个
  `reset_duration = 1.2`，仍然是 Tween（那时 `_focus_target` 已经是 null，没有第二个写入者）。
- `focus_on_body()` 里仍然 `kill()` 掉可能还在跑的归位 Tween（快速开关地图时它会写同一个属性）。

**验证**：

- 非 headless 截图探针（`--path . res://_probe_map_shot.tscn`），进地图后逐帧抓
  `get_viewport().get_texture().get_image()` + `unproject_position(天体)`：
  - 修后 `01_first`（**第一帧**）就是 距离 648 / 投影中心 (540,1200)，此后每一采样都**恰好** 648 与 (540,1200)，
    0.1→3.2 秒全程无漂移、无回跳；
  - 退场（点返回）后回程平滑（0.05s 距离 663 → 0.30s 1514 → 0.70s 8686 → 1.10s 11244 ≈ 归位），
    且 `可见天体 7/7、可见轨道线弧段 6`；
  - 把 `focus_duration` 临时改成 1.2 再跑一遍（漫游分支）：距离 11339 → 10589 → 3590 → 665 → 648，
    投影中心**每一帧都是 (540,1200)** —— 漫游期间天体也始终在正中。
- `pwsh scripts/godot-lint.ps1`：`error=0 warn=0`。
- `pwsh scripts/verify-engine.ps1 -Project taptap_game_jam_2026`：无新增 ERROR/WARNING（基线 5 行）。

**教训 / 回流做法**：

- **通用结论**：**同一个属性只能有一个写入者。** 用 Tween 动画某个属性时，
  如果别的代码（`_process` / 物理帧 / 另一个 Tween）也在写它，行为会变成"谁后写谁赢"，
  而且 `Tween` 的起点是**延迟到第一次 step 才取**的 —— 期间别人改写过的值会变成它的"起点"，
  于是动画变成"原地不动"。这类 bug **不报错**，只能靠逐帧采样发现。
- **通用结论**：需要"跟随一个一直在动的目标"时，不要用 Tween + 每帧修正两套机制，
  直接自己插值（一个写入者 + 自己数 `elapsed`）。
- **通用结论**：`0 时长` 的语义要在配置里写清楚（这里是"立即锁定"），
  Tween 的 `duration = 0` 依然会占用一个写入者，容易踩上面这个坑。
- **回流模板**：`AGENTS.md` 的 Godot 坑加一条：*同一属性只许一个写入者；
  Tween 与每帧跟随不能同时写一个属性（会静默变成"原地不动"）；跟随运动目标请自己插值*。

### 017 兜底默认配置与 `.tres` 实际配置不一致

- **日期**：2026-10-07
- **类型**：架构
- **严重度**：功能级（有配置时看不出来；缺配置/新建配置时是**另一个星系**）
- **位置**：`data/types/galaxy_config.gd` 的 `build_default()`
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：没有任何报错。`data/resources/galaxy.tres` 里是 **7 颗**天体（1 恒星 + 6 行星，
正好对应插件里的 7 个场景），而同一个类型的兜底构造函数 `GalaxyConfig.build_default()`
里还留着**10 颗**（多出 2 颗冰/气态 + 1 颗类地），而且它的
`no_atmosphere` / `gaseous` 的 `scale` 还是 280 / 300 —— 那正是
ENGINEERING_NOTES 010 里已经被渲染实测证伪的"照抄了插件烘焙 transform"的坏值
（正确值是 0.8 / 0.25）。文件头的注释也还在按老数据解释取值依据（"恒星 865"等）。

**原因**：`galaxy.tres` 是后改的（减到 7 颗、修 scale），`build_default()`
是**同一份数据的第二副本**，改一处忘一处。两份数据没有任何机制保证一致，
`build_default()` 平时根本不走（只有 `Paths.GALAXY_CONFIG` 缺失时才用），所以不会有人发现。

**改动**：

- `build_default()` 的星球表与 `galaxy.tres` 对齐（7 颗，scale 用 0.48 / 0.75 / 0.8 / 0.6 / 0.7 / 0.75 / 0.25）；
- 注释改成"**必须和 `galaxy.tres` 保持一致**"并写明基准半径依据，
  另外点名"不要照抄插件场景里的烘焙 transform（010）"。

**验证**：`pwsh scripts/godot-lint.ps1`（`error=0 warn=0`）+
`pwsh scripts/verify-engine.ps1 -Project taptap_game_jam_2026`（无新增 ERROR/WARNING）。
**注意**：这次只是把两份数据**改成一致**，没有加"自动校验一致性"的机制（下面「待办」）。
真正的运行时验证（删掉 `galaxy.tres` 看兜底星系）没有做，所以这条的状态是"已修"仅指
"两份数据已对齐"，不是"兜底路径已实测"。

**教训 / 回流做法**：

- **通用结论**：**同一份配置数据不要存在两份。** 兜底默认值一旦和实际 `.tres` 分家，
  就是"平时永远走不到、走到就是错"的死代码 —— 而且它偏偏是**出错路径**（配置丢了/读坏了），
  用户看到的是另一个游戏。
- **通用结论**：兜底数据要**从实际配置生成**（比如"配置缺失时用 `galaxy.tres` 同目录的一份
  `_default` 资源"），而不是在脚本里再手写一遍数值。本项目暂时保留手写 + 注释锁死，
  因为 `data/types/` 里放静态资源引用会违反"类型定义不引用资源实例"的分层。
- **回流模板**：`AGENTS.md` 的 `data/` 约定加一条：*`build_default()` 之类的兜底值必须与
  `data/resources/*.tres` 逐字段对齐，并在注释里互相点名；改一处必须改两处*。

### 018 量"星球在屏幕上多大"这件事，量法本身会骗人

- **日期**：2026-10-07
- **类型**：工程实践（测量方法）
- **严重度**：功能级（照错的数字标定参数，会把已经认可的取景改坏）
- **位置**：`data/resources/galaxy.tres` 的 `focus_radius_scale`（量法用的是临时探针）
- **状态**：已修（尺寸）；**光照角度差异仅记录**（见文末）
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：地图里加「< 名称 >」切天体之后，切一颗看着就像换了个镜头：
实测熔岩的圆面几乎顶满 2400 高的画面，无大气却只占 ~24% —— 差 4 倍。
`GalaxyConfig.focus_distance_factor` 是同一个值，问题出在各天体的
`focus_radius_scale` 全是默认 1.0，而"相机距离 = 估算半径 x 倍数"里的
**估算半径是网格半径**，和实际画出来的可见半径差得很远（010 的同一个根）。

**为什么第一次没量对**（两条错误的路，都走过）：

1. **两帧差分**（同一镜头拍"有星球"和"把天体全隐藏"，两张相减取剪影）：
   好几颗天体的**背光面几乎和星空一样黑**，量到的中心像素差只有
   0（无大气）/ 8（类地）/ 15（沙）/ 45（气态），阈值 40 全过不了 ——
   只有受光面被量到；7 颗里有 4 颗直接量出 0px。
2. **灰度阈值找"成片的灰"**：又有两个坑。
   - 星空 shader 的**星云是有色的**，它的亮度正好落在灰度区间里 →
     每行都被判成"星球"，水平半径被撑到 ~520px（真实 286px），
     而且每个天体朝不同方向、看到的星云不一样 → 数字随机漂；
   - 星球**大到超出画面**时水平方向被画面边界裁掉（熔岩第一轮 x[0..1076] 两边都贴边）
     → 量出的半径偏小，于是"按这个数字缩小"反而越缩越小、来回震荡。

**正解（本轮用的量法）**：

- 测量时临时给该天体下所有 `MeshInstance3D` 套一个 `material_override`
  （`StandardMaterial3D`：`albedo_color` 灰 0.35、`SHADING_MODE_UNSHADED`、双面）
  —— **灰 0.35 低于 glow 阈值 0.9，不会泛光溢出**，整颗球变成一个纯色圆盘；
- 判定像素用"接近该灰（±0.10）**且**接近中性色（RGB 互差 < 0.05）"→ 星云被排除；
- **只认垂直半径**（视口 1080x2400，竖直方向永远裁不到；水平会被裁）；
- 还要求"整行成片"（一行至少 8 个采样点）→ 星点被排除。

**改动**：以**用户已经看过并认可的"无大气"当基准**（垂直半径 286px），
迭代 3 轮 `新 scale = 旧 scale x 实测 / 目标`，写进 `galaxy.tres`：

| 天体 | 无大气 | 气态 | 恒星 | 冰 | 沙 | 熔岩 | 类地 |
|---|---|---|---|---|---|---|---|
| `focus_radius_scale` | 1.0 | 1.0385 | 1.1533 | 1.9852 | 1.9954 | 2.0256 | 2.0358 |

**验证**：同一探针复核，7 颗的垂直半径**全部 286px（偏差 +0.0%）**；
非 headless 截图对比"无大气 / 熔岩"两张，圆面尺寸一致；
`pwsh scripts/godot-lint.ps1` = `error=0 warn=0`；
`pwsh scripts/verify-engine.ps1` 无新增 ERROR/WARNING。

**教训 / 回流做法**：

- **通用结论**：**"看起来一样大"要先用像素量出来才谈得上标定。**
  绝不能用 `get_aabb()` / 节点 `scale` 推（010 已经栽过一次），也不能用
  "按公式算出来的投影半径"当实测 —— 本轮早先就犯过：把
  `unproject_position(天体 + 相机右方向 x 估算半径)` 的结果（512px）当成"实测半径"，
  那只是把配置里的数字又算了一遍（循环论证），所以"每颗都 43%"这个结论是假的。
- **通用结论**：写"量视觉尺寸"的算法前问三个问题：
  ① **暗部还认得出来吗**？（背光面可能和背景同色）
  ② **背景里还有别的东西符合判据吗**？（星云/泛光/UI）
  ③ **目标会不会超出画面被裁**？（被裁时量出的是下界）
  三个都答不上来就换量法（本轮最终用的是"临时换材质 + 只认垂直方向"）。
- **通用结论**：**基准值要选"人类已经看过并认可的那一个"**，不要自己发明。
  本轮第一次跑出来的目标值 397px 是被星云污染的错数字，照它改会让**所有**星球
  比现在大 40% —— 幸好基准星球（无大气）在同一套污染下量出来是 397，
  我才发现"目标"和"基准"用的是同一个错数，改回 286 才对上用户看过的样子。
- **回流模板**：`AGENTS.md` 的"视觉验证"一节补上这套测量配方与三个提问。

**仅记录（没修）**：各天体特写时的**受光角度不一样** —— 镜头偏移方向取的是
"全景时相机所在方向"，而光照方向固定，于是有的天体正对光、有的只露一条亮边
（无大气那张能看到明显的明暗界线穿过画面中心）。
要统一观感，得把镜头偏移方向按 `light_direction` 摆（例如固定"光从画面左上 45° 来"），
这会改变现在的构图，**需要人类拍板**，本轮没动。

### 019 ScrollContainer 抄上 mouse_filter = IGNORE，滚动直接静默死掉

- **日期**：2026-10-07
- **类型**：初级错误
- **严重度**：功能级（界面照常显示，就是**滚不动**，且不报任何错）
- **位置**：`ui/score/score.tscn`（`Scroll` 节点）
- **状态**：已修（上线前拦下，没进过仓库的可用版本）
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：新建评分界面时，`ScrollContainer` 的 `mouse_filter` 一开始照抄了本工程
其它全屏 `Control` / 面板的写法 `mouse_filter = 2`（`MOUSE_FILTER_IGNORE`）。
实测（非 headless，`Viewport.push_input` 真推滚轮事件）：

```
滚轮测试[默认 mouse_filter（STOP）]：scroll_vertical 0 → 277  能滚
滚轮测试[抄成全屏常用的 IGNORE]：  scroll_vertical 0 → 0    滚不动
```

**原因**：`MOUSE_FILTER_IGNORE` 的语义是"这个控件对鼠标完全透明"，
**鼠标事件根本不派发给它** —— 滚动条的滚轮 / 触摸拖拽都是靠控件自己收事件实现的，
所以 IGNORE 等于把滚动关掉。项目里别的全屏 `Control` 写 IGNORE 是为了"不挡住下面的东西"
（地图的 `CardArea`、`Background`），那是对的；**交互型容器不能这么写**。

**改动**：`Scroll` 去掉 `mouse_filter = 2`（用默认的 `STOP`）。
它下方只有一块纯装饰的 `Background`，挡不到任何需要点击的东西。

**验证**：上表两行就是实测输出（同一份探针里改一次 `mouse_filter` 各推一次滚轮）；
程序化滚动（`scroll_vertical = 100000` → 停在 888 = 最大值）也验了；
截图确认滚到底后能看到最后一行卡片。另外 7 张卡时内容 1087px < 滚动区 2220px，
**不出滚动条是正常的**（灌到 21 张时 max 3108 > page 2220 才滚）。

**教训 / 回流做法**：

- **通用结论**：`mouse_filter = IGNORE` **不是"不挡别人"的同义词，而是"我也不收输入"**。
  全屏装饰层可以 IGNORE；**任何要收滚轮 / 拖拽 / 点击的容器（`ScrollContainer`、
  可拖拽面板）都不能**。这类错误**不报错、界面照常显示**，只有真滚一下才发现。
- **通用结论**：**"程序化赋值生效"不能证明"输入路径通"**。
  `scroll_vertical = N` 能滚，跟滚轮能不能滚是两件事 —— 本条目第一版探针只验了前者，
  差点放过；补上"推真实输入事件"才暴露。
- **通用结论**：**用 `Viewport.push_input` 造 GUI 输入时，必须先推一次
  `InputEventMouseMotion`**（否则 Godot 不知道鼠标悬停在哪个控件上，滚轮事件会被丢掉，
  于是**测出来永远是"滚不动"**，连正确的控件都会被误判）。坐标要给**视口本地坐标**
  并传 `in_local_coords = true`，别让窗口拉伸变换再乘一遍。
  本条目第一版探针就踩了这个，得到"两种情况都滚不动"的假结论。
- **回流模板**：`AGENTS.md` 的 Godot 坑加一条：*`ScrollContainer` / 可交互容器不要写
  `mouse_filter = IGNORE`；测输入要先送 MouseMotion，且别拿程序化赋值当输入验证*。

**后续（2026-10-07 同日）**：应人类要求，**评分界面已整体删除**
（`ui/score/`、`ScoreBoard` / `ScoreEntry` / `score_board.tres` 与相关语言 key 都没了），
所以本条目「位置」里的文件**已经不在仓库里**。教训本身与文件无关 ——
将来任何 `ScrollContainer`（比如库存列表、设置里的长列表）都会踩同一个坑，条目保留。

### 020 引用了不存在的翻译 key，界面直接把 key 原文显示出来

- **日期**：2026-10-07
- **类型**：初级错误
- **严重度**：功能级（界面照常显示，只是那块文案变成 `ui.workshop.warehouse` 这样的原文）
- **位置**：`ui/workshop/workshop.tscn:165`（+ 门禁 `scripts/godot-lint.ps1`）
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**（人类发现）："车间有一个无效的 stringkey"。实测确认：

```
车间下半屏标题：节点.text='ui.workshop.warehouse' → 显示='ui.workshop.warehouse'
```

场景里那个 Label 写的是 `ui.workshop.warehouse`，而语言文件里只有
`ui.warehouse.title`（仓库）。引擎**不报错**，Label 就把 key 字符串**原样画出来**。
全工程扫一遍，这类"引用了但没定义"的 key **当时有且只有这 1 处**。

**原因**：

1. 写 key 时凭印象拼了一个（`ui.workshop.warehouse` 看着比 `ui.warehouse.title` 更"合理"），
   而 `.tscn` / 脚本里的翻译 key **没有任何编译期校验** —— 引擎只在运行时"查不到就原样返回"。
2. **门禁当时查不到这类错误**：`locale` 规则只比对"三个语言文件之间的 msgid 是否一致"，
   `locale_orphan` 只查"语言文件里有、但没人引用" —— 两个方向都不覆盖
   **"代码引用了、语言文件里没有"**。这是纯粹的盲区（和 013 是同一类问题的另一半）。

**改动**：

1. `workshop.tscn:165` 的 `ui.workshop.warehouse` → **`ui.warehouse.title`**
   （这个 key 已存在；配合下面的改名，显示为「图鉴」）。
2. **`godot-lint.ps1` 新增 `locale_missing` 规则（error 级）**：扫 `core/data/ui/entry/...` 下的
   `.gd` / `.tscn` / `.tres`，把里面出现的翻译 key 字面量逐个比对语言文件的 msgid 集合，
   对不上就报 error（带文件:行 + key）。前缀**不写死** `ui.`，而是从语言文件里现有的 key 取，
   以后加新命名空间会自动跟着查。
3. 顺带按人类要求改名：车间 → **制造**（`ui.main_menu.workshop`）、
   仓库 → **图鉴**（`ui.main_menu.warehouse` / `ui.warehouse.title`）；英文对应
   Manufacture / Codex。**只改显示值，不改 key 名**（key 是稳定标识，目录也还叫 `ui/workshop/`）。

**验证**：

- **门禁真的能拦**（故意写坏再恢复）：
  ```
  把 text 改成 ui.workshop.warehouse_typo →
  [ERROR] locale_missing taptap_game_jam_2026/ui/workshop/workshop.tscn:165
          > ui.workshop.warehouse_typo
  error=1  warn=0 → 有 error 级违规，必须修。
  改回 ui.warehouse.title 后 → error=0 warn=0
  ```
- **运行时显示**（非 headless，`tr(节点.text)` 就是 Label 画出来的字）：
  ```
  主菜单按钮（4）：设置 / 开始 / 制造 / 图鉴
  车间下半屏标题：节点.text='ui.warehouse.title' → 显示='图鉴'
  仓库标题：节点.text='ui.warehouse.title' → 显示='图鉴'
  ```
  截图确认车间下半屏标题不再是 key 原文。

**教训 / 回流做法**：

- **通用结论**：**翻译 key 是"字符串 API"，写错了不会编译报错，只会让界面显示一串 key**。
  凡是"用字符串去查表"的地方（翻译 key、输入动作名、事件名、资源路径、存档键），
  都必须有**引用端 ↔ 定义端**的双向检查：只查"定义了没人用"（orphan）**不够**，
  必须同时查"用了没定义"（missing）。
- **通用结论**：这类检查要**从定义端取前缀**，别在脚本里硬编码命名空间 ——
  否则以后加了新前缀，规则会静默漏检（和门禁自身要能被门禁是同一个道理，见 009）。
- **回流模板**：`AGENTS.md` 硬规则 3 补一句：*新增 key 三处同步**之外**，还要保证 key
  已定义 —— `godot-lint.ps1` 的 `locale_missing` 会拦"引用了但没定义"*。





### 021 同一场景里两个节点重名，find_child / % 取到哪个看树序

- **日期**：2026-10-07
- **类型**：初级错误
- **严重度**：功能级（**不报错**，但点到的是另一个按钮 / 拿到的是另一个节点）
- **位置**：`ui/map/map.tscn`（顶栏的 `NextButton` 与切换行的 `NextButton` 重名）
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：地图界面上有两个 `NextButton` —— 顶栏右上的「下一步」（进制造界面）
和切换行右边的「>」（切下一颗星球）。两者**都**带 `unique_name_in_owner = true`。
场景加载**没有任何报错**。

写验证探针时用 `map.find_child("NextButton", true, false)` 想点「切下一颗星球」，
结果点到的是**顶栏的「下一步」**：界面当场切走、`map` 被释放，下一行
`map.find_child(...)` 直接抛
`Cannot call method 'find_child' on a previously freed instance.`，
探针整个函数中断（后续代码不执行，进程挂住直到超时）。

**原因**：`find_child()`（以及 `%唯一名` 的解析）**同名时取树序靠前的那个**，
没有"重名"这个概念，也不会告警。所以"名字看着对"完全不能保证拿到的是想要的那个节点。

**改动**：把切换行的两个按钮改名去歧义：
`PrevButton` → `PrevPlanetButton`、`NextButton` → `NextPlanetButton`
（`.tscn` 里的 `[connection]` 路径同步改；顶栏那个仍叫 `NextButton`）。
产品代码本来就是用 `.tscn` 的 `[connection]` 按**完整路径**连的，所以之前没坏 ——
坏的是"按名字找"的人和探针。

**验证**：改后重跑整条链路探针，逐条对上：
```
① 地图：当前天体='熔岩行星' 下标=3            ← 切换行按钮真的切了星球
② 下一步：Map 在场=false  Workshop 在场=true   ← 顶栏按钮真的进了制造
   制造顶栏：返回 rect=[50,50] '返回'  开始 rect=[790,50] '开始'
④ 点开始：Workshop 在场=false 主菜单在场=false SceneRoot 子=1
⑤ +2.0s：SceneRoot 子=1 关卡名=ExampleLevel
⑥ 回标题后：SceneRoot 子=0 主菜单在场=true
```

**教训 / 回流做法**：

- **通用结论**：**同一场景里不要出现同名节点。** `find_child` / `get_node("X")` /
  `%X` 都是"按名字找"，重名时结果取决于**树序**（谁在前取谁），且**不报错** ——
  典型表现就是"点了一个按钮，另一个按钮的动作跑了"。
- **通用结论**：场景内部引用**优先用 `[connection]` 的完整路径**（产品代码这次正是这么写的，
  所以没坏），`find_child` / `%` 更适合"唯一命名的关键节点"（如各屏的 `%CardList`）。
  命名时把"位置/用途"写进名字（`NextPlanetButton` vs `NextButton`）就不会撞。
- **回流模板**：`AGENTS.md` 的 Godot 坑加一条：*同名节点不报错但 `find_child` / `%` 只取树序第一个；
  场景里不要重名，按名字找之前先确认名字唯一*。

### 022 多入口界面把「返回」写死成回主菜单，从第二个入口进来就丢了上下文

- **日期**：2026-10-07
- **类型**：架构
- **严重度**：功能级（不报错，但"从哪来回哪去"做不到，还留着一个点下去没反应的按钮）
- **位置**：`ui/workshop/workshop.gd`（`_on_back_pressed`）、`core/types.gd`（`OpenUiRequest`）、`core/ui_root.gd`
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：制造界面（`ui/workshop`）原来只有一个入口（地图界面「下一步」），所以它的「返回」直接写死
`OPEN_MAIN_MENU`。2026-10-07 给人加了第二个入口（方案界面右下角「新建方案」）之后，立刻暴露两处问题：

1. 从方案进制造、点「返回」回主菜单 —— **方案那一屏凭空消失**，玩家得重新走一遍；
2. 同一条路上点「开始」（进关卡）**什么都不会发生**，只有一行日志：
   `[ERROR] [GameFlow] 既没给关卡路径、也没有已选定的关卡，无法开始`
   —— 关卡路径是地图界面发 `SELECT_LEVEL` 记下的，这条路上没人发过。

**原因**：这两个行为都取决于**"我是从哪进来的"**，而界面被 `UiRoot` 实例化时**拿不到任何参数**
（`OpenUiRequest` 只有 `path` / `ui_layer` / `data`）。于是作者只能把"回主菜单"当唯一事实写死，
第二个入口一出现这个假设就不成立了。

**改动**：

- `core/types.gd`：`OpenUiRequest` 加 `caller: String`（调用方自己的路径，留空 = 未指定来源）；
- `core/ui_root.gd`：`add_child()` **之后**，若界面实现了可选方法 `set_caller()`，把 `caller` 交给它
  （必须在 `add_child` 之后：界面里通常要动 `%唯一名` 节点，那些要 `_ready()` 才解析）；
- `ui/plan/plan.gd` 开制造时填 `caller = Paths.UI_PLAN`，`ui/map/map.gd` 填 `caller = Paths.UI_MAP`
  （**写明白**，别靠"默认就是地图形态"）；
- `ui/workshop/workshop.gd`：`_caller` → `_from_plan()`。**从方案来**：「开始」隐藏、
  「返回」= 关自己 + 开方案界面；**其它**：维持原样（`OPEN_MAIN_MENU`）。

**验证**：非 headless 真窗口 + 真鼠标/键盘事件探针（每次点击前用 `gui_get_hovered_control()`
自检"鼠标真的悬停在这个控件上"），两条链路都跑：

```
A) 方案形态：主菜单「方案」→ 方案在场=true；右下 rect=[790,2230 240x120] 显示='新建方案'
   点它 → 方案在场=false 制造在场=true，「开始」可见=false（截图确认没画出来）
   点制造「返回」→ 制造=false 方案=true          ← 从哪来回哪去
B) 正常形态：主菜单「开始」→ 地图 → 「下一步」→ 制造在场=true，「开始」可见=true（截图确认画出来了）
   点制造「返回」→ 制造=false 主菜单=true 地图=false
```

**教训 / 回流做法**：

- **通用结论**：界面的行为只要**依赖入口**，入口就必须**随打开请求一起传下去**
  （`OpenUiRequest.caller` + 可选的 `set_caller()` 契约）。**不能**让界面去问"某个全局变量上一个界面是谁"
  —— 那个全局值在第二个入口出现时会被别的路径覆盖，淡入淡出/异步关闭下时序也不可靠。
- **通用结论**：给一个界面加第二个入口时，要**逐一检查所有"把入口假设写死"的地方**：
  返回去哪、哪些按钮该在、关掉时要不要恢复上一层（本条的「开始」按钮就是漏网的那类）。
- **回流模板**：`AGENTS.md` 硬规则 2 补一句"来源（`caller`）随 `OPEN_UI` 传"，
  并在 `core/types.gd` 的字段注释里把这个契约写清楚（原生模板同样会长出多入口界面）。

### 023 给存档加分段时，"哪个文件装哪些分段"没有单一事实来源

- **日期**：2026-10-07
- **类型**：架构
- **严重度**：功能级（**全程不报错**，只是数据悄悄串到别的文件里 / 被旧值覆盖）
- **位置**：`core/save_service.gd`（`_payload_for()` / `_do_save_list()` / 启动载入）、`core/save_storage.gd`（`list_slots`）
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：给「方案」加存档（`PlanSave` → `plans.sav`）时，原来的 `_payload_for()` 只有两种情形：

```gdscript
if slot == OptionsSave.SLOT:
    return save_data.to_dict()        # 整棵树！
var game_payload := save_data.to_dict()
game_payload.erase("options")
return game_payload
```

于是**新加的 `plans` 段会自动混进每一类文件**：写 `options.sav` 时带上 plans、写任何游戏档时也带上 plans；
而 `_do_load()` 是整份 `from_dict()`，于是"载入一局游戏"会顺手把内存里的方案列表覆盖成那份文件里的旧值
（游戏档里的副本）。同理 `list_slots()` 只排除 `options` 一个槽位，`plans.sav` 会**出现在"读档列表"里**。
三处都是**静默**的：没有一行报错，只有"方案莫名其妙少了几条"这种事后现象。

**原因**：**"一个分段属于哪个文件"这件事没有单一事实来源** —— 它被拆散在
"写文件的过滤逻辑（`_payload_for`）"、"列存档的排除名单（`list_slots` 的第二个参数）"、
"启动载入（`_autoload_options` 整份读）"三个地方，各自都只认识自己那一个分段。
加分段的人只要漏掉任何一处，症状都不是"报错"而是"数据对不上"。

**改动**：

- `_payload_for()` 改成显式 `match slot`：`options` 档只留 meta + options（`erase("plans")`）、
  `plans` 档只留 meta + plans（`erase("options")`）、**游戏档两个都 erase**；
  注释写明"漏 erase 的症状"；
- `SaveStorage.list_slots(dir, excluded_slot)` → `list_slots(dir, excluded_slots: Array)`，
  `save_service` 用常量 `GLOBAL_SLOTS = [OptionsSave.SLOT, PlanSave.SLOT]` 传进去；
- 新增 `_plans_ready()`：启动时**只** `from_dict` 自己那一段（`plans`），
  **不整份读** —— 方案档里的 `meta` 是落盘时顺手写的，整份读会把"当前是哪一局游戏"的元数据覆盖掉
  （`SaveData.metadata()` 就会报错槽位）。

**验证**：非 headless 探针直接问服务要三类文件的落盘字典（`_payload_for`）并断言分段集合，
再用真文件读写验一遍方案：
```
⑨ [盘上原文] version=5 分段=["version","meta","plans"]；盘上方案=["ProbePlanA"]
⑪ options 档含 plans=false ｜ plans 档含 options=false ｜ 游戏档含 options/plans=false/false
⑫ v4 档迁移：version=5 有 plans 段=true 空列表=true
```

**教训 / 回流做法**：

- **通用结论**：**"一个数据属于哪个文件"必须有单一事实来源**（这里就是 `_payload_for()` 那张表 +
  `GLOBAL_SLOTS`），加东西时**同时改表和名单**；分散在多处的"过滤 / 排除 / 载入"是漏改温床。
- **通用结论**：**载入不要整份读**。每个文件只 `from_dict` 自己那一段，否则别的文件里的
  `meta` / 别的分段会被顺手覆盖（这也是"半读入"的一种）。
- **回流模板**：`AGENTS.md` 的「存档系统契约」写清"哪个文件装哪些分段"是一张表、
  加分段 MUST 同时改 `_payload_for()` + `GLOBAL_SLOTS` + 启动载入函数。

### 024 任何一次存档都会顺手 `validate` 掉别的分段

- **日期**：2026-10-07
- **类型**：工程实践
- **严重度**：噪声级（只是告警刷屏 + 内存里的值被就地修正；正常构建下看不到）
- **位置**：`core/save_service.gd:170`（`_do_save` → `save_data.validate_tree()`）与
  `core/save_service.gd` 的 `_seed_options_from_engine()`
- **状态**：仅记录（**没修**，属既有行为）
- **是否回流模板**：是（在 AGENTS.md 存档契约里点明这个副作用）

**现象**：保存**方案**时打出：

```
WARNING: [OptionsSave] 分辨率 (270, 600) 不在候选表里，改回默认 (1152, 648)
   at: validate (res://save_data/options_save.gd:41)
   [1] validate_tree (res://save_data/save_section.gd:111)
   [2] validate_tree (res://save_data/save_section.gd:110)
   [3] _do_save (res://core/save_service.gd:170)
```

**原因**：`_do_save()` 落盘前对**整棵** `SaveData` 跑 `validate_tree()`（这是有意的：范围 / 白名单问题在
落盘前兜住），所以"保存 A 分段"会连带校正 B 分段里**值不合理**的字段。
本例里 `options.resolution = (270, 600)` 来自首次运行的种子值 —— `_seed_options_from_engine()` 取的是
**真实窗口尺寸**，而本项目 `project.godot` 为了让编辑器窗口放得下写了
`window_width_override/window_height_override = 270×600`，那个尺寸当然不在 `OptionsData.RESOLUTIONS` 里。
正常构建（窗口尺寸就是候选值）不会触发。

**影响**：内存里的 `options.resolution` 会被改成 1152×648，和真实窗口不一致；
以后打开设置界面会显示 1152×648（而引擎窗口仍是 270×600 的调试尺寸）。
**没有实际落盘**（这次写的是 `plans.sav`，`options.sav` 不会被动），所以只是内存不一致。

**教训**：`validate()` 是"整棵树一起"的副作用，不是"只验刚写的那一段"；
调试用的窗口尺寸覆盖会让"种子值不在候选表里"成为常态 —— 看到这条告警先确认窗口尺寸，
不要以为是自己新加的分段写坏了。真要修，得让种子值吸附到候选表（或按 `viewport_*` 而不是真实窗口播种）。

### 025 `.tscn` 里手写 `Transform3D`，行列顺序搞反：相机朝天看

- **日期**：2026-10-07
- **类型**：初级错误
- **严重度**：功能级（**不报错**，画面里该有的东西全在画面外）
- **位置**：`game/road/road_level.tscn`（相机节点）
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：新关卡（3D 三车道躲车）第一版把相机的 45° 俯视**手写进 `.tscn`**：

```
transform = Transform3D(1, 0, 0, 0, 0.707107, -0.707107, 0, 0.707107, 0.707107, 0, 14, 14)
```

按"列优先（x/y/z 轴各三个数）"推，这应该是 `rotX(-45°)`。跑起来**没有任何报错**，
但画面里看不到路面 —— 只剩背景色（当时还被星系的星空 sky 顶着，看上去"像一片星空"）。
探针把相机的 `global_rotation_degrees` 打出来才发现是 **(45, 0, 0)** —— 转反了，
相机朝天看，路面全部落在画面外。

**原因**：`.tscn` 里 `Transform3D(...)` 那 12 个数字的行/列顺序很容易记反（手算贝塞尔/旋转矩阵时尤其），
而**写反了既不报错也不警告**：它就是另一个合法的旋转矩阵。用投影自检也能看出来：
`unproject_position(Vector3.ZERO)` 返回 `(0,0)`（点在近平面后面时是垃圾值），
`(0,0,-20)` 投到 y=5313（视口只有 1080 高）—— 全在屏幕外。

**改动**：角度/位置这类**玩法参数**不再手写进 `.tscn`，改成 `@export` + 代码设一次：

```gdscript
@export var camera_tilt_degrees: float = 45.0
@export var camera_height: float = 14.0
@export var camera_back: float = 14.0

func _setup_camera() -> void:
	_camera.position = Vector3(0.0, camera_height, camera_back)
	_camera.rotation_degrees = Vector3(-camera_tilt_degrees, 0.0, 0.0)
```
（`.tscn` 里那个节点保留，`transform` 只当编辑器里的占位。）

**验证**：非 headless 探针打印相机状态与投影，并截图：
```
Camera3D: current=true 位置=(0,14,14) 旋转=(-45,0,0) fov=70 视口=(486,1071)
投影：原点=(540,1200) ｜ (0,0,-20)=(540,486) ｜ (0,0,-100)=(540,-139)
截图：三车道沥青路面 + 白色虚线 + 两侧护栏与灯柱 + 绿色兽人 + 前方红色车 ✓
```

> **后续（同日）**：人类看过之后认为 3D 透视版不好看，关卡**整体改成纯 2D 俯视**
> （`game/road/` 现在是 `Node2D`，没有相机 / 环境），本条目里那段 3D 相机代码已删除。
> **教训本身仍然成立**：手写 transform / 角度这类"写错了也是合法值"的东西，
> 不能拿"跑起来没报错"当验证（现在关卡里改成了 2D 坐标，同样靠探针打印实际数值自检）。

**教训 / 回流做法**：

- **通用结论**：**手写 `.tscn` 里的 `Transform3D` / `Basis` 是高危操作**（行列顺序、是否需要转置、
  欧拉顺序），错了**静默生效**。能用 `@export` + 代码设就别手写；非要手写，就用
  `unproject_position()` 或 `global_rotation_degrees` 打印自检，别靠"看着没报错"。
- **同类教训（同一轮里踩的第二个）**：给"没传参数"留的哨兵值撞上了合法值域 ——
  `func _spawn_car(at_z: float = -1.0)` 里用 `-1.0` 表示"用默认生成点"，
  但**车道的 z 本来就是负数**，于是起跑铺的车全被扔到 380 米外，
  表现是"前 17 秒路面空的、像关卡没动"。宁可多写一个函数（`_spawn_car()` / `_spawn_car_at(z)`），
  也不要让哨兵和值域重叠。
- **回流模板**：`AGENTS.md` 的 Godot 坑加一条"手写 Transform3D 行列顺序错了不报错"。

### 026 `SubViewport` 默认和根视口共享 World3D，星系的环境漏进关卡

- **日期**：2026-10-07
- **类型**：架构
- **严重度**：功能级（**不报错**：关卡的天空被星系的星空顶掉，两边 3D 互相污染）
- **位置**：`ui/galaxy/galaxy_background.tscn`（`Viewport/SubViewport`）
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：加了 3D 关卡之后，关卡里看到的不是自己的天空 —— 而是**星系的星空**。
探针把场上所有 `WorldEnvironment` 列出来：

```
场上所有 WorldEnvironment: ["WorldEnvironment(背景=2)", "WorldEnvironment(背景=1)"]
   星系 SubViewport: own_world_3d=false ｜ 世界==关卡世界=true
```

两个环境（星系的是 `BG_SKY` + 星空 shader，关卡的是 `BG_COLOR`）在**同一个 World3D** 里抢
`World3D.environment`，谁最后写谁赢 —— 于是"关卡用什么天空"变成了树序 + 时序的运气。

**原因**：`SubViewport.own_world_3d` 默认是 **`false`**：SubViewport **共享父视口的 World3D**。
所以那个"装星系的 SubViewport"里的东西 —— `WorldEnvironment`（星空的 sky）、灯光、相机 ——
统统在**根视口的世界**里。主菜单里看不出来（那时世界里只有星系），一旦关卡也往同一个世界
里放自己的环境/灯光/相机，两边就开始互相覆盖。

**改动**：`ui/galaxy/galaxy_background.tscn` 的 SubViewport 加一行 `own_world_3d = true`
（星系自带相机 / 灯光 / WorldEnvironment，本来就该是一个独立世界）。

**验证**：同一个探针改后：
```
星系 SubViewport: own_world_3d=true ｜ 世界==关卡世界=false
截图①：关卡 = 沥青路面 + 车道虚线 + 护栏 + 兽人 + 车（天空是关卡自己的深蓝）
截图②：回主菜单后 = 星系背景照常（行星 + 轨道 + 星空），主菜单按钮正常
```

**教训 / 回流做法**：

- **通用结论**：**`SubViewport` 默认共享父视口的 World3D**。任何"给某个 SubViewport 单独搭一套 3D"
  （背景层、预览窗、小地图、镜子）的地方，MUST 显式 `own_world_3d = true`，
  否则它的环境 / 灯光 / 相机会漏进主世界（"我的天空被别人的天空顶掉"这类怪现象）。
- **通用结论**：`WorldEnvironment` 是**每 World3D 一个**的资源，不是"每场景一个"。
  在同一世界里放两个，行为取决于处理顺序 —— 不要指望"后加的那个赢"。
- **回流模板**：`AGENTS.md` 的 Godot 坑加一条（SubViewport 的 World3D 共享），
  并把"背景层用独立世界"写进 `ui/galaxy/` 的说明。

### 027 挂在 `Node2D` 下的 `Control`：锚点等于没写，尺寸就是 offset 的差

- **日期**：2026-10-07
- **类型**：初级错误
- **严重度**：功能级（**不报错**：该铺满屏幕的东西是 0 像素高，画面里"少了一层"）
- **位置**：`game/road/road_level.tscn`（路面 / 边缘线 / 护栏 / 底色）
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：2D 关卡的静态铺底矩形按"锚点铺满"的老习惯写：

```
[node name="Road" type="ColorRect" parent="."]
offset_left = 90.0
offset_right = 990.0
anchor_bottom = 1.0          # ← 想让它铺满屏幕高度
grow_vertical = 2
```

跑起来**没有报错**，但路面、边缘线、护栏、整屏底色**全都不见了**（截图里只剩车道虚线和护栏反光条
——它们有显式尺寸）。探针把矩形打出来：

```
路面 rect=[90,0 900x0]        ← 宽度是 offset 的差（900 ✓），高度是 0 ✗
```

**原因**：`Control` 的锚点是相对**父节点的可锚定矩形**算的。父节点是 `Control` / `CanvasLayer` 时，
那个矩形是父控件的矩形 / 视口；但父节点是 **`Node2D`（或普通 `Node`）时父矩形是零** ——
于是 `anchor_bottom = 1.0` 乘 0 还是 0，**锚点等于没写**，尺寸就退化成"offset 的差"。
本项目里同一个坑：`Hud` 挂在 `CanvasLayer` 下 → 锚点正常（失败面板能居中、提示能贴底），
而世界节点挂在 `Node2D` 根下 → 锚点失效。

**改动**：2D 关卡的静态铺底节点**写成设计尺寸的显式 offset**（工程是固定竖屏 1080×2400，
`project.godot` 里 `resizable=false`，和 `ui/galaxy/galaxy_background.tscn` 里写死 `size = 1080x2400`
是同一个口径）：

```
offset_left = 90.0
offset_top = 0.0
offset_right = 990.0
offset_bottom = 2400.0
```

**验证**：同一个探针改后：
```
路面 rect=[90,0 900x2400] → 车道中心=[240.0, 540.0, 840.0]
截图：深色路面 + 两侧边缘线 + 灰色护栏（带滚动反光条）+ 两条车道虚线 + 车 + 兽人 ✓
```

**教训 / 回流做法**：

- **通用结论**：`Control` 的锚点**只在父节点是 `Control` 或 `CanvasLayer` 时按父矩形/视口算**；
  挂在 `Node2D` / `Node` 下时父矩形是零，`anchors_preset = 15` 之类的写法**静默失效**
  （尺寸退化成 offset 的差）。2D 场景里"想铺满屏幕"的装饰层，要么放进 `CanvasLayer`，
  要么按设计分辨率写死 offset（固定分辨率工程推荐后者：编辑器里所见即所得）。
- **通用结论**：这类"少了一层"的问题，**用探针把 `get_global_rect()` 打出来**最快定位
  —— 比对着截图猜"是不是颜色不对"快得多。
- **回流模板**：`AGENTS.md` 的 Godot 坑加一条（Control 锚点在非 Control 父节点下失效）。

### 028 删设置项不能只删界面：字段、应用逻辑、日志引用都得一起删

- **日期**：2026-10-07
- **类型**：架构
- **严重度**：功能级（漏改会**报运行时错误**；更隐蔽的是"界面上没有了、启动时还在生效"）
- **位置**：`ui/options/options.gd` / `ui/options/options.tscn`、`save_data/options_save.gd`、
  `core/options_data.gd`、`core/options_applier.gd`、`core/save_service.gd`、`locale/*`
- **状态**：已修
- **是否回流模板**：是 —— 见下方「回流做法」

**现象**：人类要求"设置界面只留语言 + 音量"（删掉分辨率与按键重映射）。第一版只改了界面与存档字段，
结果**每次写设置档**都抛：

```
SCRIPT ERROR: Invalid access to property or key 'resolution' on a base object of type 'RefCounted (OptionsSave)'
   at: _apply_options (res://core/save_service.gd:317)
```

那是 `_apply_options()` 里的一句**日志**：

```gdscript
CoreSystem.logger.info("[SaveService] 已应用设置：resolution=%s language=%s"
	% [options.resolution, TranslationServer.get_locale()])
```

字段没了，这行就成了运行时错误；按"报错中断所在函数"的规则，它中断了 `_apply_options` ——
好在 `OptionsApplier.apply()` 在它**之前**已经跑完，所以"音量生效了、语言也生效了"，只有日志炸了。
**要是顺序反过来，就是"设置点了没反应"。**

**原因**：一个设置项的"存在"分散在**五处**，缺一处都不算删干净：

| 位置 | 内容 |
|---|---|
| `ui/options/*` | 界面控件 + 回调（最显眼，也最容易只改这里） |
| `save_data/options_save.gd` | 存档字段（+ `validate()` 里的范围检查） |
| `core/options_data.gd` | 候选值表（`RESOLUTIONS` / `REMAPPABLE_ACTIONS`…） |
| `core/options_applier.gd` | **"应用到引擎"的逻辑**（改窗口尺寸 / 改 InputMap） |
| 别处对字段的引用 | 日志、种子值（`_seed_options_from_engine()`）、界面回填… |

只删界面 = 留下**隐形设置**：界面上改不了，启动时却照样生效（分辨率会改窗口、旧的重映射会生效），
玩家永远没法改回来。

**改动**（这次做全了）：

- `ui/options/options.tscn` / `options.gd`：删掉分辨率行与按键重映射行，重排成大字号
  （返回 240×120/字号 48、行标签 44、下拉 420×112、滑块 460×112 且 `step = 1`）；
  `get_popup()` 的弹层字号要单独设（PopupMenu 不继承按钮的 `font_size`）。
- `save_data/options_save.gd`：删 `resolution` / `input_bindings` 字段与 `validate()` 里的分辨率分支。
- `core/options_data.gd`：删 `RESOLUTIONS` / `SHOW_FULLSCREEN_OPTION` / `FULLSCREEN` / `REMAPPABLE_ACTIONS`。
- `core/options_applier.gd`：删 `_apply_input_bindings()` 与分辨率那一整块（**只留音量 + 语言**）。
- `core/save_service.gd`：`_seed_options_from_engine()` 不再播种分辨率；`_apply_options()` 的日志只报现在存在的字段。
- **存档版本 5 → 6 + 写迁移**：`migrate()` 里把 `options` 段的 `resolution` / `input_bindings` **erase** 掉
  （删字段也要迁移：留着会被 `from_dict` 当未知字段告警，值还会被当成"仍然生效"）。
- `locale/*` 三处：删 `ui.options.resolution` / `.fullscreen` / `.pause_key` / `.reset_key` / `.waiting_key`
  （留着会变成 `locale_orphan`）。

**验证**：非 headless 探针（真点击 + 读盘）：

```
① 可交互控件（5 个）：OptionButton(420x112 字号44) / HSlider×3(460x112 step=1) / Button(返回 240x120 字号48)
   文字（7 个）：语言 / 主音量 / 音乐音量 / 音效音量 + 三个数值（字号 44）   ← 旧的两行真的没了
② 真点主音量滑块 30% 处：值 10 → 3（step 吸附）、标签 3、Master 总线 -10.46 dB、存档里 0.3
③ 点开下拉（真点击）→ 选 English：TranslationServer=en、存档 language=en；再切回 zh_CN 也正常
④ 设置档：version=6 ｜ options 键 = [language, master_volume, music_volume, sfx_volume]
⑤ v5 → v6 迁移：resolution / input_bindings 都没了，language 保留
```

**教训 / 回流做法**：

- **通用结论**：删一个设置项 MUST **全仓 grep 它的字段名 / 常量名**（这次是
  `grep resolution|input_bindings|REMAPPABLE_ACTIONS` 才揪出日志里那处引用），并按上表五处逐一对齐；
  只删界面等于把它变成**隐形设置**。
- **通用结论**：**删字段也要提升存档版本 + 写迁移**（不是"只有加字段才要"）。旧键留在文件里
  会被当成仍然生效的设置，`from_dict` 还会对未知字段告警。
- **通用结论**：`_apply_options()` 这类"应用 + 日志"的函数里，**日志引用的字段和真正应用的字段一样危险** ——
  报错会中断函数（顺序不对时表现就是"设置没生效"）。
- **回流模板**：`AGENTS.md` 的存档契约写明"删字段同样要迁移"，并在「已知未完成事项」里给出
  "要把按键重映射加回来必须做哪四件事"的清单。