# AGENTS.md — godot-template

面向在本仓库工作的编码 agent（也当项目约定文档用）。本文件是**约束**，与个人风格偏好冲突时以本文件为准。

## 这是什么

Godot **4.7** 项目模板（纯 GDScript），用来快速起各种游戏。分两层，写代码主要在第 2 层：

| 层 | 位置 | 说明 |
|---|---|---|
| 框架层 | `godot-template/addons/godot_core_system/` | 第三方插件：autoload 单例 `CoreSystem` + 13 个模块 + 工具类。**默认不改**；确需改动要在提交信息里单独说明理由 |
| 项目层 | `godot-template/` 下的 `core/`、`save_data/`、`ui/`、`game/`、`entry/`、`locale/` | 约定层 + 业务层 |

启动链路：主场景 `entry/main.tscn` → `Main` 下挂三个**独立场景实例**：`UiRoot`（UI 记账，`core/ui_root.tscn`）、
`SaveService`（存档，`core/save_service.tscn`）、`GameFlow`（流程 + 关卡容器，`core/game_flow.tscn`）
→ `entry/main.gd` 发事件打开主菜单。

流程层是**常驻壳**：`UiRoot` / `SaveService` / `GameFlow` 不随关卡切换重建，关卡只被换进
`GameFlow/SceneRoot`。`boot → title（主菜单）→ gameplay（关卡）→ pause（暂停界面，`get_tree().paused`）`
全部由 `core/game_flow.gd` 统一驱动。关卡容器（`GameFlow/SceneRoot`）与转场遮罩
（`GameFlow/TransitionLayer/FadeRect`）都在 `core/game_flow.tscn` 里，编辑器可见可调；
**不要用代码 `CanvasLayer.new()` 动态造遮罩**（会留下 `@CanvasLayer@N` 这类匿名节点）。

## 框架层能力速查（动手前先看这里）

**没有现成实现可参考时，优先用框架层已有能力**；项目和插件都没有的方案才自研。
下面这份清单就是为了让"先查插件"这一步不必每次重新 grep。

`CoreSystem` 暴露 **13 个模块**（`addons/godot_core_system/source/core_system.gd`）：

| 模块 | 目录 | 容易被忽略的子能力 |
|---|---|---|
| `event_bus` | `event_system/` | 事件订阅/派发，`subscribe_unique_script` |
| `save_manager` | `save_system/` | 4 种格式策略 `binary` / `json` / `resource` / `async_io`；存档目录设置 |
| `resource_manager` | `resource_system/` | 资源加载与缓存（`load_resource` / `get_instance`） |
| `scene_manager` | `scene_system/` | **转场**：`fade` / `slide` / `dissolve` + `base_transition`、`scene_base`、场景栈 |
| `input_manager` | `input_system/` | **功能类**：`input_buffer`、`input_virtual_axis`、`input_recorder`、`input_event_processor`、`input_config` |
| `config_manager` | `config_system/` | 配置读写（user://config.cfg） |
| `state_machine_manager` | `state_machine/` | `base_state_machine` / `base_state` |
| `entity_manager` | `entity_system/` | 实体管理 |
| `trigger_manager` | `trigger_system/` | 触发器 + 条件：`event_type` / `state` / `composite` |
| `tag_manager` | `tag_system/` | GameplayTag |
| `time_manager` | `time_system/` | 时间 / 计时 |
| `audio_manager` | `audio_system/` | 音频播放 |
| `logger` | `logger/` | `core_logger` |

工具类（`CoreSystem` 直接暴露）：`FrameSplitter`、`SingleThread` / `ModuleThread`、`RandomPicker`、`AsyncIOManager`。

查询方式：读 `core_system.gd` 的模块/工具清单 → 在 `source/` 下按关键词检索
（`transition` / `buffer` / `async` / `tag` / `trigger` / `strategy`）→ 读目标模块的公开方法签名。
**注意**：模块可经 `godot_core_system/module_enable/<module_id>` 被关闭，此时取到 null，调用方不能假设可用。

**已于本项目用过的框架能力**：`event_bus`（全部跨模块通信）、`logger`、`resource_manager`（关卡加载）、
`save_manager`（只借存档目录设置）、`FadeTransition`（`GameFlow` 的转场动画）。
**没用 `scene_manager` 的场景切换**：它是"替换 current_scene"的语义，会把这层常驻壳一起释放；
只复用了它的转场实现。

## 硬规则（必须遵守）

1. **路径 / 事件名 / 类型三处集中**：`res://` 路径只写在 `core/paths.gd`（`Paths`），事件名只写在
   `core/events.gd`（`Events`），请求与结果结构体只写在 `core/types.gd`（`Types`），设置候选值写在
   `core/options_data.gd`。脚本与场景里禁止散落硬编码路径或事件字符串（`godot-lint.ps1` 会拦）。
2. **UI 只能通过事件开关**：发 `Events.OPEN_UI`（payload `Types.OpenUiRequest`）与 `Events.CLOSE_UI`
   （payload 路径字符串），由 `core/ui_root.gd` 负责实例化、分层、记账。**不要**自己 `instantiate()`
   界面，也不要自己 `queue_free()` 关闭界面（会绕过 `ui_dict` 记账，留悬挂引用）。
   界面的行为若**依赖"从哪进来的"**（返回回哪屏、哪些按钮该在），把来源填进
   `Types.OpenUiRequest.caller`（**调用方自己的路径**）—— `ui_root` 会在 `add_child()` 之后
   把它交给界面上的可选方法 `set_caller()`。**不要**另设"上一个界面是谁"这类全局变量：
   多入口时它会被别的路径覆盖（见 `ENGINEERING_NOTES.md` 022）。
