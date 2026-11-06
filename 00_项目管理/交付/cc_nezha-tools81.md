# 交付：cc/nezha-tools81

- 车道／工作者：工具／哪吒（cc，项目线程「完成再刷西游Godot引擎重制」）
- 状态：可合并
- 基于：main 8e5ac381（dev.384，已合入本分支）。没改共用文件。

## 变更记录草稿

## 2026-11-06 【cc·哪吒·未经审查】长任务真正脱离会话；事件状态探针按地图增量并分段；补齐认 XIYOU_APP（dev.待定）

- **① 长任务.py start 改由 launchd 起**（`07_开发环境/长任务.py`）。查明了换源同步两次 143 的原因：原来用 start_new_session，任务的父进程虽然是 1、也自成会话，但 macOS 的「责任进程」（responsible pid）仍是发起它的 claude CLI，会话一关 app 按责任进程连带 SIGTERM。实测当时总装那轮同步（pid 87630）的责任进程就是一个 claude 会话。现在 macOS 上 start 写一份临时 plist（0600，登记完即删），用 `launchctl bootstrap gui/<uid>` 起 run：不保活，环境变量、工作目录、umask、打开文件数上限照搬，ProcessType Standard（不降速）。任务的父进程是 launchd，责任进程是它自己。start 用本轮启动令牌认状态文件（不再靠 pid）；作业起不来时报 `.start.err` 里的错。已结束作业的登记由 wait 看到终态时卸掉，下次 start 也清扫 2 分钟以前的。回退：`XIYOU_LONG_TASK_LAUNCHD=0`（没有 launchctl 时自动退回）。新测试 `测试增量同步.py` 的 `test_start_survives_killing_the_session_that_started_it`：发起 start 的假会话连进程组一起 SIGKILL 后任务照样跑完，并断言父进程是 1、责任进程是任务自己。用旧做法（`XIYOU_LONG_TASK_LAUNCHD=0`）跑这条会挂，责任进程等于发起它的 claude，说明测试咬得住。另加了退回旧做法的用例。
- **② 事件状态探针提速**（`mv_oracle/event_state_probe.cjs`、新 `03_转换工具/event_state_shards.py`、`同步正式西游.py`、`补跑事件状态探针.py`、`incremental_sync.py`）。原来 event_state_probe（10426 个变体）在同步里单进程整份重量。同步开跑前会删掉 `.sandbox` 里的上次产物，所以探针自带的增量从来没生效；上次被掐时它已经跑了 8255 秒还没完，是同步的长杆。
  - 按地图算摘要：探针包住 `fs.readFileSync`，记下每例读了冻结源的哪些 `data/MapNNN.json`（所在地图、场所移动去的地图、开局快照读的、启动时读的、插件自己读的）。每例的摘要＝冻结源除地图以外的全部＋开局设定＋探针代码＋本例读到的那几张地图＋用例号、预设、基础页指令与坐标。不再含整份切片和切片地图表，那两样只决定有哪些用例，不影响单个用例的结果。换源只改了几张地图、或切片只加了地图时，其余变体原样取回。原来的 1% 抽查重跑保留，而且现在结果和读到的地图都要相同，不同就整份重跑。坐标原来不在摘要里，顺手补上。
  - 同步里分段：与补跑一样按变体序号分 `XIYOU_STATE_SHARDS` 段（默认 4，每段占 1 槽）并行，并排进慢探针先起。
  - 摘要账：上次的结果用已发布的 `generated/oracle/event_states.json`。摘要记在 `.sandbox/event_state_keys.json`，按结果文件的 SHA-256 认领，留最近 6 份。`新建工作树.sh --补齐` 会带上主工作区的账，车道已有账时合并。账上认不出就整份重量（不会出错，只是慢）。同步日志里这一段开头写明走的是哪一种。补跑也用这本账、也往里记。
  - `event_state_shards.py` 进了该探针的缓存键（`PROBE_INPUTS`）。回退：`XIYOU_STATE_SHARDS=1` 单进程，`XIYOU_STATE_INCREMENTAL=0` 整份重量。
  - 摘要格式升到第 2 版，合并后第一轮还是整份量（4 段并行），之后才开始取回。
- **③ 新建工作树.sh --补齐 认 XIYOU_APP**：设了 `XIYOU_APP` 时，冻结正式源链接指向它；已有链接指向别处就改指过来。没设时不动已有链接，免得按新源补齐过的树被改回旧源。主工作区参照（`generated/oracle/events.json` 的 releaseVersion）与 XIYOU_APP 的版本不同时，不拿主工作区的参照覆盖本树已有的参照，打印一行说明；树里还没有 generated 时照旧拷贝，但警告参照对不上新源、要在本树同步。转换器 `xiyou_export.py` 已经认 XIYOU_APP（tools80），补跑也认，所以这一步只补了链接和参照两处。新测试 `测试提交守卫.py` 的 `test_fill_in_links_frozen_source_to_xiyou_app`。

## 交接板

- 下一步：合并后总装下一轮同步看日志里「事件状态探针：4 段；…」那一行，并记下 event_state 的耗时。第一轮整份量，预计约为原来的四分之一；第二轮起，没改的地图应该全部取回。
- 下一步（提醒）：在本分支合并之前，用旧 `长任务.py start` 起的任务还挂在发起它的会话上，那个会话别关。
- 用户试玩说明：无（工具）。
- 需要用户决定：无。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：①②③（回退开关见上）。
- 建议：tools73 的「只差预设行」合并（`presets_merge_plan`）拼出的 event_states.json 不在摘要账上，合并后下一轮同步的 event_state 会整份量一次。可以在 PRESETS_MERGE_JS 里顺手把车道和 main 两份摘要也拼进账里。收益是合并后那一轮省一次整份量（4 段约 30 分钟）。归工具车道。
- 建议：event_probe 的分段存档目录不带头顶／云裳成长记录（EVENT_LEDGERS，实测输出相同）；event_state 的分段还带着。要是实测输出也相同，可以照样去掉，每例新开局能少复制 11 MB。没验，先没动。

## 验证

- 工具专项：`测试增量同步.py` 71 项全过（含两个新用例）。`测试事件探针分段.py` 22 项全过，新用例包括：克隆冻结源后改一张无关地图，全部取回、结果一致；改变体所在地图，只有它们重跑、结果一致；同步分段路径第二轮经摘要账全部取回、结果逐字相同，发布的那份被改过就认不出；摘要合并、账的认领、只留最近几份、带账合并。`测试提交守卫.py` 17 项全过。
- `工具回归.py` 10 项全过。`事件空绿扫描.py --check` 通过（空绿 55 例，均在基线内）。
- 选测：`选测.py main --list` 因为改了探针、同步，列出了整批 Godot 场景。没跑这些场景，理由：Godot 测试读 `event_states.json`，而它的格式和内容不变。摘要只决定「取回还是重跑」，不改变量出来的东西；上面的用例已经验了取回与重跑逐字相同。本树也没有重新测量参照。
- 没实跑整轮同步：总装正在跑约 4 小时的整轮同步，占着槽，按派单不动它。

## 本分支提交

- 60b0f829 WIP：长任务 start 改由 launchd 起；补存活测试
- afcb04f2 WIP：event_state 探针按地图摘要增量＋同步里分段并行
- dfd31ac6 WIP：新建工作树.sh --补齐 认 XIYOU_APP；文档
- ebbc8643 合并 main
- 交付单 cc_nezha-tools81（本提交）
