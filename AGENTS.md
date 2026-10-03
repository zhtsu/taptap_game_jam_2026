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
3. **界面文案一律用翻译 key**：场景里写 `text = "ui.xxx.yyy"`；新增 key 必须在 `locale/en.po`、
   `locale/zh_CN.po`、`locale/texts.pot` **三处同步**（`locale/fallback="zh_CN"`）。
   只有语言母语名这类不翻译的内容才写原文。
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
- 手写用到的类型字面量：`Color(r, g, b, a)`、`Vector3(x, y, z)`、`@export_file` 的字段写成带引号的字符串。

## 存档系统契约（改动前必读）

- **格式**：4 字节魔数 `GTSV` + `var_to_bytes(纯数据字典)`，扩展名 `.sav`；读用 `bytes_to_var()`
  （**不是** `bytes_to_var_with_objects()`）。因此存档文件里不可能承载任何逻辑/脚本/对象 —— 刻意设计，
  **不要换回去**（json 明文与 `.tres` 方案都因"可承载逻辑"被否过）。
- **结构**（当前 `version = 4`）：
  ```
  { "version": 4, "meta": { slot, saved_at, game_version, playtime },
    "options": { resolution, language, master_volume, music_volume, sfx_volume, input_bindings } }
  ```
  游戏档落盘时剔除 `options`（机器级设置单独进 `options.sav`，`list_slots` 把它排除）。
  `SaveData.metadata()` 对外仍返回**平铺的那 5 个键**（值取自 `meta`），存档列表靠它。
- **一段一个类**：分段都在 `save_data/`，继承 `SaveSection`；**加分段 = 新建类 + 在 `save_data.gd`
  加一行 `var xxx: XxxSave = XxxSave.new()`**，`SaveService` 不需要改。
- **分段里只放数据字段**（int/float/bool/String/`Vector2(i)`/Color/Array/Dictionary…）。
  放 `Object`/`Callable`/`Signal`/`RID` 会被 `to_dict()` 跳过并告警 —— **静默丢数据是 bug**，别用。
- **版本与兼容策略**：改结构 MUST 提升 `SaveData.version`，并 MUST 在 `save_data.gd` 的 `migrate()`
  里**声明策略**：**写迁移**（按 `from_version` 逐级补齐字段）或**显式拒绝**（返回 `{}`，由
  `SaveService` 给出可区分原因）。MUST NOT 悄悄改结构而不动版本号；MUST NOT 出现半读入。
  **三个已有范例**：`v1 → v2`（元数据搬进 `meta` 段）用的是**显式拒绝** —— 那是一次性决定
  （模板尚未发布、无真实用户存档），**以后 MUST NOT 再整体拒绝一整个版本**；
  `v2 → v3`（`options` 段加三个音量字段）与 `v3 → v4`（加 `input_bindings` 重映射表）用的是**写迁移**，
  按 `from_version` 补齐默认值、旧档照常可读。新的结构变更照后两个的样子写。
- **补丁类型校验**：`SaveSection.apply_dict()` 逐字段比对类型 —— 不兼容（除 `int` ↔ `float` 互通）时
  **拒绝该字段 + 告警 + 保持原值**。别指望 `set()` 兜底：Godot 对可转换的坏类型会静默转换
  （`float ← "abc"` → `0.0`），对不可转换的会静默忽略，两者都不告警。补丁路径是
  `{"meta": {"playtime": 5}}` / `{"options": {"language": "zh_CN"}}`。
- **设置单独存**：分辨率 / 语言 / 音量（Master / Music / SFX）/ 按键重映射都在 `OptionsSave.SLOT`
  （`options.sav`）。没有存档、**或设置档无法载入**（版本过旧 / 损坏）时，`SaveService` 用
  **当前引擎状态**播种默认值（保证界面显示 = 实际生效）并告警。
- **设置界面是"改动即存"**：下拉框 / 音量滑块 / 按键重映射任何一处改动都会立刻发 `SAVE_REQUEST`
  写进设置档，SaveService 写完立即应用。**没有 Apply / Cancel 这层缓冲** ——
  所以界面上也没有"确认"这一步，改错了只能再改回去。
