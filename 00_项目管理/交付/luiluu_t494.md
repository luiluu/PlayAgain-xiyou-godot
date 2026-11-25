# 交付：luiluu/t494

- 车道／工作者：T494 修：西游档抽奖期望恢复原版（小A，Neon＋high，P8）
- 状态：可合并

## 修复方案与设计理由

依据 Kyo 2026-11-25 拍板（事项 65 推荐项「恢复原版正期望，保留读档不能刷」，玩家不补偿）及补充要求（「自定义抽也要检查」），本单在前期只读排查（`3e2691aa8`）基础上完成修复：

1. **方案选型：按 `XTianqi.active` 分流＋可回退开关 `XLotteryRework.TIANQI_ONLY := true`（而非直接将 `EV_NOT_POSITIVE` 改为 `false`）**
   - **理由**：当前工程中天启篇没有另外一套抽奖期望模块，其 1431/1432/1433/1434 抽奖直接复用 `XLotteryRework.remap`/`text`（且天启篇虚拟玩家脚本 `tests/virtual_player/virtual_player.gd:129` 等经济口径依赖 `EV_NOT_POSITIVE`）。若把 `EV_NOT_POSITIVE` 直接改 `false`，天启篇也会一并变为正期望，违背「天启篇零改动」。
   - **实现**：
     - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/lottery_rework.gd`：新增 `static var TIANQI_ONLY := true` 与 `static func ev_active(s: XState = null) -> bool`（当 `EV_NOT_POSITIVE` 为真且 `TIANQI_ONLY` 为真时，仅 `XTianqi.active(s if s != null else XState.current)` 为真才启用非正期望改写）；`remap` 与 `text` 改调 `ev_active(s)` 并新增向后兼容的可选参数 `s: XState = null`。
     - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/mv_event_core.gd`：`_variable_random`（115 行）与 401 对话文字处理（274 行）调用 `XLotteryRework.remap`/`text` 时显式透传 `state()`。
     - **西游档**（含发行空壳下 `XTianqi.active` 恒为 `false`）：`ev_active` 恒为 `false`，CE 1431/1432/1433/1434 的全部随机范围与对话框文字 100% 回到原版 v0.62.12；
     - **天启篇档**（`XTianqi.active == true`）：`ev_active` 恒为 `true`，范围、文字、期望完全不变（零改动）；
     - **防 SL 与老存档兼容**：`SAVED_STREAM := true`、`SEED_FROM_ORB := true` 丝毫未动，西游档与天启篇均保留读档不可重抽，老存档的 `lotteryRandom` 字段照旧可读续抽；
     - **回退能力**：`XLotteryRework.TIANQI_ONLY = false` 即可单开关恢复「西游档也走非正期望」，`XLotteryRework.EV_NOT_POSITIVE = false` 可让全部存档回原版。

## 西游档全部抽奖入口盘点与结论

经全库扫描（`modes/xiyou/generated/db/CommonEvents.json`、`modes/xiyou/generated/maps/Map*.json` 全部 `code=117`／`103`／`355`／`102`、`Items.json`／`Skills.json` 公共事件效果，以及全部 `.gd` 脚本），西游档抽奖入口分为两类：

### A. 受 O-389（`XLotteryRework`）影响的肝帝积分赌场／抽奖入口（共 6 处）

