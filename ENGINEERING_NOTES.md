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

- 删除前：`git status --short` 可见该文件与 `.uid` 均未被忽略；`godot-lint.ps1` 的 `temp_files` 规则命中。
- 删除后：`godot-lint.ps1` 报 **`error=0  warn=0`**（与 `AGENTS.md` 里"存量 warn 已清零"一致）；
  `verify-engine.ps1 -Project ... -Scenario res://entry/main.tscn` 退出码 0、**无新增 ERROR/WARNING**；
  `--headless --editor --quit` 无任何脚本类告警（顺带确认它没给别人留下编译期引用）。

**教训 / 回流做法**：

- 回流模板：**让规则自己兜底**，别指望收尾时记得住 ——
  1. 在工程 `project.godot` 同级的 `.gitignore` 里忽略 `_*` 探针（`_probe*` / `_*_probe*`）与
     配套的 `.uid`，让残留**不会进提交**；
  2. 把 `temp_files` 从 warn 提升为 **error**（探针是"用完即弃"的东西，残留即失败），
     或在 `verify-engine.ps1` 结尾扫一遍 `_*` 并让退出码非 0；
  3. `AGENTS.md` 里把「探针约定」从"记得删"改成"**探针一律放 `user://` 或 `.godot/` 之外**"——
     例如统一放到 `res://.probe/`（整个目录 gitignore），用完连同目录一起删，不会有半删状态。

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
