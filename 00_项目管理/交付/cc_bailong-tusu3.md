# 交付：cc/bailong-tusu3

- 车道／工作者：E 角色专属／白龙_14（cc）起头，白龙 tusu3b（cc）接手收尾
- 状态：**可合并**（见文末「选测」）
- 分支从 cc/bailong-tusu2 末端 d3a80a62 切出（链式交付，包含 tusu2、tusu1、cat-trial1；tusu1 已在 main）。11-02 合了 main 两次（到 4c31709f）：`actor.gd` param 链冲突，main 改了注释的序号写法，本分支加了屠苏一层，合成两边都留、屠苏标第 42 个（冻结 modules.json：谷雨 38、屠苏 42、种族 53）。
- 范围：屠苏三期，另插审查第 21 期 P3③（总装十二插单）、沙僧二审 S2-1-03（总装插单，甲档）、审查第 22 期 P3-1（总装插单）。画面层不做。
- 旧工作树 `.claude/worktrees/nostalgic-curie-5a2b2d` 还挂着本分支（白龙_14 的），已不再写，清理时删。

## 本期选了盘点表的哪几行、为什么

tusu1 盘点表三期写的是屠苏的三行，本期做了前两行和第三行的一半：

| 盘点行 | 本期 | 理由 |
| --- | --- | --- |
| 武具数据、属性基准、伤害公式、止戈环加成 | 武具数据、基准、公式函数做了；止戈环的加成（支援伤害、金汤护盾 ×淬纹倍率，第一回合兵势 +0）留四期 | 止戈环加成只作用在支援上，跟支援一起做 |
| 噬主（屠苏先付、持武者三倍代付、都付不起回人形） | 全做 | 玩家化武后第一个碰到的就是费用；绑定框架的第一个用户 |
| 绑定登记、五相主动支援、易武／化武／归形、锁定与和鸣 | 绑定登记、三个指令、技能条件、「攻击」换归形做了；支援的施放与效果、锁定与和鸣留四期 | 支援要接统一伤害钩子与公式（MODULE_FORMULAS 在悟空 events3），一起做才测得了 |

另做了盾相双防补底（原表在四期「盾相双防补底」，只是 param 一行，跟武相状态一起测）。

## 变更记录草稿

## 2026-11-02 【cc·白龙·未经审查】屠苏三期：武具、噬主与三个指令；小猫试炼还原后刷新事件；云裳包装包住黄泉／宿傩／甚尔（dev.待定）

1. **屠苏武具骨架**（installNativeTusuRuntime.js）：新模块 `XTusu`。
   - 武具数据：当前武相、预约、化武选的武相、持武者本回合行动次数；上次武相跨战斗记在 s.flags（原版记在角色上）。
   - 绑定登记：种类 tusu，manual，不转充能。化武时定武相，宿主加持武状态；解除时清宿主的持武、锁定、和鸣状态与预约。回合开始有预约就换武相；屠苏和持武者都付不起当前武相任何一招时，噬主失败回人形。
   - 指令：归形解除；易武预约下回合的武相；化武能当宿主就绑定。
   - 技能条件：易武要绑定且不是当前／预约的武相；化武要没绑定；支援要是当前武相那招、持武者活着；武具态别的技能只有防御；武装技能要持武者拿着对应武相；器谱战斗外。「攻击」在武具态恒为归形。
   - 噬主：武装技能与绑定中的支援先由屠苏付自己最大 MP 的比例，付不起由持武者按自己最大 MP 付三倍，都付不起不能用；持武者的面板 MP 在屠苏付得起时显示 0。书相时持武者的魔法技能 MP ×0.7。
   - 盾相：持盾的宿主双防不低于屠苏的双防。
   - 属性基准与公式 `XTusu.damage(a, b, 键)`：书相取屠苏魔攻，其余取物攻，乘随屠苏等级的系数（接转换器是 A 车道的事）。
   - 战斗结束、读档清理。
   - 归形的条件（XTusuXuan.meets）：一期起恒不可用，现在照原版 bindGrowth：战斗中、绑定中、活着、能动。
   - 不做（四期）：支援的施放与效果、统一伤害钩子（武装基准代入、行动分摊、锁定、和鸣、支援上下限、挫势、护阵）、止戈环加成、自动战斗与智能 AI、开刃与器谱、战斗日志台词、指令窗。
