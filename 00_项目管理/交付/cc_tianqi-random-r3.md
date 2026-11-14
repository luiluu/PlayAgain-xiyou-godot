# 交付：cc/tianqi-random-r3

- 车道／工作者：C 规则·随机门面 R3／cc 车道（Opus＋high 先做规则核定、再实现；协调派单 task_8373eaab232f；方案见 `git show 12cd35586^:00_项目管理/交付/cc_save-rng-facade.md` 第 2.4、2.5、3.1、3.3 节与「协调批复」）
- 状态：进行中

## 规则核定：布阵阶段取了哪几次（实现前先盘，方案 3.3 风险①）

做法：实现前写了一个临时探针（不入库），在 main 代码上对天启篇档（战争／饥荒／瘟疫／死亡四线 × 3、12、25 层 × 敌群 69、30）和西游档各开一场 `XBattleLogic.setup`，读 `random.rule.journal` 按 reason 计数；再对着 `setup()` 的代码逐个调用核对 `_rule()`／`_float`／`_int`／`_mod` 和各模块自己的流。

**`setup()` 整段从 rule 流取的（全部挪到 setup 流，天启篇档按战斗键钉住）**

| reason | 谁取 | 实测次数 | 说明 |
|---|---|---|---|
| `enemy_elite` | `XEnemy.setup`（`elite_roll`） | 每个敌人 1 | 精英／神话判定（天启篇 `XTianqi.strip_myth` 去神话但照样掷） |
| `enemy_level` | `XEnemy.setup_level`（`level_roll`） | 每个敌人 1 | 敌人等级浮动 |
| `tianqi_seg.up`／`tianqi_seg.kind` | `XTianqiSegAlien.setup` | 6 层起符合段表的每只 1～2 | **按段异化挂谁、挂哪种**（批复第 2 条点名） |
| `initial_tp` | `_start_battle_effects` | 每个出战单位 1（5～7） | 初始 TP |
| `start_state`／`state_duration` | `_start_battle_effects` → 开战状态块 | 2／4～5 | 开战状态是否挂上、持续回合 |
| `alien_enemy`／`alien_encounter`／`alien_weighted`／`alien_variant` | `XAlienBattle.start` → `setup_encounter` | 本次探针 0（天启篇不出原版异化遭遇） | 走 `_rule()`，若出现同样进 setup 流 |
| `qiyin_scroll` | `XTianqiQiyinEffects.start` | 本次探针 0（要穿七印神器） | 七印书卷揭哪条规则 |
| `demon_crown.roll` | `XDemonCrown.begin` | 本次探针 0（要穿魔冠） | 魔冠掉落战斗开战掷点 |
| `XZhenqi.troop_setup` | 真气瓶颈之战 | 本次探针 0 | 幻化参照守层者 |

**`setup()` 里不经 rule 的**：七首之龙、四骑士、五条悟试炼、各线预设异化（prepare 时已定，存档派生 `XTianqiQiyin.save_rng` 等）、`XRiftAlien`（西游档专用，自己的流）、元素牌组（存档种子）——本来就不随读档变，不动。宠物捕捉 `pet` 流在 `setup` 之后（`XPetCapture.roll_battle`），天启篇不掷（`XTianqiPetHide`），照旧运行时。

**`setup` 之后、照旧 rule（读档可变，批复第 2 条）**：`roll_encounter` 的 `encounter_preemptive`／`encounter_surprise`（先手／偷袭，实测 2 次）、回合内全部（暴击、命中、AI、各角色被动）。

**结算阶段从 rule 取的（方案只列了 reward 流上的 7 处，盘点多出来 6 处，一并按「打完出结果」钉住）**

| 段（`XBattleRandom.phase`） | 谁取 | 说明 |
|---|---|---|
| `grant` | `XStarburstBooks.on_victory`（`starburst.immortal`）、`gain_exp(…, _rule())` | 不朽存在掉书、升级时的资源刷新 |
| `end\|guyu` | `XGuyu.roll_stone`（`guyu_stone`，1/50） | 谷雨在队时的谷种金缮石 |
| `end` | `sync_boss_armor`、胜逃败效果（`run_unit`） | 结束时其余规则取数 |
| `end\|heartsteel`／`end\|forge`／`end\|hubris` | `XHeartsteel.clear_reward`／`XGrowthForge.award_core`／`XHubris.clear_reward` | 心之钢 10%、锻造锤 20%、狂妄 10% |

**reward 流上的 7 处（方案 2.4）**：原版掉落与删栏重抽 → `reward_for(敌人|drop)`；天启篇通用掉落 → `reward_for("tianqi_generic")`；异化装备 → `reward_for(敌人|alien)`；元素书 → `reward_for("elem_book")`；米拉 → `reward_for("mira")`；流萤残核 → `reward_for(敌人|liuying)`（方案写的是 `stable_id(e)|liuying`，照做；残核是每只倒下的标记敌人各掷一次）。招牌掉落照旧走掉落账（本来就钉住、有保底），不并进战斗键。

