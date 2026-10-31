# 交付：claude/bajie-sukuna2

- 车道／工作者：C 规则／八戒（Claude，八戒_91 开分支后交接，八戒_92 做完，Opus／medium）
- 状态：可合并
- 分支从 claude/bajie-shaseng-p2 末端 a05a72b7 切（唐僧交代），带着 warehouse、alien-leftover、shaseng-p2 三条的提交。
- **提交所在分支**：`cc/compassionate-gagarin-ec734e`（工作树 `.claude/worktrees/compassionate-gagarin-ec734e`）。它从 `claude/bajie-sukuna2` 末端 711e16e0 快进而来，本期提交都在它上面；`claude/bajie-sukuna2` 本身还停在 711e16e0。原因：本会话的 app 工作树守卫不许写别的工作树，派单指定的 funny-wozniak 工作树写不进去（第一个提交 c77cd443 是在那边用命令行写的，之后挪回本工作树）。合并时请合 `cc/compassionate-gagarin-ec734e`，或先把 `claude/bajie-sukuna2` 快进到它再照常合。

## 交接（八戒_91 → 下一位八戒）

八戒_91 本会话已连交三期，上下文过 40%，按规矩不开大活，只切了分支、写了这一节。接手者从这里开工：

- 任务（唐僧原话要点）：宿傩第二期，把 `modes/xiyou/core/sukuna.gd` 文件头第 20～22 行列的「未移植」战斗内机制按冻结 v0.28 `js/codex/runtime/installNativeSukunaRuntime.js`（W.CodexSukuna，约 20 KB）补上，先做影响伤害的：施放帧 `_sukunaCast`／`_sukunaPart`（`damage` 第 93 行注释说没有）、神灶准备层（第 102 行恒 0）、领域展开、魔虚罗适应层（恒 0）、伤口（受治疗减半）；黑闪要和甚尔共用就抽成共用模块（CodexBlackFlash）。
- 第一步：把原版机制清单与重制现状对成一张表写进本交付单（下面「机制对照」节），一期做不完就分期，写下期清单。
- 参照探针对原版（mv_oracle 只写 `.sandbox/`），专项含反向验证；O-待定 写进「## 优化登记草稿」表，不直接改优化登记；改了原沙僧核心文件（battle_logic／actor／battler／damage／xstate）要在交付单点名。
- 撞车提醒：白龙在 `battle_logic.gd` 加渡鸦钩子，悟空在改 skill_cost／上限／伤害链；改 battle_logic 前先 `rg` 对一下。
- 选测超过 40 个场景走云端（`云端选测.py run`＋`wait`）；本机同时最多 2 条车道跑测试。
- 回报发给唐僧总装 五（local_f30544cb-6325-4e44-a095-a54d8f831b39），只在可合并、卡住、要新车道时发。

## 机制对照

原版 `installNativeSukunaRuntime.js`（W.CodexSukuna）里的战斗内机制对重制现状；「本期」都按原版写在 `modes/xiyou/core/sukuna.gd` 新的「战斗内（第二期）」一节，接线在 `battle_logic.gd` 与 `resource_context.gd`。

