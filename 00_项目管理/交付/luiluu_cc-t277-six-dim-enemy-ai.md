# 交付：luiluu/cc-t277-six-dim-enemy-ai

- 车道／工作者：T277 六维③敌方 AI 接线（cc 车道，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T277·未经审查】天启篇敌方六维 AI：战商 5 档选招／选目标、辅助／输出／生存／速度倾向、低韧性慌乱、四骑士自由点名（dev.待定）

- 新增 `modes/xiyou/battle/tianqi_enemy_ai.gd`（`XTianqiEnemyAI`，开关 `ENABLED`，默认开）：只认六维表里真录了的敌人（`six_dim.json` 的 `enemies` 有这一号，或骑士键 `knights` 有这条线；协调 11-20 Q1＝A）。没录的、战商 1 档（蒙昧）、西游档、`XTianqiSixDim.ENABLED`／本开关关着，一律走原版 `enemy_action`，一个数都不多取。估值用 T282 的 `XBattleEval`（只读、不取随机数），六维只读 `XTianqiSixDim`，两者都没改。
- 选招（`battle_logic.decide` 的普通敌人分支）：候选、rating 带与原版相同；每招底分 (rating−zero)×100，再乘整数百分比：输出→伤害招、辅助→友方支援招（队友受伤／缺这项增益／有人倒下时按辅助档乘，用不上时一律 ×10%，不空奶）与召唤招（有空位按辅助档乘，满员 ×10%）、生存→防御和只对自己的招只在低于自己的血线（E／D 55%、C／B 35%、A／S 20%、SS／SSS 15%）时乘，自奶满血 ×10%；嘲讽／给自己叠防御在血线以下乘，生存 A 起平时也乘、速度→复读上一招（E／D 偏爱、A 起降权）与抢节奏招（A 起，表里没这列，模块常量）；战商 3 档起：全体免疫或吸收 ×10%、打得到弱点 ×130%、纯控制白交（都挂着或硬免控）×10%；4 档起：能斩杀 ×140%、只剩一个敌人还交全体伤害招（scope 2）×50%（随机 n 下不算，单敌时全段集中）；5 档：我方主力护盾 ≥ 剩余血 50% 时高耗爆发 ×35%、减益／抢节奏／驱散 ×130%。仍只掷一次 `enemy_action`。
- 选目标（`_random_target` 加可选参数 skill）：只对六维 AI 刚决定的这一位、这一招改各目标权重（脚本首领、七印寂静、混乱、烙印等别的来源不改），仍只掷一次 `target`。2 档：一半照受击率、一半盯最低血（有人挂着嘲讽状态照原样；天生或装备的高受击率不算嘲讽，只在原权重里照常体现）；3 档：对这招免疫的目标 ×10%、弱点 ×130%；4 档：能斩杀 ×600%、治疗／复活点 ×150%、再乘威胁度；5 档：治疗点与主力输出 ×200%、厚盾铁壁 ×50%；4 档起有人挂嘲讽状态时只按免疫筛。斩杀只认 HP 伤害招。
- 四骑士（协调 11-20 Q2＝B）：`tianqi_horsemen.gd` 的 `_pick_target` 加参数 u（出手的骑士），没给 chosen 的自由点名按骑士战商加权（2 档盯最低血、3 档避厚盾、4 档残血 <30% 与治疗点、5 档主力），仍只掷一次 `horseman_target`；脚本锁死的 chosen 原样；援军不是骑士、没录，原样。技能序列（回合表、阶段、计量）一点不动。
- 低韧性慌乱：只录表的 class minion／elite、非首领（`is_boss`、`boss_difficulty_boss`）、非骑士和援军；能行动、韧性 E 残血 <25%（或本回合刚有敌人倒下，借 `XRaven.any_death`）／D <20% 时掷 `six_dim_panic`（几率读表 panic_pct：E 20、D 10），慌了再掷一次三选一：防御退缩、普攻乱打（目标照原版受击率）、发抖空过；`act` 开头出一条战报。没资格不取数。
- `core/enemy.gd`：`boss_control_state` 的控制标签正则预编译成静态变量（T276 核查 P2-1），全库状态判定逐个不变。
- 新专项 `tests/xiyou_tianqi_enemy_ai`（99 条）、`tests/xiyou_tianqi_enemy_ai_scene`（16 条，真战斗画面看慌乱战报停留）。六维档全在测试里自设（T280 正重算，不写死角色档）。
- 玩家可见：天启篇接入敌方六维行为：天启四骑士在非指定目标的出手时会按各自「战商」挑选目标（既定出招顺序不变）；后续录入六维的敌人也会依「战商」选招与挑人（避开免疫属性、优先补刀残血与压制治疗），并按「输出、生存、速度、辅助」呈现抢攻、保命嘲讽、减少连用同招、支援队友等打法倾向，低韧性普通小怪残血或同伴倒下时还可能阵脚大乱。原版西游存档不受影响。（小A r1 文字审定稿）