| 入口 | 位置与调用链 | 是否自定义次数 | 修复后范围／文字与期望 | 与手动逐抽一致性 | 防 SL（读档同结果） | 对应测试与结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 大厅希禾·手动单抽 | `Map004 EV60` 页 0/1 选「是」→ `CALL_CE 1432` → `MVEventCore`（`lottery_id=1432`） | 否（1 券/次） | 回原版（`-400..600`、`-300..850`；文字 `-400~+600`、`-1800~+2500`）；4000 抽实测均 `+167.9`（原版量级 ~+165） | 基准入口 | 保留（`SAVED_STREAM=true`） | `tests/xiyou_fabao_rework.gd`：`range.xiyou_1432_*`、`text.xiyou_1432_*`、`msg.xiyou_1432`、`ev.xiyou_1432_orig`、`stream.reload_same` 全过 |
| 大厅希禾·自定义单抽（数量框＋批量） | `Map004 EV60` 页 0/1 选「自定义单抽」→ `mv_script.gd` `CodexCasino.open(this)` → `XCasinoBatch.open("single")` → `XCasinoDialog` → 逐抽 `MVInterpreter`（`lottery_id=1432`） | **是**（数量框填数或 MAX） | 走同一条 `MVEventCore._variable_random` → `XLotteryRework.remap(1432,...,state())`，西游档回原版正期望（无对话展示） | 与手动单抽逐抽积分、二阶段次数、`lotteryRandom` 比特级一致 | 保留：真数量框读档重抽逐项一致 | `tests/xiyou_casino_batch.gd`：`custom_single.ev_orig` / `.done` / `.reload_same` / `.matches_manual` 全过；玩家存档只读副本 100 抽验证通过 |
| 大厅希禾·手动 20 连抽 | `Map004 EV60` 页 2 选「是」→ `CALL_CE 1431` → `MVEventCore`（`lottery_id=1431`） | 否（20 券/次） | 回原版（`-8000..12500`、`-5000..9000`；文字 `-8000~+12500`、`-35000~+43000`）；6000 次实测均 `+2796.7`（原版量级 ~+2809） | 基准入口 | 保留（`SAVED_STREAM=true`） | `tests/xiyou_fabao_rework.gd`：`range.xiyou_1431_*`、`text.xiyou_1431_*`、`msg.xiyou_1431`、`ev.xiyou_1431_orig` 全过 |
| 大厅希禾·自定义 20 连抽（数量框＋批量） | `Map004 EV60` 页 2 选「自定义20连抽」→ `mv_script.gd` `CodexCasino.open(this,"twenty")` → `XCasinoBatch.open("twenty")` → `XCasinoDialog` → 逐次 `MVInterpreter`（`lottery_id=1431`） | **是**（数量框填数或 MAX） | 走同一条 `MVEventCore._variable_random` → `XLotteryRework.remap(1431,...,state())`，西游档回原版正期望 | 与手动 20 连逐次积分、二阶段次数、`lotteryRandom` 比特级一致 | 保留：真数量框读档重抽逐项一致 | `tests/xiyou_casino_batch.gd`：`custom_twenty.ev_orig` / `.done` / `.reload_same` / `.matches_manual` 全过；玩家存档只读副本 50 次验证通过 |
| 深渊赌场（未知存在胜利后） | `Map141/152/160/161/176/177/223 EV1`、`Map162/210 EV4` → `CALL_CE 1434` → `MVEventCore`（`lottery_id=1434`） | 否（自动触发） | 回原版（两处 `-300..330`；文字 `-300~+330`、`-3000~+3000`）；4000 次实测均 `+15.2`（原版量级 ~+15/+17） | 无自定义批量入口 | 保留（`SAVED_STREAM=true`） | `tests/xiyou_fabao_rework.gd`：`range.xiyou_1434_*`、`text.xiyou_1434_*`、`msg.xiyou_1434`、`ev.xiyou_1434_orig` 全过 |
| 欧皇活动（`☆欧皇活动☆`） | `CommonEvents 1433`（原版留存公共事件，当前地图与物品无直接入口，仍在 `XLotteryRework.EVENTS` 内） | 否 | 回原版（二阶段格子 `-350..380`/`-350..500`、附加 `-50..60`）；4000 次实测均 `+14.4`（原版正期望） | 无自定义批量入口 | 保留（`SAVED_STREAM=true`） | `tests/xiyou_fabao_rework.gd`：`range.xiyou_1433_*`、`ev.xiyou_1433_orig` 全过 |

> 说明：西游档下 `XUiSkin.on()` 为 `false`，自定义数量框固定走 `modes/xiyou/ui/casino_dialog.gd`（`XCasinoDialog`）；即便将来启用新皮肤 `XSkinCasinoDialog`，其确认逻辑同样只把次数交给 `XCasinoBatch.begin(value)`，与 `XCasinoBatch` 共用完全一致的底层结算。

### B. 全库扫描确认的其他非积分赌场类「抽奖」入口（均不受 O-389 影响、均无自定义次数框）

| 入口 | 位置 | 结论 |
| --- | --- | --- |
| 秘境技能书抽奖 | `Map004 EV61`、`Map225 EV10` → `CALL_CE 1440` | 安慰奖券抽秘境被动书；不在 `XLotteryRework.EVENTS` 内，无自定义次数框，未受 O-389 影响 |
| 丹药抽奖 | `Map004 EV63` → `CALL_CE 1230` | 人道意志碎片抽丹药；不在 `XLotteryRework.EVENTS` 内，无自定义次数框，未受 O-389 影响 |
| 深渊／不朽商人装备抽取 | `modes/xiyou/core/abyss_merchant.gd` `XAbyssMerchant.draw` | 消耗战利品点逐次单抽装备（每轮最多 3 次），自有 LCG 随机流，不在 `XLotteryRework.EVENTS` 内，无自定义次数框 |
| 抽伙伴随机／抽奖事件 1～4／洪荒技能抽奖 | `CE 50/407/408/409/416`、`CE 1421~1424`、`CE 1441~1442` | 均不在 `XLotteryRework.EVENTS` 内，无自定义次数框，未受 O-389 影响 |

