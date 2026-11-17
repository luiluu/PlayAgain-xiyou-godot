# 交付：luiluu/cc-t134-hangup-tp

- 车道／工作者：T134 挂机按实际消耗判 TP／MP＋T135 奈叶领域开战卡、猫哥 18 组（cc，Opus＋medium，同一工作树）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·T134·未经审查】挂机顺序表按实际消耗判 TP／MP：书把消耗降到 0 也能放（dev.待定）

- 依据：玩家反馈（Kyo 11-17 转，私密仓 `协作交接/附图/玩家反馈_1117/`）：米拉吃了书（洗髓经，技能消耗 −100%）后解放·黑龙手动开局就能放，挂机排了解放却一直普攻，有人回 TP 才变身。
- 根因：`XHangUpAuto.scheduled_skill` 照搬原版 `XdRs_HangUp.js` 的 `Game_Actor.makeAction`（冻结正式源 v0.62.12 第 1735 行）：拿 `$dataSkills[id].mpCost／tpCost`（技能表原始值，解放 80 TP）比当前 MP／TP，不看书、装备、状态、禁忌等减耗。原版 bug，重制照搬了。智能 AI 选技、手动出招都走 `can_use`（含 `skill_cost` 实际消耗），只有挂机顺序表这一处用原始值。原版自己的异化饕餮包装（Adv:138-142）也是同样的问题、改走 canUse，重制 `_auto_battle_action` 已照它做。
- 修法：`XHangUpAuto.REAL_COST`（O-待定-1，默认开）：顺序表技能只看 `can_use`（已含实际 MP／TP、HP、物品等费用判定），去掉原始值比较；MP 同一条。关掉＝原版。
- 专项 `xiyou_mira_battle` 加 `hangup_free.*` 4 项：带洗髓经、TP 0、表排解放 → 挂机放 10146；`REAL_COST = false` 退成普攻（修前行为）；不带书 TP 0 两种都不放。反向验证：把判定换回原始值，`hangup_free.book_real_liberates` 挂（得 1＝普攻）。
- 玩家可见：挂机技能顺序表里的技能按实际消耗判断够不够，被书、装备等减到 0 消耗的技能开局就会放，不再改放普通攻击。

## 2026-11-17 【cc·T135·未经审查】奈叶领域开战卡减半；猫哥「独立装备数组长度」6 变 18 修回（dev.待定）

- 依据：同一条玩家反馈：开战、收场又卡，奈叶下阵就好；大厅猫哥（Map004 EV024）「清理存档」那里以前显示 6，现在 18（玩家自己清空了背包）。
- **领域开战卡**：魔法领域 1774 开战预约 CE2478（O-183 做活后才会跑），里面 16 条「更改状态」313：先全队拿 1792～1799、再加 1792／1793／1794／1782／1784／1799／1798 与 1783。原版 command313 每人只 addState／removeState 再 clearResult：addState 里的 refresh 被 `_Fix_StackOverflow` 的锁压住，removeState 没有该状态就不 refresh。重制战斗解释器 `XBattleLogic._change_actor_state` 每人每条再整套 `_refresh_battler` 一次，五人队开战多 80 次 refresh（每次卸装判断、夹三项资源、重建被动），装备多的存档上就是一顿。
  - 修法：`XBattleLogic.CMD313_NO_EXTRA_REFRESH`（O-待定-2，默认开）不再另外 refresh；add／remove 自己的 refresh 照旧。领域数值不动。
  - 测量（临时探针，四人 99 级带装备＋八人后备、敌群 3，本机 headless）：领域事件 107～113 毫秒 → 53～56 毫秒；奈叶下阵 0～1 毫秒。收场 52～57 毫秒（下阵 15～18）没变：多出来的是拿掉这 8 个战斗状态，每拿一个原版也 refresh 一次，主要花在夹三项资源时重算上限，不是多余的活。
  - 专项 `xiyou_nanoha` 加 `domain.refresh.*` 3 项：五人 50 级、开关两态跑完领域事件后各人生命、魔法、TP、八项能力值、状态、回合、状态私有数据完全一样，开着少 76 次以上 refresh（关掉时这段 120 次）。反向验证：强制每人再 refresh，`domain.refresh.fewer` 挂（120 对 120）。计数用新加的 `XResourceContext.refresh_total`（只给测试）。
- **猫哥 18 组**：EV024 显示 `$dataArmors.length+$dataWeapons.length-12000`。原版数的是独立装备在数据表里堆出来的条数，没有独立装备时是 6；重制装备是实例、不进数据表，原来直接读运行时表长。冠军庆典 `XFestRing.patch_armors` 把防具表从 8001 补到 8013（戒指 8010～8012），于是 6 变 18。不是装备重复或错列，玩家清背包也不影响这个数。
  - 修法：`XMVText._eval_text` 改按 `XDB.source_size`（单独读一次数据文件的条数、走解析缓存）算，恢复 6。重制自己补号造成的显示错，不登记优化。
  - 专项 `xiyou_script_gaps` 加 `cleanup_array_length_6`（同时确认防具表确实补长、戒指在）；反向验证：换回旧算法得 "18"。
