# 交付：cc/bailong-tusu4

- 车道／工作者：C 规则·角色专属／白龙（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-02 【cc·白龙·未经审查】屠苏噬主付费照走里层、绑定种类开机即登记；屠苏四期一部分：武装技能以屠苏出手（dev.待定）

1. **审查第 24 期 P2-1（甲）**：原版屠苏的 paySkillCost 包装（installNativeTusuRuntime 440～450 行）在外层，`old.apply` 照走里层：异化缄默／饕餮、扣 MP／TP、YEP_SkillCore 的 HP 费用、YEP_SkillMasteryLevels 的熟练度记次；只是期间 devourPaying 让支援的面板 MP 记 0。重制原来 `if XTusu.pay(...): pass` 把这些都跳过了，持武者的武装技能、屠苏绑定中的支援永远不涨熟练度。
   - 改法：`XTusu.pay` 拆成 `pay_begin`（返回付款方，设 devourPaying）和 `pay_after`（放下标记，屠苏代付武装技能扣屠苏、持武者代付支援扣持武者）；付费整段抽成 `XBattleLogic.pay_skill_cost`（execute 和专项共用，含冷却）。
   - 参照：`tusu_battle_probe` 的 pay 步多记 `_actionMastery`；新例 mastery：持武者走真实行动用两次斩锋（屠苏自付一次、持武者代付一次），使用次数 1、2。
2. **审查第 24 期 P3-1**：屠苏的绑定种类原来只在开战时登记，开机后没打过仗就读档，`XBinding.clear_all` 认不出屠苏，她身上的武具／空形态状态清不掉。原版模块装入时就登记，现在 `XBinding.kind_of` 每次先 `XTusu.register_kind()`（已登记就直接返回），start_battle 里那行去掉。xiyou_tusu 补一例（去掉种类后读带两个形态状态的档，状态清掉、种类登记上）。
3. **屠苏四期一部分（installNativeTusuRuntime 的 apply／subject 包装与统一伤害钩子）**：
   - 武装技能以屠苏为出手者：原版持武者用武装技能时，整个 Game_Action.apply 的 subject 换成屠苏（按屠苏的属性与加成结算，豁免异界制约）。`XTusu.apply_subject` 在 `apply` 最外层（绑定之外）和 `_invoke` 的饿狼／云裳／渡鸦等 apply 层之前换；付费、反击判定、行动次数仍是持武者。
   - 公式 `CodexTusu.damage(a,b,'键')`：公式程序不认引号（formulaIssue unexpected_character），`XFormulaExecution.run_item` 先按原文认（`XTusu.formula`）。转换器标成 module 是 A 车道的事，屠苏进切片时可以顺手改成 module。
   - 伤害钩子 tusu（并进 `XActorDamageHooks`）：武装技能按武相定物理／魔法，威力按持武者本回合行动次数分摊（2 次为基准），贯日打锁定目标 ×lockRate、敕令带和鸣 ×hemingRate；护阵中的角色受伤 ×huzhenRate。
   - endAction：敕令启动即消费持武者的和鸣（`XTusu.end_action`，谷雨之外）。
   - 参照：新例 armdmg（书相敕令、挂和鸣再敕令、锤相震击、敌人打护阵角色）已进夹具，专项暂跳（见下「没做完」）。
- 钩子各一行：`battle_logic.gd`（付费抽成 pay_skill_cost、apply 与 _invoke 换出手者、endAction 消费和鸣）、`binding.gd`（kind_of 登记屠苏）、`formula_execution.gd`（屠苏公式）、`actor_damage_hooks.gd`（tusu 钩子）。
- **没做完（四期剩余，下一位接着做）**：
  - armdmg 例对不上的三处：①止戈环 60 级（installThreeGrowthRelicRuntime 的 three60-effects 钩子与 apply 分段）：五兵淬纹 temperRate（敕令、震击 60 级 ×1.2 等）、弓／书武装技能 60 级带止戈环分两段（每段 value×1.2/段数、余数累加）、横扫第二个目标起 ×curve、剑锋锻痕等；②挫势（震击、镇魂给敌人挂挫势，敌人出手 ×rate，2 层与眩晕、回合末到期）；③和鸣倍率：参照里挂和鸣后敕令只 ×1.25，按 hemingRate(60 级) 应 ×1.5，还没查明（可能是 three60 分段与和鸣的交互）。做完删掉 `xiyou_tusu_battle` 的 `PENDING` 那行。
  - 支援的施放与效果（B.cast、roundSupport：剑气、锁定、金汤、和鸣、镇魂；startAction／endAction 触发；回合末释放；applyItemUserEffect 的锁定、和鸣、金汤护盾、本体护盾、护阵、挫势、开刃·剑破防）、支援上下限（res.after）、贯日的锁定与击杀返还。
  - 噬主时的台词（CFG.lines.devour）与 CodexTusuDevour.paid 计数、其余战斗日志台词、指令窗、自动战斗与智能 AI 估算、开刃与器谱菜单。

## 交接板

- 下一步：屠苏四期剩余（见变更记录草稿「没做完」），新会话读本交付单接着做，同一分支 `git switch --ignore-other-worktrees cc/bailong-tusu4`。
- 用户试玩说明：屠苏还没进切片，玩家碰不到。
- 需要用户决定：无

## 进度账

- 屠苏：三期之后补了付费、读档清理与武装技能出手者、伤害钩子的主体；支援施放、止戈环 60 级、挫势未做。

## 验证

- 语法检查通过。
- 专项：xiyou_tusu_battle、xiyou_tusu、xiyou_binding 通过（xiyou_tusu_battle 跳过 armdmg 一例，原因见上）。
- 反向验证（`07_开发环境/反向验证.py`）：kind_of 不先登记屠苏 → xiyou_tusu 挂；噬主时跳过熟练度记次、噬主时整段里层不走、武装技能不换出手者、不认 CodexTusu.damage 公式 → xiyou_tusu_battle 都挂。
- 选测：`选测.py main --list` 148 个，云端选测通过（提交 816d899816，10 片，[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41391895060)）；偶发 xiyou_battle_log（并行失败、单跑通过，算通过）。
- mv_oracle：改了 `tusu_battle_probe.cjs`（pay 记 _actionMastery；新步骤 arm、state、hit；新例 mastery、armdmg），不进同步，产物拷成 `tests/fixtures/tusu_battle_oracle.json`。

## 待交叉核查

- 改了原沙僧独占的 `battle_logic.gd`（付费抽函数、apply／_invoke 换出手者、endAction 一行），请重点核付费次序与出手者替换的范围。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 73e8c4bc 屠苏噬主付费里层照走（P2-1）
- cbea2c76 屠苏绑定种类在 kind_of 时登记（P3-1）
- 816d8998 屠苏四期一部分：武装技能以屠苏出手、公式、伤害钩子、敕令消费和鸣
