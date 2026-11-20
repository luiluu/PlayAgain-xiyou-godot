# 交付：luiluu/cc-t293-dmg-hook-cache

- 车道／工作者：T293 战斗提速·三个天启伤害钩子／cc 车道（Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T293·未经审查】战斗提速：天启伤害钩子 is_attack 用到才问＋普攻号只读窗口记忆（dev.待定）

- 依据：T282 交付单性能一节（三个天启伤害钩子各约 0.6 ms）。本单先量再改，量出来慢处不在钩子自己，见下面「量出来的」。
- `XTianqiQiyinEffects`／`XTianqiAffixBattle`／`XTianqiTrumpet` 的 `damage_ops`：是不是普攻（`is_attack`）只在用得到时才问——七印只有穿了「范围技增伤／技能增伤／封技普攻增伤」三条之一才问，词条只有带「技能伤害」才问，号卷只有学了一号才问；用不到时那几项本来就是 0，乘区一样。三个开关各自 `LAZY_ATTACK`（默认开）。
- `XBattler.attack_skill_id`：角色在只读窗口（O-348）里同一代只查一次（记进 `XActor._read_memo`，键 `ra0／ra1` 带小猫剑圣空手标记）；换代即丢。换代来源照实：加减状态、clear_states、param_mark_dirty、学／忘技能、HP／MP／TP 写入、公式帧进出；换装走 `XEquipment.preview`（read_touch）、`XEquipment.change`（末尾写 hp／mp）、`init_equips`／`release_unequippable`（卸了东西时）／`release_to_party`。`refresh_passive` 本身不换代；直接改 `equips[]` 又不走这些路径的不换代（和已有的技能表、特性表窗口记忆同一前提）。甚尔形态、宿傩、屠苏武具态这些角色自己的包装在 `XActor.attack_skill_id` 里、不进记忆，照旧每次现算；窗口外、敌人照旧即时查。开关 `XBattler.ATTACK_ID_MEMO`（默认开）；`XIYOU_READ_VERIFY=1` 时每次命中重算比对。
- 结果不变：新专项开关全开／全关，钩子输出逐项相同，天启篇与西游档整场同种子逐位相同。
- 玩家可见：无（只提速）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/battler.gd` `XBattler.ATTACK_ID_MEMO`；`core/tianqi_qiyin_effects.gd`、`core/tianqi_affix_battle.gd`、`core/tianqi_trumpet.gd` 各自的 `LAZY_ATTACK` | 普攻号（`<Replace Attack>`）每次即时逐个状态／装备／技能／职业／角色备注按整串查表，一次约 70～100 µs（冷窗口里还要先算技能表，约 600 µs）；三个天启伤害钩子每段伤害都各问一次 | 普攻号在只读窗口里按角色记一次，换代即丢；三个钩子只在用得到时才问 | T293 战斗提速：窗口里三个钩子合计约 400 µs → 约 90 µs，一次 capture 约 450 → 200 µs；结果逐位不变 | `XBattler.ATTACK_ID_MEMO = false`；`XTianqiQiyinEffects.LAZY_ATTACK = false`、`XTianqiAffixBattle.LAZY_ATTACK = false`、`XTianqiTrumpet.LAZY_ATTACK = false` | cc（T293） | 保留 |

## 量出来的（验收 1、4）

本机 M1 Pro 无头，`--audio-driver Dummy`。夹具：天启篇炼狱 4 人（1 逍遥、100 云霄、131 立希、107 钟离，学全部重构技、60 级）打敌群 394（5 个），每人穿一印全套 5 件＋真印武器、每件带词条、学了一二四号号卷。数字是专项 `xiyou_tianqi_dmg_hook_lazy` 第四段的 PERF 行（两次跑取的典型值）。

### 三个钩子慢在哪

| 调用（窗口里，A→E 一次技能伤害） | 关（原样） | 开 |
| --- | --- | --- |
| 七印 `damage_ops` | 120～175 µs | 约 40 µs |
| 词条 `damage_ops` | 105～120 µs | 约 33 µs |
| 号卷 `damage_ops` | 85～100 µs | 约 18 µs |
| `XActorDamageHooks.capture`（24 段） | 约 450 µs | 约 200 µs |

- 三个钩子各自的逻辑只有几到几十 µs（`effects`、`view`、号卷持有人表都早已按人缓存）。每个钩子里七八成的时间是同一处：各问一次 `a.is_attack(item)` → `attack_skill_id()` → 逐个状态／装备／技能／职业／角色的备注按**整串字符串**查 `_replace_attack_cache`（长备注每次都要算哈希），窗口里一次约 70～100 µs。
- T282 量到的「各约 0.6 ms」是冷窗口：谁先读技能表谁替大家付 `skills()` 冷算（约 550 µs）。真出手时就算钩子不读，后面读攻击力也照样要付这一笔（冷窗口里 `a.atk` 约 800～1000 µs），所以这一笔不该算在钩子头上。
- 敌人打我方（E→A）三个钩子本来就只要 3～30 µs，没动。
- **没加缓存**（验收 2 不做，协调同意）：钩子剩下的几十 µs 键要带双方 HP 比例、本次第几段、回合、减益层数，签名错一点就是伤害算错，收益约 2%，不划算。

### calculate 和自动选招（开关前后）

| 项 | 关 | 开 |
| --- | --- | --- |
| `XDamage.calculate`（带 rawValue，外面包一个窗口） | 约 3.5～4.1 ms | 约 3.5 ms |
| `XDamage.calculate`（每次新窗口） | 约 3.5～3.9 ms | 约 3.3～3.5 ms |
| 4v5 一次 `XSmartAI.choose`（main 上的卡 1 路径，平均／最慢） | 70 ms／176 ms | 74 ms／148 ms（误差范围内，没变快） |

- calculate 基本没变快，原因是下面这条：calculate 进门 `XAlienBattle.push_formula`、出门 `pop_formula` 都 `XActor.read_touch()`，**每次 calculate 都把只读窗口整个作废**，所以哪怕外面包了窗口（智能选招 O-392 就包了），每段伤害照样从冷开始重算技能表、能力值、被动。本单省下的 is_attack 只在同一次 calculate 里第二次以后的读取上见效。

### calculate 剩下的时间去了哪（验收 4，协调要求量清）

临时在 `damage.gd` 里插计时点量的（只本地量，已还原，没提交）。一次 calculate（带 rawValue）约 2.3 ms（不穿装）／3.5 ms（穿满）：

| 段 | 不穿装 | 穿满 | 主要是什么 |
| --- | --- | --- | --- |
| `capture_facts`（含 24 段模块钩子） | 约 240 µs | 约 1540 µs | 冷窗口里第一个读技能表／生命上限的人付冷算（穿满时词条钩子读 `mhp` 触发） |
| 公式值之后、取双方攻防（`a.atk`、`b.def`、`a.mat`、`b.mdf`） | 约 1070 µs | 约 780 µs | 冷窗口里角色能力值链（被动、装备、状态全套）；谁先读谁付，和上一行此消彼长 |
| 种族、套装确认、live 归池、九线封顶 | 约 330 µs | 约 390 µs | `_race_factors` 单独约 150～175 µs |
| `dispatch`（注册表跑 7 个钩子，每个钩子帧深拷贝三次＋冻结） | 约 250 µs | 约 300 µs | `module_registry.gd` |
| 元素候选逐行（抗性、独立乘区、总账明细） | 约 100 µs | 约 150 µs | |
| 其余（档位、烙印、暴击加成、熟练度、审计） | 约 200 µs | 约 230 µs | |

- 结论：calculate 的大头是**每次冷窗口的整套重算**（约 1.3～2.3 ms），不是三个钩子。
- 试过（只量、已还原）：把 `push_formula`／`pop_formula` 的两处 `read_touch` 去掉，外面包窗口的 calculate 3.5 → 1.3 ms，4v5 选招 70 → 53 ms。正确性没验（逆骨公式帧确实会改能力值读法），所以只写成建议，见「可优化」。

## 验证（验收 3、5）

- 新专项 `xiyou_tianqi_dmg_hook_lazy` 30/30（返修后，`XIYOU_READ_VERIFY=1`）（本机约 25～50 秒）：
  1. 每一印（全套＋真印武器）× 带词条（终伤、技能伤、元素伤、背水、先声、减伤、磐石、猎首）× 号卷一二四五六号，4 角色 × 5 敌人 × 各伤害／治疗技＋普攻、敌打我，窗口里／窗口外，开关全开／全关的三个钩子输出逐项相同（浮点按 17 位有效数字比）；七印跟普攻有关的那一支（need_kind 为真）有覆盖。
  2. 普攻号记忆：替换普攻武器 1109→1004、状态 66→562、五条悟角色备注；窗口里第二次命中记忆且等于即时查；窗口没关时加状态、去状态当场换代读到新值；换武器先热一次记忆（1004），再走正式 `XEquipment.preview`：本体记忆作废、预览克隆读到新值（Neon 核查 P2-1 返修，原来裸改 equips[0]＋refresh_passive 是假过）；开关关掉不记。
  3. 整场同种子：天启篇 4v5（穿七印＋词条＋号卷、一人拿替换普攻武器、第 2 回合给一人挂替换普攻状态，敌人血量照常、真打 5 回合）和西游档（替换普攻武器＋第 2 回合挂状态，4 回合），开关全开与全关的每回合日志、HP／MP／TP／状态／护盾、随机流快照逐位相同；全开再跑一次也相同。这几回合是真实自动行动（多段技、七印印记／疫、号卷、词条照常结算），但**没有逐一确认每种机制在这 5 回合里都触发了**；命运骰没有专门布置（只比了随机流快照）。逐项覆盖靠第 1 条钩子逐项比对和云端选测里各机制自己的专项。
  4. 性能 PERF 行（上表），钩子合计开着不比关着慢（粗上限）。
- 本机 `XIYOU_READ_VERIFY=1`（记忆每次命中都重算比对，不一致当场崩）：xiyou_tianqi_dmg_hook_lazy、xiyou_replace_attack_motion、xiyou_shana_zhuanwu_attack、xiyou_gojo、xiyou_tianqi_smart_ai、xiyou_smart_ai、xiyou_tianqi_qiyin_effects、xiyou_tianqi_affix_battle、xiyou_tianqi_trumpet、xiyou_toji_battle、xiyou_tusu_battle 11/11 过。
- 云端选测 786f5944d6（`选测.py` 选中的 222 个场景、16 片，含 xiyou_determinism、xiyou_smart_ai*、xiyou_rules 全部段、事件对照、替换普攻／武器解放／五条悟／甚尔／屠苏）：通过；偶发 1 个 xiyou_tianqi_followup_kill（并行失败、云端单跑过，本机再单跑也过），我猜是并行负载，不像本单（它不读普攻号以外的东西，开关前后整场一致）。
- `工具回归.py` 全部通过。
- `语法检查.py` 1094 个 .gd 0 问题。
- 合并请带 `--oracle`（改了 battler.gd 普攻号）。

## 改了哪些核心文件（请核查方重点看）

- `modes/xiyou/core/battler.gd`：`attack_skill_id` 拆成外壳（窗口记忆）＋`_attack_skill_id_now`（原逻辑逐字不变）；新开关 `ATTACK_ID_MEMO`。依赖的前提和已有的 `skills()`／`all_traits` 窗口记忆相同：窗口里改装备、状态要走会换代的路径（来源见变更记录草稿）。
- 三个钩子文件只动 `damage_ops` 里 `is_attack` 的取法和顶上的开关。

## 核查返修（Neon 核 P1×0）

- P2-1 已改：`memo_equip_change_gen` 原来前面 b 增删状态已清了全局记忆、裸改 equips[0]＋refresh_passive 本身不换代，是假过；改成先热 `a.attack_skill_id()`（断言记忆里有 1004），再走 `XEquipment.preview`，断言本体记忆被作废、预览克隆读到新值。没用 `XEquipment.change`：它在窗口里调会让**已有的**特性表记忆读到旧值（先换装备、后 `release_unequippable` 读特性，中间没换代），`XIYOU_READ_VERIFY=1` 当场崩在 all_traits，与本单无关，记成下面的建议。
- P2-2 已改：`battler.gd` 注释与本单草稿不再说「刷新被动换代」，照实列换代来源。
- P3：Neon 的 P3 原文没随返修派单转来，未逐条写入；待协调转原文后补（不改代码）。

## 交接板

- 下一步：无（本单做完）。
- 用户试玩说明：无可见变化。
- 需要用户决定：无。

## 进度账

- 无（性能优化，不涉完成度）。

## 可优化（流程／工具／效率）

- 已做：普攻号窗口记忆、三个钩子 is_attack 用到才问（回退见优化登记）。
- 建议（收益最大，战斗核心车道，Opus＋medium）：`XAlienBattle.push_formula／pop_formula` 每次 calculate 进出都 `read_touch` 整窗作废，改成只在这一帧真会改能力值读法时（逆骨类：`_formula_frames` 里 physical／逆骨技能、或双方有逆骨词条）才作废。实测外面包窗口的 calculate 3.5 → 1.3 ms、4v5 自动选招 70 → 53 ms；真出手每段伤害也受益（同一行动多段时）。要配 `XIYOU_READ_VERIFY=1` 整轮。
- 建议：`XBattler._replace_attack_raw` 按整串备注做键，长备注每次算哈希；窗口外（敌人、UI）照样慢。可改成按记录（表名＋id）键或预扫一次。归同一车道。
- 建议（P3 级，战斗核心／装备车道）：`XEquipment.change` 先 `equips[slot]=item` 再 `release_unequippable()` 读特性，中间没 read_touch；在只读窗口里调（现在正式流程没有）会读到旧特性表。可在赋值后补一句 `XActor.read_touch()`。
- 建议：`XDamage._race_factors` 一次约 150～175 µs、`XModuleRegistry.dispatch` 每个钩子帧深拷贝三次（约 250～300 µs），等 T282 合并后可在 damage.gd／module_registry.gd 里各省一截。
- 建议：T282 交付单「各钩子 0.6 ms」的量法是每次冷窗口，会把技能表冷算记到第一个读者头上；以后量钩子单项请在同一个窗口里量，或明说冷／热。

## 本分支提交

- 786f5944d T293：天启伤害钩子 is_attack 用到才问（三个 LAZY_ATTACK）＋普攻号只读窗口记忆（XBattler.ATTACK_ID_MEMO）；专项 xiyou_tianqi_dmg_hook_lazy
