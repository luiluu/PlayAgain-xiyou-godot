# 交付：cc/wukong-casino1

- 车道／工作者：C 规则／悟空（cc）
- 基线：总装九派单，从 cc/wukong-itembag1 末端 c2e81ab5（含批量抽奖原版参照）切出，再 cherry-pick cc/wukong-title2fix fb830b96（本分支 3b49195e，事件对照登记更换称号两条）。所以本分支带着 itembag1 的全部提交与它的交付单 `cc_wukong-itembag1.md`；itembag1 先合了的话这里只多出批量抽奖。
- 状态：可合并

## 变更记录草稿

## 2026-11-01 【cc·悟空·未经审查】批量抽奖（自定义单抽／20连抽）（dev.待定）

- 大厅希禾（Map004 EV60）的「自定义单抽」「自定义20连抽」做出来了（正式版 installCasinoBatchRuntime，CodexCasino v3）：弹数量框填抽数（或 MAX），开始后每抽扣券、把原生抽奖公共事件（单抽 1432／20 连 1431）整条跑一遍，自动选「赢下所有」，跳过文字与最外层的动画、等待，抽取中右上角提示静音；每帧最多 4 抽。中途可「停止后续抽取」，积分低于原门槛、券不够、赌场关了也会停。结束一句三行结果（停下的写原因）。
- 新模块 `core/casino_batch.gd`（XCasinoBatch：open／begin／cancel／update／finish、MODES、native_list）与 `ui/casino_dialog.gd`（XCasinoDialog，原版 DOM 覆盖层的样式与文字）。
- `core/mv_event_core.gd`：批量模式 `casino_draw`／`casino_root`（101 跳 401、102 选第 0 项且最外层缩进 5 记二阶段、最外层 212／230 跳过、待显示文字不中途弹出），117 与 setup_child 的子游标带上 `casino_draw`。默认 null，别的事件不受影响。
- `map/mv_script.gd`：认 `if(window.CodexCasino)CodexCasino.open(this[,"twenty"]);else …` 整段，交给 XCasinoBatch.open（等这一局结束）。
- `map/map_scene.gd`：`toast` 在抽取中直接返回（原版每抽把 $.toaster 换成空函数）；`_on_ui_page` 不把数量框当成「开了别的画面」（原版 DOM 覆盖层不是场景切换，不打断道具回背包）。
- O-待定 一抽没跑就结束要说明（见下），开关可回退。
- 专项 `xiyou_casino_batch`（新）。

## 原版缺陷（O-待定，开关可回退）

- **O-待定 一抽没跑就结束要说明**：原版 finish 只有 `if(s.used)` 才加消息。点「开始抽取」后第一抽前就停（积分已低于原门槛、赌场已关、券被别处用掉）时，弹窗直接消失，什么也不说（参照 `single.below`：messages 为空）。重制加两行「自定义单抽未开始：<原因>」「积分 N；剩余券 N」。取消不算（照旧不出消息）。恢复方法：`XCasinoBatch.notify_unstarted = false`。专项两支都跑（关时对原版、开时对「未开始」消息）。

## 优化登记草稿

| 编号 | 名称 | 原版 | 重制 | 恢复方法 | 状态 |
| --- | --- | --- | --- | --- | --- |
| O-待定 | 批量抽奖一抽没跑要说明 | installCasinoBatchRuntime finish 只在抽过时出消息，第一抽前就停（积分低于门槛、赌场关）弹窗直接消失 | 加「未开始：原因」与积分、剩余券两行；取消照旧不出消息 | `XCasinoBatch.notify_unstarted = false` | 待用户确认 |

## 参照

- 探针 `03_转换工具/mv_oracle/casino_batch_probe.cjs` 与 `tests/fixtures/casino_batch_oracle.json` 是上一位悟空在 itembag1 做的（12 例，Math.random 0.5），本分支没改探针、没扩切片，不用重跑同步。
- 读数要点：0.5 时单抽每抽 +100、20 连每次 +2250，二阶段与欧皇都是 0；关赌场那例 3 抽在第一帧就跑完（每帧 4 抽），照样「完成」；停止那例第一帧跑满 4 抽，第二帧才判到停止，原因「已停止」。
- 原版 nativeList 给全员学技能循环补 `if(actor)`，v0.28 数据里 1432／1431 已经都写了，补丁不起作用；重制照做（`native_list`）。
- CE1432／1431 里的 `117 [1]`（存档）前后把变量 21 加一再减一，存档公共事件要变量 21＝0 才存，批量里不会存档。

## 验证

- 专项 `xiyou_casino_batch`（新，239/239，单跑 11 秒）：12 例对原版（开没开、数量框标题／说明／标签／预览／MAX 后／抽取中按钮、结果 last_result 含前 20 抽样本、结果消息、提示静音、抽后积分／券／变量 1197／1196、全员 8101／8102／8091、没有跳过的脚本）＋解释器批量模式规则（选项第 0 项、二阶段、子游标不跳等待、普通游标照常问）＋native_list＋O-待定两支＋不固定随机数的 60 抽（二阶段、欧皇、券数与消息自洽）。专项把 `frame_budget_ms` 放宽，让每帧确定跑满 4 抽对齐参照。
- 选测 12 场景（CHECK_JOBS=3，墙钟 25 分钟，等槽为主）全过、无偶发：`xiyou_casino_batch`、`xiyou_event_compare`（必跑，5/5，登记未变）、`xiyou_item_bag`、`xiyou_flow`、`xiyou_lobby_shops`、`xiyou_book_capacity`、`xiyou_book_capacity_ui`（`_on_ui_page`）、`xiyou_script`、`xiyou_common_scripts`、`xiyou_interp_review`（MVScript 入口）、`xiyou_battle_events`、`xiyou_battle_common_event_child`（MVEventCore 117／setup_child）。日志 `04_验证/本地结果/并行测试/20261101_021532_hyrqvu39/`。不固定随机数那 60 抽：二阶段 14 次、欧皇 0 次（欧皇那支没碰到，只验了自洽）。
- `语法检查.py` 通过。
- 事件对照：对照替身宿主不是 XMapScene，原版探针也不是 Scene_Map，两边 open 都返回 false、不出消息；EV60 选项默认选「是」，「自定义单抽」分支本来就走不到，登记不用改（选测里 xiyou_event_compare 确认）。

## 交接板

- 下一步：O-待定「批量抽奖一抽没跑要说明」等 Kyo 确认。养成三个小件里批量抽奖做完（道具回背包已在 itembag1，批量吃药在哪吒 bulkpills1）。
- 用户试玩说明：大厅希禾选「自定义单抽」或「自定义20连抽」会弹数量框，填抽数（或点 MAX）后开始，自动连抽到完成或停下，最后一句结果；中途可点「停止后续抽取」。

## 进度账

- 养成·三个小件：批量抽奖完成（道具回背包在 itembag1；批量吃药在哪吒）。

## 可优化（流程／工具／效率）

- 无。

## 本分支提交

- 3b49195e（cherry-pick fb830b96）事件对照登记 m4e1p2／p3
- b925929a WIP：XCasinoBatch＋XCasinoDialog＋解释器批量模式＋MVScript 入口
- b9a12aed WIP：专项 xiyou_casino_batch
- 交付单定稿（本提交）
