# 交付：cc/bailong-yunshang6

- 车道／工作者：E 角色专属／白龙_10、白龙_11（cc）
- 状态：可合并
- 分支从 cc/bailong-yunshang5 末端 c579efdd 切出（总装十同意；yunshang5 的工作树守卫不让写），**包含 yunshang4 与 yunshang5**。yunshang5 的交付单内容（孤灯照众 10）并进本单，那张已删掉，合本分支就够。yunshang4 是独立的「可合并」交付单（B 批前一半），照它自己的单合。本分支已合过一次 main（cbaf1d48，含谷雨一期、battlelog2、tools30，没有冲突），合完补齐过一次。
- 范围：云裳第二期 B 批后一半——天衣 5 千军入袖、6 空袖藏星（借技能）、7 九曲回针（针眼）、10 孤灯照众，自动战斗 AI（智能 AI 档案、估算器、makeAutoBattleActions 包装）。战斗指令窗与天衣铺界面不做（界面车道）。

## 变更记录草稿

## 2026-11-01 【cc·白龙_10、白龙_11·未经审查】云裳第二期 B 批后一半：千军入袖、空袖藏星、九曲回针、孤灯照众与自动战斗（dev.待定）

照原版 installNativeYunshangRuntime.js（行号是该文件的），扩 `XYunshang`：

1. **孤灯照众 10**（第 358～363、229、394 行，白龙_10）：有醒着的穿戴者时，任何队员新得的普通增益（每回合最多 3 种）分给全队；没醒的穿戴者自己每回合第一次新得的分给全队；对友方全体的行动施放中不共享。原版包在 Game_Battler.addState 上，但参照里敌人得到的增益不共享，所以只接角色。
2. **千军入袖 5**（第 265、319～321、422、535、541、752 行）：收袖开关 `XYunshang.sleeve[角色]`（原版 a._yunSleeve：指令窗切换，自动战斗设为开），每次行动 prepare 时抄进本次行动。收袖时对敌全体（scope 2）的行动，或云裳学了云丝展幅的伤害行动，记下全部活着的对手，目标收成 smoothTarget 那一个（段数照常）；伤害钩子 split 对记下的每个对手各算一次相加（各取各的防御、元素，公式也按各自重新求值）。觉醒中打倒目标时，溢出量（这段伤害−打前生命）依次传给其余活着的敌人（见优化登记）。
3. **空袖藏星 6**（第 248～249、253、387、64 行）：天衣铺设的借用技能 `setting(a).borrow`（没醒取前 1 个、醒取前 3 个），主人要在出战且会这招、技能可借（`XYunshang.borrowable`，第 249 行那串条件整个移植）；能不能用照第 253 行；醒着用借来的技能时物攻／魔攻至少取主人的（prepare 记、endAction 清）。
4. **九曲回针 7**（第 216、254、388、429 行）：针眼 `setting(a).eye`；觉醒那一刻清针眼冷却；醒着每回合一次越过冷却（能不能用时不看冷却、预热照看；施放时先清冷却，付费再照常进冷却）；用过针眼后，别的技能（含普通攻击、防御，每回合最多 3 种）各让针眼冷却 −1。`battle_logic.can_use` 的冷却那行加了 `XYunshang.eye_bypass`。
5. **自动战斗**（第 448～505、541 行）：
   - 智能 AI 档案（registerProfile）：云裳的伤害技能倍率（双针 ×0.555、戴织神天梭 ×1.99、余辉再 ×1.33）与云丝展幅溅射（0.77／0.66／0.5）；一身两世 12（没醒 ×2、同回合复演过 ×1、醒 ×3）、万法同裳 13 觉醒 ×2；敕衣点神只选穿天衣没醒的、御风（队列里第一个敌人之后还有没行动的队友才给分）、换锦（能换几对、觉醒时全队可转的减益＋最多 3 个可夺的增益）、赠行（对方输出高于自己时）、储行（自己打不到人时）的收益。
   - `XSmartAI` 补上原版档案的三个回调：`targetAllowed`（限目标）、`targetUtility`（加目标收益）、`prepareTarget`（选中时记下，换锦用它定要换的一对）；`profile` 改成先问甚尔、再问云裳。
   - 估算器（CodexAIEstimators）：云裳公式的钉影、拆神、收针、山河击、符针按防 0 估（收针按 aiGather 会选的觉醒者回合数）；智能 AI 的段数补上云裳双针的 ×2（原版 action.numRepeats 含这层包装）。
   - makeAutoBattleActions 包装（`XBattleLogic.auto_battle_action` 选完之后）：觉醒的同袍换日免费赠给双攻最高的队友、寸光留仙放行、六衡裁身（魔攻≥物攻选魔攻＋敏捷，否则物攻＋敏捷）、千军入袖开收袖。
   - 原版另包的 Game_Action.evaluate（关掉智能 AI 时的原生自动战斗估值）不移植：重制关掉智能 AI 时自动战斗直接普通攻击，那层用不上。