- 玩家可见：带奈叶开战时卡顿明显减轻（收场那段没变）；大厅猫哥显示的独立装备数组长度回到 6。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/hang_up_auto.gd` `XHangUpAuto.scheduled_skill` | XdRs_HangUp makeAction 拿技能表原始 mpCost／tpCost 比当前值，减耗到 0 仍判不够、改普攻 | 按实际消耗（同手动出招 canUse） | 玩家反馈 T134：吃书后挂机放不出解放·黑龙 | `XHangUpAuto.REAL_COST = false` | cc | 保留 |
| O-待定-2 | `modes/xiyou/battle/battle_logic.gd` `XBattleLogic._change_actor_state`（战斗里的 313） | command313 每人只 addState／removeState，不另外 refresh（重制原先每人再 refresh 一次，不是原版行为） | 照原版不另外 refresh | T135：奈叶领域 CE2478 十六条 313，五人队开战多 80 次 refresh，装备多的存档开战卡 | `XBattleLogic.CMD313_NO_EXTRA_REFRESH = false` | cc | 保留 |

## 交接板

- 下一步：无（T134 修复要摘进补丁线 cc/v00300，见下）
- 用户试玩说明：米拉学洗髓经后，挂机顺序表第 1 回合排解放·黑龙，开局 TP 不满也会直接变身。带奈叶开战卡顿减轻；猫哥那里显示回到 6。
- 需要用户决定：无

## 进度账

- 无（bug 修复）

## 补丁线（cc/v00300）要摘的提交

- **T134**：`ae7ab815e`：只改 `hang_up_auto.gd`、`tests/xiyou_mira_battle.gd`（西游档文件，不依赖天启篇改动）。摘进去后跑 `xiyou_mira_battle xiyou_hangup_auto`。
- **T135**（两个提交，可单摘）：
  - `32d2f757e` 猫哥 6 变 18：`xdb.gd`、`ui/mv_text.gd`、`tests/xiyou_script_gaps.gd`；补丁线也有冠军戒指补号，同样是 18。摘进去后跑 `xiyou_script_gaps`。
  - `5bf8b0afe` 领域开战卡：`battle/battle_logic.gd`、`core/resource_context.gd`、`tests/xiyou_nanoha.gd`。摘进去后跑 `xiyou_nanoha`，改到战斗核心，补丁线最好再按选测跑一轮（本树选测 554 个场景）。
- 三个提交按 ae7ab815e → 32d2f757e → 5bf8b0afe 在临时克隆里对 `cc/v00300`（3b661b8ef）依次 `cherry-pick` 过，都没有冲突（猫哥那个第一版改了 `table()` 里读表那一行，补丁线那行不一样会冲突，已改成单独读文件、不碰那行）；补丁线上没跑专项（克隆没有转换产物）。

## 我不同意的地方

- T134 无。派单写的「改成和手动出招同一套判定」就是对的口径；补一句：智能 AI 选技本来就走实际消耗，没问题的不用动，所以只改了顺序表这一处。
- T135 没有玩家存档，耗时是在本机造的四人 99 级带装备队上量的，只能说减了一半，玩家那边具体快多少要拿存档再量。收场那段我没动：每拿一个状态 refresh 一次是原版行为，要再省得动 refresh 本身（夹资源时上限重算），影响面大，不适合进补丁；需要的话另开单、先要存档。

## 验证

- `并行测试.py … xiyou_mira_battle xiyou_hangup_auto`：292/292、239/239。
- `检查.sh --affected main --oracle`：退出 0，选中 14 个场景全过（含 event_compare 四份、floor_run 三份、hangup_auto、mira_battle、nanoha），MV 参照引擎启动正常。
- `工具回归.py`：全部通过（91 秒）。
- `交付自检.py`：退出 0（交付单提交后跑）。
- T135：`并行测试.py … xiyou_script_gaps xiyou_nanoha`：73/73、307/307；`语法检查.py` 通过（第一次挂在测试子类同名成员 refresh_calls，已改名 refresh_total）。
- T135：`检查.sh --affected main --oracle --cloud`（选中 554 个场景，分 16 片，基准 8a3b9dcfe）：退出 0，全部通过；MV 参照引擎、同源、内容覆盖、事件对照空绿都过。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- ae7ab815e T134 挂机顺序表按实际消耗判 TP／MP（书减耗到 0 也能放）
- 32d2f757e T135 猫哥「独立装备数组长度」按数据文件条数算（冠军戒指补号让 6 变 18）
- 5bf8b0afe T135 战斗 313 照原版不另外 refresh（奈叶领域开战卡）
