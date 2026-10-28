# 交付：claude/bajie-weapon-unleash-4656d6

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_79）
- 状态：可合并
- 基线：main 5c850de1。
- 本期：attack-query 期二交付单遗留 3——YEP_WeaponUnleash 的 Weapon Unleash（普攻按几率换成别的技能），先补原版探针再改。

## 原版查下来的结论（YEP_WeaponUnleash.js 与 weapon_unleash_probe 实测）

- **标签全集**（processWULNotetags1，角色／职业／敌人／武器／防具／状态／技能都解析）：`<Weapon Unleash x%: 技能>`、`<Guard Unleash x%: 技能>`、加成 `<Weapon Unleash: ±x%>`／`<Weapon Unleash 技能: ±x%>`（Guard 同）、`<Custom Weapon Unleash: 技能>…</…>`（Guard 同），另有已实现的 Replace Attack／Guard 与指令名。插件无参数。
- **正式数据里实际出现的只有武器上的 `<Weapon Unleash x%: id>`**，共 18 把（逐条）：
  77 贽殿遮那 100%:5769、78 戮仙剑 100%:5564、83 天外天·贽殿遮那 100%:5769、93 天外天·永恒吞噬 100%:5636、207 渔人枪 50%:127、392 钢铁狼爪 50%:258、393 狼神爪 50%:259、405／412 魔法之剑 各 30%:294、295、296、429 名刀 月隐 50%:309、680 灭却 60%:495／30%:496／10%:497、744 名刀 烦恼风 40%:638、1062 鹰角长弓 99%:792、1388 瞄准机械弓 99%:792、1504 传承:雪藏 50%:2802、1505 霸王丸 75%:2802、1508 红丸 75%:2806、1887 “至臻”霸王丸 100%:2802。
  没有 Guard Unleash、没有加成、没有自定义；状态／角色／职业／敌人上都没有。
- **触发时点**：`BattleManager.startAction` 链里。执行顺序（外到内）：Codex 运行时各包装（云裳、异化、种族、谷雨等）→ MOG 连击 → TorigoyaMZ_SkillChangeTo → OTB → YEP_BuffsStatesCore 行动开始状态效果 → **WUL processUnleash** → YEP_BattleEngineCore startAction（useItem 付费等）。所以在 Replace Attack 之后（比的是此刻的 attackSkillId）、行动开始状态效果之后、付费之前。
- **只换普攻**：行动技能号 === `attackSkillId()` 才处理（物品、别的技能不换；替换攻击的武器拿技能 1 也不换——429 拿 1 时 attackSkillId 是 308）。
- **逐条试**：来源顺序 状态 → 装备（槽序）→ 职业 → 角色（敌人：状态 → 敌人）；不看技能。每条先 `canUse(技能)`，不能用就跳过且**不掷**；能用才掷一次 `Math.random()`，`> 几率` 才跳过（**等于几率算中**），第一条中的为准；几率＝x×0.01＋加成（正式数据加成恒 0）。
- **哪些路径会触发**：凡是走 startAction 的都触发——手动攻击、自动战斗、挂机、智能 AI、强制行动（processForcedAction→startAction）、混乱（setAttack 后照常 startAction）。**反击不触发**（invokeCounterAttack 不走 startAction）。
- **可达性**（探针实测，等级上限提到 99 后按武器 `<req_level>` 升级）：
  - 207、392、393、405、412、429、680、744、1062、1388、1504、1505、1508、1887：普通角色装得上（1、2、3、6 号），能触发。1062／1388 的 792 要 5 TP、680 的 497 要 1 TP，TP 不够时那条跳过不掷。
  - 77／83（154 专属）：换出的 5769 是 occasion 3 被动，canUse 恒否，**永不触发**（攻击本身也是 5769，canAttack 为假）。
  - 93（166 专属）：Replace Attack 与解放都是 5636，换了等于没换（TP≥35 时掷一次数）。
  - 78：原版谁都装不上（attack_query 已记），不可达。
- 新角色默认等级上限 10（YEP_CoreEngine Max Level），需求等级 13～40 的武器要进度提上限后才装得上。

## 变更记录草稿

## 2026-10-28 【Claude·八戒·未经Codex检验】武器解放（YEP_WeaponUnleash Weapon Unleash）：普攻按武器几率换成别的技能（dev.待定）

1. `battler.gd`：`weapon_unleash_objects()`（状态）、`weapon_unleashes()`、`weapon_unleash_of()`（逐行认 `<Weapon Unleash x%: 技能>`，几率 x×0.01，按备注缓存）。`actor.gd` 覆盖来源为 状态 → 装备 → 职业 → 角色；`enemy.gd` 为 状态 → 敌人。
2. `battle_logic.gd`：新增 `weapon_unleash(u, skill)`；`execute` 在 Custom Action Start（行动开始状态效果）之后、导入平衡判定与付费之前调用。此刻的普攻才处理，逐条：不能用跳过（不掷），能用掷 rule 流 `"unleash"`，掷数 ≤ 几率就换。换出来的技能照常付费、选目标、记 action。反击走 `_invoke` 不经 execute，不换。
3. 原版探针 `weapon_unleash_probe.cjs`（86 例）：走真实 `BattleManager.startAction` 链（只把 WUL 之后的 BEC startAction 换成记录），只给 `switchUnleashSkill` 里的取数喂磁带；17 把可装武器 × TP 0／100 × 必中／不中，5 把边界（等于几率／略大），680、405 多条依次掷，非普攻（技能 1、直接放解放技能、物品）与空手对照。登记 `同步正式西游.py` 探针表与 `oracle_additions.py` KEYS。
4. 专项 `xiyou_weapon_unleash`（950 项）：照参照摆角色（提上限、升到需求等级、装武器、设 TP），开敌群 1 走 `BattleLogic.act`，比 attackSkillId、canAttack、每条解放的技能／几率／canUse、真正开始的行动技能、解放取数次数。

