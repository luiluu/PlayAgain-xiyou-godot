# 交付：cc/nezha-tools83

- 车道／工作者：工具／哪吒（cc，项目线程「完成再刷西游Godot引擎重制」）
- 状态：可合并
- 基于：cc/nezha-save2 头（4282a987）。save2 合进 main 之前先从它切的，交付前要再 `git merge main`（见「验证」末尾）。

## 做了什么

### 1. `待核查.py` 认短分支名、认不出打警告

- 起因：审查 46～50 的核查条目里分支名都写短名（`android3`、`platform-keys1～3`、`tools71／72`、`release1／2`），旧版只认 `cc/…` 全名，审查 50 因此漏销 15 批，`检查.sh` 报 33 批、其实只有 21 批真没核（审查 51 手工补销）。
- 现在：核查条目的范围（标题和「核查覆盖」等范围行）里不带前缀的小写名字，按「合并进 main 的分支名去掉 `cc/` 后等于它、或以 `-它` 结尾」去认，**只有唯一一批对得上才销**。`ui16` 对上 `cc/rules-ui16`，`android3` 不会误销 `cc/other-android30`。
- 写法也认：`名字1～3` 展开成 1、2、3，`名字71／72`、`名字71、72` 展开成并列；提交号（十六进制）、`dev.NNN`、事件号（`m4e69p0`、`ce942`）、带下划线的不当成分支名。
- 认不出的打警告（标准错误，不影响清单）：对不上任何已合并批、或对上多批；只警告「像分支家族」的名字（去掉数字后是某个已合并分支的末段），区间、并列展开出来的名字对不上不警告。
- 对上多批的用别名表 `07_开发环境/待核查别名.json` 指定。审查 50 的 `release1` 同时是 `cc/entry-release1`（审查 49 核）和 `cc/platform-release1`，别名表里指向后者。
- 效果：在这个分支上跑 `待核查.py`，审查 50 的 15 批里 14 批靠自动识别销掉，`release1` 靠别名销掉；待核查总数 51 → 36 批，甲档 30 → 18 批（审查 51 不在本分支里，这里只看到审查 50 那 15 批被销；审查 51 合进 main 后清单会更短）。
- 回退：删掉 `待核查.py` 里 `short_names` 的调用块（`pending` 里 `for name, explicit in …` 那一段）即回到只认全名。
- 测试：`测试记录工具.py`（`ReviewListTests.test_short_branch_names`、`test_unknown_short_name_warns_but_noise_does_not`），16 项通过。

### 2. `entry.gd` 选测

- 起因：`modes/xiyou/entry.gd` 在 `选测对照.json` 里没有规则，落到最后一条 `*`＝整轮。
- 新增 `entry` 组，规则匹配 `modes/xiyou/entry.gd` 和 `entry.tscn`（.uid 照旧按去掉 .uid 归组）：固定场景 `xiyou_entry_release`（发行入口）、`ui_smoke`（标题）、`xiyou_key_smoke`、`xiyou_reincarnation_entry`、`xiyou_save_page`、`xiyou_platform`、`xiyou_input_handled`、`xiyou_flow`、`xiyou_event_compare`，再加引用了 entry 的测试（`refs`）。检查：guards。
- 测试：`测试选测.py` 新增 `EntryGroupTests` 4 项：真对照表把 entry.gd／entry.tscn 归 entry、别的 modes/xiyou 文件仍是整轮；改 entry.gd 不再整轮、选到入口一组而不选规则场景；入口组列的场景在 tests/ 里都有。反向验证：把规则改回 full，其中 3 项失败。
- 回退：删掉对照表里的 `entry` 组和两条 `entry` 规则，回到整轮。

### 3. 事件状态探针分段跑时打进度

- 起因：`event_state_probe` 整份重量（换源、新工作树）跑近一小时，各段 `subprocess.run(capture_output=True)` 期间完全没有输出，会话被 idle 超时掐断。
- 现在：`03_转换工具/event_state_shards.py` 新增 `Progress`，`run_sharded` 用它：开始打一行，之后每 60 秒打一行「已 mm 分 ss 秒，n/总数 段完成，还在跑」，每段结束再打一行；单段（`XIYOU_STATE_SHARDS=1`）也打。`补跑事件状态探针.py` 和 `同步正式西游.py` 的分段路径共用这一个函数，两处都有。结果文件不受影响（测试里开关心跳前后拼回的结果逐字相同）。
- 回退：环境变量 `XIYOU_STATE_PROGRESS_SECS=0` 关掉（回到整段无输出）；也可设成别的秒数。
- 测试：`测试事件探针分段.py` 新增 `ProgressTests` 5 项（心跳线程、退出即停、关掉不打、环境变量、真走 `run_sharded` 两段＋单段）；该文件 27 项通过（3 项跳过是本机没有参照引擎依赖的老用例）。
- 改了 `03_转换工具/` 下文件：同步脚本（`event_state_shards.py` 在 `incremental_sync.py` 的 PROBE_INPUTS 里）下一次同步会因此重跑事件状态探针一次，结果应与现有产物逐字相同。

