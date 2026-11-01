# 交付：cc/bajie-guyu2a

- 车道／工作者：C 规则／八戒（cc，八戒）
- 状态：可合并
- 分支从 cc/bajie-guyu2 末端 424e383b（含一期 cc/bajie-guyu1 846f2ceb＋上一位的交接稿）切（总装九派），开工先合了 main（甚尔四期、云裳二期）；工作树 `.claude/worktrees/pensive-ardinghelli-6b5eb0`。一期还没并进 main，合本分支会把一期一起带进来（cc_bajie-guyu1.md 也在本分支上，状态可合并）。
- 上一位的交接稿（原 cc_bajie-guyu2.md）已并进本单，原文件改名为本单。

## 做到哪

- ✓ 二期 A：战斗生命周期、生命储备（含成长生未央）、花期 open、绽放 bloom、终结 finish、进阶石 rollStone。
- 二期 B 留下一期：代命 substitute 与归根 root／再生 regenerate（含 isAlive／isDead／canMove／revive／recoverAll 包装、OTB 复活插队）、花荫 shield（CodexShieldLedger 来源 guyu.shield、先许一枝开 springBoost）、转移 transfer（含 isValid、转移比例窗口、待绽 bud）、autoAction、回合受伤压力。原版行号与挂点见下「二期 B 要点」。

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】谷雨 175 第二期 A：生命储备、花期、绽放、终结、胜利掉谷种金缮石（dev.待定）

1. **谷雨战斗内 XGuyu**（冻结 v0.28 `installNativeGuyuRuntime.js`）：`modes/xiyou/core/guyu.gd` 第二期 A 段。
   - 生命周期：BattleManager.setup 包装（`battle_logic.setup` 首行）清状态、开 activeBattle；startTurn 包装（`start_turn` 首尾各一行）round＝回合数；endTurn 包装（`end_turn` 末尾）花期到期收束；endBattle 包装（`end_battle`，异化放回装备之后）清储备与花期、全队生命夹到不含储备的上限，胜利再掉石。
   - 生命储备：按角色 id 记；`XActor.param` 在异化之外、种族之内加一层（原版安装次序 129 → 133 → 148），战斗中最大生命＝原值＋储备。上限：谷雨本人无上限，其余 floor((curve(1,1.25,1.5,1.75)＋0.15×谷雨阶位)×不含储备的最大生命)，超出记浪费。
   - 回血记储备：`XResourceContext.gain` 外面包一层（宿傩、异化之外，同原版 gainHp 包装次序）：谷雨活跃、受益者是出战角色且之前活着，储备加 floor(回血量)（传进来的量，满血也全记）；谷雨的直接治疗先取整，学了生未央（45 级）且不在花期再加 20%。
   - 花期与终结（Game_Action.apply 包装 doSpecial，`battle_logic.apply` 改为调 `XGuyu.apply`，原 apply 改名 `_apply_core`）：花期要目标活着、不在花期、过了冷却，开两回合、种子＝目标；终结要花期里储备 ≥1，威力＝全部储备×curve(33,50；40/60 级)，付全部、收束花期、冷却到 +2 回合；两者没生效时整次不结算。终结是全体技能，三个敌人同一威力。
   - 绽放：本次行动的技能（不是物品、防御、花期、终结）真的执行过、出手者活着，行动结束（`act` 里米拉解放之后）付 floor(储备×25%)，威力＝付出×curve(5,6,7,8)，用 10299 直接打种子（种子死了换第一个活着的敌人，不在花期也照校种子），伤害按谷雨算（`_apply_core` 的 `_damage_value` 换攻击者，原版 calcOwner）。学了我即万物之春（60 级 5 阶）付储备一律不扣。
   - 技能条件：终结改读花期与储备；花荫、转移仍恒不能用（效果第二期 B 才有，免得能用却白付 MP，原版这时已能用）。
   - 胜利掉石：谷雨在队、还差进阶、背包里谷种金缮石少于差额、1/50（规则流 reason `guyu_stone`）给 1 个，右上角提示。
2. **修一期漏接的治疗公式**：一期只接了 `XDamage.eval_formula`，实战结算走 `XFormulaExecution.run_item`，谷雨的泽苍生在战斗里恒为 0。本期在 `run_item` 开头（异化之外）接上同一个公式（绽放、终结也走这里）。
3. **同步登记**：一期的 `guyu_probe.cjs` 没登记进 `同步正式西游.py` 的 PROBES，主工作区同步不会出 `guyu.json`，`xiyou_guyu` 在 main 上会缺参照；本期补登记，并登记新探针 `guyu_battle_probe.cjs`（`oracle_additions.py` 两份都加 cases 键）。
4. **参照与专项**：新探针 `mv_oracle/guyu_battle_probe.cjs`（真实 BattleManager，队伍 [175, 1]，四个等级脚本 10／35／45／60（5 阶）与五个掉石例；去掉五乘区 zones-correction 与超强者路线压制 route-suppress 两个伤害钩子，用户 10-12 定不移植，O-050），新专项 `xiyou_guyu_battle` 544 项（每步比命中与储备、上限、最大生命、生命、花期、冷却、种子、条件、累计）。
   - 反向验证（临时改代码，已还原）：生未央比例 0、冷却 +1、终结系数 30、param 不加储备、掉石判 !=1、我即万物之春照付、花期中能重开，各自在对应例上失败。专项里常驻：谷雨不出战不记储备、不在花期不绽放、物品不绽放、别人用花期不生效、战后储备清零。

## 交接板

