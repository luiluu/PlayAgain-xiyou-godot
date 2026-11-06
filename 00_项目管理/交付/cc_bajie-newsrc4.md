# 交付：cc/bajie-newsrc3（续四，DD）

- 车道／工作者：A 内容·楼层／八戒（cc，第十四批 DD）
- 状态：① 做完（集成分支用，不合 main，不标可合并）；② 等总装失败表。
- 分支沿用 `cc/bajie-newsrc3`，开工合了 `cc/newsrc-switch` 7c2a3a7e（优化登记冲突：两边新增行都留）。工作树 `.claude/worktrees/quizzical-neumann-d318e5`；generated、`.godot`、`mv_oracle/.sandbox` 从集成树 `recursing-shamir-4cd3d8` 克隆（v0.62.12 新源）。
- 上一棒交付单 `cc_bajie-newsrc3.md` 的内容照旧有效（变更记录草稿、待核查、两条 O-待定），本单只写新增。

## 变更记录草稿

### 【cc·八戒·未经审查】换源追平续四：event_compare 新源基线重出、深渊赌场二阶段跟新源换序

- **深渊赌场 1434 二阶段**（event_compare ce1434#o5_3）：新源 v0.62.10 的 `installCasinoBatchRuntime` 里有 `fixAbyssStage2`，读入公共事件时把 1434 二阶段五对「1197 = v1191～1195、再重抽那一格」换成先抽再读（原注释：旧顺序 20 连后这几格残留约 ±30000）。数据文件本身没改，所以重制照数据跑就和参照对不上。参照探针打桩实测：执行到第 45 条时跑的是「1195 = 随机」。重制在 `XDB.table("CommonEvents")` 读入时调 `XCasinoBatch.fix_abyss_stage2` 做同样的换序；开关 `XCasinoBatch.ABYSS_STAGE2_ROLL_FIRST`（默认 true，false 回到 v0.28 数据原序），登「O-待定·深渊赌场二阶段」。casino_batch 加 abyss2.raw／roll_first／o-off 三项。
- **event_compare 基线按新源重出**：15565 例，一致 15556，登记 9 例（原有 3 例＋新进 6 例，理由都写进了基线的 note）；跳过基线收进 ce1370 四条（O_PUSH_RECAST 在战斗里补，地图对照认不出）和 ce9043 一条。
- **ce9039#n2／ce9026#n2**：上一棒给预设加的 `difficulty: 9` 是对的。集成树的事件状态产物是在这条预设改动之前量的，所以参照里还留着「超强者仅限地狱及以上难度获取」。用新源单跑这两例（`XIYOU_APP=…/v0.62.12/app.nw node event_state_probe.cjs 'ce9039#n2' 'ce9026#n2'`），提示没了，结果补进本树 generated 的 event_states 后两例一致。**集成树合本分支后的同步会重量这两例**（预设变了，增量键也跟着变），不用手补。

## event_compare 五例定性

| 用例 | 定性 | 处理 |
| --- | --- | --- |
| m148e38p0 | 新源数据：大厅 Map148 EV38 传到 Map234 凤凰殿，是新源新加的地图 234～239（v0.54 一护剧情），还没进 `xiyou_slice.json`，所以重制传不过去，战斗背景为空 | 进基线。**切片加 234～239 是另一件事**（盘点第 139 条早就列了，A 车道的独占文件），等总装决定派不派 |
| ce1434#o5_3 | 新源改动重制没跟上（上面） | 已修，现在一致 |
| m4e71p0 | 参照宿主的问题：jsdom 的同步读文件拿不到 `data/PlayerChangelog/*.json` 和 `data/ContentVersion.json`。新源单跑 `CodexGuide.readChangelog(37)` 得 null，`changelogEntries()` 得 0 条，所以参照只剩 Map004 里 v0.36 以前的那几页。真游戏读得到，重制先列 v0.62 是对的 | 进基线；**hboot 读文件这块交工具车道** |
| ce9039#n2、ce9026#n2 | 产物旧了（上面） | 现在一致；同步后照旧一致 |

另 3 例新进基线是上一棒定过性的：m4e69p1 及 #o4_2／#o4_3（O-待定·升级文字）、ce9043（流萤招募没做）。

## 验证

- 本机新源：`xiyou_event_compare` 全量 11/11（--update-baseline 那一轮；改前那轮 9/11，退步 6 例都是上表这些）、`xiyou_casino_batch` 261/261、`xiyou_floor_reach109` 过、`xiyou_determinism` 过。
- `casino_batch` 退出时有 3 条 SCRIPT ERROR（解释器在地图释放后还往下跑，`mv_interpreter.gd:218／245／69`），出在 TEST_RESULT 之后。并行测试因此判失败、重跑一次还是这样。**集成分支原版测试文件一样会出**（258/258 后同样 3 条），不是本单引起的，没查。
- `选测.py cc/newsrc-switch --list` 因为改了 `xdb.gd` 列了 387 个场景，没全跑：只有 1434 的读法变了，跑了引用 1434 的两个测试和 determinism。
- `事件空绿扫描.py --check`：空绿 96 例都在基线内，理由齐。
- `语法检查.py` 0 问题；`回退开关覆盖.py`：新开关算已覆盖。

## 待交叉核查

- `casino_batch.gd`（fix_abyss_stage2、开关）、`xdb.gd`（读入时调用）、`tests/xiyou_casino_batch.gd`（abyss2 三项）、`tests/event_compare_baseline.json`（note 与 9 例）、`tests/event_skipped_baseline.json`、`优化登记.md`（O-待定·深渊赌场二阶段）。

## 交接板

- 需要用户决定：O-待定·深渊赌场二阶段（默认跟新源，可回退），连同上一棒那两条 O-待定，编号等总装分。
- 下一步：② 等总装同步后的失败表，再认领事件／地图项。

## 可优化（流程／工具／效率）

- **hboot 读不到 data 下的 JSON**（工具车道）：`CodexGuide.releaseInfo()`、`readChangelog()` 都是同步 XHR，参照宿主返回空。修好以后 m4e71p0 能对上，标题版本号相关的参照也能量。
- **切片加地图 234～239**（A 车道独占文件）：m148e38p0 和一护剧情的事件对照都等着它。
- 测试槽满的时候，event_compare 要等很久（这次 import 加对照前后等了约 30 分钟）；本机直接跑只要 7～8 分钟。

## 本分支提交

- 见 `git log cc/newsrc-switch..cc/bajie-newsrc3`