### rift1 结案

- 照 `cc_nezha-save2.md`「第二项」：rift1（CodexWhisper／`codexWhisperSeen`）和 `XConfig.whisper_mark` 只在新源分支（`cc/wukong-newsrc10`／`-ec`）上，main 和本分支都没有这个过场，没有东西可复现。悟空已在 2ff9d706／0f753038 处理了 `xiyou_actor_p0`、`floor_run`、`fortress029` 里已知的残档。本单**不另做**，作结案处理。
- 留给新源合进 main 之后的跟进（save2 交付单建议 1～3 原文有效）：约 50 个测试改成开头也删 options.json、收成公用小函数；新源上起跑在 Map004 的逐个确认要不要标 rift1。

## 改动文件

- 改：`03_再刷重制_Godot/07_开发环境/待核查.py`、`测试记录工具.py`、`选测对照.json`、`测试选测.py`、`测试事件探针分段.py`
- 新：`03_再刷重制_Godot/07_开发环境/待核查别名.json`
- 改：`03_再刷重制_Godot/03_转换工具/event_state_shards.py`

## 验证

- `07_开发环境/工具回归.py`：11 项全过（59 秒）。
- `测试记录工具.py` 16 项、`测试事件探针分段.py` 27 项（3 跳过）、`测试选测.py EntryGroupTests` 4 项通过；`测试选测.py` 整份见下。
- 没改任何 Godot 工程文件（.gd／.tscn／.cfg），所以没有跑 Godot 场景，也没有走云端：`选测.py 4282a987 --list` 因为动了 `03_转换工具/event_state_shards.py` 会按转换器组列出 xiyou_rules 全部段，但这是工具层的改动、不进游戏，列出的场景与这次改动无关，总装合并时按影响面自行定。本机空闲磁盘 31 GB（高于 20 GB 线），没做全量或导出。
- 交付前要合最新 main：save2 合进 main 后，在本分支 `git merge main`（协调者要求用 merge、不 rebase），再跑一次 `待核查.py` 与 `工具回归.py`。

## 变更记录草稿

## 2026-11-07 【cc·哪吒·未经审查】工具三项：待核查认短分支名、entry.gd 选测、事件状态探针打进度（dev.待定）

- `待核查.py`：核查条目范围里不带 `cc/` 的短分支名（`android3`、`platform-keys1～3`、`tools71／72`）按「分支名等于它或以 `-它` 结尾」认，唯一对上才销；对不上或对上多批打警告，对上多批的用 `待核查别名.json` 指定（`release1`→`cc/platform-release1`）。起因审查 50 写短名漏销 15 批。
- `选测对照.json`：新增 `entry` 组，`modes/xiyou/entry.gd`／`entry.tscn` 改动只选入口、标题、发行版冒烟那一组，不再判整轮；`测试选测.py` 加 4 项。
- `event_state_shards.py`：分段跑事件状态探针时每 60 秒打一行进度（`XIYOU_STATE_PROGRESS_SECS`，0 关），补跑与同步共用；避免整份重量近一小时无输出被 idle 超时掐断。
- rift1（Map004 漩涡过场残留 options.json）：只在新源分支存在，main 上无法复现，按 save2 交付单第二项结案。

## 交接板

- 下一步：save2 合进 main 后合并本分支；新源合进 main 后做 options.json 公用小函数（save2 交付单第二项建议 1～3）。
- 需要用户决定：无。

## 优化登记草稿

无 O-待定：三项都是开发工具，不改游戏行为，回退方式见各项（对照表删 entry 组、环境变量 `XIYOU_STATE_PROGRESS_SECS=0`、删短名识别块）。

## 待交叉核查

- 丙档（工具）：`待核查.py` 短名识别会不会误销（尤其后缀匹配与区间展开）；`event_state_shards.py` 心跳线程在同步路径里不影响结果与退出码。

## 可优化

- 审查条目仍建议直接写 `cc/` 全名或合并提交号；短名识别是兜底。

## 本分支提交

- 待核查短名、entry 选测、探针进度三个提交（见 `git log 4282a987..`）。