- battle_logic.gd：`targets_for` 把 chosen 传给 `XYunshang.targets`；`can_use` 冷却一行；`_calculate_damage` 拆出 `_formula_raw`（收袖的段对别的目标重新求值公式，算完还原 `_formula_outcome`）；`auto_battle_action` 包一层调 `XYunshang.auto_battle`。smart_ai.gd：`profile`、`safe_damage`（估算器、双针段数）、`score_candidate`（三个回调）、`_choose`（prepareTarget）。
- 参照：`yunshang_probe.cjs` 加 4 例 p4.*（p4.eye 加第 2 回合越过冷却的两步）与 11 例 p5.*（档案、目标收益、估伤、choose 与前 6 名候选、自动战斗包装）；专项 `xiyou_yunshang` 1570 项。

## 优化登记草稿

- O-待定（可回退）：千军入袖觉醒的溢出（第 422 行）判的是 `!live(target)`，可原版行动中目标有 YEP IMMORTAL（行动序列 `immortal: targets, true`），生命到 0 也不倒下，溢出从来不触发，打倒目标后剩下的段照样打在它身上（参照 p4.sleeve：生命 1000 的敌人挨满 4 段、没有派生伤害）。重制默认目标生命到 0 就算打倒，照写的把溢出传给其余敌人（之后打在生命 0 目标上的段整段溢出）；`XYunshang.o_sleeve_overflow = false` 照原版不传。

## 验证

- 专项 xiyou_yunshang 1570/1570（直接跑；B 批前一半 950＋孤灯 12＋千军入袖、空袖藏星、九曲回针约 330＋自动战斗约 280）。千军入袖的参照比较在开关关着时跑，开关开着另比溢出（4 段派生伤害、数值与目标生命）。
- 反向验证（逐个改、各自单跑，用备份文件还原，已还原）19 项有 18 项抓到：收袖不拆目标、不取主人能力、针眼不越过冷却、别的技能不减冷却、醒着只借 1 个、溢出不传、觉醒不清冷却、双针倍率、溅射、御风等人、换锦觉醒计数、赠行收益、估算器、收袖不开、六衡反选、不免费赠行、敕衣点神不限目标、一身两世倍率。**储行收益没抓到**：参照里队友总打得到人（aiOutput＞0），储行的 4500 分没出现过，只按读码接。
- 语法检查通过。没改切片与转换器；只改了 yunshang_probe（不接全量同步），不用重跑同步与内容覆盖检查。
- 选测（本机 CHECK_JOBS=3，规则对照 `RULES_ONLY_ACTORS=174`，合 main 并补齐后，22 分钟）54 个场景全过、没有偶发，名单写全名：xiyou_yunshang、xiyou_help_card、xiyou_alien_battle、xiyou_alien_affix、xiyou_rules 与 xiyou_rules_d1b～d6d 全部 24 份、xiyou_battle、xiyou_battle_gaps、xiyou_otb、xiyou_action_sequence、xiyou_custom_damage、xiyou_jingliu、xiyou_jingliu2、xiyou_sukuna_battle、xiyou_garou_battle、xiyou_raven_battle、xiyou_mira_battle、xiyou_yomi_battle、xiyou_toji、xiyou_toji_battle、xiyou_race_battle、xiyou_cat、xiyou_smart_ai、xiyou_smart_ai_b、xiyou_smart_ai_c、xiyou_smart_ai_d、xiyou_actor_p0、xiyou_actor_modules，另加改动直接相关的 xiyou_boss_output_context、xiyou_state_effects、xiyou_state_effects_tp（覆写 `_calculate_damage`）与 xiyou_attack_query（调 `auto_battle_action`）。合 main 前跑过一轮，help_card 与 rules 共 7 个失败，是分支落后 main、产物来自主工作区（谷雨、来源指纹）所致，合 main 补齐后全过。
- 回退开关覆盖：`回退开关覆盖.py` 新缺口 0（o_sleeve_overflow 在专项里赋了回退值）。

