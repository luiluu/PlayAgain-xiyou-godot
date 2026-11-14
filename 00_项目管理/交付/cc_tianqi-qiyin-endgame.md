# 交付：cc/tianqi-qiyin-endgame

- 车道／工作者：C 规则·机制／cc（七印终局收口，Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【cc·七印终局·未经审查】七印终局收口：掉率接加成、神器保底防重、书卷代价与豁免、默印技能、随机流存档派生、再动间隔（dev.待定）

- 依据：小A《天启篇_内容与设计全面评审 v0.1》第二节 P1 第 3、4 条、第三节第 6 点，Kyo 11-14 拍板；经济返修车道盘出的七印随机种子问题。六项各带回退开关（O-待定-1～6），只认天启篇存档。
- 掉率：七印里副本 Boss 的套装件、毕业武器几率乘全队掉率加成，和常规掉落同一套（`XTianqiDrop.party_mult`：技能、套装、号卷、寻宝猎人、亡魂汲取、词条「物品掉落」相加后 合计×200÷(合计＋200)，最高逼近 3 倍）；基础掉率一律不抬；真印、神器、龙隙不吃。
- 神器：里副本 Boss 和七首之龙共用一个存档计数（`flags.tianqi.qiyin.artifact_miss`），连着没出 332 次、第 333 次必出，出了清零；只从本档还没有的神器里出（印库没领的、领过的、背包和身上的都算有），五件齐了不再掷也不再计；老档缺字段补 0。
- 七印书卷：揭开的规则佩戴者自己也受（其余队友不受），七条逐条处理见交付单「书卷逐条」；战斗里有天启四骑士（本体、影子、生存战）或 34 层鸿钧时不揭、不付代价，开场说一句。代价文案改成真实代价。
- 默印 5 件：附带技能「万籁俱寂」分配技能号 10777（天启篇表外号段，按 6065 复制），穿满 5 件才出现在战斗技能列表，放了敌方全体沉默 1 回合、我方下一回合技能不耗魔法和 TP，每场 1 次。
- 随机流：祭坛、七首之龙、首杀招募候选的随机数改由存档派生（种子由 `orb_seed` 派生，存档里记已开的条数），读档后同样的操作掷出同样的结果，不能读档重掷。
- 异化词条「再动」间隔四级改 6／5／3／2（原 5／3／3／2，蚀骨和化形一样），文案按级写明。
- `battle_logic.gd` 只加一行钩子（`battle_skills` 里列出万籁俱寂）。
- 玩家可见：天启篇七印里副本掉套装件、毕业武器吃掉率加成；神器最多刷 333 次必出、不出重复；七印书卷揭开的规则自己也受，打骑士和登顶首领时书卷不揭；默印 5 件多一个技能「万籁俱寂」；读档不能重刷七印掉落；异化「再动」侵染 6 回合、蚀骨 5 回合一次。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi_qiyin.gd` `XTianqiQiyin.DROP_BONUS`、`drop_mult` | 七印掉率写死 1.0，不吃任何掉率加成 | 套装件、毕业武器几率乘 `XTianqiDrop.party_mult`（同常规掉落的相加递减）；基础掉率不动 | 评审 v0.1 P1 第 3 条；Kyo 11-14「接上，但掉率要非常低」 | `XTianqiQiyin.DROP_BONUS = false` | 小A | 保留 |
| O-待定-2 | `tianqi_qiyin.gd` `XTianqiQiyin.ARTIFACT_PITY`、`roll_artifact`；`tianqi_qiyin_drop.gd`、`tianqi_qiyin_dragon.gd`（`with_artifact` 参数）；`tianqi_qiyin_dragon_run.gd`；`qiyin_drop.json` `artifact.pity_after` | 神器 0.1%／3%，没有保底、可重复 | 里副本和七首之龙共用计数，第 333 次必出、出了清零；只从没有的里出，五件齐了不掷不计 | 评审 v0.1 第三节第 6 点；Kyo 11-14 | `XTianqiQiyin.ARTIFACT_PITY = false` | 小A | 保留 |
| O-待定-3 | `modes/xiyou/core/tianqi_qiyin_rule.gd` `XTianqiQiyinRule.SCROLL_COST`、`SCROLL_BOSS_EXEMPT`；`tianqi_qiyin_effects.gd` start；`qiyin_gear.json` 书卷 costs | 七印书卷零代价、对所有战斗（含骑士、34～36 层首领）生效 | 揭开的规则佩戴者自己也受；有天启四骑士或 34 层鸿钧的战斗不揭 | 评审 v0.1 P1 第 4 条；Kyo 11-14 | `XTianqiQiyinRule.SCROLL_COST = false`、`XTianqiQiyinRule.SCROLL_BOSS_EXEMPT = false` | 小A | 保留 |
| O-待定-4 | `tianqi_qiyin_effects.gd` `XTianqiQiyinEffects.SILENCE_SKILL`、`TUNE.silence_skill_id`；`skill_rework.json` 10777；`battle/battle_logic.gd` battle_skills 一行 | 默印 5 件附带技能号 0，技能出不来 | 分配 10777「万籁俱寂」，穿满 5 件列出、放了 use_silence_all、每场 1 次 | 评审 v0.1 P1 第 4 条 | `XTianqiQiyinEffects.SILENCE_SKILL = false` | 小A | 保留 |
| O-待定-5 | `tianqi_qiyin.gd` `XTianqiQiyin.SEED_FROM_SAVE`、`save_rng`、`next_seed`；`tianqi_qiyin_dragon_run.gd` `_rng`、`recruit_offer`；`tianqi_qiyin_equip.gd` 兑换一处 | 七印祭坛、七首之龙每次 `fresh_seed`，读档可重掷 | 种子由 `orb_seed` 派生＋存档里的条数计数，读档掷出一样 | 经济返修车道同类盘点（`tianqi_qiyin.gd:63`、`tianqi_qiyin_dragon_run.gd:65`、`:265`） | `XTianqiQiyin.SEED_FROM_SAVE = false` | cc | 保留 |
| O-待定-6 | `modes/xiyou/core/tianqi_alien_affix.gd` `XTianqiAlienAffix.AGAIN_EVERY_V2`；`alien_gear.json` `again.every` | 再动间隔 5／3／3／2（蚀骨、化形一样） | 6／5／3／2，文案按级写 | 评审 v0.1 P1 第 6 条；Kyo 授权优化（原为避 4 定的 3、3） | `XTianqiAlienAffix.AGAIN_EVERY_V2 = false` | 小A | 保留 |

## 满词条时各类七印掉落的最终概率（给数值线）

倍率＝1＋有效加成，有效加成＝合计×200÷(合计＋200)（`XTianqiDrop.effective`）。「满词条」按上场 5 人（含助力位）×12 格各一条极品「物品掉落」6% ＝ 合计 +360% 估（未算技能、套装、号卷、寻宝猎人 +30、亡魂汲取 +20；全算上也到不了 3 倍）。

| 项目 | 无加成 ×1.00 | 合计 +100%（×1.67） | 满词条 +360%（×2.29） | 理论上限（逼近 ×3） |
| --- | --- | --- | --- | --- |
| 套装件：Boss 首掷（没空过，5%） | 5.0% | 8.3% | 11.4% | 15.0% |
| 套装件：连空 19 次后那一掷（43%） | 43.0% | 71.7% | 98.3% | 100% |
| 套装件：平均几场掉一次（含递增和 21 场暗保底） | 7.3 | 5.4 | 4.4 | 3.7 |
| 套装件：躁动印首掷（×2） | 10.0% | 16.7% | 22.9% | 30.0% |
| 毕业武器 寻常 3%（平均场数，20 次保底） | 3.0%（15.8） | 5.0%（13.2） | 6.9%（11.3） | 9.0%（9.6） |
| 毕业武器 艰险 5% | 5.0%（13.2） | 8.3%（10.1） | 11.4%（8.1） | 15.0%（6.4） |
| 毕业武器 九死 6% | 6.0%（12.1） | 10.0%（8.9） | 13.7%（7.0） | 18.0%（5.5） |
| 毕业武器 炼狱 8% | 8.0%（10.3） | 13.3%（7.1） | 18.3%（5.4） | 24.0%（4.2） |
| 毕业武器 证道 10% | 10.0%（8.9） | 16.7%（5.9） | 22.9%（4.4） | 30.0%（3.3） |
| 献一把本印武器（武器几率 ×2，在上面基础上再乘） | 见上 ×2 | 见上 ×2 | 见上 ×2 | 封顶 100% |
| 真印（每件单独掷，5%～30% 按难度，30 件暗保底） | 不吃加成 | 不变 | 不变 | 不变 |
| 神器：里副本 Boss 0.1%（共用 333 次保底） | 0.1% | 不变 | 不变 | 不变 |
| 神器：七首之龙 3%（共用保底） | 3% | 不变 | 不变 | 不变 |
| 龙隙出现 3%～10%（30 次暗保底） | 不吃加成 | 不变 | 不变 | 不变 |
| 精英印屑 33% | 不吃加成 | 不变 | 不变 | 不变 |

说明：只打里副本 Boss 时神器平均约 283 场出第一件（0.1% 叠 333 保底，第 333 场前自然出的约 28%）；`roll_field`（31～35 层野外精英 0.5%、守护者 3% 掉套装件）表里写了吃加成，但流程里还没接（原样，没动）。数值线要压低时，最直接的旋钮是 `qiyin_drop.json` 的 `boss_set.base／step`、`boss_weapon.chance`，或给七印另设一个加成折算（现在和常规掉落共用曲线，没有单独的系数）。

## 书卷逐条（揭开的规则落在佩戴者自己身上）

佩戴者＝本场生效那件神器的主人（出战顺序里第一个戴神器的人）；其余队友一概不受。

| 印·规则 | 对佩戴者 | 有没有意义／会不会卡死 | 处理 |
| --- | --- | --- | --- |
| 白·不愈 | 佩戴者身上的减益（含能力值减益）不到期，只能驱散 | 有意义；不卡死（能驱散、减益本身不阻止行动以外） | 照规则 |
| 红·杀声 | 打在佩戴者身上的伤害按全场倒下数 +5%／个 | 有意义 | 照规则 |
| 黑·限时 | 佩戴者魔法、TP 不自然恢复；技能数佩戴者自己单算每回合 5 个（敌方合计另算） | 单人一回合放满 5 个技能基本碰不到，实际代价是不回蓝；不卡死（普攻、防御、物品不算） | 单算计数，不和敌方共用（共用会被敌人用光，变成封技能） |
| 灰·魔塔 | 佩戴者不能暴击 | 有意义 | 照规则；宝石只在里副本有，书卷不给 |
| 殉·献祭 | 每回合开始佩戴者失去 10% 当前生命（不致死），不给加伤 | 原规则是「全场生命最高那个」，和敌人比生命佩戴者几乎轮不到，等于没代价 | 改成佩戴者单独每回合扣一次；敌方最高那只照扣，敌我都不加伤 |
| 震·星坠 | 每 3 回合佩戴者失去当前生命 33%（不致死） | 有意义 | 照规则 |
| 默·寂静 | 双数回合佩戴者只能普攻、防御、用物品 | 有意义；不卡死（普攻、防御能用；自动战斗照常选普攻） | 照规则 |

没有会卡死或完全没意义的条目；献祭、限时两条改了落法（见上）。豁免：战斗里有天启四骑士（本体、影子、生存战，`XTianqiHorsemen.active`）、34 层鸿钧（`_ref == "hongjun"`）或正在登 34～36 层（`XTianqiSummit._at`）时，书卷不掷、不揭、不付代价，开场战斗日志说「七印书卷沉寂了：天启的骑士与登顶之战面前，七印不肯揭开。」35、36 层首领就是骑士的影子和本体，已被骑士判定覆盖；大厅「再挑战」34～36 层走同一套 prepare，同样豁免。

## 核查返修

gpt 静态核五个提交：保底、种子、掉率、默印没发现问题；2 项 P2 返修，另补 2 处验证（协调派单）。

| 问题 | 修法 | 测试（断言） |
| --- | --- | --- |
| P2 `tianqi_qiyin_rule.gd` 星坠只扫 `logic.actors`：佩戴者被天启换人换到助力位后不付 33% 代价 | 协调定口径「代价跟着佩戴者走」：星坠照献祭的写法，场上和敌方按原规则扫（排除佩戴者），佩戴者只要活着单独扣一次，在场上还是在助力位都一样；佩戴者阵亡后代价停，揭开的规则对敌方照旧 | `xiyou_tianqi_qiyin_endgame`：`cost_star_bench`（第 3 回合前换到助力位仍扣 33%、敌方照挨）、`cost_sacrifice_bench`、`cost_dead_stops`；反向验证「星坠只扫场上」「死了也扣」都咬住 |
| P2 `tianqi_alien_affix.gd`／`alien_gear.json` 再动：开关关掉只改行为，文案还是 6／5／3／2 | 新增 `XTianqiAlienAffix.again_every(级)`／`again_every_all()`，行为和文案同一个来源；`alien_gear.json` 的 benefit 写成 `{every}` 占位，`XTianqiAlienGear.affix_view` 按实际间隔填 | `xiyou_tianqi_alien_affix`：`again_text_follows`（开着 6／5／3／2、关掉 5／3／3／2、不留占位）；反向验证咬住 |
| 补验证 a：完整磁盘存读档 | 只补测试 | `seed_disk_roundtrip`：`XSave.save(1)` 写盘、`load_slot(1)` 读回新的 XState，orb_seed、qiyin.seed、rng_n、artifact_miss（217）、artifacts／artifacts_got 都在，读回后下一次掷数和存档后不读档时一样，已得神器不在池子里 |
| 补验证 b：技能号 10777 冲突核对 | 只核对 | 冻结正式源 `app.nw/data/Skills.json` 共 10634 条、最大号 10633，没有 10777；转换产物 Skills.json 同（10633）；天启篇表外号段 skill_rework.json `new_skills` 41 个（10701～10777），10777 只出现一次；`new_states` 从 10801 起（状态表，不同表）；五条悟 10634～10650；`modes/` 全部 .gd／.json 和 tests 里只有本车道三处用到 10777；本机 31 个分支 `git grep` 都没有别处占用 10777。结论：无冲突 |

书卷「佩戴者在助力位」逐条落点（补进上面「书卷逐条」）：星坠、献祭照扣（活着就付）；不愈、魔塔、寂静、限时、杀声只在他行动、被打、状态走回合时才有落点，人在助力位不行动、不挨打、状态不走回合，等于暂停，换回场上接着生效；佩戴者阵亡后代价全停，收益（敌方那份）照旧。

## 交接板

- 下一步：gpt 甲档核（存档字段、随机流、战斗规则）。
- 用户试玩说明：天启篇存档里——七印里副本 Boss 掉套装件、毕业武器吃掉率加成（加成大时能看出来，平时变化很小）；戴七印书卷进普通战斗，揭开的规则自己也受（比如星坠时自己也掉三成血、寂静回合只能普攻）；戴书卷打天启骑士、鸿钧时开场提示书卷沉寂、不揭规则；默印穿满 5 件，战斗技能里多一个「万籁俱寂」，每场能放 1 次；存档后进里副本，读档再进同样操作掉的东西一样；异化「再动」侵染第 6、12 回合、蚀骨第 5、10 回合多动一次。
- 需要用户决定：
  1. 神器吃不吃掉率加成：现照设计稿不吃（已有 333 次保底），要吃就把 `roll_artifact` 的 chance 乘 `drop_mult`。默认不吃，继续。
  2. 「已拥有」怎么算：现认本档拿到过的（印库、领过、背包、身上），神器卖掉／分解后也不会再掉回来。要「现在手上没有就能再掉」的话改 `owned_artifacts` 只看背包和身上。默认按拿到过算。
  3. 书卷豁免名单：现只认四骑士（本体、影子、生存战）和 34 层鸿钧；31～33 层守层者、七首之龙不豁免（七首之龙自带七段规则，书卷本来就不叠）。默认如此。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：本车道开工的 `新建工作树.sh --补齐` 跑起了整份事件状态探针（4 段并行，22 分钟 0/4 段完成），占满 4 个共用测试槽、挡住本车道和别的车道的测试；本车道不改切片、转换器、探针，手动停掉了自己那一份（只停本工作树的进程）。
- 建议：`--补齐` 在分支相对 main 没有改切片、转换器、探针时跳过事件状态探针（或只做增量），归工具车道；预计每次开车道省 20 分钟以上、少占 4 槽。

## 验证

- 语法检查：840 个 .gd，0 个问题。工具回归：全部通过（104 秒）。
- 专项（本机）：`xiyou_tianqi_qiyin_endgame` 58/58（新）、`xiyou_tianqi_alien_affix`、`xiyou_tianqi_alien_gear`、`xiyou_tianqi_qiyin_*`（altar、art、dragon、dragon_run、drop、effects、equip、gear）、`xiyou_tianqi_skills`、`xiyou_fabao_rework`、`xiyou_tianqi_affix_battle`、`xiyou_tianqi_drop`、`xiyou_determinism`，共 16 个场景全部通过。
- 选测：`选测.py main` 结论整轮（`battle_logic.gd` 改动＋`skill_rework.json` 找不到引用测试），走云端（提交 c77712a72，583 个场景 16 片，运行 43580647343）：582 个通过；`xiyou_flow` 一个失败（云端重跑仍失败），断言是 `alt_enter_not_map_action`（Alt＋Enter 不算地图动作的按键映射），和七印无关；同一提交本机单跑 `xiyou_flow` 通过（13 秒）。请总装合并时留意是不是云端环境的按键问题。
- 反向验证（`反向验证.py`，12 处故意改坏全部咬住）：保底差一次、防重失效、掉率不接加成、随机流计数不前进、随机流回到现开、书卷代价不落佩戴者、献祭不扣佩戴者、首领不豁免、万籁俱寂不进列表、放了不生效、龙不走共用保底（`xiyou_tianqi_qiyin_endgame`）；再动回到 5／3／3／2（`xiyou_tianqi_alien_affix`）。
- 回退开关：7 个开关（DROP_BONUS、ARTIFACT_PITY、SCROLL_COST、SCROLL_BOSS_EXEMPT、SILENCE_SKILL、SEED_FROM_SAVE、AGAIN_EVERY_V2）在专项里都设成 false 断言过回退支。

## 待交叉核查

- 甲档（存档、随机流、战斗规则）：`core/tianqi_qiyin.gd`（save_rng／next_seed、progress 新字段 seed／rng_n／artifact_miss、drop_mult、roll_artifact／owned_artifacts、settle）、`core/tianqi_qiyin_dragon_run.gd`（_rng、settle 神器、recruit_offer 种子）、`core/tianqi_qiyin_rule.gd`（_hits／scroll_owner、献祭、限时单算、scroll_exempt、can_use 前置）、`core/tianqi_qiyin_effects.gd`（start 豁免、battle_skills／skill_usable／begin_action）。
- 原归 Codex 的核心文件：`battle/battle_logic.gd` 只加一行（`battle_skills` 末尾 `XTianqiQiyinEffects.battle_skills(a)`）。
- 数据：`qiyin_drop.json`（artifact.pity_after 333）、`qiyin_gear.json`（书卷文案、reveal_self）、`skill_rework.json`（10777）、`alien_gear.json`（again.every）。

## 本分支提交

- 3e5e21a6f 天启篇异化「再动」间隔四级改 6／5／3／2（O-待定-6）
- 550c55c6d 七印随机流存档派生、掉率接加成、神器保底 333＋防重（O-待定-5、1、2）
- 892518894 七印书卷真实代价＋首领豁免（O-待定-3）；默印 5 件技能接线的模块侧
- d67243c36 默印 5 件「万籁俱寂」技能号 10777；七印终局专项（O-待定-4）
- c77712a72 七印终局专项：书卷豁免的提示在开场 setup 里已取进 turn_start_logs
- 247fe9798 交付单：可合并
- （返修）见下一条提交：星坠代价跟着佩戴者走、再动文案跟开关、存读档与 10777 核对
