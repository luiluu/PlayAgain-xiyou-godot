# 交付：cc/replace-attack-motion

- 车道／工作者：C 规则·战斗演出（cc，Orca worker task_e2234cedc9c7，claude-opus-5-5＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·战斗演出·未经审查】替换后的普攻按技能自己的动作演出（甚尔、宿傩除外）；琴里「平A」查明是技能自身序列＋技能动画默认关（dev.待定）

- 背景：玩家反馈琴里「打单怪平A」；上一单（cc/fix-step-encounter-1115）查明学了炽烈之魂（6174）后普攻恒为 6170「初火*炽烈火柱」，怀疑原版 `isAttack` 让替换后的普攻按武器挥砍演出。Kyo 11-15 定改。
- 查明（琴里）：6170 **自己的行动序列**写死 `motion swing: user`×3、`<Cast Animation: 0>`，不经 PERFORM ACTION，火柱是每段在目标身上放动画 158；`isAttack` 对它的画面没有影响（专项实测开关前后逐帧动作一样）。看着像平A的真因是设置「技能动画」默认关（原版默认值）：关时 158 不放，只剩三下挥武器。直接放 6170 也一样。协调 11-15 定按 A 收尾：6170 不动，玩家回复写明打开「技能动画」能看到三段火柱（已同时问 Kyo，改选别的再追加）。
- 全游戏 `<Replace Attack: x>` 盘点（武器、防具、状态、被动技能共约 150 处，另加甚尔／宿傩／屠苏运行时）：替换技能全都有自己的 YEP 序列。原版 `isAttack` 只在两处影响画面：PERFORM ACTION 的动作（`performAttack` 挥武器＋武器图）与 CAST ANIMATION（攻击不放施放动画）。真正会变的是「带技能类型（stypeId>0）且序列走 PERFORM ACTION」的 24 个：漩涡、冷冰、闪烁之杖、名刀 鬼彻、天堂之光、新世代爆破手套（两把）、诅咒之锤、修补能量锤、断禅、断禅*改、番天印、传承:惊宵锤、戮仙剑、天外天·轩辕剑、天外天·永恒吞噬、贽殿遮那、天外天·贽殿遮那、护摩之杖，被动 紫色の忧郁／你就是歌姬吧／劫天运，以及甚尔四个咒具形态（已排除）；运行时替换的宿傩 10238 咒力体术也走 PERFORM ACTION（已排除）。其余替换技能序列里自己写了动作（motion swing／missile／spell 等），不受影响。stypeId 0 的「攻击」类（飞镖、苦无、回旋镖等）照旧挥武器。屠苏归形、璇寄星 stypeId 0，照旧。
- 修法（O-待定，默认开）：`XBattler.attack_motion(item)`——演出上是否按「攻击」走：原版就是 `is_attack`；开关 `XBattler.REPLACED_ATTACK_OWN_MOTION` 开时，普攻被替换成 stypeId>0 的技能就按普通技能演出（技能类型在 System.magicSkills 里放 spell，否则 skill；不出武器图；没写 `<Cast Animation>` 的按命中类型放施放动画，物理 52／魔法 51／必中 0）。排除名单 `XBattler.OWN_MOTION_EXCLUDE`（默认甚尔四形态主技能 10216～10219，挥咒具是设定，协调 11-15 定；宿傩 10238 咒力体术，体术挥拳同理，本车道按同一理由加入，可改）照旧挥武器。用到的三处：`battle_scene._perform_action`、`sequence_player._cast_animation`、`XXuanTusuArt.motion_for`（ArtPack performAttack 包装，现只影响屠苏／璇，两人的替换技能都是 stypeId 0，画面不变）。
- 只动演出：`is_attack` 本身、普攻追加次数、伤害、命中、暴击、TP、段数、天启篇各词条／七印／种族对「普攻」的判断都没改（都还读 `is_attack`／`attack_skill_id`）；战斗逻辑不读新开关。自动战斗、挂机、智能 AI 选完招后都走同一个演出入口（`_play` → 行动序列），三条路径一样；双持角色的武器动画只在挥武器分支里用，按技能演出时不出武器图；技能动画关时只少施放动画，动作照技能；战斗变速只改等待帧数，不影响选哪个动作。
- 专项 `xiyou_replace_attack_motion`（新，36 项）：判断层——琴里 6170、火精灵文书（1004）、飞镖（12，stypeId 0 照旧挥）、敌人佛陀真身（状态 66 → 562）、技能 1、甚尔／宿傩排除名单（清空名单才按技能演出），开关开／关；结算层——同种子出一次 6170，开关前后伤害／暴击／命中／TP／追加次数／敌人 HP 全同；画面层——真战斗场景跑完整行动序列逐帧记出手者动作、武器图、出手者身上施放动画、顶部日志招名：琴里开关前后一样（自身序列挥砍）、日志显示「初火*炽烈火柱」；传承:惊宵锤（4437 雷降）开＝施法动作、不出武器图、放施放动画 52，关＝挥武器、不放；没替换的普攻不变；技能动画开／关各一遍。
- 玩家可见：装了漩涡、冷冰、闪烁之杖、鬼彻、番天印、惊宵锤、断禅等「普攻换成技能」的武器（以及紫色の忧郁等被动）时，普攻按那个技能的施法／技能动作演出，不再挥武器。琴里的炽烈火柱本来就是挥三下＋火柱，看火柱要在设置里打开「技能动画」。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `core/battler.gd` `XBattler.REPLACED_ATTACK_OWN_MOTION`、`OWN_MOTION_EXCLUDE`、`attack_motion`；`battle_scene._perform_action`、`sequence_player._cast_animation`、`XXuanTusuArt.motion_for` | `<Replace Attack>` 换来的技能仍算 isAttack：PERFORM ACTION 挥武器出武器图、不放施放动画 | 换成带技能类型（stypeId>0）的技能时按技能本身演出（施法／技能动作、施放动画）；stypeId 0 的攻击类与排除名单（甚尔四形态、宿傩）照旧挥武器；结算不变 | 普攻换成法术类技能还挥武器，看着像平A（Kyo 11-15 定改） | `XBattler.REPLACED_ATTACK_OWN_MOTION = false` | cc | 保留 |

