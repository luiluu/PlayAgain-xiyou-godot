# 交付：cc/bajie-guyu2

- 车道／工作者：C 规则／八戒（cc，八戒）
- 状态：进行中
- 分支从 cc/bajie-guyu1 末端 846f2ceb 切（总装九派），工作树 `.claude/worktrees/sleepy-khayyam-db2439`。
- **交接**：这一期还没写代码。上一位八戒（做完 toji4、guyu1）上下文用得多，谷雨战斗内机制量大，建议新开一个会话接手；下面是已经查清的原版逻辑与重制挂点，接手照这个做。

## 范围（总装九：交付单 guyu1「下期」）

储备、花期绽放、代命归根、花荫、转移、终结、autoAction、进阶石掉落。量大，建议拆两期：
- 二期 A：战斗生命周期、生命储备（含成长生未央）、花期 open、绽放 bloom、终结 finish、进阶石 rollStone。
- 二期 B：代命 substitute 与归根 root／再生 regenerate（含 isAlive／isDead／canMove／revive／recoverAll 包装、OTB 复活插队）、花荫 shield（CodexShieldLedger 来源 guyu.shield、先许一枝开 springBoost）、转移 transfer（含 isValid、转移比例窗口）、autoAction。

## 原版要点（installNativeGuyuRuntime.js 行号）

- 状态（G.*）：activeBattle、round、flowerUntil、flowerSerial、openAt、seed、events（行动事件栈）、rows（每人 e 储备、shield、shieldUntil、rootUntil、bud、budFlower、springBoost…）、tracked、internal、unprotected、calcOwner、healing、totals、roundTaken、lastRoundPressure、springReturnDone。BattleManager.setup 包装 reset＋activeBattle＝true（403），endBattle 包装 finishBattle（163～170：归根且有幸存者先再生、reset、全员 _hp 夹到 mhp）＋胜利 rollStone（417～422：谷雨在队、还差进阶、背包里谷种金缮石少于差额、Math.randomInt(50)==0 给 1 个）。
- 回合：startTurn 包装 G.round＝turnCount＋1 跑原 startTurn 后再设回 turnCount（404）；endTurn 包装（原 endTurn 之后、不在弹字等待中）endRound（154～161：本回合受伤压力、过期护盾清零、花期到期 closeFlower、归根到期且有队友活着就再生）。
- 储备：row(b).e；cap＝谷雨本人无上限，其余 floor((curve(1,1.25,1.5,1.75)＋0.15×谷雨阶位)×baseMhp)（50）；addE（54～59，超出记浪费、b._hp 夹 mhp、refresh）；pay（60，学了我即万物之春不付）。param 包装（258～263）：战斗中角色 param(0)＋e（baseMhp 走计数器不加）。
- gainHp 包装（264～280）：归根中不回血；扣血先吸花荫（无账本时）；回血时谷雨活跃、受益者是出战角色且之前活着、不是内部操作：addE(floor(回血))，来源是谷雨的直接治疗时记 healed，且学了生未央、不在花期时再 addE(floor×0.2)。不在行动里的扣血包进 isolated 事件。G.healing 由 Game_Action.apply 包装设（{subject, direct: isHpRecover 或带效果 11}）。
- 治疗公式的 h：事件 heights（G.begin 时记每个出战队员的 mhp，含储备）。
- 行动事件：startAction 包装 G.begin(action, true)（清 _guyuSpecialDone 等）；endAction 包装 G.end(e, true)→原 endAction→afterAction(e)（绽放）。
- 花期 open（doSpecial 196～201）：目标活着、不在花期、round≥openAt 才开；flowerSerial＋1、flowerUntil＝round＋1、seed＝目标。closeFlower：flowerUntil＝−1、seed＝null、openAt＝round＋2、清待绽。
- 绽放 bloom（116～132）：队友（出战、活着）在花期里用技能（不是防御、不是内部、不是 open／shield／finish、行动真的执行了）后，付储备 25%（待绽 35%，春之后 60 级 50%），威力＝付出×curve(5,6,7,8)×(先许一枝开 20 级起 springBoost ×1.1／60 级 1.2)，用技能 10299 打种子（死了换第一个活着的敌人），calcOwner＝谷雨（伤害按谷雨算），不会心。
- 终结 finish：花期中且储备≥1，威力＝全部储备×curve(33,50；40/60 级)，付全部、closeFlower。绽放／终结公式 max(0, 威力−(CodexDamage 计算中 0，否则 魔防×0.5))。
- 自动战斗 autoAction（447～472）与 CFG.ai 阈值：最低血＜35% 治疗；受伤（＜70% 且无护盾）≥2 人或上回合压力≥20% 且没人有护盾→花荫；花期中储备比≥80% 或花期最后一回合→终结；不在花期且有人储备≥50% 上限→花期打血最多的敌人；否则治疗。

## 重制挂点（已查，未改）

- `XActor.param`（actor.gd 665）：原版安装次序谷雨 133 在异化 129 之后、种族 148 之前，所以写成 `XRaceBattle.param(self, i, XGuyu.param(self, i, XAlienBattle.param(...)))`。
- `XResourceContext.gain`（resource_context.gd 108～160）：回血的统一入口；谷雨 gainHp 包装挂在 `_set_resource` 之后（回血量、之前是否活着在 snapshot 里有）。
- `battle_logic.gd`：setup（97，开战 reset／activeBattle）、start_turn（704）、end_turn（805，endRound）、execute（1367，begin／end 事件与 afterAction 绽放）、_apply（1721，healing 上下文与 doSpecial）、end_battle（2299，finishBattle、rollStone）。只加一行一行的钩子；toji、云裳二期也在这些函数里加了行，合 main 时照并列保留（总装九提醒：云裳二期改了 applied、sure、damage_ops 三处）。
- 第一期 `XGuyu` 已有 flower_until／open_at／round 三个静态量（meets 读），二期接上即可；meets 里 finish／shield／transfer 现恒 false，要改成读储备与花期。
- 参照：仿 `toji_battle_probe.cjs`（真实 BattleManager，队伍 [175, 1]，Math.random 0.5，步骤脚本 act／end／state／foehp…），记每步命中、各人储备 e、mhp、hp、花期与种子；专项仿 `xiyou_toji_battle`。

## 变更记录草稿

（待写）

## 验证

（待写）

## 本分支提交

- 交付单交接稿（本提交）