2. **审查第 21 期 P3③**：小猫试炼打完，地图的 start_battle 是在还原队伍之前刷新的事件（那时只有 178），37 个事件页用了「角色在队」条件。现在还原队伍后再刷一次（`mv_script.gd`）。xiyou_cat_trial 补一例。
3. **沙僧二审 S2-1-03（甲档）**：原版云裳的 Game_Action.apply 包装（冻结 modules.json 第 31 个）在黄泉（9）、甚尔（10）、宿傩（18）、饿狼（19）外层，重制这三人的专属技能提前 return，跳过了云裳那一层（指令、种针、拆神、觉醒引爆符针、天衣命中效果）和饿狼的记帧。参照 `yunshang_wraps_probe` 先确认原版：
   - 三人的主行动整次跑完后，云裳只看一次（对主目标最后一段的结果）：觉醒中引爆主目标一根针，黄泉溅射、重复两次都只引爆一次。
   - 甚尔万里锁的溅射、术师杀手反弹，宿傩 S.perform 的追斩 10236、神灶，原版都是 `new Game_Action(...).apply`，是**独立的子行动**，各自走一遍云裳包装（各自 prepareAction、各自引爆自己目标一根针）。实测甚尔觉醒万里锁一次去掉三个敌人各一根；宿傩捌＋追斩一次去掉两根。
   - `_yunTotal` 原版在 executeHpDamage 包装里累计 min(打前生命, 伤害)，包在里层的多段（宿傩冲击＋斩、黄泉溅射）都算进同一次行动。
   - 改法：`battle_logic._invoke` 三支不再提前 return，跑完走 `XGarou.applied`（外层看最后一段）和新的 `XYunshang.after_wrapped`；新 `XYunshang.child` 给子行动存外层帧、prepare 建子帧、跑完 applied 再还原（`toji._spread`、`toji.reflect`、`sukuna.perform` 用）；`frame.total` 从 applied 挪到 `after_hp`（battle_logic 传打前生命）。
   - 镜流 `j_applied`、渡鸦 `applied`：原版也在内层，但只管自己的行动（own(u)），黄泉／宿傩／甚尔出手时是空操作，不用动。
4. **审查第 22 期 P3-1**：`tusu_xuan.gd` 的 `_owner` 原来用 `XState.actor()`，本体没建过时会顺手新建一个 1 级本体；原版 ownerInstance 读 `$gameActors._data[本体]`，不建。改成只读 `s.actors.get(本体)`：本体不存在时别人的屠苏／璇专属技能全滤、不能用，系数按 1 级（B.curve 的 a 为空取 1 级，与原来一样）。xiyou_tusu 补 no_owner 两例（176、177 各：滤掉、不能用、系数、不建本体）。
- 钩子各一行：`battle_logic.gd`（can_use 加 XTusu.meets；canPay 的噬主包装；付费的噬主包装；_skill_cost 的屠苏费用；apply 的三个指令；end_battle 清理）、`actor.gd`（attack_skill_id、param 链加盾相补底）、`xstate.gd`（读档清理）、`binding.gd`（start_battle 登记屠苏种类）。
- 参照：新探针 `mv_oracle/tusu_battle_probe.cjs`（真实 CodexTusu＋CodexBinding、真实 BattleManager），不进同步，产物拷成 `tests/fixtures/tusu_battle_oracle.json`。新专项 `xiyou_tusu_battle`。
- 参照：新探针 `mv_oracle/yunshang_wraps_probe.cjs`（真实 BattleManager，Math.random 0.5，关五乘区），不进同步，产物拷成 `tests/fixtures/yunshang_wraps_oracle.json`。新专项 `xiyou_yunshang_wraps`。

## 原版里看到的、照原版没改的

- `T.coefficient` 原版自己那份（四舍五入、默认 4 档等级）被 bindGrowth 换掉了，实际按 7 档等级向下取整；重制直接用 XTusuXuan.coefficient。
- 屠苏的技能条件里写了「归形要 1 点充能」，但种类是 manual、充能恒 0，而且 bindGrowth 的归形判断在最外层先返回，这一层到不了。照原版，归形只看战斗中、绑定、活着、能动。
- S2-1-03：宿傩神灶 10233 主行动直接返回、不调原 apply 时，原版云裳读到的是上一次留下的 `target.result()`（可能是旧的命中）。重制当没命中（不引爆、不触发天衣命中），这一处没对参照，属于原版读旧值的边角。
- 同一回合里先解除再化武，屠苏身上的「武具」状态加不上（MV 同一结果槽里刚去掉的状态不能再加），要到下个回合同步时才有。「攻击」换归形不受影响（看的是绑定，不是状态）。重制照原版（参照 shield 例）。