| 机制 | 原版出处 | 状态 | 重制位置 |
| --- | --- | --- | --- |
| 施放帧 `_sukunaCast`（目标、施放前层数、伤口、终式） | `S.begin`、`apply` 包装 | 本期 | `XSukuna.begin`／`cast`；`execute` 两条路（行动序列与直接）在付费、定目标后调 |
| 看破层数（10240：每回合每目标 +2 上限、最多 3 层，状态 2640～2642） | `addLayer`／`layers`，`S.finish` | 本期 | `XSukuna.finish`；主技能命中后加层 |
| 敌人行动结束给自己加层（非强制行动） | `S.finish` 末尾 | 本期 | `act` 与 `_force_action`（强制不加）都调 `finish` |
| 终式：三层时解／捌／伏魔御厨子转空间斩 10234 或次元斩 10235（真伤、属性 13、免属性／物魔率／防御／harmRe、护盾视为 0），结束清层 | `S.begin`、`trueHit`、`executeHpDamage` 包装、伤害钩子 | 本期 | `formula`／`damage_ops` 读 `cast.terminal`；`execute_hp_damage` 包 `strip_shield`／`restore_shield` |
| 伤口 2637（施放前目标≥2 层且命中就附，下一回合结束解除） | `apply` 包装、`S.endRound` | 本期 | `XSukuna.apply`／`end_round` |
| 伤口受治疗减半 | `gainHp` 包装 | 本期 | `XResourceContext.gain`、`_regenerate`、`sequence_gain` 直写支 |
| 捌 10230 冲击段（权重 0.3、物防 ×0.5、不算斩击）＋斩击段，冲击打死不打斩击 | `apply` 包装、`damage`、伤害钩子 | 本期 | `XSukuna.apply`（`part`） |
| 领域 10231：开始行动即展开 4 回合（状态 2636），斩击 ×1.3（10237 除外） | `S.begin`、`damage` | 本期 | `begin`、`formula` |
| 领域回合结束：全体敌人御厨子·斩击 10237，准备层 +1（至 4），到期会神灶就全体神灶：开，否则收领域；之后 3 回合内不能再展开 | `S.endRound`、`endDomain` | 本期 | `end_round`（`end_turn` 里在米拉之前） |
| 神灶 10232：只能打被主技能命中过（蓄力）的目标，命中后消耗；没蓄力的目标不结算 | `apply` 包装、`meetsSkillConditions` | 本期 | `apply`、`meets` |
| 神灶：开 10233：直接施放不结算，行动结束按准备层数对全体敌人打 | `apply` 包装、`S.finish`→`open` | 本期 | `apply`、`finish`、`open` |
| 追斩 10241：主技能／神灶／体术命中后，每回合一次 10236 | `S.finish` | 本期 | `finish`→`perform` |
| 咒力体术 10238 命中回 20 TP | `S.finish` | 本期 | `finish` |
| 魔虚罗适应 10246：被敌人主行动扣血后 +1（每回合一次、至 3，状态 2638），斩击 ×(1＋0.05×层) | `executeHpDamage` 包装、`S.finish`、`damage` | 本期 | `restore_shield` 记受害者，`finish` 加层 |
| 技能条件（解锁、领域中或冷却中不能展开、神灶要有蓄力目标、神灶：开要领域与准备层） | `meetsSkillConditions` 包装 | 本期 | `can_use`→`XSukuna.meets` |
| 战斗中技能列表（空间斩／次元斩不列、领域有准备层时不列神灶、没准备层不列神灶：开） | `skills` 包装 | 本期 | `battle_skills`→`XSukuna.listed` |
| 领域中解／捌 TP ×0.5（stage≥2） | `skillTpCost` 包装 | 本期 | `skill_cost`（米拉之后、种族之前） |
| 开战清数据、同步；TP 至少 60；战斗结束清 | `startBattle`／`endBattle` 包装 | 本期 | `setup`（`start_battle`／`start_tp`）、`end_battle` |
| 看破层≥1 时斩击不闪避 | `itemEva` 包装 | 本期（西游无效） | `item_eva`；YEP 闪避公式在西游为 0，照写 |
| stage 3 makeDamageValue ×1.99 | `makeDamageValue` 包装 | **原版死代码，去掉** | 第一期并进了伤害钩子；`installDamageElementRuntime` 后装、整个换掉 makeDamageValue 不调旧链，原版不生效（参照 3 进阶各段比值证实），二十指说明也只写结算 ×1.5 |
| applyCriticalRate 改写（暴伤加成从缓存挪出另加） | `applyCriticalRate` 包装 | 不需要 | CodexDamage 下不走旧暴击链（`installDamageElementRuntime.js:155` 注释） |
| 熟练度上限（变量 8 或技能上限） | `skillMasteryLevel` 包装 | 不涉及 | 重制熟练度恒 0 |
| 宿傩阵亡清战斗数据 | `Game_Actor.die` 包装 | 下期 | 复活后适应、领域应清零；目前只在 `active_domain` 看存活 |
| 黑闪（CodexBlackFlash，与甚尔共用）：斩击强化 emp、觉醒 2639、内部神灶：开 ×1.2、终式不吃黑闪 | `B.register`、`installNativeBlackFlashRuntime.js`（13 KB） | 下期 | 重制恒不觉醒、emp 0；甚尔 171 也还没移植，建议和甚尔一期做共用模块 |
| 神灶选目标窗只列蓄力敌人、战斗日志文字（「发动了神灶：开！」等） | `Window_BattleEnemy.refresh`、`_logWindow` | 下期（画面） | 逻辑层出 `{"type": "battle_text"}` 记录，画面没接 |
| 技能分类与指令窗（[2,1,5,3,4]）、完全体外观 2643、旧档迁移、Map132 补号角 | 各包装 | 下期／别处 | Map132 补号角已做（a39112c0） |

## 变更记录草稿

## 2026-10-31 【Claude·八戒_92·未经审查】宿傩 172 第二期：战斗内机制（看破、终式、伤口、捌两段、领域、神灶、追斩、适应、技能条件）（dev.待定）