## 交接板

- 下一步：等 Kyo 对琴里 6170 的答复（协调已问）：A 不动（本单）／B 另加开关把写死 motion swing 的替换技能改施法动作／C 替换普攻无视「技能动画」开关总放技能动画。
- 用户试玩说明：
  1. 给能装锤的角色（如窃格瓦拉·周）装「传承:惊宵锤」，战斗里点攻击：放「雷降」时角色举手施法、身上有施放光效，不再挥锤。
  2. 琴里学了炽烈之魂后攻击：仍是挥三下（技能自己这么设计），顶部日志显示「初火*炽烈火柱」；设置里打开「技能动画」能看到三段火柱。
  3. 甚尔四个咒具形态、宿傩的普攻照旧。
- 需要用户决定：琴里 6170 走 A／B／C（协调已问 Kyo，本单按 A）。不进 v0.02.00 补丁，出补丁时再问 Kyo。

## 进度账

- 无（演出优化）

## 可优化（流程／工具／效率）

- 建议：「技能动画」默认关时很多技能（不只替换普攻）看着都只剩挥砍。可考虑给玩家反馈问卷／帮助加一句「看不到技能特效先开技能动画」（归小A 文案）。

## 待交叉核查

- `modes/xiyou/core/battler.gd`（新增 `attack_motion`、两个开关，未改 `is_attack`／`attack_skill_id`）、`battle/battle_scene.gd` `_perform_action`、`battle/sequence_player.gd` `_cast_animation`、`core/xuan_tusu_art.gd` `motion_for`——甲档（碰战斗演出与原版移植逻辑），请 co 核；重点：结算路径是否确实不读新开关、甚尔／宿傩排除是否合适、是否该扩到别的。
- 新专项 `tests/xiyou_replace_attack_motion.gd`。
- `--oracle` 建议：总装合并后跑一次；本单只改演出，参照对照应全同。

## 验证

