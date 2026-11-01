# 交付：cc/bajie-guyu1

- 车道／工作者：C 规则／八戒（cc，八戒）
- 状态：可合并
- 分支接在 cc/bajie-toji4 末端 6d8173e1 后面（总装八建议：谷雨也在 actor_modules、切片等处加行，带着甚尔切少一次冲突；先从 main bbeecb5b 切、做完一半后 rebase 过来），工作树 `.claude/worktrees/sleepy-khayyam-db2439`。

## 做到哪

- ✓ 入切片（actors 加 175）、战斗外部分（见变更记录草稿）。
- 战斗内机制盘点（原版 installNativeGuyuRuntime.js 682 行，第二期起）：见「下期」。

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】谷雨 175 第一期：入切片、技能同步、MP 比例收费、技能条件、治疗公式、号角招募（dev.待定）

1. **谷雨 XGuyu**（冻结 v0.28 `installNativeGuyuRuntime.js`，W.Guyu v0.3.1）：新文件 `modes/xiyou/core/guyu.gd`。原版按备注标签现找角色、技能、法宝、号角、进阶石，重制写死 175、10288～10299、7912、2943、2944。
   - 技能同步 syncSkills：unlock 表的键（不含绽放）到等级就学、不到就忘，「我即万物之春」另要 5 阶；挂在 setup、升级与改等级（`XActorModules`，IDS 加 175）、进阶后（`XAdvance.advance`）、开战（`battle_logic.setup`）、读档（`XState.from_dict`）。
   - 技能表（`XActor.skills` 包装，在异化之后）：「先许一枝开」10 级起才列，绽放永不列，其余按解锁。
   - MP 消耗（`battle_logic._skill_cost`，米拉与异化缄默之外、种族之内）：五个主动技收 ceil(最大MP×比例×mcr)，治疗 6%、花期 5%、转移 2%、花荫 3%、终结 8%，再按通用减耗 floor(×(1−max(减耗, −100)/100))。悟空 gaps2 记的「谷雨 CFG.mp」就是这条。
   - 技能条件（`battle_logic.can_use` 一行）：五个主动技别人不能用；谷雨要已解锁；花期要不在花期且过了冷却；终结、花荫、转移要战斗内储备与花期，第一期恒不能用。
   - 公式（`XDamage.eval_formula` 开头）：谷雨的泽苍生 ＝ −(目标最大生命×治疗比例)，比例 curve(.25,.30,.35,.40；1/20/40/60 级)×Π(1＋治疗被动%)，结算时不再乘治疗被动（`XDamage._healing`）；绽放、终结按威力（第二期，现 0）。`XGuyu.curve` 即 CodexBinding.curve。
   - 命中（`battle_logic.item_hit` 一行）：绽放、终结、治疗必中（闪避、暴击原表就是 0）。
   - 号角招募（`mv_script` 的 Guyu 分支，公共事件 9012）：已在队返回 false；没送过百谷生（`flags.guyu_relic_granted`，原版 `$gameSystem._guyuRelicGranted`）就拿背包里的或生成一件装进 13 号装备类型的槽；入队、同步技能、提示「谷雨加入队伍，已装备百谷生。」（本次运行已提示过就换成「谷雨加入队伍。」）。
2. **说明卡**（`ui/character_help.gd`）：nowGrowthView 的谷雨部分——治疗比例、转移比例、待绽比例与花荫倍率、队友储备比例与绽放系数、归春系数，按谷雨当前等级／阶位换掉「成长：」行（屠苏、璇仍未接）。
3. **参照与专项**：新探针 `mv_oracle/guyu_probe.cjs`（29 例：13 个等级 × 进阶 0／5 的已学技能、技能表、五个主动技 MP 消耗、最大 MP、治疗比例、对自己的泽苍生公式与结算、战斗中能不能用、1 号主角不能用；招募四例），新专项 `xiyou_guyu` 66 项。
   - 反向验证（临时改代码，已还原）：MP 不按比例收费、治疗比例写死 0.25 后，26 档 MP 与 24 档治疗对不上。专项里常驻：减耗 20% 的算式、别的角色不吃谷雨包装、绽放不列。

## 下期

