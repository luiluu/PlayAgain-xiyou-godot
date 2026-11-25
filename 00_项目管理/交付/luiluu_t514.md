# 交付：luiluu/t514

- 车道／工作者：天启篇养成线 T013 3A 真气（烙印）境底＋境支／cc（Opus＋medium，T514）
- 状态：可合并

## 变更记录草稿

## 2026-11-25 【cc·T514·未经审查】天启篇七境境底＋境支实装（dev.待定）

- 依据：设计仓库《原版养成线重做方案 v0.3》第三节第 5 条（境底、19 境支）、第五节第 1～3 条甲（境支能换、花钱、一次一境）；《天启篇_烙印 v0.6》第四节第 5 条（D129 迎劫境底物攻魔攻 +5% 换成生命 +5%，九条带攻境支去攻，D145 其中锋骨／化刃／劫火／开印改成换伤支 伤害 +3%／承伤 +3%）、第三节第 3 条（换伤支伤害并在 K 那一项）、第四节第 7 条（境底承伤和破防同在承伤池相加）。拆卡稿 `协作交接/派单/T513_二三期拆卡.md` §3A。
- 新模块 `modes/xiyou/core/tianqi_brand_realm.gd`（`XTianqiBrandRealm`），数在 `tianqi_data/brand.json` 新段 `realm`（整数百分数；出处总写在 `realm.source`，D129／D145 改过的迎劫和九条支另写行内 `src`）。境按立到的境（`brand_realm`，打赢心魔才升）算，不按烙印值。
- 境底（之前各境都在）：守一生命 +5%；不染 生命 +3% 魔防 +5%、被上有害状态和能力减益 10% 不中（和异常抵抗相乘）；铸骨 生命 +3% 物防 +5% 承伤 −5%；砥柱 生命 +3% 魔法 +5%、战斗里生命低于一半时受到的回复 +15%（各线削减和虚不受补之后）；真形 生命 +3% 敏捷 +5% 承伤再 −5%；迎劫 生命 +8%（每境 +3% 加 D129 的 +5%）、一下超过最大生命一半的部分少受三成（在各保命之前）；逆命 生命 +3% 幸运 +5%、每场一次挨打真掉了血、掉到三成以下还活着时，这一击结算完后独立回复最大生命 20%（经砥柱 +15%）。
- 境支：不染～逆命每境一条，18 条摆出来能选（逆命「本线支」稿写属性「看线」，3B 接联动前不摆）。普通支两项属性各 +3%，没有一条带物攻、魔攻；换伤支伤害 +3% 并进 K × 烙印那一项（`XTianqiBase.k_actor_mult`）、承伤 +3% 进承伤池。联动只写在表里给人看，本单不接（3B）。
- 选支／换支：闭关人物页新加「加深分支（已选/已立）」；一览列到立到的那一段，点进去选。没选过的段按第一条算，第一次选免费（养成线稿老存档口径：默认第一支、免费改一次）；之后改选花钱，价 ＝ `swap_price_units`（10）场钱 × 难度价格倍数（`XTianqiMoney.price`，场钱按最高到达层，所以跟层走），钱不够不换。打赢心魔立入下一段后直接进这一段的选支页。改选只在方桌大厅（不在副本、里副本里；主菜单「真气」在别处也能打开，所以按地点拦），在别处只能看；某段第一次选（破境当场选）在哪都能选。
- 存档：角色 `zhenqi.brand_branch` {"段号": 支 key}；`XZhenqi.from_save` 只在本来就有时留（西游档、没选过的档不新建）。
- 接线：`XActor.param_rate` 末尾乘 `param_rate`；`XTianqiBrand.taken_mult` 改成承伤池相加（境底、换伤支、破防，算完不低于 0）；`XTianqiBrand.heal` 虚不受补之后接砥柱；`BattleLogic.execute_hp_damage` 心魔特点之后接迎劫、末尾接逆命；`BattleLogic.state_rate`、`add_debuff_effect`、`XTianqiElementEffects._actor_state_rate` 乘不染。
- 开关 `XTianqiBrandRealm.ENABLED`（默认开）：关掉境底、境支一律不算，闭关不出「加深分支」；烙印本体关着（`XTianqiBrand.ENABLED`）时也跟着没有。只在天启篇存档（`XTianqiBrand.on` → `XTianqi.active`），西游档零改动。
- 发给谁（第五节第 5 条甲：出战全额含倒下、助力一半、后备不给、不补发）：真气已由烙印取代，烙印的结算 `XTianqiBrand.settle` 早就是这个口径（T117），本单没改，专项 `xiyou_tianqi_brand` t6_assist 那组照过。
- 数据校验：`天启篇数据校验.py` 的 brand 规则加 realm 段（七行境底照七境顺序、整数百分、每境 3 支逆命 4 支共 19、换伤支对得上 trade 且不带属性、其余支两项属性不带物攻魔攻、key 不重）。
- 专项 `xiyou_tianqi_brand_realm`（新，46 条）：表、属性（守一、逆命默认支逐项、迎劫 +8%、穷举所有选法物攻魔攻都是 1）、换伤支（K ×1.12、承伤 0.90／1.02／破防 1.32）、四条生存效果（含真打 `execute_hp_damage`）、换支（免费、收钱、钱不够、hidden、没立到）、闭关菜单和立境后选支、存档来回、开关关和西游档。`xiyou_tianqi_brand` 专项量的是烙印本体和代价的单独倍率，开头把 `XTianqiBrandRealm.ENABLED` 关掉跑（248/248）。
- 跟着改的旧专项（首轮云端整轮 4 个失败，都是旧断言假定天启篇属性倍率为 1 或没有境底，本机改后都过）：
  - `xiyou_tianqi_element_fabaos`、`xiyou_ui_skin_card_o`：「生命倍率 == 1」「修炼预览差 == 修炼值」改成对裸身倍率／乘上属性倍率比。
  - `xiyou_tianqi_xinmo_traits` 两条：立到砥柱、半血以下的人另有境底受疗 +15%，和逆流叠乘（115→132、50→57）；心魔特点稿 v0.2 砥柱注写了默认允许叠乘。
  - `xiyou_gojo_trials` 心宿脚本打法 4 个种子输了：临时探针逐回合比过，脚本「生命低于一半才放反转术式」，生命 +5% 后第 8 回合停在 14918／29106（一半线上 365 点），不放反转、被连招打倒；影子出招按本体基础生命算，不跟境底变。是脚本阈值，不是试炼变难，这一段按没有境底跑、末尾还原（探针没入仓）。