3. **界面文案一律用翻译 key**：场景里写 `text = "ui.xxx.yyy"`；新增 key 必须在 `locale/en.po`、
   `locale/zh_CN.po`、`locale/texts.pot` **三处同步**（`locale/fallback="zh_CN"`）。
   只有语言母语名这类不翻译的内容才写原文。
   **三处同步之外，还要保证这个 key 真的被定义了** —— 引用了不存在的 key 时引擎**不报错**，
   界面会把 key 原文（`ui.workshop.warehouse` 这种）直接显示出来；`godot-lint.ps1` 的
   `locale_missing` 规则会拦（ENGINEERING_NOTES 020）。
4. **事件总线语义**：`push_event(name, payload)` 的 payload **就是订阅者的参数表** ——
   非数组会自动包成单元素参数表；**数组则原样当参数表用**：
   - `push_event(N, 对象)` → 订阅者收到 **1 个参数**（该对象本身）
   - `push_event(N, [items])`（**单元素**）→ 订阅者收到 **1 个参数**：`items` 本身
   - `push_event(N, [a, b, c])`（**多元素**）→ 订阅者收到 **3 个参数**
   - `push_event(N, [])` → **0 个参数**

   所以"数组时要再包一层"是**错的**。事件没有返回值 → 一律"请求事件 + 结果事件"配对，
   结果里**必须处理 `ok == false`**。
5. **暂停相关**：`get_tree().paused` 的**唯一权威是 `core/game_flow.gd`**；界面只发 `Events.PAUSE_TOGGLE`。
   与暂停有关的节点（GameFlow、暂停界面）MUST 设 `process_mode = ALWAYS`，否则暂停后按 ESC 无法恢复、
   按钮点不动。
6. **不要交"看起来对"的代码**：任何非平凡改动都要真跑一遍引擎验证（见下）。
7. **禁止改变仓库状态的 git 操作**：`commit` / `push` / `pull` / `fetch` / `merge` / `rebase` / `reset` /
   `checkout` / `switch` / `restore` / `stash`（除 `list`）/ `tag` / `branch`（增删改）/ `clean`（除 `-n`）/
   `rm` / `mv` 等**一律不许**，除非人类在当次对话里明确要求。需要提交时，在报告里写出**建议人类执行的
   命令和原因**。只读查询（`git status` / `diff` / `log` / `show` / `ls-files` …）随时可用。

## 可配置数据的分层（`data/` vs `save_data/`）

新增"能在编辑器里配的数据"时按这个分工放，别混：

| 目录 | 放什么 | 例子 |
|---|---|---|
| `data/types/` | **类型定义**：`Resource` 子类，`@export` 出一堆字段 | `GalaxyBody`、`GalaxyConfig` |
| `data/resources/` | **配好的实例**：`.tres`，在编辑器里改数值 | `galaxy.tres`（路径经 `Paths.GALAXY_CONFIG` 引用） |
| `data/_archive/` | 被取代的旧配置快照。**存 `.txt` 不存 `.tres`** | `galaxy_ring_based_old.txt` |
| `save_data/` | **玩家存档**的分段（一套独立体系，见下节） | `OptionsSave`、`MetaSave` |

**为什么 `save_data/` 不并进 `data/`**：存档那套自带版本迁移、类型校验、纯数据约束，
是一层完整契约；`data/` 是"业务配置"。两者都是 `Resource`/`RefCounted` 数据类，但生命周期完全不同
（配置是开发期静态资源，存档是运行期读写文件）。

**加一类新配置的步骤**：
1. `data/types/xxx.gd`：`class_name Xxx extends Resource`，字段用 `@export`；
   **要嵌套列表就再建一个独立顶层类**（内部类无法被 `.tres` 正确序列化，见 `ENGINEERING_NOTES.md` 008）；
   **导出数组写 `Array` 不要写 `Array[自定义类型]`**（同上）；
2. 路径常量加到 `core/paths.gd`（`res://` 字面量只能出现在那里）；
3. `data/resources/xxx.tres` 里配实例（手写容易错，用 `ResourceSaver.save()` 生成更稳）；
4. 加载方用 `@export_file("*.tres")` 或 `Paths.XXX` 引用，**存完必须读回来断言字段值**。

**`.tres` 里"哪些字段是显式的"**（本项目已按此约定执行）：

- **`ResourceSaver.save()` 会跳过值等于 `@export` 默认值的属性** —— 实测 32 个配置字段只写出
  8 个，其余 30 个在文件里根本没有对应行。**给属性显式赋一次值也无效**（赋的就是默认值）。
  所以"让默认值也出现在文件里"**只能手写 `.tres`**，不能靠保存生成。
- 本项目约定：**`data/resources/*.tres` 写全每一个字段**，让文件本身是一份完整可读的配置，
  不用回头翻 `data/types/xxx.gd` 的默认值。`galaxy.tres` 是范例：
  `[resource]` 段 33 行（`bodies` + 32 个配置字段），每个天体子资源 10 行（全部 9 个 + `script`）。
