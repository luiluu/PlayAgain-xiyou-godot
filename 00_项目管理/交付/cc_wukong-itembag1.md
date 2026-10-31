# 交付：cc/wukong-itembag1

- 车道／工作者：C 规则／悟空（cc）
- 基线：从 main bbeecb5b 切出（brief 没等到，按上期 cc/wukong-smallsys1 盘点表做；smallsys1 只有盘点、不用合）。
- 状态：**道具用完回背包（ItemBagContinuation）做完，可合并**；批量抽奖（CasinoBatch）只做了原版参照，重制代码没写，交给下一位（见文末「接续」）。

## 道具用完回背包（installItemBagContinuationRuntime）

新模块 `core/item_bag_return.gd`（XItemBagReturn），原来只给 CE1317（被动书容量满）做的专用续用（`XPassiveBooks.remember_return／take_return`）换成通用的：

- **当场提示**：物品页每次真正用掉道具（药水、回 TP、直接用的），按原版快照比较给一句「已生效／已使用／事件已执行／未检测到效果：名字（…）」，主说明卡换成这句（附卡保留，沿用 O-007／O-008 字号与贴行摆位）＋右上角提示；光标换行才被说明盖掉，选人阶段照旧隐藏。
- **回背包**：用后预约了公共事件的，回地图跑完（同一张图、没有别的预约／事件／文字）再自动回物品页，选回原分类与那件（用完了就同一格、夹在列表内），焦点在列表，提示换成跑完后的结果；取消照旧回主菜单。同图传送（指路灯回大厅时人在大厅）照样回；换了图、或中途开了别的画面（战斗、商店、各页面；输入文字 prompt 不算）就不回。判定放在地图 `_process`（等同 Scene_Map.update 包装），开画面用地图 ui 加子节点判（等同 Scene_Map.stop 包装）。
- **换装卡 CE1343**：只含 0/122/355/655 的那条在物品页当场用地图解释器跑完，不回地图。
- 改动文件：`core/item_bag_return.gd`（新）、`ui/item_scene.gd`（`_after_use(ctx)`、`show_notice`、`restore_return` 取代 `restore_capacity_return`）、`map/map_scene.gd`（`_process` 回背包、`run_common_event` 记事件开始、`ui.child_entered_tree`；删掉 open_menu 里的 take_return）、`core/passive_books.gd`（删专用续用三个函数与 meta）。

## 原版缺陷（O-待定，开关可回退）

- **O-待定 快照记 TP**：原版快照不含 TP，回 TP 的道具明明加了 TP，提示却是「已使用」，不消耗的（无尽哈啤 789）直接说「未检测到效果……（请检查使用条件）」。重制把各角色 TP 记进快照。恢复方法：`XItemBagReturn.snapshot_tp = false`。专项两支都跑（关时对原版、开时改成「已生效」）。

## 优化登记草稿

| 编号 | 名称 | 原版 | 重制 | 恢复方法 | 状态 |
| --- | --- | --- | --- | --- | --- |
| O-待定 | 道具结果提示记 TP | installItemBagContinuationRuntime 快照不含 TP，回 TP 道具提示「已使用」或「未检测到效果」 | 快照加各角色 TP，回 TP 道具提示「已生效」 | `XItemBagReturn.snapshot_tp = false` | 待用户确认 |

## 参照

- 探针 `03_转换工具/mv_oracle/item_bag_probe.cjs`（11 例：药水、回 TP 消耗／不消耗、伙伴号角招募／最后一个／已在队、指路灯同图／换图、换画面、换装卡当场跑／已有卡），真走原版七个包装，窗口与场景是替身；产物手工复制为 `tests/fixtures/item_bag_oracle.json`（不进 PROBES，同 book_capacity）。
- 探针替身说明：大厅新局挂着自动执行事件，替身地图不跑它们，所以探针里关了 `checkEventTriggerAuto` 并清 `_starting`；传送照正式版同一帧换场景的次序补了 Scene_Map.stop＋performTransfer。

## 验证

- 专项 `xiyou_item_bag`（新，160/160，单跑 17 秒）：11 例对原版（提示文字、回不回地图、回到的分类／列表／选中、回来后的提示与 toaster、队伍与数量、技能增减、取消回主菜单、光标挪开提示消失）＋纯规则＋O-待定两支。
- `xiyou_book_capacity` 的续用守卫改成测通用 API（多了「换画面」与「另有预约是等不是放弃」两条）；它的 messages 比较滤掉物品页结果提示（原版探针直接走 Scene_ItemBase，没有 Scene_Item 包装）。
- 选测（相关 25 场景，含必跑 `xiyou_event_compare`）：见下方「选测结果」。
- `语法检查.py` 通过。