- 专项 `xiyou_replace_attack_motion` 36/36（无头；窗口截图那遍 35/35，宿傩排除是之后加的）。
- 截图（窗口模式，`-- --out=`）：`03_再刷重制_Godot/04_验证/本地结果/replace_attack_motion/`：`kotori_on_*.png`／`kotori_off_*.png`（琴里开关前后，一样）、`hammer_on_*.png`／`hammer_off_*.png`（惊宵锤开＝施法＋施放光效、关＝挥锤），各取第 6／18／34 帧。
- 本地选测（`选测.py main --list` 给 297 个，含 xiyou_rules 全部段与事件对照；本单只改演出、逻辑不读新开关，本地选了演出／普攻／战斗核心相关 45 个）：xiyou_replace_attack_motion、sequence_visual、action_sequence、boss_sequence、attack_query、weapon_unleash、**determinism**、toji_battle、xuan_tusu_art、xuan_battle、tusu_battle、cat、dual_wield、mv_animation、battle_log、battle_speed、battle_pace、gojo、sukuna_fx、kotori_firepower、smart_ai*（17 个）、hangup_options、combat、raven_fx、guyu_battle、costume_battle、actor_sv_compare、battle_ui、mira_battle 全部通过；加宿傩排除后复跑 replace_attack_motion、sukuna*、toji_battle 通过。xiyou_rules 各段、事件对照等未跑，留给总装合并选测。
- 语法检查 0 问题；工具回归全过。

## 本分支提交

- a967b38c7 WIP：XBattler.attack_motion、开关、三处演出改用；专项初版
- 0300b1750 甚尔／宿傩排除名单、专项 36 项、交付单

## co 甲档核查

- 核查对象：`d9b869c30`（累计包含 a967b38c7、0300b1750 的代码），co／gpt-6.1-sol＋medium，2026-11-15；只改本节，不改游戏代码。
- 结论：通过（附非阻断 P3 补测建议）；未发现 P1／P2，不改游戏代码。
- P3（非阻断）：`tests/xiyou_replace_attack_motion.gd:123`、`:211`，开关结算对比只测演出本来不变的琴里 6170，惊宵锤画面测试未直接对比结算和随机流快照。建议后续增加 4437 完整行动序列开／关的伤害、TP、追加次数与 `logic.random.snapshot()` 对比；现有 determinism 是演出矩阵通用保障，不是这个开关的直接证据。
- 结算与时序：新函数仅供三个演出调用点读取，伤害／追加次数／AI 的 `is_attack`、`attack_skill_id` 不变；`_cast_animation → _normal_animation → _start_animation → MVAnimation` 无战斗随机流调用，音效 timing 也无随机数抽取；WAIT FOR ANIMATION 会延长演出等待，顺序仍串行，等待只推进显示状态。随机动作 randattack 使用独立 RandomNumberGenerator，不消耗战斗 rule／reward 流。
- 回退：开关关时 `attack_motion(item)` 与 `is_attack(item)` 等价，三个替换点恢复原条件，未改其余分支，技能动画开关及变速仍走原实现。
- 边界只读：stypeId 0（飞镖／苦无等）返回攻击动作；双持／空手的 attack_visual 与 `_attack_animation_ids` 没改，新技能分支不出武器图；自动／挂机／智能 AI 选招后共用 `_play` 和序列演出入口。双持本轮没有重新运行专项（不在该基准的云端选测集合），不以执行者历史测试冒充本轮证据。
- 排除名单：与 `XActor.TOJI_MAIN` 四形态及宿傩固定普攻一致，保留咒具挥击／体术符合本单要求；不需要扩名单。琴里 6170 的显式 swing 与 Cast Animation 0 保持不动（Kyo A）。
- 本轮验证：修正后云端 25/25 场景通过（7 片及 report 全部 success），包括 xiyou_replace_attack_motion、xiyou_determinism、xiyou_smart_ai 及 b～p／profile 共 17 个、attack_query、battle_speed、hangup_options、sequence_visual、toji_battle、sukuna_fx；运行证据：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/43737201174 （attempt 2）。
- 原版对照：本轮实际运行 `mv_oracle/boot_check.cjs`，db=true、277 scripts、165 plugins、modulesFailed/errors 均空（约 4.6 秒）；云端 attack_query、smart_ai 使用已有原版探针基线，并非重新生成全部原版探针，未跑全量 `检查.sh --oracle`、未重同步正式源。
- 云端执行说明：首次跳过名单漏 `.tscn` 后缀，误启动 297 场景，已取消；修正后重跑的 plan.json 确认为 25 场景／7 片，以下结论只据修正后的结果。