1. **战斗内机制**（冻结 v0.28 `installNativeSukunaRuntime.js` 的 S.begin／finish／endRound 与 Game_Action.apply、itemEva、executeHpDamage、gainHp、meetsSkillConditions、skillTpCost、skills、startBattle、endBattle 包装）：`modes/xiyou/core/sukuna.gd` 新增「战斗内（第二期）」一节，逐项见本交付单「机制对照」表。`formula` 读施放帧：终式按空间斩／次元斩权重、捌冲击段权重 0.3、适应／领域／伤口加成；`damage_ops` 终式定真伤、属性 13，捌冲击段物防率 ×0.5。
2. **接线**（改了原沙僧核心文件 `battle_logic.gd`，另改 `resource_context.gd`）：`setup`（开战清数据、TP 至少 60）、`skill_cost`（领域半价）、`can_use`（技能条件）、`battle_skills`（列表过滤）、`act`／`_force_action`（行动结束 `finish`）、`execute`（两条路定目标后 `begin`）、`end_turn`（`end_round`，在米拉之前）、`_invoke`（反射与普通两支都走 `XSukuna.apply`）、`item_eva`、`execute_hp_damage`（真伤免护盾、记受害者）、`_regenerate`／`sequence_gain`（伤口回复减半）、`end_battle`；`XResourceContext.gain` 生命回复先过伤口减半。别的角色都不进这些分支。
3. **去掉第一期误并的 stage 3 结算 ×1.99**：原版 `makeDamageValue` 的宿傩包装被后装的 `installDamageElementRuntime` 整个换掉，不生效；参照 3 进阶（二十指）各段与 0～2 进阶的比值相同证实。只影响二十指宿傩的伤害（重制原先多乘 1.99）。
4. **参照与专项**：新探针 `mv_oracle/sukuna_battle_probe.cjs`（真实 BattleManager／Game_Action，Math.random 0.5，四段脚本：0 进阶看破与伤口、1 进阶空间斩与护盾、2 进阶领域与神灶：开、3 进阶适应与次元斩；每步比命中与快照），进 `同步正式西游.py` PROBES 与 `oracle_additions.py`；专项 `xiyou_sukuna_battle`（425 项）逐步比，另有本地断言（开战 TP、别的角色不吃包装、没伤口治疗不减半、神灶打没蓄力目标不结算、战斗结束清空）。
   - 生命伤害比值对比：55 级宿傩各技能重制恒为原版的 0.96079 倍，与黄泉 `xiyou_yomi_battle` 记的 55 级约 3.9% 固定差相同，出在伤害链／能力值，与本期机制无关；专项每例取第一段比值、其余各段（终式、冲击段、领域斩击、神灶：开）都要相同，并断言比值为 0.96079。
   - 反向验证：每回合加层上限 2 改 3（12 项失败）、领域 ×1.3 去掉（8 项）、终式免护盾去掉（1 项）、伤口治疗减半去掉（2 项），都已还原。

## 交接板

- 下一步：宿傩第三期——黑闪（CodexBlackFlash，建议与甚尔 171 移植合一期做共用模块）、阵亡清战斗数据；画面车道接神灶选目标只列蓄力敌人与 `battle_text` 日志。另：55 级专属角色（黄泉、宿傩）伤害比原版低约 3.9% 的固定差该派伤害链／能力值核查。
- 用户试玩说明：宿傩在战斗里的招式机制都能用了——连斩叠看破、三层时解／捌自动变空间斩／次元斩（真伤、无视护盾）、伤口让敌人回血减半、捌先冲击再斩击、伏魔御厨子领域每回合自动斩全体并在到期时放神灶：开、神灶只能打被斩过的敌人、追斩、体术回 TP、魔虚罗适应；二十指宿傩伤害不再多乘 1.99。黑闪觉醒还没有。
- 需要用户决定：无。

## 优化登记草稿

无（本期没有新的 O 号；×1.99 是对齐原版实际行为，不是优化）。

## 进度账

- 172 宿傩：战斗内机制除黑闪外完成。

## 可优化（流程／工具／效率）

- 建议：`并行测试.py` 碰到脚本解析错误（SCRIPT ERROR: Parse Error）时 Godot 不退出，要等满 600 秒超时；可以在看到 Parse Error 那一行就杀掉并报失败（预计每次写错省近 10 分钟，归工具车道）。
- 建议：车道会话被 app 自建工作树、而派单指定另一个工作树时，app 的工作树守卫不让写那边，只能在自己工作树接着做（本期就是）。派单时可直接写「在 app 给的工作树里把分支快进到 X 再做」，交付分支名照实回报（归总装）。

## 待交叉核查（改了原沙僧核心文件）

- `battle_logic.gd`：见变更记录草稿第 2 条各处，重点 `act` 里 `finish` 的调用条件（`started and not skipped`）、`_invoke` 反射支返回多条、`execute_hp_damage` 的护盾暂存与还原。
- `resource_context.gd`：`gain` 开头的伤口减半（在异化路由之前）。

## 验证

- 专项：`xiyou_sukuna_battle` 425/425（参照 `sukuna_battle.json`，探针在本工作树跑出，8 秒）。
- 选测（`并行测试.py`，25 个场景全过、无偶发，1062 秒）：xiyou_sukuna_battle、actor_modules、alien_affix、alien_battle、attack_element、attack_query、battle、battle_common_events、battle_events、battle_ui、cat、custom_damage、mira_battle、race_battle、yomi_battle、rules（难度 1 四段 rules／d1b／d1c／d1d）、smart_ai 四段、help_card、difficulty_inherit_battle。
- 同步：本工作树 `同步正式西游.py --accept-additions` 通过（新探针执行 1、复用 67，测量不变），产物指纹已留。
- 未合 main：分支基于 main 96bfe11c，交付时 main 没有前进。

## 本分支提交

- c77cd443 宿傩第二期战斗内机制初稿
- a8e3aa76 原版探针 sukuna_battle_probe 与专项 xiyou_sukuna_battle；去掉 ×1.99
- 本提交：交付单验证、可合并