> 全库 `code=103`（输入数值）扫描确认：赌场相关仅有一处 `Map004 EV50`（讨债人借积分），并非抽奖入口。西游档全游戏能自己填次数的抽奖入口**仅**大厅 `Map004 EV60` 的「自定义单抽」与「自定义20连抽」两处。

## 测试与玩家存档只读验证

### 1. 本机无头 Godot 专项（一律 `--audio-driver Dummy`）

- `tests/xiyou_fabao_rework.tscn`：**112/112** 通过
  - 西游档期望实测：`1432`（4000 抽）均值 `+167.9`，`1431`（6000 次）均值 `+2796.7`，`1434`（4000 次）均值 `+15.2`，`1433`（4000 次）均值 `+14.4`；
  - 天启篇档期望实测：`1432`（4000 抽）均值 `-13.1`，`1431`（6000 次）均值 `-91.8`；关 `EV_NOT_POSITIVE` 回退 `+164.0`；
  - 四事件范围映射、对话首句文字（西游回原版、天启篇照旧）、`TIANQI_ONLY = false` 回退支、`EV_NOT_POSITIVE = false` 回退支、`SAVED_STREAM` 防 SL 与回退支全部通过。
- `tests/xiyou_casino_batch.tscn`：**273/273** 通过
  - 含 13 例原版参照对照、60 抽随机抽、以及新增真地图 `Map004 EV60`＋`XCasinoDialog` 数量框 `custom_single`（25 抽）与 `custom_twenty`（15 次）的 `ev_orig`／`reload_same`／`matches_manual` 端到端验证。
- `tests/xiyou_lottery_seed.tscn`：**12/12** 通过（首抽派生、老存档 `lotteryRandom` 续抽防 SL、回退支）。
- 静态与门禁：`03_再刷重制_Godot/07_开发环境/发行空壳.py check` 退出码 **0**（84 个脚本，825 个函数都有）；`03_再刷重制_Godot/07_开发环境/语法检查.py` 退出码 **0**（1224 个 `.gd`，0 个问题）。

### 2. 玩家存档只读副本验证（绝不修改原文件）

通过官方 `XSaveTransfer.read_import`＋`XSave.load_slot` 在隔离目录读入 `T494_赌场多抽_玩家存档.json`（运行前后原文件 SHA-256 均为 `1d559cdf9dad0241fb774e1f79d087f191511903011ed6ebcab9b85133ea082f`，一字节未改；临时验证脚本已从 `/tmp` 清理）：

- 读档状态：`XTianqi.active = false`、`XLotteryRework.ev_active = false`，老存档 `lotteryRandom`（`draws = 1616`，含 `seed`、`state`）正常读取；
- 对话框首句文字：CE 1432 含 `-400~+600`、CE 1431 含 `-8000~+12500`、CE 1434 含 `-300~+330`（全部恢复原版）；
- 真 `XMapScene`＋`Map004 EV60`＋`XCasinoDialog` 数量框实测（内存补足券）：
  - 自定义单抽 100 抽：净变化 **`+12875`**（均 **`+128.75`/抽**，二阶段 16 次，`draws = 1864`；修复前同起点为 `-2985`）；读档重抽完全一致，与同起点手动逐抽 100 抽完全一致；
  - 自定义 20 连抽 50 次：净变化 **`+144631`**（均 **`+2892.62`/次**，二阶段 9 次，`draws = 1935`；修复前同起点为 `+39691`）；读档重抽完全一致，与同起点手动逐次 50 次完全一致；
- 同起点连续大样本实测：单抽 4000 抽均值 **`+154.8`**（`draws = 12090`），20 连 4000 次均值 **`+2790.0`**（`draws = 25962`），回到原版量级。

## 玩家可见变更说明草稿（由小A 拟稿）

- 恢复赌场单抽、20连抽、自定义批量抽奖及深渊赌场的原版奖励区间与说明文字，同时保留读档不可重抽机制。

## 变更记录草稿

## 2026-11-25 【小A·T494·未经审查】修：西游档抽奖期望恢复原版正期望，保留防 SL（dev.待定）