- 手写 `.tres` 的**字段名必须与脚本里的变量名逐字一致**（`.tres` 里名字写错 = **静默忽略**，
  不报错、不提示，值悄悄变回默认）。所以**手写完必须读回逐字段断言**，
  且断言要覆盖**每一个**字段，不能只抽查几个。
  **实测确认（2026-10-07）**：故意往 `.tres` 里加一行 `bogus_field_xyz = 9.0` 再 `load()`，
  引擎**一行报错都没有**；所以"没报错"完全不能当作"字段名写对了"的证据。
  另外"读回来等于默认值"也**不能**当作证据 —— 名字写错时读到的就是默认值。
  想证明某一行的字段名正确，只能**临时填一个非默认值**再读回断言（见 `ENGINEERING_NOTES.md` 016）。
- 手写用到的类型字面量：`Color(r, g, b, a)`、`Vector3(x, y, z)`、`@export_file` 的字段写成带引号的字符串。
- **同一份数据不要有第二份副本**：类型的 `build_default()`（缺配置时的兜底）必须与
  `data/resources/*.tres` **逐字段对齐**，两边注释互相点名，改一处必须改两处。
  兜底值平时永远走不到，一旦和 `.tres` 分家，用户看到的就是"另一个游戏"
  （`ENGINEERING_NOTES.md` 017：兜底里留着 10 颗星球 + 已被证伪的 scale）。

## 存档系统契约（改动前必读）

- **格式**：4 字节魔数 `GTSV` + `var_to_bytes(纯数据字典)`，扩展名 `.sav`；读用 `bytes_to_var()`
  （**不是** `bytes_to_var_with_objects()`）。因此存档文件里不可能承载任何逻辑/脚本/对象 —— 刻意设计，
  **不要换回去**（json 明文与 `.tres` 方案都因"可承载逻辑"被否过）。
- **结构**（当前 `version = 6`）：
  ```
  { "version": 6, "meta": { slot, saved_at, game_version, playtime },
    "options": { language, master_volume, music_volume, sfx_volume },
    "plans": { "plans": [ { "name": "..." } ] } }
  ```
- **"哪个文件装哪些分段"是一张表**（`core/save_service.gd` 的 `_payload_for()`）：
  `options.sav` = meta + options；`plans.sav` = meta + plans；**游戏档** = meta + 除这两者外的所有分段。
  不是"一局游戏"的文件还要从 `list_slots` 里排除（`GLOBAL_SLOTS`）。
  **加分段 MUST 同时改这张表** —— 漏改的症状是"游戏档里多出一份副本，载入游戏档时又把内存里的那份覆盖回旧值"，
  而且**不报错**。载入时也**每个文件只取自己那一段**（`_plans_ready()` 只 `from_dict` 自己的 `plans`）：
  整份读会把别的文件里的 `meta` 覆盖进内存（存档列表会显示错槽位）。
  `SaveData.metadata()` 对外仍返回**平铺的那 5 个键**（值取自 `meta`），存档列表靠它。
- `_do_save()` 落盘前会对**整棵** `SaveData` 跑 `validate_tree()`：也就是说保存 A 分段时，
  B 分段里"值不合理"的字段也会被就地修正（例：旧版本里保存方案时把和候选表不符的
  `options.resolution` 改回默认）。正常构建下看不到，但用 `window_width_override` 调过窗口尺寸时
  会稳定告警（ENGINEERING_NOTES 024）。
- **一段一个类**：分段都在 `save_data/`，继承 `SaveSection`；**加一个普通分段 = 新建类 + 在 `save_data.gd`
  加一行 `var xxx: XxxSave = XxxSave.new()`**。但**如果这个分段有自己的存档文件**
  （像 `options` / `plans`），就必须**同时**改 `core/save_service.gd`：`_payload_for()` 的归属表、
  `GLOBAL_SLOTS`（列存档时要排除）、以及启动时"只取自己那一段"的载入函数。
- **分段里只放数据字段**（int/float/bool/String/`Vector2(i)`/Color/Array/Dictionary…）。
  放 `Object`/`Callable`/`Signal`/`RID` 会被 `to_dict()` 跳过并告警 —— **静默丢数据是 bug**，别用。
- **版本与兼容策略**：改结构 MUST 提升 `SaveData.version`，并 MUST 在 `save_data.gd` 的 `migrate()`
  里**声明策略**：**写迁移**（按 `from_version` 逐级补齐字段）或**显式拒绝**（返回 `{}`，由
  `SaveService` 给出可区分原因）。MUST NOT 悄悄改结构而不动版本号；MUST NOT 出现半读入。
  **五个已有范例**：`v1 → v2`（元数据搬进 `meta` 段）用的是**显式拒绝** —— 那是一次性决定
  （模板尚未发布、无真实用户存档），**以后 MUST NOT 再整体拒绝一整个版本**；
  `v2 → v3`（`options` 段加三个音量字段）、`v3 → v4`（加 `input_bindings` 重映射表）、
  `v4 → v5`（加 `plans` 方案段）与 `v5 → v6`（**删** `options` 段的 `resolution` / `input_bindings`）
  用的是**写迁移**：按 `from_version` 逐级处理，旧档照常可读。
  **删字段同样要迁移**（不是"只有加字段才要"）：留着旧键会被 `from_dict` 当未知字段警告，
  而且那份值会被当成"仍然生效的设置"（`ENGINEERING_NOTES.md` 028）。