## 文字（待小A 审）

- 慌乱战报（小A r1 定稿，按三种表现分句；`XTianqiEnemyAI.PANIC_TEXT`）：「%s阵脚大乱，慌忙缩身防守！」／「%s阵脚大乱，胡乱挥出一击！」／「%s阵脚大乱，呆在原地没敢出手！」；带 tianqi_fit，战斗画面停 36 帧
- 上面「玩家可见」一条

## 验证

- r1 返修（小A 甲档核 P1×3 P2×2 P3×5 全修）：专项 `xiyou_tianqi_enemy_ai` 99/99（新增 w4_random_not_waste、w_summon、w_stall、w_self_heal、t2_high_tgr_not_taunt，改 w_guard、w_support、p_text_*、auto_battle_same 目标下标）；`xiyou_tianqi_enemy_ai_scene` 16/16（无头与带窗口 --audio-driver Dummy 各跑一遍：三种表现战报都停 ≥34 帧，去掉 tianqi_fit 的对照组 ≤1 帧）。P3-1：`end_battle` 时清 `_decided_user`（r1 原先也在 `targets_for` 非 confusable 时清，复核 r2 P2-3 指出会被璇自律预检提前清掉，已改，见下）。P3-4 用的是 `XEnemy.boss_id`（库里没有 is_boss_id，备注「BOSS级怪物」由它认）。
- r1 本机选测 19 个全过：xiyou_tianqi_enemy_ai、xiyou_tianqi_enemy_ai_scene、xiyou_tianqi_horsemen*（2）、xiyou_tianqi_war、xiyou_tianqi_famine*（2）、xiyou_tianqi_plague、xiyou_tianqi_death、xiyou_determinism、xiyou_confusion、xiyou_target_eval、xiyou_tianqi_six_dim_resist、xiyou_tianqi_smart_ai_eval、xiyou_gojo_trials、xiyou_battle_log、xiyou_tianqi_brand、xiyou_tianqi_skills、xiyou_binding。r1 没重跑云端整轮。
- P2-3（小A 复核 r2）：六维点名登记改在 `act` 末尾和 `_forced_run` 开头清，`targets_for` 不再清（`XXuanBattle.start_action` 的预检 `targets_for` 曾把它提前清掉）。新用例 `xuan_auto_keeps_weights`（炼狱档，队伍带 60 级三阶、星谱自动、已绑定的璇，4 档敌人 60 次真 `act`，开 vs 关打中可斩杀目标的次数）、`xuan_cleared_after_act`、`forced_run_clears`；专项 103/103。反向验证：把清登记放回 `targets_for`，`xuan_auto_keeps_weights` 失败（开／关都是 22 次）。本机选测 26 个全过（xiyou_tianqi_enemy_ai*、四骑士各线、xiyou_determinism、xiyou_confusion、xiyou_target_eval、xiyou_tianqi_brand、xiyou_tianqi_skills、xiyou_binding、xiyou_xuan*、xiyou_troop_events、xiyou_battle_events、xiyou_battle_log、xiyou_gojo_trials 等）。
- r0：专项 `xiyou_tianqi_enemy_ai` 94/94（门控 9、选招权重 15、实战选招 4、选目标 11、慌乱 26、四骑士 4 条线本体＋影子 29、五条悟试炼 1、不改数值与我方自动战斗 2、正则 1 等）。
  - 卡 3 验收 1：选招逐档（`w3_*`、`w4_*`、`w5_*`、`real_tier1_half`／`real_tier3_avoids_immune`）、选目标逐档（`t2_*`～`t5_*`、`t_e2e_kill_target`）。
  - 验收 2：输出／辅助／生存／速度（`w_aggro`、`w_support`、`w_guard`、`w_repeat`、`w_tempo`）；敌人 mhp／攻防魔敏、估伤、state_rate 开关两边一致（`numbers_same`）。
  - 验收 3：E／D 残血才掷、边界几率、三种表现、战报只出一次、同伴倒下只算 E、C 起／首领类／霸体首领 0 触发且不取数、同种子 40 回合战报序列一致（`p_*`）。
  - 验收 4：四骑士四条线 body＋shadow 各 8 回合（我方防御、加厚），开／关技能序列一致、各 reason 掷数一致、开时自由点名确实加权；战商 1 档时目标也一致；五条悟试炼影子录成宗师，回合表开／关一致。
  - 验收 5：我方 `auto_battle_action` 开／关同种子选招一致；敌人韧性取 C（T276 核查 P3-1：避开韧性非 C＋非必中控制会让我方 XSmartAI 估算跟着变的边界；本单开关只关 XTianqiEnemyAI，不动 XTianqiSixDim）。
  - 门控：没录、1 档、XTianqiSixDim 关、西游档，与关掉本开关 60 次决定序列与掷数完全一致；5 档掷数也一致。