- **音量是分档的**：档位定义在 `OptionsData.VOLUME_STEPS`（当前 `0~10`、每档 1，共 11 档；
  线性音量 = 档位 / `VOLUME_MAX_STEP`）。滑块 `step` 负责吸附，脚本再按档位去重 ——
  **只有档位真的变了才写档**，同一档内的抖动不落盘。存档里出现非档位值（旧档 / 手改）时，
  由 `OptionsSave.validate()` 吸附到最近档并告警。要换档位（不均匀档位、或改成 0~20）只改 `VOLUME_STEPS`
  与滑块的 `max_value`/`step`。
- **按键重映射**：`OptionsSave.input_bindings`（动作名 → 物理键码）**只记被改过的动作**；
  `OptionsApplier` 应用时先给 `OptionsData.REMAPPABLE_ACTIONS` 里的动作**恢复出厂绑定**再套用覆盖，
  所以"恢复默认"只要删掉表里的条目就行（幂等）。允许改哪些动作只写在 `REMAPPABLE_ACTIONS`。
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
- Tween 默认 `TWEEN_PAUSE_BOUND`：节点的 `process_mode` 决定它在暂停时是否推进 —— 转场/暂停界面要 ALWAYS。

## 目录速查

| 路径 | 内容 |
|---|---|
| `entry/` | `main.tscn`（主场景/常驻壳）、`main.gd` |
| `core/` | 约定（`paths` / `events` / `types` / `options_data`）+ 服务脚本（`save_storage` / `options_applier`）+ 三个独立场景（`ui_root.tscn` / `save_service.tscn` / `game_flow.tscn`，都挂在 `entry/main.tscn` 上） |
| `data/types/` | **可配置数据的类型定义**（`Resource` 子类，如 `GalaxyBody` / `GalaxyConfig`）。加"能在编辑器里配的数据"就放这里 |
| `data/resources/` | **配好的数据实例**（`.tres`，如 `galaxy.tres`）。路径走 `Paths.GALAXY_CONFIG` 这类常量 |
| `data/_archive/` | 被取代的旧配置快照（**存成 `.txt` 而不是 `.tres`**：引用了已删脚本的 `.tres` 是"加载就报错的坏资源"） |
| `save_data/` | `save_section.gd`（基类）、`save_data.gd`（根）、`meta_save.gd`（元数据段）、`options_save.gd`（设置段） |
| `ui/` | `main_menu/`、`options/`、`pause_menu/`、`credits/` |
| `game/` | 关卡场景（模板只放 `example_level`；换成自己的关卡后改 `Paths.GAME_EXAMPLE_LEVEL`） |
| `locale/` | `en.po`、`zh_CN.po`、`texts.pot` |
| `default_bus_layout.tres`（工程根） | 音频总线布局：Master / Music / SFX（音量设置作用于这三条） |
| `addons/godot_core_system/` | 框架插件，入口 `source/core_system.gd` |
| `scripts/` | `godot-lint.ps1`（静态门禁）、`verify-engine.ps1`（引擎验证）、`engine-baseline.json`（机器相关基线） |

## 已知未完成事项（别当 bug 反复修）

- 设置界面已完成：**分辨率 / 语言 / 音量（Master / Music / SFX）/ 按键重映射（pause）**，
  全部是**改动即存**（没有 Apply / Cancel）；落盘 `version = 4`。
- `[input]` 动作表目前只有 `pause`（ESC）。要让玩家改移动 / 跳跃等玩法动作：先在 `project.godot` 的
  `[input]` 里加动作，再把动作加进 `OptionsData.REMAPPABLE_ACTIONS`（界面会自动多出一行）。
- **存量静态 warn 已清零**：`godot-lint.ps1` 报 `error=0 warn=0`。
  原先 6 条 `locale_orphan` 来自**主菜单里已不存在的按钮**
  （`ui.main_menu.title` / `.options` / `.credits` / `.quit_game` / `.galaxy_placeholder`），
  已从 `locale/` 三处同步删除。注意 `ui.main_menu.credits` 和 credits 界面用的
  `ui.credits.*`（`title` / `body` / `back`）**是两套 key** —— 删前者不影响后者，
  别连坐删掉。
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
