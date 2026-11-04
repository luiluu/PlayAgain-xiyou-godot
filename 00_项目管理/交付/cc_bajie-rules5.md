# 交付：cc/bajie-rules5

- 车道／工作者：C 规则／八戒（cc，唐僧总装十九派）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·八戒·未经审查】其它、回合／行动钩子切片可达 16 块翻成原生实现，弹字按原版顺序（dev.待定）

- **原版行为**（`state_effects_probe` 新用例 `hook.blocks` 实测）：
  - 7 块原版就没效果，译成 `noop`（reason `no_effect`）：1067 的 `_isMarked` 只有 5576／5577 的 Custom Damage Formula 读，而实测标记与否伤害一样（公式不生效）；1068 给 `def` 赋值无效（只有 getter），`_baseDef` 没人读，暴击块 crit 冻结版不触发；1072 `this.isDamageAffected` 不存在，一进块就 TypeError，也就不会反击；2548 是空块。
  - 1711 秩序、1716 同谐用 `else if` 写，条件 `>1`、`>0` 先成立，后面的分支到不了：1711 活人>1 才加 1712 并去 1713、1714，1716 恒加 1717。
  - 1452 存护的 `user` 是行动者，移除的是**行动者队伍**的 1451，不是持有者队伍。
  - 1306 小爱莉被动：每个活队友加状态、扣 `ceil(持有者血*0.13)`、弹字、清结果；敌人持有时 `hasSkill` 不存在，TypeError，什么都不做。
  - 83 命之诅咒：目标血为 0 时移除自身，行动者死亡率>0.01 且不抵抗就播 65 号动画、血设 0。
  - 1301 往世乐土：普通序列里目标 immortal，deselect 时血 0 未倒下，块排入强制行动 7303 并移除自身；但收尾解除 immortal 后目标已倒下，339 判 `isDeathStateAffected` 不行动。所以**一般打死时 7303 不放**，只有事件阶段目标又活着（别的复活）才放。
  - 2574 非天逆斩：用户计数清 0，108 号角色计数 += 等级；108 没有计数时原版得 NaN。
- **转换器**（`xiyou_export.py`、`formula_program.py`）：83 加进 `MEASURED_EFFECT_BLOCKS`；`MEASURED_EFFECT_SOURCES` 8 块（1301、1306、1452、1711、1716、2544、2545、2574）整块比对后换成等价写法；`NO_EFFECT_BLOCKS` 7 块。生成数据 `op: js` 263 → 247。
- **运行时**（`state_effects.gd`、`actor.gd`、`battle_logic.gd`）：`effect_program` 加队友遍历（循环前取活人名单）、加状态、动画、设血、计数器、强制行动排队。`XStateEffects.battle_units` 开战时设；`take_forces` 在事件阶段经 `_force_action` 执行（已有的倒下不行动判定）。
- **弹字顺序，修 rules3 的遗漏**（`battle_logic.gd`、`battle_scene.gd`）：实测 YEP_BattleEngineCore 的 apply 包在 BuffsStatesCore 的 deselect 之内，所以这一击和行动者的弹字在 deselect 之前就发了。之前重制是 deselect 后才按结果弹：复活块清结果时这一击的数字没了，没清结果的 1164、1837 回血还多弹一次。现在 `apply` 在 deselect 前存结果，`popupQueue` 为「之前的弹字、这一击、deselect 里的弹字」，`r.shown`、`r.started_split` 给场景用；`r.hp`、`r.result` 的含义不变。
- **探针**：`hook.blocks` 借的测试状态用完摘掉，否则后面用例新建状态的号会变（第一次干净同步就报了 `tp.refresh_state_boundary` 测量改变）。预期内的原版报错记 `sourceErrors`，不用 `errors`。
- **场景**（审查 36 P3）：行动者没有形象时跳过弹字与倒下，`xiyou_battle_log` 加 `popup_order_case` 测弹字顺序、行动者弹字与倒下、没形象的行动者。
- **选测对照**：`battle`、`converter` 组加 `xiyou_status_power_panel`（rules4 的预览崩溃选测没选到）。
- **报数**：`xiyou_state_effects_tp` 的未翻译块改 `inventory.untranslated_105`（换装 142 不变）。
- 测试：`xiyou_state_effects` 加 `_hook_blocks`，`_revive_apply` 加弹字条数与先后；`测试状态js翻译.py` 加 `HookBlockTranslationTests`。