- 本机选测（并行 2）13 个全过：xiyou_tianqi_enemy_ai、xiyou_tianqi_horsemen、xiyou_tianqi_horsemen_battle、xiyou_tianqi_war、xiyou_tianqi_famine、xiyou_tianqi_plague、xiyou_tianqi_death、xiyou_determinism、xiyou_confusion、xiyou_target_eval、xiyou_tianqi_six_dim_resist、xiyou_tianqi_smart_ai_eval、xiyou_gojo_trials。
- 云端选测（`选测.py` 列的 464 个场景，提交 0ff9d032e，16 片）：全过。
- 语法检查通过；工具回归全过（98 秒）。
- 没跑：`--oracle`（按派单由总装合并时带）。没做反向验证（`反向验证.py`）。

## 交接板

- 下一步：`six_dim.json` 的 `enemies` 现在是空的，所以实战里真生效的只有四骑士自由点名（骑士四条线都录了）；普通怪要录六维（或写 template）才走六维 AI 和慌乱，协调说另开数据卡。卡 4／5（界面）照常。
- 用户试玩说明：天启篇四骑士战，骑士自由点名不再完全随机（死亡、瘟疫、饥荒、战争按各自战商挑人），出招顺序不变；开关 `XTianqiEnemyAI.ENABLED`
- 需要用户决定：无

## 进度账

- 无

## 没做／偏离

- 稿 2.1 的 3 档「综合 tgr 与有效伤害」只做了按属性免疫／弱点改权重，没把有效伤害大小折进目标权重；4 档「把高耗群体大招浪费在 1 名残血上」做成「只剩 1 个敌人时群体伤害招 ×50%（有单体伤害招可选）」，不判残血和耗费。
- 稿 2.2「援护」：库里没有统一的援护标记，只把「给自己挂嘲讽」算进生存那一项；召唤按技能名／备注认（召唤、援军、召集、呼唤、叫来、摇人、Summon），有空位（队里有倒下的）才乘。
- 稿 2.3 速度「先手增益／控制／减速」的 125／145 表里没有这一列，写成模块常量 `TEMPO_PCT`；慌乱血线 25／20 同样是常量 `PANIC_HP_PCT`（six_dim.json 只读）。数值改表要等 T280／数据卡加列。
- `XRandomStream.next_int_inclusive` 是有界取数，区间长变了时极小概率（≈区间长／2^32）会多拒绝一次重掷；改权重的两处区间长跟原版不同，严格说「掷数一致」在这个概率下不成立，专项实测一致。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log
