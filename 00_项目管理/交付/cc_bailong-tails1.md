# 交付：cc/bailong-tails1

- 车道／工作者：白龙（cc），派单 tails1：谷雨 endAction 进强制行动、异化绝缘对云裳的核对
- 基线：main（含 tusu7，dev.278），工作树 `.claude/worktrees/bailong-tusu7`
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·白龙·未经审查】谷雨 endAction 进强制行动；绝缘×云裳核对（dev.待定）

### 一、谷雨 endAction 不进 `_forced_run`（审查第 26 期 P3-1 顺带）

- 原版：processForcedAction 也是 startAction → … → endAction，谷雨对 BattleManager.endAction 的包装（先结束行动事件、代命成立就归根，原 endAction 之后 afterAction：花期里队友用技能后绽放）照跑。重制 `battle_logic.gd` `_forced_run` 原本只有 `XGuyu.begin`（在 execute 里）没有收尾。
- 修：`_forced_run` 加三行，次序同 `act()`：屠苏之后 `XGuyu.end_action()`＋`take_visuals()`，`_tick_states`／`XMira.liberate` 之后 `XGuyu.after_action`（`mark_views` 包）。除这三行没动 `battle_logic.gd` 别处。
- 参照：`guyu_battle_probe.cjs` 加 `force` 步骤（同 tusu 探针的 forceAction＋processForcedAction 循环）和第 17 例 `script.forced`（35 级：攒储备开花期 → 1 号被强制普攻 → 绽放付储备打种子；谷雨自己被强制治疗；再强制普攻）。重制 `xiyou_guyu_battle` 加 `force` 步骤（走 `_force_action`），`covers_all` 16→17。
- 修之前新例挂 `script.forced.6`（绽放没触发，hits 少 10299、储备没付）；修之后 1637 项全过。参照 `generated/oracle/guyu_battle.json` 在本工作树重跑探针更新（合并后总装同步会重生成）。

### 二、异化绝缘对云裳 wake／addActions／freeGift：已接，一致

- 原版 `installAlienationAdvanced.js:194`：`CodexYunshang.wake(t)`、`addActions(t)` 在 `has(t,'insulation') && external(t)` 时返回 false；`freeGift(_, t)` 只判 `has(t,'insulation')`（不看 external）。
- 重制 `yunshang.gd`：`wake`（354）`XAlienBattle._insulated(a)`＝has∧external，同原版；`add_actions`（570）同；`free_gift`（586）`XAlienBattle.has(t,"insulation")` 不看 external，同原版，且 free_gift 末尾走 add_actions 又判一次（接收者是绝缘者本来就在第一道被挡）。三处判断条件与原版逐一相同，没有缺口，没改代码。
- 缺口只在测试：没有专项覆盖「绝缘者被云裳唤醒／赠行」（`alien_affix_probe` 的 insulation 例不含云裳，`xiyou_yunshang*` 不含绝缘）。要补需要给云裳配套的探针例（绝缘者＋external 帧），改动偏大，没硬做，留作后续。

## 待交叉核查

- `battle_logic.gd`（甲档核心）：`_forced_run` 加谷雨 end_action／take_visuals／after_action 三行。
- 谷雨强制行动的归根（代命成立）在强制行动里触发的次序，参照 forced 例只覆盖绽放与普通治疗，没有「强制行动当中被打死」。

## 交接板

- 下一步：补「绝缘者×云裳 wake／赠行」专项（探针例＋重制比对）；其它无。
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 无

## 验证

- `python3 07_开发环境/语法检查.py`：489 个 .gd 0 个问题。
- 并行测试（--jobs 2，不跑全量）：15 个场景全过——xiyou_guyu_battle 1637、xiyou_guyu 78、xiyou_guyu_ui 791、xiyou_determinism 372、xiyou_battle 9、xiyou_combat 34、xiyou_tusu_battle 4977、xiyou_yunshang 1593、xiyou_yunshang_wraps 214、xiyou_alien_affix 2117、xiyou_state_effects 19949、xiyou_action_sequence 115、xiyou_event_compare 5、xiyou_rules_d1b 61294、xiyou_smart_ai 5349。
- 日志：`03_再刷重制_Godot/04_验证/本地结果/并行测试/20261103_045707_vwxtd_wx/`
- 没跑：选测名单其余场景（共约 120 个，含其余 rules／smart_ai 段）与全量，留总装。探针改了（guyu_battle_probe.cjs），未在工作树跑 `同步正式西游.py --accept-additions`，总装合并时同步会重生成 guyu_battle.json。

## 本分支提交

- 见 `git log main..cc/bailong-tails1`