谷雨第二期起全是战斗内（原版行号）：
- 生命储备（row.e）：战斗中治疗溢出与回复记储备（gainHp 包装 264～280，成长 生未央 再 20%）、储备并进最大生命（param 包装 258～263）、上限 referenceCap（50 行，curve(1,1.25,1.5,1.75)＋0.15×阶位，谷雨本人无上限）、读档／战后夹血。
- 花期与绽放：请与我共赴花期 open（doSpecial 196～201，花期 2 回合、冷却到 round＋2、种子目标）、队友行动后绽放 bloom（G.bloom 116～132，储备 25%／待绽 35%，威力 ×curve(5,6,7,8)，内部行动、谷雨算攻击者 calcOwner）、终结 finish（花期中付全部储备、威力 ×curve(33,50；40/60 级)、收束花期）。
- 代命与归根：众生之劫 substitute（begin 77～82，同一来源行动里队友致死改为 1 血、谷雨代为阵亡）、骨生花 root（85～111，储备付一半、归根到下回合）、归根期间不能被复活回血（addState／removeState／revive／recoverAll／isAlive／isDead／canMove 包装）、战后再生 regenerate。
- 花荫护盾 shield（储备 30%，单人上限最大生命，两回合，CodexShieldLedger 账本来源 guyu.shield）、借一枝春色 transfer（给出／收回 25／50／75%，待绽）、先许一枝开 relic（20 级起花荫强化 springBoost）。
- 战斗流程包装：BattleManager.setup／startTurn／startAction／endAction／endTurn／endBattle（胜利 1/50 掉谷种金缮石 rollStone）、OTB 复活插队、isValid（转移目标）。
- 谷雨自动战斗固定判断 autoAction（makeAutoBattleActions 包装，447～472）；战斗界面储备条、转移窗口、立绘动作（画面）。
- 三法宝成长（installThreeGrowthRelicRuntime 的百谷生升级、改名「万象长春盏」）与战力模型的谷雨循环（installCombatPowerRuntime 331～374）未盘，随后续期看。

## 优化登记草稿

优化登记草稿：无

## 交接板

- 下一步：见「下期」。
- 用户试玩说明：谷雨可以用号角招进队（自动装上百谷生），技能按等级解锁，治疗按最大生命比例；花期、绽放、代命、护盾等战斗玩法还没做。
- 需要用户决定：无

## 进度账

- 谷雨 175：只有号角（0.05）→ 入切片与战斗外部分（技能、消耗、条件、治疗、招募、说明卡）。

## 验证

- 专项：`xiyou_guyu` 66/66；`xiyou_help_card` 1011/1011（专项里 10 级的专属角色补上 175：参照探针把切片角色都 changeLevel 到 10，说明卡的消耗行与「成长：」行按谷雨当前值算）。
- 扩角色那套（同步前先跑单探针）：slice_probe、actor_passive_probe 单跑，`RULES_ONLY_ACTORS=175` 六个难度第 0 份 `xiyou_rules`／`_d2`～`_d6` 各 1905～1907 项全过；`xiyou_actor_p0`、`xiyou_actor_modules`、`xiyou_wtype`、`xiyou_toji`、`xiyou_toji_battle` 全过。
- 同步（一轮）`同步正式西游.py --accept-additions`：「新增用例，已接受」，新增 actor_passive（175 五档）、help_cards（10288、10289、10290、10293、10298）、slice_d1～d6（175 的能力与伤害行）、wtype；来源核对 0 问题。
- `内容覆盖检查.py`：new 0、resolved 0，不用更新 baseline。
- `语法检查.py` 通过。没合 main（分支接在 toji4 后面，等总装合 toji4 时一起理）。

## 待交叉核查

- 甲档：`core/guyu.gd`；`battle/battle_logic.gd` 四处一行钩子（setup 同步、can_use、item_hit、_skill_cost）；`core/damage.gd` 两处；`core/actor.gd` skills 一行。
- 乙档：`xiyou_slice.json` 加 175。
- 丙档：`guyu_probe.cjs`、`xiyou_guyu`。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 30bb278f WIP：XGuyu 与接线、切片加 175
- 069866f2 探针与专项、说明卡成长行
- 说明卡专项补 10 级谷雨、交付单可合并（本提交）