## 验证

- 专项 xiyou_tusu_battle 992/992：参照 4 个例逐步比（basic 化武剑、易武预约、换武相、归形；shield 盾相补底、宿主阵亡解除、换宿主；devour 屠苏自付、持武者三倍代付、都付不起回人形、书相时持武者魔法技能 MP ×0.7（tusu3b 补的 cost 步：水泡术 65→45）；low 低等级没解锁的武装技能与支援）。
- 专项 xiyou_yunshang_wraps 214/214：参照 6 个例（黄泉、宿傩、甚尔 × 觉醒／没醒），逐步比每段扣血（出手者、技能、目标、暴击、绝对值）、各敌人剩余针数、觉醒、技能表、暴击率与幸运。黄泉 10185 暴击＋9.99 原版不生效（O-098），专项里照 xiyou_yomi_battle 关掉 CRIT_FIX 比。
- P3-1：xiyou_tusu 314/314（godot 直接单跑）；反向「_owner 改回 XState.actor()」6 项失败（滤掉、不能用、不建本体，两个角色），咬住；系数一项改回也过（新建的也是 1 级，结果相同），是预期。xiyou_tusu_battle 992/992、xiyou_binding 291/291、xiyou_skill_page 21/21 直接单跑全过。
  - **没跑完的**：P3-1 之后本机测试槽一直被占（等了约 20 分钟没排上），没用 `并行测试.py` 跑；`xiyou_help_card` 用 godot 直接单跑是 887/1013，但把 `_owner` 改回旧写法同样 887/1013，说明是直接单跑的环境差、不是这次改动（云端选测时它是过的）。请总装合并选测里带上 xiyou_help_card、xiyou_character_help_cost、xiyou_tusu 再确认一次。
- 相关专项另跑：xiyou_yunshang、xiyou_sukuna_battle、xiyou_toji_battle、xiyou_yomi_battle、xiyou_garou_battle 全过。
- **屠苏还没进切片**，重制里她的能力值和原版对不上（30 级魔攻 1312 对 1530；5 级、60 级各项）。专项里把屠苏六项能力值钉成参照开局的值，只比本期的逻辑。悟空把 176／177 进切片后，去掉专项里的 TusuActor 再比一次（写在接续要点）。
- xiyou_cat_trial 54/54（新一例 script.refresh）；反向「还原后不刷事件」咬住。
- 反向验证：屠苏 26＋1 处、S2-1-03 5 处（结果见下「反向验证」）。
- 语法检查通过；探针登记检查通过。
- 选测（全名）：见下「选测」。

## 需要用户决定

- 无。

## 交接板

- 下一步：屠苏四期（支援的施放与效果、统一伤害钩子、挫势、止戈环加成、自动战斗）；前置悟空 events3 把 176／177 进切片、CodexTusu 公式进 MODULE_FORMULAS，合进来后先去掉 xiyou_tusu_battle 的能力值钉子再比一次。
- 用户试玩说明：本期玩家看不到变化（屠苏不在切片里，招募脚本没接）。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：屠苏、璇 约 2/7 → 约 3/7（屠苏武具、噬主、指令），按工作量估。

## 可优化（流程／工具／效率）

- 无新增（「整数随机取中点」公用流类总装已派哪吒）。

## 待交叉核查

- **S2-1-03（甲档）**：`battle/battle_logic.gd` `_invoke` 黄泉／宿傩／甚尔三支改成跑完再走饿狼、云裳（after_wrapped），after_hp 多传打前生命；`core/yunshang.gd`（新 child、after_wrapped；frame.total 从 applied 挪到 after_hp，改成 min(打前生命, 伤害)，所有角色的云裳累计都受影响）；`core/toji.gd`（_spread、reflect 走 XYunshang.child）；`core/sukuna.gd`（perform 走 XYunshang.child）；新探针、夹具、专项 xiyou_yunshang_wraps。
- 共用核心：`battle/battle_logic.gd`（can_use 加 XTusu.meets；can_use 末尾 canPay 前 3 行噬主；execute 付费块改成先 XTusu.pay；_skill_cost 谷雨之后一行；apply 里绑定之后 3 行；end_battle 一行）；`core/actor.gd`（attack_skill_id 一支、param 链加 XTusu.param）；`core/xstate.gd` from_dict 一行；`core/binding.gd` start_battle 首行登记。
- `core/tusu_xuan.gd` meets 的归形条件（行为变化：绑定时归形可用）；`_owner` 只读不建（P3-1）。
- `map/mv_script.gd` 小猫试炼还原后刷新事件。
- `core/tusu.gd` 全文；新探针、夹具、专项。

