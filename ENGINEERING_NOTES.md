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
