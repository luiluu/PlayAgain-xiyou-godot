# 交付：cc/bailong-tusu3

- 车道／工作者：E 角色专属／白龙_14（cc）
- 状态：**WIP（未完成，不能合并）**：Kyo 周额度将尽，11-01 22:34 收工。代码与专项已提交，选测和反向验证没跑完（见「接续要点」第一条）。
- 分支从 cc/bailong-tusu2 末端 d3a80a62 切出（链式交付，**包含 tusu2、tusu1、cat-trial1**，那几张交付单照它们自己的合）。没再合 main（main 这期间没碰本车道文件、切片、转换器或探针）。
- 范围：屠苏三期，另插审查第 21 期 P3③（总装十二插单）。画面层不做。

## 本期选了盘点表的哪几行、为什么

tusu1 盘点表三期写的是屠苏的三行，本期做了前两行和第三行的一半：

| 盘点行 | 本期 | 理由 |
| --- | --- | --- |
| 武具数据、属性基准、伤害公式、止戈环加成 | 武具数据、基准、公式函数做了；止戈环的加成（支援伤害、金汤护盾 ×淬纹倍率，第一回合兵势 +0）留四期 | 止戈环加成只作用在支援上，跟支援一起做 |
| 噬主（屠苏先付、持武者三倍代付、都付不起回人形） | 全做 | 玩家化武后第一个碰到的就是费用；绑定框架的第一个用户 |
| 绑定登记、五相主动支援、易武／化武／归形、锁定与和鸣 | 绑定登记、三个指令、技能条件、「攻击」换归形做了；支援的施放与效果、锁定与和鸣留四期 | 支援要接统一伤害钩子与公式（MODULE_FORMULAS 在悟空 events3），一起做才测得了 |

另做了盾相双防补底（原表在四期「盾相双防补底」，只是 param 一行，跟武相状态一起测）。

## 变更记录草稿

## 2026-11-01 【cc·白龙_14·未经审查】屠苏三期：武具、噬主与三个指令；小猫试炼还原后刷新事件（dev.待定）

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
- 钩子各一行：`battle_logic.gd`（can_use 加 XTusu.meets；canPay 的噬主包装；付费的噬主包装；_skill_cost 的屠苏费用；apply 的三个指令；end_battle 清理）、`actor.gd`（attack_skill_id、param 链加盾相补底）、`xstate.gd`（读档清理）、`binding.gd`（start_battle 登记屠苏种类）。
- 参照：新探针 `mv_oracle/tusu_battle_probe.cjs`（真实 CodexTusu＋CodexBinding、真实 BattleManager），不进同步，产物拷成 `tests/fixtures/tusu_battle_oracle.json`。新专项 `xiyou_tusu_battle`。

## 原版里看到的、照原版没改的

- `T.coefficient` 原版自己那份（四舍五入、默认 4 档等级）被 bindGrowth 换掉了，实际按 7 档等级向下取整；重制直接用 XTusuXuan.coefficient。
- 屠苏的技能条件里写了「归形要 1 点充能」，但种类是 manual、充能恒 0，而且 bindGrowth 的归形判断在最外层先返回，这一层到不了。照原版，归形只看战斗中、绑定、活着、能动。
- 同一回合里先解除再化武，屠苏身上的「武具」状态加不上（MV 同一结果槽里刚去掉的状态不能再加），要到下个回合同步时才有。「攻击」换归形不受影响（看的是绑定，不是状态）。重制照原版（参照 shield 例）。

## 验证

- 专项 xiyou_tusu_battle 914/914：参照 4 个例逐步比（basic 化武剑、易武预约、换武相、归形；shield 盾相补底、宿主阵亡解除、换宿主；devour 屠苏自付、持武者三倍代付、都付不起回人形；low 低等级没解锁的武装技能与支援）。
- **屠苏还没进切片**，重制里她的能力值和原版对不上（30 级魔攻 1312 对 1530；5 级、60 级各项）。专项里把屠苏六项能力值钉成参照开局的值，只比本期的逻辑。悟空把 176／177 进切片后，去掉专项里的 TusuActor 再比一次（写在接续要点）。
- xiyou_cat_trial 54/54（新一例 script.refresh）；反向「还原后不刷事件」咬住。
- 反向验证：屠苏 26 处（结果见下「反向验证」）。
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