## 变更记录草稿

## 2026-11-14 【cc·随机门面R3·未经审查】天启篇战斗布阵／奖励按战斗键钉住，带来源键的装备底子与孔数按来源键钉住（dev.待定）

- **规则**（协调批复，Kyo 未提异议）：战斗键＝敌群号｜本档打这个敌群的第几次；开战布阵掷的算结果、一起钉住；回合内（先手、暴击、命中、AI）读档照旧可变；西游档不钉（1:1，`--oracle` 照原版）。布阵阶段取数清单见交付单「规则核定」节。
- `core/battle_random.gd`（`XBattleRandom`）：加 `pin(key, seed)`／`pinned()`／`reward_for(key)`／`rule_now()`／`sub_journals()`、`setup` 流、`phase`；钉住时快照多记 `battleKey`／`pinSeed`／`setup`／`subs`，`restore` 认这几项（坏种子拒收）。**没钉住时 `reward_for` 就是原来那条 `reward`、`rule_now` 就是 `rule`、快照不加键**，西游档逐字节不变。
- `core/tianqi_random.gd`（`XTianqiRandom`）：`BATTLE_FROM_SAVE`、`GEAR_BASE_FROM_SAVE` 两个开关（同一个 O 号）；`battle_on`／`battle_key`／`battle_random`／`note_battle`（计数 `flags.tianqi.rng["battle|敌群号"]`，随存档；`setup` 里推进，回放带快照重来也推到同一个数）；`gear_base_on`／`gear_stream`／`socket_number`／`create_gear`（带来源键的装备：底子走 `derive(orb_seed, "tq_gear_src|来源键|n")`、用一份空预掷池、孔数用 `tq_gear_socket|来源键|n` 派生的编号代替实例编号，n＝本档该来源键第几件，与 `on_register` 分配随机身份用的 n 相同）。头注释补 R3 说明。
- `battle/battle_logic.gd`：`setup` 取战斗流改经 `XTianqiRandom.battle_random`，整段 `phase = "setup"`；`_rule()` 改取 `random.rule_now()`；`drops_of`／`_roll_drops` 改 `reward_for(敌人|drop)`；`_tag_src` 给钉住本场的敌人掉落与通用掉落里的装备打来源键 `b|战斗键|敌人或 generic|第几件`，`gain_drops` 按 `_gear_src`（招牌掉落 `sig|键` 优先）入包；`grant`、`end_battle` 里按段切 `phase`（见上表）。
- `xstate.gd` `gain_gear` 生成改调 `XTianqiRandom.create_gear`（`source_hint` 的设与清挪进去）；`tianqi_affix_roll.gd` `_default_rng` 认出 `create_gear` 绑的底子流（`gear_binding`），词条仍走 `affix_src` 那一路；`orbs.gd` `layout` 加可选 `number`（代替实例编号，同一个哈希式）。
- `tianqi_alien_gear.gd`：掉落取数改 `reward_for(敌人|alien)`，钉住的本场本体带来源键 `b|战斗键|敌人|alien`（`create` 加可选 `source`）；`tianqi_drop.gd`／`tianqi_elements.gd`／`mira.gd`／`liuying.gd` 各一处改 `reward_for`。
- `battle_replay.gd`：取数记录钉住时多记 `setup` 与各子流（`_journal`）。
- 新专项 `tests/xiyou_tianqi_battle_seed`（49 条）：存→打→读→再打（布阵取数、名字即异化挂谁、整件装备、掉落全同，rule 流布阵阶段不取数，计数存档）；同档再打同一敌群换键；换击杀顺序（整件装备、各敌人掉落、各敌人掉落子流取数记录全同）；逃掉一只只少它那一份；换敌群不同、先打别的敌群这一场不变；关开关回运行时；西游档不钉、快照键不变、各取数口是原流；带来源键装备读档同、两件不同、不动共享预掷池、先拿别的来源不挪、没来源键照旧用池、关开关回运行时、深渊商人 `roll_fn` 优先；快照还原（含子流）、坏种子拒收、带快照从开战前重来布阵与计数相同、整场回放钉住不带来新的不符；掉率统计（40 个种子×2 敌群×4 场，钉住 1.80 对运行时 1.75 件／场，标准误 0.052，4 倍标准误内）。
- `tests/xiyou_tianqi_affix_seed`：`real_*` 那条 INFO 改成断言 `real_pinned_drops_equal`（真实结算入口两次读档、根不同，掉落连词条相同）；关开关的旧口径改打 INFO。
- 提交：见本分支提交
- 未完成／已知问题：天启篇档用 `XBattleReplay` 整场回放本来就对不上（关开关同样报 `replay_result_mismatch:logs`，与本单无关，见「可优化」）；心之钢、狂妄掉的那件装备掉不掉已钉住，但入包没带来源键（底子仍随运行时）；异化装备的 `attach`（异化词条）用的就是钉住的子流，没另设来源键。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
|---|---|---|---|---|---|---|---|
| O-待定 | `modes/xiyou/core/tianqi_random.gd` `XTianqiRandom.BATTLE_FROM_SAVE`（`battle_random`、`note_battle`）、`GEAR_BASE_FROM_SAVE`（`create_gear`、`gear_stream`、`socket_number`）；`modes/xiyou/core/battle_random.gd`（`pin`、`reward_for`、`rule_now`）；`battle/battle_logic.gd`（`setup`、`_rule`、`drops_of`、`_roll_drops`、`_tag_src`、`gain_drops`、`grant`、`end_battle`）；`xstate.gd` `gain_gear`；`orbs.gd` `layout`；`tianqi_alien_gear.gd`、`tianqi_drop.gd`、`tianqi_elements.gd`、`mira.gd`、`liuying.gd`；`tests/xiyou_tianqi_battle_seed.gd` | 战斗布阵（神话／精英、敌人等级、按段异化挂谁、初始 TP、开战状态）和结算（掉哪几件、异化装备、元素书、米拉、流萤残核、心钢等）都从运行时主种子派生，主种子不进存档：存档→打→不满意读档→再打就换一套；带来源键的装备（商店、事件、掉落）底子和孔数随运行时装备流和实例编号，先拿别的装备或读档都会变 | 天启篇档：布阵与结算按战斗键（敌群号｜本档打这个敌群第几次，计数随存档）钉住，结算按敌人分子流，谁先倒下不串号；回合内照旧可变。带来源键的装备底子与孔数按「来源键＋本档该来源第几件」派生。西游档不变 | Kyo 11-14 读档总原则（打完或点完就出结果的读档不变）；cc/save-rng-facade 方案 2.4、2.5，协调批复三条 | `XTianqiRandom.BATTLE_FROM_SAVE = false`（战斗回运行时流）；`XTianqiRandom.GEAR_BASE_FROM_SAVE = false`（底子、孔数回运行时） | cc | 保留 |