- **补丁类型校验**：`SaveSection.apply_dict()` 逐字段比对类型 —— 不兼容（除 `int` ↔ `float` 互通）时
  **拒绝该字段 + 告警 + 保持原值**。别指望 `set()` 兜底：Godot 对可转换的坏类型会静默转换
  （`float ← "abc"` → `0.0`），对不可转换的会静默忽略，两者都不告警。补丁路径是
  `{"meta": {"playtime": 5}}` / `{"options": {"language": "zh_CN"}}`。
- **设置单独存**：语言 / 音量（Master / Music / SFX）都在 `OptionsSave.SLOT`（`options.sav`）。
  没有存档、**或设置档无法载入**（版本过旧 / 损坏）时，`SaveService` 用**当前引擎状态**播种默认值
  （保证界面显示 = 实际生效）并告警。
  **分辨率与按键重映射已于 2026-10-07 删除**（人类要求：设置界面只留语言 + 音量）：字段、候选表、
  `OptionsApplier` 里的应用逻辑、语言文件里的 key 一并删除，存档 `v5 → v6` 写迁移丢掉旧键
  （`ENGINEERING_NOTES.md` 028）。
- **设置界面是"改动即存"**：语言下拉框 / 音量滑块任何一处改动都会立刻发 `SAVE_REQUEST`
  写进设置档，SaveService 写完立即应用。**没有 Apply / Cancel 这层缓冲** ——
  所以界面上也没有"确认"这一步，改错了只能再改回去。
- **音量是分档的**：档位定义在 `OptionsData.VOLUME_STEPS`（当前 `0~10`、每档 1，共 11 档；
  线性音量 = 档位 / `VOLUME_MAX_STEP`）。滑块 `step` 负责吸附，脚本再按档位去重 ——
  **只有档位真的变了才写档**，同一档内的抖动不落盘。存档里出现非档位值（旧档 / 手改）时，
  由 `OptionsSave.validate()` 吸附到最近档并告警。要换档位（不均匀档位、或改成 0~20）只改 `VOLUME_STEPS`
  与滑块的 `max_value`/`step`。
- **按键重映射（已删除，要加回来照这个清单）**：曾经的做法是 `OptionsSave.input_bindings`
  （动作名 → 物理键码，只记被改过的动作）+ `OptionsData.REMAPPABLE_ACTIONS`（允许改哪些动作）+
  `OptionsApplier` 先恢复出厂绑定再套用覆盖（幂等）。2026-10-07 随设置界面一起删掉了；
  要加回来必须**同时**做四件事：加存档字段（+ 版本迁移）、加候选表、加回 `OptionsApplier` 的应用逻辑、
  界面上加重映射行（`ENGINEERING_NOTES.md` 028）。
- **写入是原子的**（`.tmp` → `DirAccess.rename_absolute`）；槽位名会被过滤（拒绝 `..` `/` `\` `:` 等）；
  单文件上限 8 MiB。纯文件 IO 在 `core/save_storage.gd`（static、无状态、`save_dir` 由参数传入），
  设置应用在 `core/options_applier.gd`。
- 存档目录取自 `ProjectSettings` 的 `godot_core_system/save_system/save_directory`（默认 `user://saves`）。

## 验证（强制动作）

没有运行时验证的改动不算完成。两条门禁（在**仓库根**跑）：

```powershell
pwsh scripts/godot-lint.ps1        # 静态规则门禁
pwsh scripts/verify-engine.ps1     # 引擎冒烟 + 与基线逐行比对；退出码 1 = 有新增回归
```

常用参数：

```powershell
pwsh scripts/verify-engine.ps1 -Scenario res://ui/options/options.tscn   # 直接实例化某场景
pwsh scripts/verify-engine.ps1 -Probe res://_probe_xxx.gd                # 一次性探针（会显示探针输出）
pwsh scripts/verify-engine.ps1 -UpdateBaseline                           # 人工确认后重登基线
pwsh scripts/verify-engine.ps1 -NoBaseline                               # 只报告，不比对
```

- 判据 **MUST** 写成「相对 `scripts/engine-baseline.json` **无新增行**」，
  **MUST NOT** 写成"退出码 0 且没有 ERROR"：本机冒烟稳定有 5 行噪声而退出码仍是 0。
- **引擎路径（本机事实，脚本会自动探测）**：`C:\portable\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe`。
  `godot` **通常不在 PATH 上**；要用 `*_console.exe` 才拿得到 stdout。
- 基线是**机器相关**的（`user://` 下有没有存档会影响启动日志）。换机器或存档状态大变后
  MUST 用 `-UpdateBaseline` 重登，并在提交信息里说明**为什么变**。
- 探针约定：`extends SceneTree`；`--script` 模式下 **autoload 标识符 `CoreSystem` 在编译期不可用**，
  要经 `root.get_node_or_null("/root/CoreSystem")` 取；**等待必须按真实时间**（`Time.get_ticks_msec()`），
  headless 下帧率极高，按帧数等会漏掉 tween（转场 0.25s ≈ 上千帧）。
- 探针脚本不要留在仓库里：收尾用 `git status`（只读）或 `godot-lint.ps1` 的 `temp_files` 规则确认无 `_*` 残留。

## Godot 坑（踩过的，别再踩）