- 玩家可见：天启篇里每个角色随烙印段数多出生命和一项主属性、各段一条生存效果；闭关里能给每段选一条分支（第一次免费，之后改选花钱）。

- 返修（小A Neon 核 `协作交接/核查报告/T514_小A核.md`）：
  - P1-1：逆命回血不再在 `execute_hp_damage` 里用这一击的资源账回复（那样会把这一击的伤害结果、弹字改写成负的回复，压低 `hp_loss`，治疗、护盾全挡也会误耗）。改成两步：`note_hit` 只在伤害为正、生命确实减少时记下；`apply`、`horseman_strike` 末尾（结果和弹字定了之后）`after_hit` 判三成线，用 `gain_hp` 独立回复。
  - P1-2：新 `can_change`／`may_choose`：改选只在方桌大厅、不在副本里；`choose` 拦下返回「仅限在大厅闭关处更换分支。」，选支页照样列出几支但点了不落到改选。某段没选过的第一次选不拦——稿同一条写「破境时……选一条，当场生效」，心魔可能在别处打，拦了就没法当场选；这一条是我的读法，请小A 复核时看。
  - P2-1：元素独特效果我方受者有效度（`XTianqiElementEffects._actor_state_rate`）里不染改成对十二种里除圣佑以外的都乘 0.9（灼烧、冰冻名字进不了 `harmful_state` 的正则）。
  - P2-2：数据校验加 `low_heal`／`big_hit`／`rally` 子字段（齐、非负整数）、`swap_price_units` 收成非负整数；四种坏表各喂一次都报错。
  - P3-1：抽自己、六亲不认那一下换伤支也按 1。P3-2：`XTianqiBrand.stand`、换支后 `param_mark_dirty`；`xiyou_tianqi_brand` 末尾把境底开关还原。P3-3：交付单措辞对齐实际（见上）。P3-4：文字按报告第四节定稿落（见「文字」）。
  - 专项 46 → 59 条：逆命延后回复（伤害里头不回、结算后回、量含砥柱）、真走 `apply` 和 `horseman_strike` 结果仍是正伤害、残血挨治疗和护盾全挡不误耗且之后照常能触发、元素灼烧冰冻、`_plain_hit`、立境当场生效、不在大厅／副本里拦改选不扣钱、第一次选照放、定稿文字。

## 交接板

- 下一步：3B（境支联动第一批，接已有的线：道法、宝珠、种族、异化、四条线）、3C（道法三个悟在不染／砥柱／迎劫）另拆；换支价（现 10 场钱占位）待金钱线定；逆命本线支的属性待定（3B 时一起）。
- 用户试玩说明：天启篇大厅「闭关」→ 选人 →「加深分支」：看到已立各段，点进去选一条；属性在状态页能看到变化。
- 需要用户决定：无（下方「要定」两条可由协调或金钱线定）

## 进度账