## 交接板

- 下一步：甲档核查 `cc/tianqi-random-r3`（碰 `battle_logic.gd`、`battle_random.gd`、`xstate.gd`，加 `--oracle`）。
- 用户试玩说明：天启篇档先存档、打一场、读档再打同一场，掉落（哪几件、词条、数值、孔数）和这场的异化、神话、开场状态都一样；想换只能再打一次这个敌群（第二次是新的掉落机会）。商店、事件拿到的装备读档再拿也一样。回合内暴击、先手照旧会变。西游档不变。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 发现：天启篇档用 `XBattleReplay` 记一场再重放，在本单之前就报 `replay_result_mismatch:logs`（关 `BATTLE_FROM_SAVE` 同样），西游档的回放（`xiyou_random_streams`、`xiyou_determinism`）正常。多半是天启篇各模块的本场状态没进回放的初始存档。只是调试工具，不影响玩家；建议随战斗门面那一单查（Opus＋medium）。
- 建议：心之钢、狂妄、锻造锤三处 `gain_gear` 不带来源键（底子仍随运行时），可在 `heartsteel.gd`／`hubris.gd` 补 `b|战斗键|heartsteel` 一类来源键（小，Sonnet＋medium，西游档不受影响）。
- 建议：`XBattleRandom.phase` 现在由 `battle_logic.gd` 手动切段；战斗门面落地时可改成 `with_phase(name, fn)` 包一层，免得新加的结束包装忘了切段。

## 验证

（待写）

## 待交叉核查

- 甲档（碰战斗核心，派单定）＋ `--oracle`：
  - 原沙僧独占核心文件：`battle/battle_logic.gd`（`_rule`、`setup` 首尾、`drops_of`、`_roll_drops`、`_gear_src`／`_tag_src`、`gain_drops`、`grant` 首尾、`_phase`、`end_battle` 三处）、`core/battle_random.gd`（全文新增部分）、`core/xstate.gd`（`gain_gear` 一行）。
  - 西游档逐字节不变的论证：`reward_for`／`rule_now` 未钉住时返回原对象、快照不加键、`_tag_src` 原样返回、`_gear_src` 退化成原式、`create_gear` 无来源键或非天启篇时与原来 `source_hint`＋`XGear.create` 同序；`orbs.gd` `layout` 默认参数不变。
  - 布阵清单是否盘全（上面「规则核定」）：特别是 `setup()` 里经 `_rule()` 但本次探针没触发的分支（原版异化遭遇、七印书卷、魔冠、真气）。
  - `create_gear` 里还原：`roll_fn` 只在原本无效时才绑，所以还原成空；`rom` 四键逐个还原；`gear_binding` 与 `_default_rng` 的配合（深渊商人自己的 `roll_fn` 照旧优先）。

## 本分支提交

- 619ecee2d WIP：随机门面 R3 实现＋专项
- （其余见 `git log main..cc/tianqi-random-r3`）
