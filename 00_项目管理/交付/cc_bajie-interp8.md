# 交付：cc/bajie-interp8

- 车道／工作者：事件解释器（cc·八戒，派单第十六批 GB6；第二棒接续第一棒掉线的会话）
- 状态：可合并
- 基于：github/main 00fa4857，交付前已合 github/main 1772d9ac（tools-merge-probe，只改工具，没碰切片／转换器／探针）。

## 变更记录草稿

## 2026-11-09 【cc·八戒·未经审查】参照宿主中文路径读文件、审查 66／71 遗留（dev.待定）

- **m4e71p0 根因修好（O-待定·参照宿主中文路径读文件）**：`03_转换工具/mv_oracle/hboot.cjs` 的 `boot` 给 `XMLHttpRequest` 包一层 open／send：同步 GET 的 `file:` 请求用 `fileURLToPath` 解码百分号转义后经 fs（仍走 fs 守卫）直接读，给 status 200／404、readyState 4、responseText。原来 jsdom 不解码，工程路径含中文时 `data/ContentVersion.json`、`data/PlayerChangelog/*.json` 全 ENOENT，参照里 `CodexGuide.releaseInfo()` 为空、`changelogEntries()` 为 0。快测：releaseInfo＝v0.62.12，更新日志 12 版、v0.62 打头。回退：`XIYOU_HBOOT_FILE_XHR=0`。只影响参照，不影响游戏。
- **审查 66 P3-1**：interp6 的 i7 七层变体一半重复、「给够见面礼」那支没覆盖。改成给够见面礼：物品 182 到门槛（35～110／20），206＝30×门槛（210～510／150），去掉被门前赋值盖掉的 843（`event_presets.json`，14 个预设）。
- **审查 66 P3-2**：`事件写法覆盖.gate_of` 把没执行到的 411 当门。加 `if_head_executed`：只有同缩进的 111 执行到了，411 没执行到才算「条件成立、没走否则」的门；111 自己也没执行到时接着往外找。
- **审查 71 P3-1**：`tests/xiyou_troop_events.gd` 的 more_slots 放宽口径加 `not oracle_half`：_half 份的规则随机跟参照一样固定 0.5，多出格就是重制错了，不放宽。
- **审查 71 P3-3**：`battle/battle_event_runner.gd` 约 483 行注释「全灭回大厅」改成「走 O-244 结束画面回标题」。
- 审查 66 P3-3（分段乙 tag 前缀 b1／b2 重用）按派单只登记，没改。审查 71 P3-2 总装自己改，没碰。

## 预期测量变化

hboot.cjs 修好中文路径 file:// XHR 后，参照里 CodexGuide 读得到 v0.62.12 的 ContentVersion 与 PlayerChangelog，event_probe 的 m4e71p0（改版向导）更新日志页从 v0.36 以前的旧页变成 v0.62 起的 12 版，选项与台词随之变化，这是修正后的正确参照（O-待定·参照宿主中文路径读文件）。

## 交接板

- 下一步：hboot 修好后，参照能读到 v0.62.12 的更新日志了，但现有 m4e71p0 的 23 个用例没有一个选「更新日志」（都是 i4／i6 走别的分支），所以本次整份结果在 m4e71p0 上没变化。要覆盖更新日志页，可派分段甲车道给 m4e71p0 出选「更新日志」的变体（interp6 估约 200 实例），增量探针即可，不用再整份。
- 用户试玩说明：无（只改参照工具、测试和注释；i7 预设只影响参照对照）
- 需要用户决定：无

## 进度账

- 无变化（参照工具修正与审查遗留）

## 优化登记草稿

