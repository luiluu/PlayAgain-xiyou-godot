# 交付：cc/bajie-guyu2b

- 车道／工作者：C 规则／八戒（cc，八戒）
- 状态：可合并
- 分支从 cc/bajie-guyu2a 末端 5f48e4fb 切（总装十派），工作树 `.claude/worktrees/pensive-ardinghelli-6b5eb0`。guyu2a 还没进 main：合本分支会把一期、二期 A 一起带进来（两张交付单都在本分支上）。

## 做到哪

- ✓ 二期 B：代命、归根、再生（含归春）、花荫（谷雨来源的护盾账本、先许一枝开强化绽放）、转移与待绽、受伤压力、自动战斗 autoAction。
- 谷雨的战斗机制到这里都移植完了。没做的只剩界面与画面：转移窗口（模式与比例选择，现在固定「给出 50%」）、战斗界面储备条与花荫显示、立绘与动作；另有 isValid 包装没接（重制的角色行动不看 isValid，转移目标不合法时照常出手、不生效）。

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】谷雨 175 第二期 B：代命归根、花荫、转移、自动战斗（dev.待定）

1. **代命与归根**（冻结 v0.28 `installNativeGuyuRuntime.js` begin／protect／root／regenerate）：`core/guyu.gd` 行动事件改成栈（startAction 开一个；不是当前行动的 apply、不在行动里的扣血各开临时的）。25 级起开事件时记下活着的其余队员；其中有人要倒下时（`XBattler.add_state` 首行）改为留 1 血、不加死亡，事件结束（`act` 里原 endAction 之前）谷雨归根：付储备一半（我即万物之春不付）、收束花期、生命 0 强加死亡，到下回合末；谷雨自己倒下也归根。归根中算阵亡、不能行动，回血、抬生命、去死亡、recoverAll 都无效（`is_dead`、`gain`、`set_resource`、`remove_state`、`recover_all` 各一行）。回合末归根到期且有队友活着就再生（回满），胜利或逃跑结束时有幸存者也再生；60 级戴百谷生、本场第一次再生时归春：谷雨与储备比最低的队友各得 18% 不含储备的最大生命的储备。
2. **花荫**：储备 30%（不足 1 不能用）付一次，每个活着、没归根的出战队员得 min(值, 不含储备的最大生命)，两回合；重制只做了护盾账本里谷雨这一个来源（不衰减、击穿不减半、不吃护盾加成、同源取较高），在 `execute_hp_damage`、`gain`、`set_resource` 最外层先吸收，回合末撤销到期的。先许一枝开 20 级起：被花荫挡下一次后下次绽放 ×1.1（60 级 ×1.2），每次新花荫重置。
3. **转移**：从谷雨给出（或从队友收回）储备，比例 50%（10 级起原版可选 25／50／75%，重制没有窗口，固定给出 50%），接收者不超上限；10 级起从谷雨给出时受赠者「待绽」，绽放付 35%（60 级我即万物之春 50%）。技能条件：花荫要储备 30% 至少 1，转移要有能给出或收回的人（上期这两项恒不能用，本期接上）。
4. **受伤压力与自动战斗**：本回合我方受到的生命伤害（账本吸收之后）在回合末换成占全队最大生命的比例。谷雨的自动战斗按原版固定判断（`auto_battle_action` 首行，压过挂机与智能 AI）：最低血＜35% 治疗；两人以上受伤且无花荫、或上回合压力≥20%：花荫；花期里储备够或花期最后一回合：终结；有人储备过半：花期打生命最多的敌人；否则治疗。原版没有给谷雨登记智能 AI 档案，所以没接 XSmartAI 的档案通道。
5. **参照与专项**：`guyu_battle_probe.cjs` 加 7 例（代命、自己倒下、20 级不代命、花荫、转移、百谷生归春、自动战斗），快照另记各人花荫、归根、活着、待绽、上回合压力与累计；路线压制的 otherScale 改成恒 1（O-050 不移植：原版谷雨给队友的花荫会再 ×0.5）。百谷生归春用原版测试开关 G.setTestRelic（重制 `XGuyu.test_relic`）：真戴上时 60 级 5 阶的最大生命原版 19499、重制 19452，差 47（三法宝成长 installThreeGrowthRelicRuntime 没移植，百谷生升级不同），见下「发现的问题」。`xiyou_guyu_battle` 1523 项。
   - 反向验证（临时改代码，已还原）：见「验证」。