## 交接板

- 下一步：未翻译状态块剩 247（换装 142 不用翻，真未翻 105）；切片可达还剩 31 块：换装 12、改属性／变量 8、reserveCommonEvent 9、regenerate 2。
- 用户试玩说明：秩序、同谐、存护、小爱莉被动、命之诅咒、非天逆斩、剑终伤、太刀终伤现在按原版生效。自动复活时，这一击的伤害数字会先弹，再弹回血。
- 需要用户决定（原版疑似笔误，都默认照原版，要改请总装分配优化登记号）：
  1. 挨打反击 1072（方法名不存在）永远不反击；金剪追加 1068 的暴击追加永远不触发。
  2. 往世乐土 1301：一般打死时 7303 不放，等于只消耗状态。
  3. 秩序 1711、同谐 1716 的 `else if` 写反，人多的分支永远到不了。
  4. 5576／5577 带标记时增伤的公式不生效，戮仙印记没有实际作用。

## 进度账

- 战斗规则：未翻译状态块 263 → 247（真未翻 121 → 105）；切片可达「其它」「回合／行动钩子」清零。

## 可优化（流程／工具／效率）

- 单分支连着接同一探针文件时，工作树的 `generated/oracle` 已是自己上一轮的产物，同步比不出问题（rules4 的 `errors` 字段、这次的状态号漂移都这样）。这次交付前先把主工作区的 `state_effects.json` 盖回来再同步才看出来。可以让 `同步正式西游.py` 在工作树里一律用主工作区产物做基线，归哪吒评估。

## 验证

- 云端（整轮）：提交 1321fd6d63，384 个场景 13 片，只挂 `xiyou_status_power_panel`，原因是 rules4 预览走 `clone_battler` 时 `NeutralEnemy._init` 缺参，总装已在 main 修好；合 main 后本机单跑通过（Actions run 41767816917）。合 main 之后没有再跑云端。
- 上一轮云端（bf3acd9588，243 场景）查出 `xiyou_formula_effects` 未命中弹字回归，是这次弹字快照漏带 missed，已修。
- 合 main 后本机：`xiyou_state_effects` 24960、`xiyou_state_effects_tp` 538、`xiyou_status_power_panel` 11、`xiyou_battle_log` 57、`xiyou_formula_effects` 908、`xiyou_determinism` 372、`xiyou_honghuang_curse_battle` 344，全过。
- 合 main 前专项（本机）：`xiyou_state_effects` 24960、`xiyou_state_effects_tp` 538、`xiyou_state_js` 1733、`xiyou_honghuang_curse_battle` 344、`xiyou_boss_state_origin` 15723、`xiyou_state_merge_context` 866、`xiyou_determinism` 372、`xiyou_battle_events` 108、`xiyou_battle_ui` 155、`xiyou_battle_log` 50、`xiyou_formulas` 7，全过。
- 工具：`测试状态js翻译.py`、`测试未翻译块清单.py`、`测试公式程序.py`、`测试选测.py` 过；`语法检查.py` 0 问题；`内容覆盖检查.py` hard 0、new 0。
- 同步：合 main 后把主工作区的 `state_effects.json` 盖回做干净基线，`同步正式西游.py --accept-additions` 退出码 0，只新增 `hook.blocks`；之后只提交选测对照和本交付单，产物指纹仍有效。
- 没测：弹字和倒下只断言到场景分支和弹字节点，没有看实际画面。1301 在事件阶段真放 7303 的路径（目标又活着）只查了排队和倒下时不放，没有跑完整流程。
- 与原版不同的一处：2574 的 NaN 不写进计数（进存档会坏），读的地方 `paramState` 本来就把 NaN 当 0；只有原版存档读回后 NaN 变 null 再累加这条路不一样。

## 本分支提交

- 见 `git log main..cc/bajie-rules5 --no-merges`：探针 hook.blocks、16 块翻译与弹字顺序、sourceErrors 与测试状态隔离、未命中弹字修复与场景分支测试、选测对照与本交付单

## 待交叉核查（核心文件）

- `battle_logic.gd`（`apply` 的弹字快照、`_drive_events` 的强制行动）、`battle_scene.gd`（`_hit_visual` 弹字顺序，影响所有命中）、`选测对照.json`、`state_effects.gd`（`effect_program` 新调用）、`actor.gd`（`first_weapon_type`）。
