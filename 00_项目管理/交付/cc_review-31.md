# 交付：cc/review-31

- 车道／工作者：审查／cc（审查）
- 状态：可合并
- 基线：从 main `9addbc34` 切出，只加本交付单。

## 变更记录草稿

无（核查条目见下节）。

## 待总装并入变更记录的核查条目

## 2026-11-03 【cc·审查】核查 成长装备期二b：魔冠「"头顶"」、审查 29 P3-1／P3-2

- 核查覆盖：cc/bajie-growth2e（5ddc6e2c）
- 结论：P1 无，P2 无，P3 一条（P3-1，谷雨强制归根绕过魔冠死亡钩子，现有数据难走到），其余通过。甲档细核：魔冠运行时与 `installNativeDemonCrownRuntime.js` 逐段一致；按底子扣用 `_codexCrownKnown` 顶替 `$dataArmors` 查找，能复现原版「不补发」；endAction 前半段 屠苏 → 谷雨 → 狂妄 → 心钢 与原版装载次序一致；心钢拦截在谷雨 apply 里层、谷雨先置 executed，与原版一致。`_forced_run` 新次序不必单补参照例（理由见报告）。
- 验证：对着冻结 v0.28 读码（`main.js` 装载 103～151 行、`installNativeDemonCrownRuntime.js` 全文、`installNativeGuyuRuntime.js` 80～95／316～331／362 行、`installNativeTusuRuntime.js` 三处 endAction、`installNativeHubrisRuntime.js` 150～159 行、`installNativeHeartsteelRuntime.js` 190～210 行）；本树重跑 `heartsteel_probe`（41 例无错）、`demon_crown_probe`（18 例无错），产物与 tests/fixtures 逐例相同（含 order.tusu、order.guyu）；专项选测 13 个场景全部通过（见「验证」）。

## 报告

### 一、魔冠（甲档）

| 项 | 重制 `core/demon_crown.gd` | 原版 | 结论 |
| --- | --- | --- | --- |
| 公式 | `next`＝b＋(1−b/1000)，夹 0～1000；`display` 四舍五入 | `D.next`／`D.display` | 通过 |
| 实例描述 | 名字、说明、图标 290000、品质（12，备注 14／15 取大）、八项 code21 ×(1＋b/100)、成长行 | `describe`（品质走 `CodexHeartsteel.quality`） | 通过 |
| 账本 | 存档目录旁 `crown_progress_v1.json`，临时文件＋改名；version／profiles 不对就报不可用 | `storage`／`readLedger`／`commit` | 通过（少了 fsync，桌面上影响可忽略，不记） |
| 本档编号 | flags `_codexCrownProfile`；编号在、账本没有＝缺失；没编号按云裳编号或旧档身份找 legacy | `profile()` | 通过（建档推迟到用得着，登记为不同处①，结果相同：同一旧档多次读入仍落到同一 legacy 编号） |
| 改账本 | transaction：复制→改本档→revision＋1→写盘→replay | 同 | 通过 |
| 开战 begin | `setup` 里、甚尔之前；收编→记活着且穿带 uid 魔冠的出战者→不是掉落战斗且没人穿就不建账；新遭遇序号才建行、掉落战斗才掷；valid 按账本行比对；same＝地图与敌群都对上 | `begin()`，startBattle 最外层 | 通过 |
| 收战 finish | `end_battle` 末尾（狂妄 clear_reward 之后）；未结算才结算；胜利且 same 才涨、掉落 <0.03；序号＋1 | `finish()`，endBattle 最外层、原函数之后 | 通过（`end_battle` 中途没有 return，三条调用路径胜／逃／败都会走到） |
| 死亡 | `add_state` 记 was_dead，新加上死亡调 `on_death`；战斗中「角色:次数:uid」、战斗外世界序号；减半 | `addNewState` 包装 | 通过，例外见 P3-1 |
| 换装 | `XEquipment.change` 末尾 `equip_changed` | changeEquip／forceChangeEquip／discardEquip 包装 | 通过 |
| 得到 | `gain_gear` 得到 7940（非重放中）走 `grant`，失败不发 | gainItem 包装 `count>0 && !baseItemId` | 通过 |
| 直接失去 | `lose_gear(record)` 带 uid 走 `lost`→记 removed→重放移除 | gainItem 包装 `count<0 && !trade && uid` | 通过（穿上卸下是交换不走这里，同原版 trade） |
| 按底子扣 | `gain_gear(-n)`→`lose_gear(..., false)`，不记账本 | 原 gainItem 扣底子的独立物品，不记账本 | 通过 |
| 存读档 | `before_save`（收编＋重放）、`after_load`（云裳之后，记旧档身份、收编、重放） | makeSaveContents／extractSaveContents 包装 | 通过 |
| 出错 | 提示一次、已有魔冠倍率退回 1、本局不再写 | `fail`／`safely` | 通过 |

**`_codexCrownKnown` 能否复现「不补发」（派单重点）**：原版 `replay` 用 `find(uid)` 在 `$dataArmors` 里找；按底子扣只把独立物品从背包拿掉，实例仍在 `$dataArmors`（随存档存读），所以重放找得到就不再 push。重制用 flags 记「本档建过的 uid」，在 `_grant` 发新件时追加、`_adopt` 收编时追加，随存档存读。逐种情形比对：