## 发现的问题（不在本期范围）

- 百谷生 7912 戴在 60 级 5 阶谷雨身上，最大生命原版比重制多 47：原版三法宝成长（installThreeGrowthRelicRuntime：百谷生升级、改名万象长春盏）没移植。建议派给接三法宝成长的车道（八戒或悟空）。

## 交接板

- 下一步：谷雨剩界面（转移窗口、储备条与花荫显示、立绘动作），归界面车道；三法宝成长（百谷生升级）另派。
- 用户试玩说明：谷雨 25 级起会替倒下的队友挡死（自己归根一回合后再生），15 级起有花荫护盾，5 级起能把储备转给队友（固定给一半），自动战斗会按谷雨自己的套路出手。
- 需要用户决定：无

## 进度账

- 谷雨 175：战斗内二期 A → 二期 B 完成；只剩界面与画面、三法宝成长。

## 验证

- 专项：`xiyou_guyu_battle` 1523/1523（二期 A 的 9 例照旧，新 7 例）。
- 反向验证（临时改代码，已还原，各自在对应例上失败）：代命恒不成立（sub 8 项）、归根付 40%（sub 3 项）、再生晚一回合（sub 5 项）、花荫 25%（shield 4 项）、账本不吸收（shield 3 项）、待绽付 25%（transfer 3 项）、归春 20%（relic 3 项）、自动战斗受伤线 50%（ai 1 项）、先许一枝开不强化（shield 1 项）。
- 选测（本机 CHECK_JOBS=3，`RULES_ONLY_ACTORS=175`，54 个场景全过，用时 2048 秒）：`xiyou_guyu`、`xiyou_guyu_battle`、`xiyou_actor_p0`、`xiyou_actor_modules`、`xiyou_help_card`、`xiyou_wtype`、`xiyou_rules*`（24 份）、`xiyou_smart_ai`／`_b`／`_c`／`_d`、`xiyou_battle*`（8 个）、`xiyou_shield`、`xiyou_toji_battle`、`xiyou_yunshang`、`xiyou_sukuna_battle`、`xiyou_yomi_battle`、`xiyou_mira_battle`、`xiyou_raven_battle`、`xiyou_garou_battle`、`xiyou_race_battle`、`xiyou_alien_battle`、`xiyou_boss_lifecycle`。
- 同步（一轮）`同步正式西游.py --accept-additions`：只重跑了 guyu_battle_probe，「测量不变」（本树参照已是新 16 例），来源核对 0 问题。main 上合并时 guyu_battle.json 整份算新增（guyu2a 一起进）。
- `语法检查.py` 通过；没有偶发。没合 main（总装说 guyu2a 进 main 后通知再合）。

## 待交叉核查

- 甲档：`core/guyu.gd` 第二期 B；`core/battler.gd`（add_state 首尾、remove_state、recover_all、is_dead 各一行）；`core/resource_context.gd`（gain 包装加归根、账本、临时事件；set_resource 加归根与账本）；`battle/battle_logic.gd`（execute_hp_damage 首行、act 里 end_action、auto_battle_action 首行）。
- 乙档：无。
- 丙档：`guyu_battle_probe.cjs` 扩例、`xiyou_guyu_battle` 扩项。

## 优化登记草稿

优化登记草稿：无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 7439a2c8 WIP：二期 B 逻辑与钩子
- 478a7c46 WIP：参照 16 例、专项全过
- 交付单草稿、反向验证
- 交付单可合并（本提交）