## 交接板

- 下一步：批量抽奖 CasinoBatch 重制（接续见下）；O-待定 TP 快照等 Kyo 确认。
- 用户试玩说明：物品页用道具会在说明卡与右上角提示结果；用伙伴号角、指路灯这类会跑事件的，事件跑完自动回到物品页原来那格。

## 进度账

- 养成·三个小件：道具用后续事件 1/3 完成；批量服用丹药在哪吒 bulkpills1；批量抽奖只有参照。

## 可优化（流程／工具／效率）

- 无。

## 接续：批量抽奖 CasinoBatch（下一位从本分支末端接）

已有：原版 `installCasinoBatchRuntime.js`（94 行，冻结源 `js/codex/runtime/`）读完；参照探针 `mv_oracle/casino_batch_probe.cjs`（12 例：单抽 5／MAX／过门槛／低于门槛／中途关赌场／中途停止／取消／没券，20 连 2 次／券不够／已有欧皇之证，非大厅）与 `tests/fixtures/casino_batch_oracle.json`。读数要点：Math.random 0.5 时单抽每抽 +100 积分、20 连每次 +2250，二阶段与欧皇都是 0；关赌场那例 CE 自己又把 2495 打开，照样「完成」；停止那例一帧最多跑 4 抽（8 毫秒），所以点停止后多跑到 4/4。

要做：
1. **解释器批量模式**（`core/mv_event_core.gd`）：加 `casino_draw`（null 或计数字典）与 `casino_root`；`_execute` 开头：批量时 101 跳过后面的 401 直接前进；102 选第 0 项，根层缩进 5 记二阶段；根层 212／230 直接前进；117 与 `setup_child` 建子游标时把 `casino_draw` 传下去（`casino_root` 不传）。
2. **XCasinoBatch**（新 `core/casino_batch.gd`）：MODES（single 1432／1 张／−30000，twenty 1431／20 张／−200000）、券 1639、`stock／maximum`；每抽前按原版次序判停止（已停止→完成→券不足→积分低于门槛→赌场关闭 2495），扣券后用 `MVInterpreter.new(host, 4, 60, 列表副本)` 整条跑（`learnSkill(8101/8102/8091)` 前没 `if(actor)` 的补上）；静音 toaster（`map_scene.toast` 在抽取中直接返回）；`XActor.learn_skill(8101)` 抽取中记欧皇；样本前 20 次；结束消息照原版三行格式（见 fixture `messages`）。
3. **入口**：`MVScript.run` 认 `if(window.CodexCasino)CodexCasino.open(this);else …` 那句（Map004 EV60 页 0／1 单抽 `open(this)`，页 2 为 20 连 `open(this,"twenty")`，else 支的提示不用管），不在大厅或没在地图时不开；券不足时原版两句消息。
4. **弹窗**：原版是 DOM 覆盖层（标题、说明、「抽数（持有 N 张券，最多 N 抽）」、数字框＋MAX、预览「共 N 抽，消耗 N 张券；积分门槛 …」、「取消」「开始抽取」；抽取中「停止后续抽取」→「正在完成当前一抽／20连抽」、进度「已完成 a / b抽；二阶段 n 次」；Esc 取消、Enter 确定）。可参照 `XGearSearch` 的网页覆盖层写法，文字逐条对 fixture `dialog`。
5. **可能的原版缺陷**（先查再定，O-待定）：一抽都没跑就结束（积分已低于门槛、赌场已关）时 `if(s.used)` 不出任何消息，弹窗直接消失，玩家不知道为什么（fixture `single.below`：messages 空）。
6. 专项 `xiyou_casino_batch`：`MVEventCore.fixed_random = 0.5` 对齐 fixture（积分、券、消息、停止原因）；必跑 `xiyou_event_compare`（大厅 EV60 的 355 原来被跳过，改后跳过列表会变，要更新事件对照登记）。

## 本分支提交

- f7bd9003 WIP：XItemBagReturn、物品页提示、换装卡当场跑、item_bag_probe
- 579f0a4c WIP：专项 xiyou_item_bag
- （casino 参照）、（本交付单）