- **`.tscn` 里不存在的属性会被静默忽略**（不报错也不提示）→ "跑起来没报错"不能证明属性名正确。
- `var_to_bytes()` 在本版本只接受 **1 个参数**（没有 `full_objects`）。
- `OptionButton.select()` **不会**触发 `item_selected`（只有用户交互会）→ 填充下拉框不会误触发存档回调。
- 脚本运行时报错会**中断所在函数**（后续代码整段不执行）。
- **遮蔽内置标识符（`SHADOWED_GLOBAL_IDENTIFIER`）与 int→枚举（`INT_AS_ENUM_WITHOUT_CAST`）这两类
  告警只在编辑器导入 / 脚本重载时出现，headless 冒烟（`--quit-after N`）看不到** → 验证这类修复必须走
  `--editor --quit`，别拿默认冒烟当判据（详见 `ENGINEERING_NOTES.md` 001 / 005）。
- **`var_to_bytes()` / `bytes_to_var()` 不保存枚举类型**：写进去是 `Key`，读回来一定是 `int`
  （`typeof` = `TYPE_INT`）。所以存档里的枚举值赋给枚举类型属性时**必须显式转型**（`keycode as Key`）。
- `InputEventKey.physical_keycode` 的静态类型是 `Key`；本项目 `project.godot` 的出厂绑定只填 `keycode`、
  `physical_keycode` 是 **0** —— 断言"恢复默认按键"时要连 `keycode` 一起比，只比物理键码会误判。
- `$长/节点/路径` 改名后要运行时才报错 → 用 `%唯一名`、`@export`，或在 `.tscn` 里用
  `[connection signal="pressed" from="..." to="." method="..."]` 连信号（本项目主菜单/暂停/制作人员都是这么连的）。
- 全局类缓存、`.po` 翻译、`.uid` 都参与 `--import` 流程；手改 `.tscn` 的 `ext_resource` 时不要漏 `uid`。
- **shader 的语法 / 编译错误在 headless 下不一定暴露**（惰性编译）→ 改完 shader 别只看
  "场景跑起来没报错"：用 `Shader.get_shader_uniform_list()` 探针确认能拿到 uniform 列表，
  或真开窗口跑一遍（详见 `ENGINEERING_NOTES.md` 006）。
- **shader 里 `mod(x, 0.0)` 是"静默失效"写法**：除零 → `NaN` → 采样未定义，**不报错、不崩溃，
  只是效果没了**。要"取小数部分"直接写 `fract()`（顺带避开 `TIME` 变大后的精度抖动）。
- **不要用 `get_aabb()` / 节点 `scale` 推断第三方插件的可见尺寸**：带顶点位移 / 外壳 /
  菲涅尔的材质，画出来的球面**不落在网格 AABB 上**；插件场景里往往还烘焙了极大的 transform
  （本项目插件恒星 ×1200、气态行星 ×800），配置里的 `scale` 是在反向补偿它。
  用 AABB 推半径会得到**差好几个数量级**的数字，并据此改错参数（`ENGINEERING_NOTES.md` 010）。
  **视觉结论只能渲染实测**。
- **视觉验证必须非 headless**：`verify-engine.ps1 -Probe` 恒为 headless，只适合跑逻辑；
  要看画面就自己起窗口跑探针 —— 把场景挂进离屏 `SubViewport`（尺寸设为目标分辨率）
  → `get_texture().get_image().save_png()` 存图 → 读图或对像素做连通域统计：
  ```powershell
  & "C:\portable\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path <proj> --script res://_probe_shot.gd
  ```
- **量"某个东西在屏幕上多大/多高"的配方**（本项目已用它标定地图特写尺寸，见 `ENGINEERING_NOTES.md` 018）：
  临时给目标下所有 `MeshInstance3D` 套 `material_override`
  （`StandardMaterial3D`：灰 `0.35` + `SHADING_MODE_UNSHADED`；灰度**低于 glow 阈值 0.9** 才不会泛光溢出），
  再按"接近该灰 **且** 中性色（RGB 互差小）"取像素、要求**整行成片**（滤星点）、
  **只认垂直半径**（竖直方向不会被画面边界裁）。写完问自己三句：
  **暗部还认得出来吗 / 背景里有别的东西符合判据吗 / 目标会不会被裁**。
  **基准值要取"人类看过并认可的那一颗"**，不要自己发明；
  更不能用 `get_aabb()`、节点 `scale` 或"按公式算出来的投影半径"当实测（那是循环论证）。
- Tween 默认 `TWEEN_PAUSE_BOUND`：节点的 `process_mode` 决定它在暂停时是否推进 —— 转场/暂停界面要 ALWAYS。
- **`mouse_filter = IGNORE` 不是"不挡别人"，而是"我也不收输入"**：全屏装饰层（背景、
  透明信息层）可以写 IGNORE，**但 `ScrollContainer` / 任何要收滚轮、拖拽、点击的容器不能** ——
  写了就**滚不动、不报错、界面照常显示**。实测：同一个滚动容器，默认 `STOP` 时滚轮
  `scroll_vertical` 0 → 277，改成 IGNORE 后 0 → 0（`ENGINEERING_NOTES.md` 019）。
- **测 GUI 输入**：`Viewport.push_input(ev, true)` 造事件时**必须先推一次
  `InputEventMouseMotion`**（否则引擎不知道鼠标悬停在哪个控件上，滚轮会被直接丢掉，
  测出来永远是"没反应"）；坐标用视口本地坐标 + `in_local_coords = true`。
  另外**"程序化赋值生效"（如 `scroll_vertical = N`）不能证明输入路径通** —— 两者要分别验。
- **同一场景里同名节点不报错，但 `find_child` / `get_node("X")` / `%X` 只取树序第一个** ——
  表现是"点了一个按钮，另一个按钮的动作跑了"，且没有任何提示。场景内引用**优先用
  `[connection]` 的完整路径**；`%唯一名` 留给"确实唯一"的关键节点，命名时把位置/用途写进名字
  （`NextPlanetButton` vs `NextButton`）。实测踩坑见 `ENGINEERING_NOTES.md` 021。