## 接续要点

- 白龙_14 留下的三件（选测、反向、S2-1-03）tusu3b 已做完，见上。

- 四期从支援开始：主动支援是屠苏自己的行动（makeTargets 包装：和鸣恒打持武者、锁定选敌人但效果给持武者、金汤滤掉不可命中的），效果在 applyItemUserEffect（锁定、和鸣状态、金汤护盾记 XShieldLedger 来源 tusu.jintang、铸环守 tusu.body、护阵、挫势、开刃·剑破防）；持武者行动触发的内部支援要 B.cast（binding.gd 里还没有）。
- 统一伤害钩子（CodexDamageHooks 'tusu'）：武装技能把攻击者的物攻／魔攻换成 XTusu.base、按 CFG.armActions／持武者行动次数分摊（d.host_actions 已经记了）、锁定／和鸣倍率、支援的 [触发伤害×0.5, 自身×2.7] 上下限与 40 级后成长加成、挫势、护阵。
- xiyou_tusu_battle 的 TusuActor 钉了能力值；进切片后删掉它、按真实能力值重比。

## 反向验证

清单在会话 scratchpad，没入库；结论：

屠苏（xiyou_tusu_battle）27 处，24 处咬住：化武不记上次武相、化武不给宿主持武状态、解除不清宿主状态、回合开始不换预约武相、回合开始不判噬主失败、持武者行动次数不记、书相基准改物攻、比例费用不乘 mcr、代付不乘三倍、能维持恒真、屠苏付得起时持武者面板 MP 不显示 0、书相不省蓝（补 cost 步后）、支付不扣屠苏、支付不扣持武者、易武可选当前武相、绑定中仍可化武、支援不看持武者活着、武具态其他技能可用、武装技能不看武相、攻击不换归形、易武不预约、盾相不补底、归形条件恒假、can_use 不接屠苏条件。

没咬住 3 处（都是到不了的分支，不补）：
- 化武默认武相 sword：化武指令总带武相（huawu.剑／弓…），pending 恒有值，默认只给没走化武的绑定用，三期没有这种入口。
- 持武者阵亡仍可代付：持武者阵亡当场解除绑定（shield 例），绑定中持武者恒活着。
- 省蓝不看魔法技能：cost 步的对照技能是攻击 1（MP 0），×0.7 看不出；四期支援时再补物理带 MP 的技能。

S2-1-03（xiyou_yunshang_wraps）5 处全咬住：包装分支不走云裳、_yunTotal 不在扣血处累计、甚尔溅射子行动不单独成帧、宿傩内部行动不单独成帧、子帧不还原外层帧。

## 选测

- 云端选测（`云端选测.py run`，基准 GitHub main 的分叉点）：提交 e7d14f18（合 main 4c31709f＋S2-1-03 修正之后），`选测.py` 按改动选中 316 个场景（改了 battle_logic／yunshang 等，近似全量），14 片**全部通过**，无偶发。运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41361050298 。
- 之后只有一个提交改了屠苏专项与探针（cost 步，测试代码），本地单跑 xiyou_tusu_battle 992/992；交付单本提交不碰代码。
- 白龙_14 列的 29 个全名都在这 316 个里。

## 本分支提交

- 前面同 tusu2（到 d3a80a62）
- 审查第 21 期 P3③：小猫试炼还原后刷新事件
- WIP: 屠苏三期 XTusu、参照、专项
- 合并 main（两次，解 actor.gd 冲突）
- 沙僧二审 S2-1-03：云裳／饿狼包住黄泉、宿傩、甚尔；子行动各自一帧；_yunTotal 在扣血处累计
- 屠苏专项补书相省蓝参照
- 审查第 22 期 P3-1：_owner 只读不建
- 本提交：交付单可合并