## 改了的原沙僧核心文件（待交叉核查点名）

- `battle_logic.gd`：新函数 `weapon_unleash`；`execute` 在 `XStateEffects.run("action_start", u)` 之后加一行 `skill = weapon_unleash(u, skill)`。
- `battler.gd`：新函数 `weapon_unleash_objects`、`weapon_unleashes`、`weapon_unleash_of`。
- `actor.gd`：新函数 `weapon_unleash_objects`（覆盖）。
- 另改：`enemy.gd`（`weapon_unleash_objects` 覆盖）；探针 `weapon_unleash_probe.cjs`；`同步正式西游.py`、`oracle_additions.py` 各加一行登记；专项 `xiyou_weapon_unleash.gd`／`.tscn`。

## 没做（原版有、正式数据没用到）

- Guard Unleash（防御换技能）、加成标签 `<Weapon Unleash: ±x%>`／`<Weapon Unleash 技能: ±x%>`、`<Custom Weapon Unleash>` 自定义几率、标签里写技能名（不写号）。
- 混乱：重制没有混乱行动，原版混乱时 setAttack 后同样会解放；等混乱实现时它走 execute 就自动带上。

## 遗留

1. **外层 startAction 包装看到的是换之前的技能**：原版 Codex 运行时的 startAction 包装在 WUL 之外，执行时 `action.item()` 还是普攻。查过各包装：按技能号分支的只有敌人专用（异化瘟疫、导入平衡巨龙蓄息）和云裳专属技能，与这些武器的普攻／解放技能没有交集；其余只存行动引用、之后才读（读到的是换后的）。重制 `XRaceBattle.begin`／`XAlienBattle.begin` 拿的是换后的技能，与原版读取时机一致。没为此单独补探针。
2. **SkillChangeTo（TorigoyaMZ_SkillChangeTo）重制完全没有**：67 个技能带 `<ChangeTo[id]: 条件>`（多为 Math.random 几率换成别的技能），在 startAction 里比 WUL 更早执行。与本期无交集（普攻 1、308、637 与这些武器的解放技能都不带 ChangeTo），但它本身是一个缺失功能，建议另派。
3. 探针里 startAction 链另有 2 次 Math.random（不是 WUL 的；探针回 0.5 并记 `otherRolls`，专项不比）。

## 交接板

- 下一步：遗留 2 SkillChangeTo（另派，规则车道）。
- 用户试玩说明：装渔人枪、狼爪、魔法之剑、名刀月隐／烦恼风、灭却、鹰角长弓、霸王丸等武器时，普通攻击有几率直接放出武器的专属技能（会付这个技能的 TP，TP 不够的那条不会出）。
- 需要用户决定：无

## 进度账

- 战斗规则：YEP_WeaponUnleash 武器解放补齐（正式数据用到的部分）。

## 可优化（流程／工具／效率）

- **共用槽饥饿**：本期专项单个场景在 `并行测试.py` 排队 1.5 小时没拿到槽——主工作区全量检查（一个进程）连续占满 4 个槽，释放后立刻被它自己的下一个场景拿走，别的工作树排不进去。建议共用槽按先来先得（排队票号）或给单场景请求留 1 个槽。归工具车道。

## 验证

- RED：探针与专项先提交、battle_logic 未接时直接跑 `xiyou_weapon_unleash`：834/950，失败只在 `rolls`（68）与 `started`（48）——摆法、等级、装备、attackSkillId、canAttack、每条 canUse、TP 全对上；接上后 GREEN 950/950。
- 夹具差异：154／166 是超强者，重制 `enforce_party` 未开超强时把他们踢出出战（原版探针直接 addActor）；专项开超强开关 2494 后对上，不影响解放逻辑。
- 选测（`并行测试.py --log-dir`，42 场景全过、无偶发，用时 4682 秒）：`xiyou_weapon_unleash`、`xiyou_attack_query`、`xiyou_rules` 全 24 段、`xiyou_smart_ai`＋`_b`／`_c`／`_d`、`xiyou_hangup`／`_auto`／`_options`、`xiyou_troop_events`／`_b`／`_half`、`xiyou_battle_events`、`xiyou_determinism`、`xiyou_random_streams`、`xiyou_otb`、`xiyou_combat`、`xiyou_review_regressions`。
- **战斗参照**：xiyou_rules 24 段、troop_events_half 结果不变（场景里没有带解放武器的角色，新取数不进它们的 rule 流），参照不需要重测。
- 选测跑时 main（5c850de1）的 `item_marks.gd` 有重复函数编译不过，我在工作区临时删掉 357 行那份跑的（已报唐僧）；唐僧在 main 修的是同一份，合 main 前已撤掉临时改动，合进来只有这处去重和文档，选测结论不受影响。
- 合 main：80212635（无冲突，没带进切片／转换器／探针改动）。
- 同步 `同步正式西游.py --accept-additions`：只跑新探针 weapon_unleash_probe（executed 1、reused 59），测量不变，产物指纹已留。

## 本分支提交

- 9a68e3c7 WIP：探针、专项、来源列表
- c0a590cd 接 battle_logic
- 合 main（80212635）
- （本提交）交付单

可合并
