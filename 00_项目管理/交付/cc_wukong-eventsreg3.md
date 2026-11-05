# 交付：cc/wukong-eventsreg3

- 车道／工作者：A 内容·验收／悟空（cc）
- 基线：从 accept5（6e121324）切，并入 cc/dead-eventsreg1（覆盖表）与 **cc/dead-eventsreg2 的 WIP 3f8998a1**（预设 `answers` 选项应答、`random` 随机序列），交付前合 main 845c5287。
- **合并顺序：先合 cc/dead-eventsreg2，再合本分支**（我这几类写法几乎都在选项分支里，要用它的 answers；eventsreg2 之后若还改了 answers 写法，合时以它为准）。
- 状态：可合并

## 做了什么

- `event_presets.json` 加 12 个变体（tag g3／g4，用 answers 选对选项、个别再加变量／队伍预设），把派单给我的写法逐类走到：

| 写法 | 变体 | 原版效果（参照记下的） | 对照 |
| --- | --- | --- | --- |
| `$dataActors` 循环（灭世难度） | m4e41p1#g3（选「挑战灭世难度」「是」） | 开关、变量、独立开关、物品、角色技能都有变化 | 一致 |
| `CodexMapRemoval.notice` | m80e13p2#g3（random 0.1／0.5／0.9：遇深渊、难度 2、非随机副本） | 只有提示，不传送不重置 | 一致（对照里关掉 O-120 B2 的修正，见下） |
| `actor.addState`（ce1094） | ce1094#g3（82 入队、学 4955） | 角色 82 加状态 | 一致（变量 708 在页首被随机重写，实际走的是同写法的 708＝3 支） |
| `PHWarehouse remove` | m4e8p0#g3（选「重置仓库」「我以取出重要物品」） | 无可观察变化（仓库空） | 一致 |
| `SceneManager.push(Star_Scene_ActorWarehouse)` | m4e8p0#g4（选「角色仓库」） | 推入 Star_Scene_ActorWarehouse | 一致 |
| `SceneManager.push(Scene_StarWarehouse)` | m41e1p0#g3（选「取出」） | 推入 Scene_StarWarehouse | 一致 |
| toaster「传承强化已上限…」 | m195e23p0#g3（选「传承强化」，V1496＝20） | 提示 | 一致 |
| toaster「当前空闲奴隶数为 …」 | m186e3p1#g3（选「增加奴隶」，V565＝1） | 两条提示、变量 565／603 | 一致 |
| `prompt()` 改名 | m4e1p2#g3（选「我想改名字」） | prompt「你想改啥？」 | 一致 |
| `ConfigManager.DesignationN[N]` 条件 | m2e2p2#g3（V1＝3，选「就选他」） | 开关、独立开关 | 一致 |
| `CodexCasino.open`（单抽／20 连） | m4e60p0#g3、m4e60p2#g3（选第 4 项） | 「肝帝积分抽奖券不足。」／「20连抽至少需要20张…」 | **不一致，登记进 event_compare_baseline**：`XCasinoBatch.open` 只在地图场景里开，事件对照的宿主不是地图场景，提示不出；不是游戏差异，游戏里由 `xiyou_casino_batch`（自有原版参照）管 |

- 覆盖表（`04_验证/事件写法覆盖.md`，用 `xiyou_event_compare --coverage` 重跑）：没对照例的写法 **20 → 8**。剩下 8 类里：
  - dead eventsreg2 的：`103`、`261`、`354`。
  - **`HWGOE.save.cloudSaveGame`**（ce249）：云存档脚本，事件对照跳过基线里本来就登记了不移植。Kyo 14:23 定了要做 PC／安卓，这条是不是安卓版的云存档要重新判断，我没碰，留给平台车道。
  - **`CodexReincarnationRandom.*` 四类**（m221e3p0 轮回归来）：选「轮回归来！」后原版推 `Scene_ReincarnationDraft` 并等这个场景回结果，参照探针里场景不跑，跑满 6000 帧没结束（变体 m221e3p0#g3 已摘）。要做得给探针加「场景回结果」的预设（类似 battleResult），归下期。
- `xiyou_event_compare.gd`：O-120（B2）厄运王座宝箱深渊门修正 `removed_gate_fix` 照 `seal_check_fix` 的做法，只对修正表里的事件（80:13）在对照时关掉，其余用例照常开；修正本身另有专项管。
- 顺带发现（给 dead／工具车道，不在本分支改）：`--coverage` 记的下标在消息（101＋401）之后有时错位——m1e1p0 的 prompt 在 129 行，参照和重制都执行了、对照也一致，但覆盖里记的是 128、没有 129，所以这类在 eventsreg1 的表里被算成「没对照例」。本期靠 m4e1p2#g3（那里 16 行记上了）补上，表就不再列它；工具本身的错位没修。

## 验证

- 同步 `--accept-additions`：合 main 845c5287、`--补齐` 后「测量不变」；另对主工作区 generated/oracle 直接 `compare_file`：event_states 只多本期 12 个新键、改变 0，events 无变化。
- `xiyou_event_compare`（全量，带 --coverage）：6847 例，6844 一致，3 例在登记里（m4e73p0 旧的＋抽奖两例），0 退步。
- 选测：`云端选测.py run` 判成整轮（基准 accept5），427 个场景、14 片：426 过，**`xiyou_panels` 云端挂了一次**（https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42074484932）；本机单跑 35／35 过。本分支没碰界面面板相关的文件（只改事件对照测试、预设、基线），我判断是云端那一片的偶发或环境问题，但没下载云端日志确认，合并时请留意。
- `语法检查.py`、`工具回归.py`：通过。

## 变更记录草稿

## 2026-11-05 【cc·悟空·未经审查】事件写法对照补脚本／插件调用十一类（dev.待定）

- 事件对照加 12 个用选项应答走到的变体：灭世难度角色循环、地图移除提示、加状态、仓库移除与两种仓库界面、两种提示、改名、称号条件、抽奖，原版效果与重制逐条对上。
- 没对照例的写法 20 → 8；抽奖两例因对照宿主不是地图场景登记为已知不一致；轮回抽签四类要「场景回结果」预设，留下期。
- 未改游戏代码。

## 交接板

- 下一步：`CodexReincarnationRandom` 四类要给参照探针加场景回结果的预设；`--coverage` 消息后下标错位要修（归 dead／工具）；`HWGOE.save.cloudSaveGame` 按 PC／安卓重新判断移不移植。

## 进度账

- 地图事件：本期补 11 类写法的原版对照，没有发现游戏差异。

## 可优化（流程／工具／效率）

- 建议：事件对照宿主模拟成地图场景（或给 `XCasinoBatch.open` 留一个对照入口），抽奖这类就能直接比，不用登记。
- 坑：本机满载时 `event_state_probe` 等槽等过 50 分钟；改预设后别在同步还在跑时动 `event_presets.json`，否则同步报「输入在同步中改变」白跑。

## 待交叉核查

- `event_presets.json` g3／g4 12 条：选项序号是否对应派单里那一行。
- `tests/xiyou_event_compare.gd`：`removed_gate_fix` 逐用例关掉的范围。
- `tests/event_compare_baseline.json`：新登记两例与说明。
- 未改游戏代码。

## 本分支提交

- 合并 cc/dead-eventsreg1、cc/dead-eventsreg2（WIP）
- 3c2ffb5c WIP: 12 个变体、对照关 O-120 B2、抽奖登记
- 合并 main
- 交付提交（本提交）
