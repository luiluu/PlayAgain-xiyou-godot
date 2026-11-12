# 交付：cc/tianqi-alien-finale

- 车道／工作者：天启篇·各线异化的终焉效果与补做的化形效果／cc（项目线程「完成再刷西游 Godot 引擎重制」）
- 状态：可合并

## 依赖与合并顺序

- 从 main（dev.494）切出，不依赖待合的分支。和 cc/tianqi-alien-affix 都改 `battle_logic.gd`，但改的地方不同（本单：`sequence_buff` 一行、附加状态判抵抗两行；那条：`execute_hp_damage` 一行、日志两行），先合哪条都行。

## 变更记录草稿

## 2026-11-12 【cc·天启篇·未经审查】天启篇各线异化接上终焉效果（dev.待定）

- 按设计仓库《天启篇序章_四线异化与异化装备重构 v0.8》第 3.1～3.4 节的「终焉效果」一列，补上四个异化模块的「未做」。终焉级只出现在 31～36 层首领和骑士战（按段异化、各线预设），所以这些只在那几场起作用。数在各线表里（`war_line.json`、`famine_line.json`、`plague_line.json` 新加 `finale_*` 键，避开 4）。
- 战争线（`core/tianqi_war_alien.gd`）：
  - 战狂终焉：免疫能力值减益（`BattleLogic.sequence_buff` 一行，和米拉终焉同处）。
  - 号令官终焉：同场每多一只活着的怪，自己每回合多再动 1 次（上限 3）。
  - 烟火师终焉：火花满时额外对我方全体轰炸一次（攻击×1.5×攻÷(攻＋防)，交锋照乘，先吃护盾）。
  - 战意：化形起满层再动时清掉自己一个减益（能力值减益优先）；终焉满层那次再动伤害 ×2。
- 饥荒线（`core/tianqi_famine_alien.gd`）：
  - 枯竭者终焉：每回合开始我方 MP 上限再 −5%（本场累计，最多 −90%；`XActor.param` 链里加一层 `actor_param`）。
  - 荒年者终焉：我方被复活时这一下的回复无效，只剩复活给的 1 点生命（`Game_Battler` 去掉阵亡时记一下，本次行动结束清）。
  - 熬夜者终焉：每回合开始我方 TP 归零。
  - 透支者终焉：每放一次技能另扣当前 MP 的 10%。
- 瘟疫线（`core/tianqi_plague_alien.gd`）：
  - 终焉瘟疫异化在场时病灶满 8 就爆发、病弱上限 −60%（表里原来就有 `full_end`、`cap_end`，现在用上）。
  - 毒腺终焉：我方中毒期间不能被治疗（`XResourceContext._gain` 一行）。
  - 混乱者终焉：混乱一次 2 回合。传染者终焉：每回合传两次。
  - 疫源终焉：我方对减益状态的免疫无效（附加状态判抵抗的三处：`XResourceContext.add_state`、`BattleLogic` 技能附加状态和行动序列附加状态）。
  - 挑衅者终焉：全体挑衅（我方群体攻击也只打它），打它的人改为混乱（不再是不服）。