- 部件 9（数值总账与养成）：T013 3A 完成（拆卡稿折合 +0.12）；3B 的境支能换已一并做（3B 只剩联动）

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XActor.param_rate` | 末尾多乘一项（`git grep -n "param_rate(" -- '*.gd'`） | 新乘项在西游档、开关关、不是角色时恒 1；天启篇里按立到的段算，烙印本体专项照过 |
| `XTianqiBrand.taken_mult` | 2 处（`git grep -nF "XTianqiBrand.taken_mult(" -- '*.gd'`：`damage.gd` 天启篇乘区、`tianqi_horsemen.gd` 出伤） | 从「破防 ×1.3 否则 1」改成承伤池相加；没立到铸骨、没选换伤支的人和以前一样；战斗外仍是 1 |
| `XTianqiBrand.heal` | 2 处（`git grep -nF "XTianqiBrand.heal(" -- '*.gd'`：`battle_logic.gd` 再生、`resource_context.gd` `_gain`） | 虚不受补判断不变；新加的砥柱只在生命低于一半时起作用，两者分在血线两边；逆流心魔特点照旧叠乘（心魔特点稿 v0.2 写了默认允许） |
| `XTianqiBase.k_actor_mult` | 1 处（`k_for`） | 多乘换伤支，没选时恒 1 |
| `BattleLogic.execute_hp_damage`／`state_rate`／`add_debuff_effect`、`XTianqiElementEffects._actor_state_rate` | 各加一行 | 新函数在西游档、没立到那一段时原值返回 |
| 新开关 `XTianqiBrandRealm.ENABLED` | 专项 `off.all_one` 两边都跑 | 默认 true |

## 验证

- 本机：`xiyou_tianqi_brand_realm` 46/46，返修后 `xiyou_gojo_trials`、`xiyou_tianqi_element_fabaos`、`xiyou_tianqi_xinmo_traits`、`xiyou_ui_skin_card_o`、`xiyou_star_warehouse` 一起跑全过，`xiyou_tianqi_brand` 248/248（改前加了境底那一版 241/248，失败都是代价单独倍率被境底叠上，已在专项里关掉境底跑），`xiyou_zhenqi` 过。
- `语法检查.py`：1234 个 .gd，0 个问题。`天启篇数据校验.py` 全部通过（另手工喂一张清心带魔攻的表，报错）。`发行空壳.py check` 退出码 0（`debuff_rate`、`picked_count` 写进特例，四个菜单函数登记空值安全）。
- 返修云端选测：通过。选测 367 个场景、16 片，提交 679c7e31c：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45684703274 （`gh run watch` 前台等完 rc=0）。返修本机：`xiyou_tianqi_brand_realm` 59/59、`xiyou_tianqi_brand` 248/248、`xiyou_tianqi_xinmo_traits` 212/212、`xiyou_gojo_trials` 162/162、`xiyou_tianqi_element_effects` 98/98、`xiyou_tianqi_elements` 57/57、`xiyou_tianqi_element_fabaos` 32/32、`xiyou_zhenqi` 201/201；语法检查 1235 个 0 问题；数据校验全过；发行空壳 check 0。
- 首轮云端选测：通过。整轮 818 个场景、16 片，提交 c8c2c7d2a：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45677952828 （`gh run watch` 前台等完 rc=0）。首轮 4215a2912（https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45670109619）4 个失败，见上；偶发 `xiyou_star_warehouse`（单跑通过）。
- 截图：无（闭关菜单是文字页，专项断言了标签和翻页）

## 没做／偏离

- 九线属性封顶（`XTianqiLedger.param_cap` +30%）只管装备来的几条线，本单境底、境支不算进去。养成线稿真气一项属性最多约 +23%，生命按 D129 改过后到 +28%（境底）＋境支最多 +15%，它们按自己的结构封顶。若要并进 +30%，请协调定。
- 「减益 10% 不中」：有害状态（不含战斗不能）和能力减益都算。
- 生存底线的模型（烙印参数.json「境底生命」）没算 D129 的迎劫 +5%，实装多了这 5%，只会更耐打。
- 境支联动、道法：不在本单（3B、3C）。状态页修行行没加境底境支说明（菜单里有）。

## 要定

- 换支价：稿写「具体价交金钱线」，现占位 10 场钱（修炼第一级是 30），表里 `swap_price_units` 一处改。
- 逆命本线支：稿属性写「看线」，没写数；现在不摆出来，3B 接联动时一起定。

## 文字（已过小A 文字审，按 T514 核报告第四节定稿）

`tianqi_brand_realm.gd` 顶上的 `TEXT_*`：「加深分支（已选 %d/%d）」「%s 的加深分支」「每段可选一条分支，属性即刻生效；首次免费，改选消耗%s。」「%s「%s」分支：现为「%s」%s」「（未选，默认首项）」「本次选择免费。」「改选需消耗 %d %s。」「%s 的「%s」分支已定为「%s」。」「%s不足（需要 %d）。」「伤害 +%d%%、承伤 +%d%%」「%s +%d%%」「仅限在大厅闭关处更换分支。」；属性名、支名照旧。

## 本分支提交

- 4215a2912 T514 T013 3A：七境境底＋境支实装（XTianqiBrandRealm）
- c8c2c7d2a T514 云端四个专项跟上境底