- **同一个属性只许有一个写入者**：Tween 和"每帧跟随"（`_process` 里改同一个属性）**不能并存** ——
  同一帧里谁后写谁赢，而且 `Tween` 的起点是**第一次 step 时才取的**，
  期间被别人改写过的值会成为它的"起点"，动画就变成"原地不动"。实测表现是
  **瞬移到位 → 卡住整个 duration（目标照常移动、在画面里飘走）→ 再猛地跳回来**，
  **引擎不报任何错**（`ENGINEERING_NOTES.md` 016）。需要跟随一个一直在动的目标时，
  不要用 Tween，直接自己插值（自己数 `elapsed`，一帧一次写）。
- **手写 `.tscn` 里的 `Transform3D` / `Basis` 是高危操作**：`Transform3D(...)` 那 12 个数字的
  行/列顺序写反了**不报错也不警告**（它就是另一个合法的旋转矩阵）。实测：手写 `rotX(-45°)`
  被解释成 +45°，相机朝天看、路面全在画面外，画面里只剩背景色。玩法参数（相机角度/位置）
  用 `@export` + 代码设一次，并打印 `global_rotation_degrees` / `unproject_position()` 自检
  （`ENGINEERING_NOTES.md` 025）。
- **`SubViewport` 默认 `own_world_3d = false`**：它**共享父视口的 World3D**，
  于是它里面的 `WorldEnvironment` / 灯光 / 相机全都跑进主世界，两个环境互相抢
  （实测：关卡的天空被星系背景层的星空顶掉）。给 SubViewport 单独搭一套 3D 时 MUST 显式
  `own_world_3d = true`（`ENGINEERING_NOTES.md` 026）。
- **`Control` 的锚点在父节点不是 `Control` / `CanvasLayer` 时静默失效**：挂在 `Node2D`（或普通 `Node`）
  下的 `Control`，可锚定矩形是**零** → `anchor_bottom = 1.0`、`anchors_preset = 15` 等于没写，
  尺寸退化成"offset 的差"（实测：想铺满屏幕的路面变成 `900x0`，画面上"少了一层"，不报错）。
  2D 场景里想铺满屏幕：放进 `CanvasLayer`，或按设计分辨率写死 offset
  （`ENGINEERING_NOTES.md` 027）。

## 目录速查

| 路径 | 内容 |
|---|---|
| `entry/` | `main.tscn`（主场景/常驻壳）、`main.gd` |
| `core/` | 约定（`paths` / `events` / `types` / `options_data`）+ 服务脚本（`save_storage` / `options_applier`）+ 三个独立场景（`ui_root.tscn` / `save_service.tscn` / `game_flow.tscn`，都挂在 `entry/main.tscn` 上） |
| `data/types/` | **可配置数据的类型定义**（`Resource` 子类，如 `GalaxyBody` / `GalaxyConfig`）。加"能在编辑器里配的数据"就放这里 |
| `data/resources/` | **配好的数据实例**（`.tres`，如 `galaxy.tres`）。路径走 `Paths.GALAXY_CONFIG` 这类常量 |
| `data/_archive/` | 被取代的旧配置快照（**存成 `.txt` 而不是 `.tres`**：引用了已删脚本的 `.tres` 是"加载就报错的坏资源"） |
| `save_data/` | `save_section.gd`（基类）、`save_data.gd`（根）、`meta_save.gd`（元数据段）、`options_save.gd`（设置段，独立成 `options.sav`）、`plan_save.gd`（玩家保存的「方案」，独立成 `plans.sav`） |
| `ui/` | `title_screen/`、`main_menu/`、`galaxy/`（常驻的 3D 星系背景层；**它的 SubViewport 设了 `own_world_3d = true`** —— 否则星系的天空/灯光会漏进关卡世界，见 ENGINEERING_NOTES 026）、`map/`（星系地图 = 关卡选择屏：**从主菜单「开始」进入**；顶栏 **左「返回」+ 右「下一步」**（无标题），其下「< 名称 >」切天体，下半屏信息卡片；**「下一步」→ `ui/workshop`（制造：去装配兽人）**，走"先 `_close_map()` 恢复主菜单 UI → `CLOSE_UI(自己)` → `OPEN_UI(制造)`"）、`plan/`（方案：**卡片 = 已保存的方案（存档 `plans.sav`，新的在最上面）+ `plan_config.tres` 里的占位卡片**；**标题「方案」在左上**、**左下「返回」**（回主菜单）、**右下「新建方案」**（→ `ui/workshop` 制造，带 `caller = Paths.UI_PLAN`），中间**只有一个竖直 `VBoxContainer` 装所有方案卡片**（外套 `ScrollContainer`）；已保存方案的卡片标题是**玩家输入的名字**，那个 Label 的自动翻译是关掉的）、`workshop/`（制造：制作页 = 4×4 躯体装配 + 部件列表；**两个入口两种形态**（靠 `OpenUiRequest.caller` 区分，见 `ENGINEERING_NOTES.md` 022）：从地图界面「下一步」进 = 正常形态（顶栏 **左「返回」+ 右「开始」**，「开始」= 按 `SELECT_LEVEL` 选中的关卡发 `START_GAME("")` 直接进关卡），从方案界面「新建方案」进 = 编辑形态（**右上角按钮变「保存」**：点开自建命名弹窗（`SavePopup`，全屏遮罩 + 居中卡片 + `LineEdit` + 取消/确定，点遮罩＝取消、回车＝确定），名字非空才发 `SAVE_REQUEST` 写进 `plans.sav`，成功即关弹窗并回方案界面；**「返回」也回方案界面**））、`warehouse/`（**界面显示名「图鉴」**：**标题在左上、返回按钮在左下**；**整屏一个部件网格**（`ScrollContainer` + 4 列 `GridContainer`），**点部件弹自定义弹窗**看详情 —— 点「关闭」或点遮罩都能关；弹窗是 `PanelContainer` + 全屏遮罩自己做的，不是 `Window`/`PopupPanel`；**返回按钮必须排在 `PartPopup` 之前**，否则弹窗开着时它浮在遮罩上面还能点）、`options/`（设置：**只有语言 + 三路音量**，改动即存；返回在左上）、`pause_menu/`、`credits/` |
| `game/road/` | **真正的关卡**：**2D 三车道躲车**（俯视、自上而下滚动，没有透视/相机）。`road_level.tscn`（关卡本体 `Node2D` + 路面/护栏 + HUD + 失败面板 + 感知 + 装配）、`runner.tscn`（兽人**占位图形** + `runner.gd`，`Node2D`）、`car.tscn`（障碍车 + `car.gd`，`Node2D`）。路径常量 `Paths.GAME_ROAD_LEVEL` / `GAME_ROAD_CAR`。**关卡内部一切用像素**，只在事件负载与 HUD 上按 `px_per_meter`（100 像素 = 1 米）换算成米 |
| `locale/` | `en.po`、`zh_CN.po`、`texts.pot` |
| `default_bus_layout.tres`（工程根） | 音频总线布局：Master / Music / SFX（音量设置作用于这三条） |
| `addons/godot_core_system/` | 框架插件，入口 `source/core_system.gd` |
| `scripts/` | `godot-lint.ps1`（静态门禁）、`verify-engine.ps1`（引擎验证）、`engine-baseline.json`（机器相关基线） |

