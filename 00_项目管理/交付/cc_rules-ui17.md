# 交付：cc/rules-ui17

- 车道／工作者：B 界面／rules-ui（cc，BU 地图事件三类「事件对照比不了」改写专项）
- 状态：可合并

## 变更记录草稿

## 2026-11-06 【cc·rules-ui·未经审查】地图事件三类对不了的项改写专项：轮回入口新增原版对照，赌场与影片核实已有专项（dev.待定）

只加探针、夹具、测试，**没改游戏代码**；发现的不一致只记在这里。

1. **赌场 `CodexCasino.open`（m4e60 三页）——已有，核实后不另做。** `mv_oracle/casino_batch_probe.cjs` 早就真走 `CodexCasino.open／begin／update／finish`（Map004 解释器、事件 60，jsdom 读弹窗），13 例夹具 `tests/fixtures/casino_batch_oracle.json`；`xiyou_casino_batch` 用**真的 XMapScene**（地图 Map004 事件 60 那句脚本）逐例对：券不够（`single.none`「肝帝积分抽奖券不足。」、`twenty.short`「20连抽至少需要20张…」）、券够时的数量框文字、抽取后的券数／积分／变量／全员技能／结果消息、中途关赌场、停止、错地图（`wrong.map` 不开）。「事件对照的替身走不到这里」只是 `xiyou_event_compare` 的事，赌场本身不缺对照。已知差异仅 O-132（一抽没跑就结束，重制加「未开始」说明），测试里对原版时关掉、对 O-132 另比一遍。
2. **轮回入口（m221e3p0）——新做。**
   - 探针 `mv_oracle/reincarnation_entry_probe.cjs`：真创建原版 `Scene_ReincarnationDraft`（给它一层 WindowLayer，jsdom 里能跑），按用例调菜单处理函数（normal／hard／classic／back），再让 Map221 引路人事件（事件 3 第 0 页，指令 66～136）接着跑；`command301` 只记敌群并当胜利；文字清掉并记下。8 例：普通＋常规、困难＋常规、顶层返回、普通→返回→普通＋常规、困难→返回→困难＋常规、已开启 2307、已开启 2303、存档里 `entryPending`（pending.active）。每例记 open 前后／选完后／开战前／事件结束后的开关 2282／2303／2307／2494／2496／2500／2489、队伍、金币、物品 4／2896、全员学 8105 等五个技能的人数、`R.entry`／`entryAccepted`／`entryHard`、存档字段、执行过的指令序号、提示、传送。夹具 `tests/fixtures/reincarnation_entry_oracle.json`。
   - 专项 `xiyou_reincarnation_entry`：用真的 Map221 事件 3 加自动应答，逐例比开关、队伍（按集合比）、物品、全员学 8105（人数 166）、入口结果（accepted／hard）、提示、落点（接受后到方桌大厅、否则留在 Map221）。7 例参与对照，全过。
   - 原版事实：`open` 在已开启（2307／2303）时只提示「本局轮回已经开启，阵容规则不能中途更换。」、不进界面，事件直接走 111 的否则支（指令 67→135）；接受＋普通→2282 保持关、2307 开；接受＋困难→2282 开、全员学 8105、提示「这一次的轮回似乎有了些许不同」；返回再进不留痕迹；打完投影后 `finishEntry` 删存档里的 `entryPending`。
   - **发现的不一致（只记，不改）**：①原版阵容规则菜单有三项「常规阵容／随机角色／返回」，重制只有「常规阵容／返回」，「随机角色」（9 选 5 选人）是已知未开放项 O-035；②原版 `entryAccepted／entryHard` 还认存档里的 `entryPending`（读档中途重进的路径），重制没有这个存档字段，`pending.active` 一例不比；③`finishEntry` 在重制里是空操作（脚本里 `continue`），因为重制没存 `entryPending`，没有可行为差异。
3. **261 播放影片（ce1516）——核实，不新写。** 原版只有 CE1514「血轮眼开」、CE1516「幻术世界」两段用 261，参照引擎只是没有 `<video>` 才报错，不是行为差异。重制已有专项 `xiyou_movie`（8 类断言）：转换产物帧数／音轨对 ffprobe（86／76 帧、30fps）、`XMoviePlayer` 按时间逐帧、放够 帧数÷帧率 秒才发 `finished`（≥ 76 帧 ≈ 2.5 秒）、地图解释器先显示文字再放、放完才执行下一条（对应原版 `waitMode 'video'`）、片名为空不放（MV `name.length` 为 0）、战斗里记一条 movie 日志后接着往下执行（原版战斗解释器同样播完继续，重制把播放交给战斗画面层稍后演）。语义对得上，没有发现差异；没有视频元素的参照引擎无法给出夹具，所以这条是读 MV 源码核对，不是实测夹具。

### 测试
- 新专项 `xiyou_reincarnation_entry`（7 例×7 项＋来源／完整性）全过。
- 已有 `xiyou_casino_batch`、`xiyou_movie`、`xiyou_event_compare` 见下「验证」。

## 优化登记草稿

无新增。

## 交接板

- 下一步：无（总装视需要另派「随机角色 9 选 5」O-035，与本单无关）。
- 用户试玩说明：无（只加测试）。
- 需要用户决定：无。

## 进度账

- 地图事件：轮回入口加原版对照；赌场、影片确认已有专项覆盖

## 可优化（流程／工具／效率）

- 建议：`xiyou_event_compare` 的「对不了」清单里，赌场（m4e60）、影片（ce1516）、轮回（m221e3p0）三类现在各有专项，可以在清单里写明「由 xiyou_casino_batch／xiyou_movie／xiyou_reincarnation_entry 覆盖」，免得后人再当缺口（归总装）。

## 验证

- 语法检查、`工具回归.py` 通过；`xiyou_casino_batch`、`xiyou_movie`、`ui_smoke`、`xiyou_event_compare`、`xiyou_reincarnation_entry` 全过。`选测.py main --list` 只列 1 个场景（xiyou_reincarnation_entry，已含）。探针新加，夹具手工复制自 `.sandbox/reincarnation_entry.json`；未重跑整套同步（没改转换器／切片）。

## 本分支提交

- 轮回入口探针、夹具与专项 `xiyou_reincarnation_entry`；本交付单