- 共用核心：`battle/battle_logic.gd`（can_use 加 XTusu.meets；can_use 末尾 canPay 前 3 行噬主；execute 付费块改成先 XTusu.pay；_skill_cost 谷雨之后一行；apply 里绑定之后 3 行；end_battle 一行）；`core/actor.gd`（attack_skill_id 一支、param 链加 XTusu.param）；`core/xstate.gd` from_dict 一行；`core/binding.gd` start_battle 首行登记。
- `core/tusu_xuan.gd` meets 的归形条件（行为变化：绑定时归形可用）。
- `map/mv_script.gd` 小猫试炼还原后刷新事件。
- `core/tusu.gd` 全文；新探针、夹具、专项。

## 接续要点

- **收工时的现场（白龙_14，11-01）**：XTusu、钩子、探针、专项 xiyou_tusu_battle 914/914 已提交（cd0331d8 及本提交）。没做完的：
  1. 选测 29 个（名单在本单「选测」节要列的：xiyou_tusu_battle、xiyou_tusu、xiyou_binding、xiyou_shield_ledger、xiyou_shield、xiyou_cat_trial、xiyou_determinism、xiyou_event_compare、xiyou_rules、xiyou_rules_d3、xiyou_guyu、xiyou_guyu_battle、xiyou_actor_modules、xiyou_actor_p0、xiyou_skill_page、xiyou_battle、xiyou_smart_ai、xiyou_party_skills、xiyou_imported_balance、xiyou_toji_battle、xiyou_mira_battle、xiyou_yunshang、xiyou_alien_battle、xiyou_attack_query、xiyou_battle_gaps、xiyou_status_page、xiyou_help_card、xiyou_character_help_cost、xiyou_save_events）开跑后在等槽，收工时停掉了，一个都没出结果。
  2. 反向验证清单 26 处已写好、能定位（项目名见上「反向验证」该填的表；清单按 `07_开发环境/反向验证.py` 格式，改的是 core/tusu.gd、battle_logic.gd、tusu_xuan.gd 的片段），没跑。下一位照「待交叉核查」逐处重写一份即可（原清单在会话 scratchpad，没入库）。
  3. 总装插单 **沙僧二审 S2-1-03（P2，Kyo 同意修，甲档）没开始**：`battle_logic.gd` 约 1609～1616 行黄泉、宿傩、甚尔三个 wraps 分支提前 return，跳过了末尾的 `XYunshang.applied`（原版云裳 Game_Action.apply 包装在 modules.json 第 31 位，包在三者外层：applyCommand、觉醒引爆符针、天衣命中效果）以及 frame.total 累计。要修成三支也走到云裳那一层；同时查 XGarou.applied、XYomiJingliu.j_applied、XRaven.applied 在原版是不是也包在这三者外层（看 modules.json 顺序），是的话一并修。每个角色补一条「云裳种针→唤醒穿天衣的该角色→专属技能攻击」双端参照＋专项，核命中、剩余针数、追加伤害、随机抽取次序、同一行动只引爆一次。

- 四期从支援开始：主动支援是屠苏自己的行动（makeTargets 包装：和鸣恒打持武者、锁定选敌人但效果给持武者、金汤滤掉不可命中的），效果在 applyItemUserEffect（锁定、和鸣状态、金汤护盾记 XShieldLedger 来源 tusu.jintang、铸环守 tusu.body、护阵、挫势、开刃·剑破防）；持武者行动触发的内部支援要 B.cast（binding.gd 里还没有）。
- 统一伤害钩子（CodexDamageHooks 'tusu'）：武装技能把攻击者的物攻／魔攻换成 XTusu.base、按 CFG.armActions／持武者行动次数分摊（d.host_actions 已经记了）、锁定／和鸣倍率、支援的 [触发伤害×0.5, 自身×2.7] 上下限与 40 级后成长加成、挫势、护阵。
- xiyou_tusu_battle 的 TusuActor 钉了能力值；进切片后删掉它、按真实能力值重比。

## 反向验证

（跑完填）

## 选测

（跑完填）

## 本分支提交

- 前面同 tusu2（到 d3a80a62）
- 审查第 21 期 P3③：小猫试炼还原后刷新事件
- WIP: 屠苏三期 XTusu、参照、专项
- 本提交：交付单可合并