## 交接板

- 下一步：云裳只剩界面——战斗指令窗（收袖开关、放行、赠行、裁身、七曜元素、收针选人、换锦选状态）与天衣铺（借用技能、针眼、元素组的设置，制作、领取、进阶）；现在要选择的地方都照自动战斗给默认（收针选剩余回合最多的觉醒者、换锦各取第一个、针眼与借用技能默认不设）。
- 用户试玩说明：云裳的天衣又有 4 件生效了：千军入袖收袖后群攻打一个人、伤害按全部敌人算；空袖藏星能借队友的技能用（借谁的要等天衣铺界面）；九曲回针觉醒后针眼技能每回合能无视冷却放一次；孤灯照众把增益分给全队。自动战斗会用云裳和天衣的技能了（会赠行、放行、裁身、开收袖）。
- 需要用户决定：空袖藏星借来的技能照原版要满足武器类型（参照里借 1 号的天剑、万剑诀都要剑，云裳不能用）。天衣铺选技能时原版不看武器，所以多数物理技能借来也用不了。要不要让借来的技能不看武器？默认照原版。

## 进度账

- 角色与专属机制：云裳完成度 0.65 → 0.85（天衣 15 件战斗效果、借技能、自动战斗都接了；剩指令窗与天衣铺界面），角色约 +0.4 个百分点（约 400 行代码，照 yunshang4 的估法 400×0.15÷8817×50≈0.34）。按行数估，不是测量值。

## 可优化（流程／工具／效率）

- 发现（已知差异，没追）：同一场景开局的 OTB 行动顺序，重制与参照不同（battle2：参照 1、8、9、10 号在敌人前，重制 10 号、敌人、8、9、1 号；1 号敏捷 0）。p2 起专项只比队列里的行动数，本期 p5 的御风收益要看队列，测试照参照排；建议战斗核心车道查 OTB 速度的随机或排序。
- 发现（参照写法）：上一位以为「针眼冷却读数全 0」，其实 `cds` 第 1 列是钉影、第 2 列才是拆神（针眼），读数一直对。写探针时比数组建议带上技能号（如 `{10271: 2}`），少看错列。
- 无新的工具改动。

## 待交叉核查

- 原 Codex 核心文件：`battle/battle_logic.gd`——`targets_for`（chosen 传进 `XYunshang.targets`）、`can_use` 冷却一行（`XYunshang.eye_bypass`）、`_calculate_damage` 拆出 `_formula_raw` 并传给 `XYunshang.calculate_split`、`auto_battle_action` 包一层；`battle/smart_ai.gd`——`profile`、`safe_damage`、`score_candidate`、`_choose`。
- 留意：收袖段对别的目标重新求值公式，打到的目标那段沿用先算好的（原版每段都按各自目标求值，随机数先后可能差一步，只影响带 Math.random 的公式）；溢出只给技能（物品收袖不传溢出，原版会拿物品号去建技能，读码看是坏的）；收袖开关不进存档（原版 a._yunSleeve 在角色上，会存；现在只有自动战斗会开它）；储行收益、prepareTarget 记下的一对在实战里换锦的效果参照没覆盖。

## 本分支提交

- 09afdad1 参照 p4.* 4 例、孤灯照众 10、专项 962/962（白龙_10）
- c579efdd 交付单接续要点（白龙_10，WIP）
- a8859824 天衣 5／6／7 接线（WIP）
- c692cac2 天衣 5／6／7 专项接上，参照 p4.eye 加第 2 回合，1292/1292
- c78da23e 参照 p5.*（WIP）
- 94e03da6 自动战斗：档案、估算器、自动战斗包装，XSmartAI 三个回调（WIP）
- e5b05e14 专项补 prepareTarget，1570/1570（WIP）
- 9b6a770c 交付单（WIP）
- cbaf1d48 合并 main
- 本提交：选测全过，交付单可合并