- 按底子扣后存档再读：原版实例在 `$dataArmors`、重制 uid 在 known → 都不补发（参照例 `lose` 的 bybase／bybase.reload 行覆盖，本树重跑相同）。
- 读更早、还没得到这件的档（防回滚）：原版 `$dataArmors` 没有 → 补发；重制那份档的 known 没有 → 补发。一致。
- 读扣之前、这件还在背包的档：两边都还在、不补发。一致。
- 别的路子把实例拿出背包但没记 removed：原版仍在 `$dataArmors`、重制在 known，都不补发。一致。
- 唯一差别：原版找得到但不在背包时仍会把账本成长盖到那件实例上，重制直接跳过；那件玩家拿不到，看不出差别。

结论：口径能复现原版不补发，通过。

**开战掷点与规则流次序**：`demon_crown.roll` 只在「掉落战斗＋这一遭遇序号第一次开战」抽一次，放在 `setup` 里 `XZhenqi.troop_setup` 之后、甚尔等 startBattle 包装之前，和原版最外层（startBattle 之前）一致；只影响 Map162 敌群 539～542 首战之后同场的规则流抽数，`xiyou_determinism` 通过。不记问题。

### 二、审查 29 P3-1：endAction 前半段次序（甲档）

原版各包装都是「先做自己的事，再调原 endAction」，所以后装的先跑。装载：心钢（main.js 111）、狂妄（112）、谷雨（133）、屠苏（137，同文件里 482→351→218 三处）。前半段次序应为 屠苏 → 谷雨（`G.end`）→ 狂妄（`settleDeaths`、计行动）→ 心钢（减蓄力）。重制 `act()` 与 `_forced_run` 都已改成这个次序。通过。

**`_forced_run` 要不要补参照例**：不必。强制行动里狂妄不计行动（`_forcing`）、心钢不减蓄力（`_forcing`），次序只影响狂妄 `settleDeaths` 在屠苏剑气之前还是之后结算；之后的话会在下一次 apply 收尾、endAction 或 endTurn 结算，`moves` 在强制行动中不变，只有「中间这段穿戴者倒下或换装」才会看出差别。改法与 `act()` 同（`act()` 有参照例且反向验证咬得住），代价不值得单补。交付单接续第 3 条保持「可选」即可。

### 三、审查 29 P3-2：心钢拦截挪进谷雨里层（甲档）

原版谷雨 apply（133 装，外层）：设 healing → doSpecial →（谷雨自己的特殊技没生效就清结果返回）→ `e.executed = true` → 调里层；心钢 apply（111 装，里层）巨人吞噬没放成／已结算就直接 return，奈叶（103 装）更里层也不跑。重制：`XGuyu.apply` 加 `inner`，先置 executed，再调回调里的 `blocks_apply`，拦下时返回空结果并跳过 `XNanoha.applied`、`XHeartsteel.after_apply`。一致，通过。`order.guyu` 参照例本树重跑与 fixture 相同。

### 问题

- **P3-1（新）谷雨强制归根时绕过魔冠死亡钩子**：`guyu.gd` 646 行在 `add_state(1)` 没加上（死亡抵抗）时直接 `state_ids.append(1)`，不经 `add_state`，所以穿魔冠的谷雨这时不会触发 `XDemonCrown.on_death`。原版 `installNativeGuyuRuntime.js` 91～93 行同一处调的是 `g.addNewState(deathStateId)`，魔冠的 addNewState 包装会减半。只在「谷雨穿魔冠且有死亡抵抗、被强制归根」时出现，成长少减一次半。建议：646 行那一支补调 `XDemonCrown.on_death(XState.current, g)`（或抽一个不查抵抗的加死亡入口），并在 `xiyou_demon_crown` 或 `xiyou_guyu_battle` 加一例。归八戒。

### 另记（不记问题）

- 参照 `lose` 例的 bybase.reload 是扣后立即存读；「扣后读扣前的档（这件回来）」没有例，按上面分析两边一致，不要求补。

## 验证

- 读码对照：见上。
- `node heartsteel_probe.cjs` 41 例无错、`node demon_crown_probe.cjs` 18 例无错，`.sandbox` 产物与 `tests/fixtures/heartsteel_oracle.json`、`demon_crown_oracle.json` 逐键相同。
- 专项（`并行测试.py`，本树 9addbc34）：`xiyou_heartsteel`、`xiyou_demon_crown`、`xiyou_determinism`、`xiyou_guyu`、`xiyou_guyu_battle`、`xiyou_tusu`、`xiyou_tusu_battle`、`xiyou_nanoha`、`xiyou_yunshang`、`xiyou_yunshang_wraps`、`xiyou_autosave`、`xiyou_save_events`、`xiyou_equipment`，13 个全部通过。车道已按 `选测.py` 跑过 300 个场景，本审查不重跑全量。

## 交接板

- 待交叉核查：growth2e（dev.287）可销账。
- 问题：P3-1 谷雨强制归根不触发魔冠死亡减半（归八戒，见本单）。
- 需要用户决定：无。

## 可优化（流程／工具／效率）

- 无。