- 下一步：谷雨第二期 B（代命归根再生、花荫、转移、autoAction、受伤压力），挂点见交付单「二期 B 要点」；战斗界面储备条、转移窗口、立绘动作归界面车道。
- 用户试玩说明：战斗里谷雨的治疗会给全队攒「生命储备」（最大生命跟着涨，战后清掉），开花期后队友出手会绽放打种子，35 级起终结一次打出全部储备；胜利有小概率掉谷种金缮石。花荫、转移、代命还没做（技能条件里不能用）。
- 需要用户决定：无

## 进度账

- 谷雨 175：战斗外部分 → 加上战斗内二期 A（储备、花期、绽放、终结、掉石）；二期 B 未做。

## 二期 B 要点（原版 installNativeGuyuRuntime.js 行号）

- 代命 substitute（begin 77～82 protected、protect 109～114）：同一来源行动里队友致死改为 1 血、pendingDeath，G.end 时 root(谷雨, forced)。重制挂点：`XGuyu.begin` 已记 heights，protected 跟着加；addState 死亡的包装在 `XResourceContext.add_state`／`_die`。
- 归根 root（82～108）：付储备一半（我即万物之春不付）、closeFlower、rootUntil＝round＋1；归根中 isAlive 假、isDead 真、canMove 假、不能回血复活（setHp／gainHp／revive／recoverAll／removeState 包装）。再生 regenerate（144～153，endRound 与 finishBattle 里有队友活着时）：60 级法宝归春 18% 给自己与储备比最低的队友（springReturnDone 一场一次）。
- 花荫 shield（209～216）：储备 30%（单人上限不含储备的最大生命），CodexShieldLedger 来源 guyu.shield，两回合；先许一枝开 20 级起被打一次 springBoost（绽放 ×1.1／60 级 ×1.2）。
- 转移 transfer（203～208、230～243）：给出／收回，10 级起 25／50／75%，从谷雨给出时受赠者待绽（budFlower），待绽绽放 35%（60 级我即万物之春 50%）；isValid 包装。
- autoAction（447～472）与 CFG.ai 阈值；endRound 的受伤压力 lastRoundPressure（executeHpDamage 包装记 roundTaken）。

## 验证

- 专项：`xiyou_guyu_battle` 544/544（新）；`xiyou_guyu` 66/66。
- 选测第一轮（本机 CHECK_JOBS=3，云端不用）：`xiyou_guyu`、`xiyou_guyu_battle`、`xiyou_actor_modules`、`xiyou_battle`（前缀扩出 xiyou_battle_* 共 8 个）、`xiyou_battle_gaps`、`xiyou_shield`、`xiyou_toji_battle`、`xiyou_yunshang`、`xiyou_sukuna_battle`、`xiyou_yomi_battle`、`xiyou_mira_battle`、`xiyou_raven_battle`、`xiyou_garou_battle`、`xiyou_race_battle`、`xiyou_alien_battle`、`xiyou_boss_lifecycle` 全过；`xiyou_actor_p0` 当时缺 174 参照（本树参照是主工作区旧批），同步后第二轮已过。
- 同步（一轮）`同步正式西游.py --accept-additions`：「新增用例，已接受」（actor_passive、help_cards、slice_d1～d6、wtype 的 174／175 行，来自合进来的云裳与一期），来源核对 0 问题；`guyu.json`、`guyu_battle.json` 由同步重新生成。main 的参照里还没有这两份，总装合并后同步会当新增用例接受。
- `内容覆盖检查.py`：new 0、resolved 0，不用更新 baseline。
- 第二轮（同步后，`RULES_ONLY_ACTORS=175`）：`xiyou_actor_p0` 3403、`xiyou_actor_modules` 56、`xiyou_help_card` 1013、`xiyou_wtype` 16779、`xiyou_guyu` 66、`xiyou_guyu_battle` 544、`xiyou_rules`／`_d2`～`_d6` 各 1905～1907（前缀扩出各难度 b／c／d 份，共 30 个场景）全过。
- `语法检查.py` 通过；没有偶发。

## 待交叉核查

- 甲档：`core/guyu.gd` 第二期 A 段；`battle/battle_logic.gd`（setup 首行、start_turn 首尾、end_turn 末尾、execute 开头 begin、act 里 after_action、apply 改名 `_apply_core` 加外层、`_apply_core` 里 `_damage_value` 换攻击者、end_battle 一行）；`core/resource_context.gd`（gain 外层包装，原体改名 `_gain`）；`core/actor.gd` param 一行；`core/formula_execution.gd` run_item 开头。
- 乙档：无。
- 丙档：`guyu_battle_probe.cjs`、`xiyou_guyu_battle`、`同步正式西游.py`／`oracle_additions.py` 登记。

## 优化登记草稿

优化登记草稿：无（原版这期没看到要改的缺陷；花荫、转移条件暂关是移植进度，不是优化）

## 可优化（流程／工具／效率）

- 建议：新探针登记进 PROBES 没有守卫，一期漏了也没人发现（车道工作树里手动跑出的 `.sandbox` 产物盖住了）。`检查.sh` 可以加一条：`mv_oracle/*_probe.cjs` 都要在 PROBES 里（或列进豁免），预计几分钟的活，归哪吒工具车道。

## 本分支提交

- d1c2ce81 合并 main（甚尔四期、云裳二期）
- 9e8d8500 WIP：探针、XGuyu 战斗内、一行钩子、专项、同步登记
- 2a960a96 WIP：专项 544/544、参照去掉五乘区与路线压制、治疗公式走 run_item
- d2fcd2be WIP：同步通过、专项脚本 uid
- 交付单可合并（本提交）