## 已知未完成事项（别当 bug 反复修）

- **主菜单只有 设置 / 开始 / 方案 / 图鉴 四个按钮**（界面显示名）。
  - **开始 → `ui/map`（地图界面就是关卡选择屏）**：打开前先 `set_ui_visible(false)` 把主菜单 UI 藏起来，
    地图是全屏透明界面、只留 3D 星系 + 自己；返回由地图界面调 `restore_after_map()` 恢复。
    以后要单独做一层选关，就在 `ui/map/` 前面插一个界面，改 `_on_start_pressed` 里的 Path 即可。
  - 「地图」「评分」两个**按钮**已移除（2026-10-07）：地图改由「开始」进入；评分界面与其数据整体删除。
  - 原「制造」按钮已改成「方案」并指向**新界面** `ui/plan/`（同日，人类选的"指向新界面"）。
    **但 `ui/workshop/`（制造）现在从地图界面的「下一步」进**（同日）——
    流程是「开始 → 地图选星球 → 下一步 → 制造装配兽人 → 点「开始」进关卡」。所以它不是死代码。
    它还有**第二个入口**：方案界面右下角「新建方案」→ 制造（**编辑形态**：
    `OpenUiRequest.caller = Paths.UI_PLAN` → 右上角变「保存」（弹命名窗、写 `plans.sav`）、「返回」回方案界面）。
- **「方案」现在只存了名字**（2026-10-07）：`PlanSave.plans` 里每条就是 `{"name": "..."}` ——
  **装配内容（每个部位装了什么部件）还没有数据模型**（`PartHost` 未接），所以保存下来的方案打开也看不到装配。
  以后往条目里加键时 MUST 同时提升 `SaveData.version` 并写迁移。
  方案界面下半那 3 张卡片（`plan_config.tres`）仍是**占位文案**。
- **进关卡的链路已通（2026-10-07）**：地图「下一步」时 `ui/map` 读当前天体的
  `GalaxyBody.level_scene` 发 `Events.SELECT_LEVEL`（payload = 关卡路径字符串），
  `core/game_flow.gd` 把它记进 `_selected_level`；制造顶栏「开始」发 `START_GAME("")`
  —— **空路径的语义就是"用 `SELECT_LEVEL` 选中的那一关"**（见 `core/events.gd` 注释），
  两个都空才报错。**目前 `galaxy.tres` 里所有天体的 `level_scene` 都是空的**，
  于是地图会告警并回退到 `Paths.GAME_ROAD_LEVEL`（默认关卡）；字段留给人类在编辑器里配。
- **关卡是"自走"的：玩家不操作**（2026-10-07 人类定的口径，没有触摸 / 键盘换道输入）。
  链路是「**感知上报 → 部件下令 → 关卡执行**」：
  - `game/road/road_level.gd` 每帧算三条车道的占用，且**只在状态改变时**发事件
    （`OBSTACLE_AHEAD_*` / `ENEMY_LEFT_*` / `ENEMY_RIGHT_*`；payload 见 `_payload()`：
    `distance` / `lane` / `player_lane` / `lane_count`）；
  - 部件（`data/parts/dodge_brain/`「闪避脑」）收到后发 `Events.LANE_MOVE_REQUEST`
    （payload = 目标车道 int）—— **决策在部件，规则在关卡**（关卡做范围校验）；
  - **没装会躲的部件，角色就一头撞上去**：这是玩法本身，不是 bug。
  - 关卡默认装配写在 `road_level.gd` 的 `@export var loadout`（现在是 `["dodge_brain"]`）；
    换道时关卡会**补发"离开"事件**作废旧结论（否则部件会拿着上一条车道的旧数据左右横跳）。