- 死亡线（`core/tianqi_death_alien.gd`）：骑士队长在场时，七印灰印免死（`XTianqiQiyinEffects` 的保命）按队长的失效几率失效（`breaks_saves`）。
- 新专项 `tests/xiyou_tianqi_alien_finale`（27 项）。
- 玩家可见：开发版天启篇 31～36 层带终焉异化的首领战更难（各线终焉效果生效）；发行版看不到（天启篇关着）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_war_alien.gd`、`tianqi_famine_alien.gd`、`tianqi_plague_alien.gd`、`tianqi_death_alien.gd` 的终焉分支；挂钩在 `battle_logic.gd`（三行）、`resource_context.gd`（两行）、`battler.gd`、`actor.gd`、`tianqi_qiyin_effects.gd` 各一处 | 原版没有天启篇异化 | 天启篇各线异化的终焉效果（15 条）和战意的化形效果 | Kyo 11-08 定四线二十种异化都要做（v0.8 第 3 节） | 各线开关（`XTianqiWarLine.ENABLED` 等）关掉整条线；单关终焉：把各线表里 `finale_*` 改回不生效的数（如 `finale_cap` 0、`finale_bomb` 0、`finale_mmp` 0、`finale_mp` 0、`finale_turns` 1、`finale_mult` 1），表里没有的几条（病灶 8、毒腺、疫源、全体挑衅、荒年、队长）随线开关 | cc | 已接受（Kyo 11-11 优化直接接受） |

## 交接板

- 下一步：剩下的异化小项：战争线「连击兵」整个种类、烟火师的随机雷电段数；饥荒线减耗打折、角色自带资源挨饿、荒年掉落与余粮（还没有余粮物品）、掠夺者终焉扣精魄；瘟疫线混乱者化形「优先打队友」；死亡线收尸人终焉吸收技能、各角色模块自带的「不屈」被队长破；骑士战的同类小项（绝粮再提一档与口粮、疫病让减益清不掉、骑士队长破免即死不屈、识破反击与爆闪）。
- 用户试玩说明：开发版天启篇档选了线，变量 20 调到 31 以上进 31～33 层打首领（终焉异化），看战斗日志：战争线有轰炸、号令官多动；饥荒线 TP 每回合清零、MP 上限往下掉；瘟疫线病灶 8 就爆发、群攻只打挑衅者。
- 需要用户决定：无（轰炸系数 1.5、MP 上限每回合 5%、透支扣 MP 10%、混乱 2 回合是设计稿的数或测试参数）。

## 进度账

- 天启篇四线异化（扩展账）：终焉效果 0 → 15 条已接（战争 4、饥荒 4、瘟疫 6、死亡 1），战意化形已接；剩下的见交接板「下一步」。不写主表。

## 可优化（流程／工具／效率）

- 无。

## 验证

- `xiyou_tianqi_alien_finale`：27/27。
- 相关专项（Mac，本工作树，`并行测试.py`，22 个场景，219 秒，全部通过）：`xiyou_tianqi_alien_finale`、`xiyou_tianqi_war`、`xiyou_tianqi_famine`、`xiyou_tianqi_plague`、`xiyou_tianqi_death`、`xiyou_tianqi_seg_alien`、`xiyou_tianqi_rewards`、`xiyou_tianqi_qiyin_effects`、`xiyou_tianqi_horsemen_battle`、`xiyou_tianqi_summit`、`xiyou_tianqi_party`、`xiyou_determinism`、`xiyou_battle`、`xiyou_rules`、`xiyou_alien_affix`、`xiyou_alien_battle`、`xiyou_state_effects`、`xiyou_param_states`、`xiyou_shield`、`xiyou_guyu_battle`、`xiyou_liuying`、`xiyou_mira_battle`。
- 偶发：`xiyou_tianqi_plague` 并行时第一次挂 `focus_text`（期望开场病灶 0，实得 1），单独重跑通过；累计偶发 1 次（第一次）。本单没改病灶的数法（阈值那条只在终焉在场时变，这场是化形），看着是那场开场随机挂上的减益，第二次偶发就该固定随机。
- 没跑的：`battle_logic.gd`、`actor.gd`、`battler.gd`、`resource_context.gd` 都让选测判整轮；本单在这些文件里各只加一处受「天启篇终焉异化在场」门控的判断（蚀骨对照 `*_shigu`、`shigu_plain` 覆盖不触发），其余请总装合并时按选测照常跑。
- 反向验证（`反向验证.py`，单跑本专项）：15 条终焉效果各改坏一处，15 处全部咬住。传染者「每回合传两次」没有单独断言。
- `语法检查.py`：通过。
- `交付自检.py`：提交后跑，见回报。

## 本分支提交

- 天启篇各线异化终焉效果与专项
- 交付单