- 依据 Kyo 11-25 拍板（事项 65 推荐项：西游档恢复原版正期望，保留读档不可重抽；玩家不补偿）与补充要求（核查自定义抽入口），在 `modes/xiyou/core/lottery_rework.gd` 新增可回退开关 `XLotteryRework.TIANQI_ONLY := true` 与 `ev_active(s)`：`EV_NOT_POSITIVE` 仅对天启篇存档（`XTianqi.active`）生效，西游档下公共事件 1431／1432／1433／1434 的全部随机范围与对话框文字回到原版 v0.62.12，天启篇零改动；`SAVED_STREAM` 与 `SEED_FROM_ORB` 保持不动，防 SL 与老存档 `lotteryRandom` 读取不变；`MVEventCore` 两处调用透传 `state()`。
- 全库盘点全部抽奖与自定义次数入口：西游档自定义次数抽奖仅大厅 `Map004 EV60` 的「自定义单抽」与「自定义20连抽」两处，其余秘境技能书／丹药／深渊商人等均不走 `XLotteryRework` 且无自定义次数框。
- 测试：`xiyou_fabao_rework` 112/112（西游档四事件范围、对话文字、4000／6000 抽均值单抽 `+167.9`、20 连 `+2796.7`、深渊 `+15.2`、欧皇活动 `+14.4`；天启篇维持非正期望；两档回退开关均覆盖）、`xiyou_casino_batch` 273/273（真地图数量框自定义单抽／20 连抽与手动逐抽一致、读档同结果）、`xiyou_lottery_seed` 12/12；玩家存档只读副本验证自定义单抽 100 抽 `+12875`、20 连 50 次 `+144631`、4000 抽均 `+154.8`／`+2790.0`、读档同结果与老存档 `lotteryRandom` 读取均通过；`发行空壳.py check` 0、`语法检查.py` 0。
- 玩家可见：恢复赌场单抽、20连抽、自定义批量抽奖及深渊赌场的原版奖励区间与说明文字，同时保留读档不可重抽机制。

## 交接板

- 下一步：合并入 `main` 后随西游线补丁／整包发布（同步更新 `03_再刷重制_Godot/00_设计/优化登记.md` O-389 备注：西游档默认 `XLotteryRework.TIANQI_ONLY = true` 回原版范围与文字，仅天启篇生效；回退 `XLotteryRework.TIANQI_ONLY = false`）
- 用户试玩说明：西游档大厅赌场单抽、20 连抽、自定义单抽、自定义 20 连抽及深渊赌场的奖励范围与对话说明恢复原版正期望，读档仍不可重抽；天启篇不受影响。
- 需要用户决定：无（Kyo 11-25 已拍板）

## 进度账

- 无变化

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方数（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XLotteryRework.remap` | 生产 1 处＋测试 6 处，共 7 处（`git grep -nE 'XLotteryRework\.remap\(' -- '*.gd'`） | 调用方 7 处逐处结论：`mv_event_core.gd:115` 已透传 `state()`，按当前存档分流（西游档回原版、天启篇走非正期望）；`tests/xiyou_fabao_rework.gd` 6 处已同步按无档／西游档／天启篇档／两档回退开关分别断言，新增可选参数 `s: XState = null` 保持向后兼容，无破坏调用方 |
| `XLotteryRework.text` | 生产 1 处＋测试 5 处，共 6 处（`git grep -nE 'XLotteryRework\.text\(' -- '*.gd'`） | 调用方 6 处逐处结论：`mv_event_core.gd:274` 已透传 `state()`，西游档 401 对话文字回原版范围、天启篇照旧改写；`tests/xiyou_fabao_rework.gd` 5 处已同步更新，向后兼容 |
| `XLotteryRework.TIANQI_ONLY` / `ev_active` | 新增开关与门面函数，调用方 5 处（`git grep -nE 'XLotteryRework\.(TIANQI_ONLY|ev_active)' -- '*.gd'`） | 调用方 5 处逐处结论：`lottery_rework.gd` 内部 `remap`/`text` 各 1 处；`tests/xiyou_fabao_rework.gd` 覆盖 `TIANQI_ONLY = false` 回退支 2 处；`tests/xiyou_casino_batch.gd:290` 断言西游档 `ev_active == false` 1 处；发行空壳下 `XTianqi.active` 恒为 `false`，西游发行包安全 |
| `XLotteryRework.EV_NOT_POSITIVE` | 测试赋值 6 处（`git grep -nE 'XLotteryRework\.EV_NOT_POSITIVE' -- '*.gd'`） | 调用方 6 处逐处结论：默认值保持 `true` 不变；`xiyou_event_compare.gd:302` 与 `xiyou_casino_batch.gd:40,58` 原版参照关开均正常；`xiyou_fabao_rework.gd:163,165,263,267` 覆盖天启篇回退支 |

## 云端选测

- 已通过：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45583400520（提交 `5ffe987e18`，`ci/luiluu/t494`，50 个场景、3 片全部通过，最长一片 13.1 分钟，`gh run watch` 前台等完）

## 本分支提交

- `3e2691aa8` T494：查赌场多抽结果总是负的（只读排查，非 bug，系 O-389 期望改造与负波动，交付单入仓）
- `5ffe987e1` T494：西游档抽奖期望恢复原版正期望（按 XTianqi.active 分流，保留防 SL）
- 本交付单更新提交（补全修复方案、全部抽奖入口盘点表、玩家存档只读副本验证与云端选测结果）