- **进关卡时银河系背景层会被自动隐藏**（2026-10-07，人类选的"GameFlow 切显隐"）：
  `core/game_flow.gd` 在 `START_GAME` 淡黑之后藏、回主菜单/标题时显回来。**必须藏**：
  它是 `CanvasLayer(-1)`，而 CanvasLayer 永远画在 3D 之上、且在默认 2D 画布**之下** ——
  所以 3D 关卡会被它整屏盖住（曾经的 3D 版就是这样）；现在的 2D 关卡自己有铺满的底色，
  藏与不藏都盖得住，但藏起来最省心（也给以后可能加的 3D 内容留余地）。
  另注：导出的是 `galaxy_layer_path: NodePath`，**不是** `@export var x: CanvasLayer` ——
  后者在 `.tscn` 里存成 `NodePath(...)` 但**不会被解析成节点引用**（赋值被静默忽略，实测）。
- **关卡里那个兽人是占位图形**（`game/road/runner.tscn`：身体 + 腰带 + 头，纯色矩形拼的 2D 立绘）。
  换成"装配好的兽人"时替换这一个场景即可，`road_level.gd` 只调 `move_toward_x()` / `crash()`。
- **「制造」= 代码里的 workshop，「图鉴」= 代码里的 warehouse**：场景/目录/翻译 key 名都还叫
  workshop / warehouse（key 是稳定标识，显示名跟着语言走）。别看到对不上就"顺手改回去"
  （ENGINEERING_NOTES 020 记录了这次改名）。
- 评分界面（`ui/score/`）与它的成绩表（`ScoreBoard` / `ScoreEntry` / `score_board.tres`）已整体删除，
  语言文件里的 `ui.score.*` / `ui.main_menu.score` 也一并清掉（否则会留孤儿 key）。
- **设置界面只有两样：语言 + 三路音量**（2026-10-07 人类要求改的版；分辨率与按键重映射已删，
  见上面的存档契约与 `ENGINEERING_NOTES.md` 028）。全部是**改动即存**（没有 Apply / Cancel）；
  存档结构 `version = 6`（设置档仍只有 meta + options）。字号按别的界面来：
  返回按钮 240×120 / 字号 48（和制造、图鉴、地图一致），行标签与数值 44，下拉框 420×112，
  滑块 460×112（`step = 1` 吸附到档位）—— 想再调就改 `ui/options/options.tscn`。
- `[input]` 动作表目前只有 `pause`（ESC）。**设置界面里没有按键重映射入口**（同日删掉了）：
  要加回来的清单见上面的「按键重映射（已删除…）」。
- **存量静态 warn 已清零**：`godot-lint.ps1` 报 `error=0 warn=0`。
  原先 6 条 `locale_orphan` 来自**主菜单里已不存在的按钮**
  （`ui.main_menu.title` / `.options` / `.credits` / `.quit_game` / `.galaxy_placeholder`），
  已从 `locale/` 三处同步删除。注意 `ui.main_menu.credits` 和 credits 界面用的
  `ui.credits.*`（`title` / `body` / `back`）**是两套 key** —— 删前者不影响后者，
  别连坐删掉。
- **地图的"单颗特写"里看不到公转，这是几何必然、不是 bug**：相机与天体刚性绑定
  （每帧 `天体位置 + 固定偏移`），两者一起绕恒星转，相对关系永远不变 ——
  实测投影中心**恒为 (540,1200)**、相机到天体距离**恒为 648**，画面除了星球自转完全静止。
  已与人类确认过：**保持"尺寸绝对不变"即可**，不要求看到星球位移。
  真要看到位移，只能让相机与天体的相对位置变化，代价是"尺寸会变"或"星球飘出画面"
  —— **要改先问人类**（数据见 `ENGINEERING_NOTES.md` 016）。
- `godot-lint.ps1` 的 `-Project` 接受相对路径（入口会 `Resolve-Path` 归一化），
  不带参数时自动探测仓库根下含 `project.godot` 的目录。
- **仅编辑器导入时**会出现一次 `ERROR: Unrecognized UID: "uid://cc28skn5h7aup"`
  （就是 `entry/main.tscn` 自己的 UID），`--editor --quit` 反复跑都在、不在基线里，
  且**正常启动（`--quit-after`）不出现**、`entry/main.tscn` 与 HEAD 逐字一致。
  属于编辑器 UID 缓存的既有噪声，**不是回归**，没定位到根因前别乱改 `main.tscn` 的 uid。

## 工程笔记（改完代码 MUST 登记）

`ENGINEERING_NOTES.md`（仓库根）：记录**初级错误**（语言/引擎层面的坑）与**设计架构问题**，
每条都标注*是否回流项目模板*及回流做法 —— 逐条攒着，别每次从零重踩。

- 修掉一个坑、或发现一个架构问题之后，**MUST** 在它的「索引」表加一行、在「条目」里补一节
  （模板见文件开头），字段按那里的模板填全；
- 「是否回流模板」**MUST** 二选一填死（`是` / `否`），空着等于没记录；
- 改动**没有经过运行时验证**时，状态不许写「已修」。