| O-待定·参照宿主中文路径读文件 | `03_转换工具/mv_oracle/hboot.cjs`（工具，只影响参照，不影响游戏）：`boot` 里给 `XMLHttpRequest` 包 open／send | jsdom 的 file:// XHR 不解码百分号转义，工程路径含中文时同步读 `data/ContentVersion.json`、`data/PlayerChangelog/*.json` 全 ENOENT：参照里 `CodexGuide.releaseInfo()` 为空、`changelogEntries()` 为 0，m4e71p0 更新日志只剩 Map004 里 v0.36 以前的页 | 同步 GET 的 file: 请求用 `fileURLToPath` 解码后 fs 直接读（仍经 fs 守卫），给 status 200／404、readyState 4、responseText；实测 releaseInfo＝v0.62.12、更新日志 12 版 v0.62 打头 | 参照宿主的环境缺陷，原版在 NW.js 里读得到；修了参照才跟正式版一致（interp6 查实，interp8 做） | 环境变量 `XIYOU_HBOOT_FILE_XHR=0` 退回 jsdom 原行为 | cc（八戒 interp8） | 工具修正；编号待总装分配 |

## 验证

- 事件状态探针整份重量（hboot.cjs 在探针 coreFingerprint 里）：`XIYOU_STATE_SHARDS=2`，经 `占槽.py`＋`长任务.py --idle-timeout 7200`，11-09 09:10～11:55 UTC（164 分钟），24058 例，reused 0，errors／unfinished 都空。
- 整份结果跟 main 已发布的 `generated/oracle/event_states.json` 逐例比：24058／24058 对上号，只 14 例变了，全是本分支改的 i7 见面礼变体（m30e8p0、m32e1p0、m33e3p0、m45e1p0、m46e1p0、m47e13p0、m64e1p0 各 2 例），其余逐字相同。
- 云端选测（基准 1772d9ac，`选测.py main` 列出的 83 个场景，含 xiyou_event_compare*、xiyou_troop_events*、xiyou_rules*、xiyou_determinism 等）：9 片全过，最长一片 13.9 分钟。运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42614222235
- `工具回归.py` 全过（74 秒）；`语法检查.py` 659 个 .gd 0 问题。
- 同步（总装定的 A 方案）：hboot.cjs 是 mv_oracle 公共 helper，进 incremental_sync 公共键，所有参照探针键都变。本车道已用 `长任务.py --idle-timeout 7200` 跑 `同步正式西游.py --accept-additions`（PROBE_PLAN executed 96），结果见下。
  - 12:19～14:36 UTC（约 2 小时 17 分，经共用槽排队，探针全部跑完、无失败）。结果「有变化」退出码 2：只有 `events.json` 的 `m4e71p0` 一例 trace 变了（更新日志页变成 v0.62 起的 12 版，正是 hboot 修复的效果），verify issues 空。已用 `生成接受单.py --reason-from` 写成接受单 `03_再刷重制_Godot/04_验证/测量接受/cc_bajie-interp8.json`（1 条）。同步已写待接受指纹（pendingAcceptance），总装合并可直接用本树产物，main 按自己的基线比较时带上这张接受单。
  - `event_states.json` 不在测量键表（oracle_additions）里，i7 那 14 例随预设变，不需要接受单。

## 合并提示

- 产物指纹在本工作树 `generated/sync_stamp.json`，总装合并走 `--from-worktree`。工作树：`/private/tmp/claude-501/-Users-kyo-Documents--------/68ff293e-5d57-476e-9ea4-b5e620476291/scratchpad/interp8`（scratchpad 里的 clone，合并后可删）。
- 若 `--from-worktree` 被拒、退回完整同步，事件状态探针会经 `--state-prev-from` 从本树取回（24058 例）；其他探针要重跑。

## 可优化（流程／工具／效率）

- 建议：hboot.cjs 这类公共 helper 一改，同步就要重跑全部 50 来个参照探针。派单只写了「事件探针整份重量」，没算到这一层，第二棒才发现。可在 `选测.py`／`合并车道.py` 的提示里，改到 mv_oracle 公共 helper（非 `*_probe.cjs`）时直接说「同步会重跑全部探针，车道先跑 --accept-additions」（归工具车道哪吒，省总装一次临时排槽）。

## 本分支提交

- 648f65629 审查 71 P3-1／P3-3、审查 66 P3-2
- 06fb9b608 审查 66 P3-1：i7 见面礼变体
- 0486c72a9 m4e71p0：hboot 中文路径 file:// XHR
- 26fa805ee 合 github/main（tools-merge-probe）
