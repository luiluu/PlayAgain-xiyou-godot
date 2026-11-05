# 交付：cc/bajie-rules10

- 车道／工作者：C 规则／八戒（cc，派单第三批 AC）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·八戒·未经审查】说明与代码不符三条按说明做：隐月可叠层、1749 暴击伤害、一株莲打敌方（三个开关，dev.待定）

依据：Kyo 11-04「说明与代码不符一律按说明走」、11-05「待拍板按你分析的优化方向做，改了什么记得登记」。三条各一个开关，关掉就回原版。

- **隐月叠层**（O-待定，`XBattler.FLOOR_YINYUE`）
  - 原版：剑饮空月（7489／7503～7506／10119）说明写「命中敌人为自己附加 1 层隐月，每层 +x% 暴击，可无限叠加」，但 dsPassiveSkill 已带着就不再挂，实测恒 1 层（rules9b）。
  - 现在：命中时已带着就再叠一层，不限层数，每层效果与原版单层相同（照 CP_StateFloor：多出的每层各补一份状态特性，暴击加算）。状态被解除、阵亡、战斗结束后，下次附加从 1 层算起。挂状态的掷骰次数和顺序不变。
  - 实测（Godot，角色 1 基础暴击 0.19，叠 1／5／20 层后的暴击率）：隐月 1323（+2%）0.21／0.29／0.59；1324（+4%）0.23／0.39／0.99；1325（+6%）0.25／0.49／1.39；1326（+8%）0.27／0.59／1.79；1327（+10%）0.29／0.69／2.19；2521（+0.2%）0.192／0.200／0.230。
  - 失衡看法：1324 以上大约 10～25 次命中就到 100% 暴击，之后再叠对普通伤害没用；但和 1749（暴击伤害按暴击率加）同时带时，超过 100% 的部分会变成暴击伤害（1327 叠 20 层：暴击伤害再 +219%）。按派单默认照说明做、不设上限，数字写在这里给 Kyo 看。
- **数据错误:暴击 1749**（O-待定，`XStateEffects.FIX_CRIT_1749`）
  - 原版：Custom Confirm Effect 调用不存在的 `user.criticalRate()`，报错，整块无效果（rules8 量过）。
  - 现在：持有者打出暴击时，伤害 + ceil(伤害 × 最终暴击率)，即每 1% 暴击率 +1% 暴击伤害；暴击率取持有者最终 cri（含被动、隐月层），不封顶；不暴击不变。转换器 `EFFECT_FIXES` 加 `FIX_CRIT_1749` 修正程序，原版块照旧是 no_effect。
  - 实测：暴击率 0.19 的角色，公式 1000 的暴击一击 273 → 325。
- **万古青天一株莲 7303 打敌方**（O-待定，`XStateEffects.LOTUS_DAMAGE_7303`）
  - 原版：说明写「显化青莲虚影，对敌方全体造成伤害，并为友方完全回复」，技能本身只回复友方（scope 8），敌方不受伤；说明没写数值。
  - 现在：放完后对敌方全体各造成「本次回复总量 × 50%」的伤害。回复总量＝各队友施放前后生命之差的和（实际回上来的，含拉起倒下的人，溢出的不算）；每个敌人再乘自己对属性 6（技能属性）的有效度，不暴击；走 executeHpDamage（护盾、真气减伤等照常），每个敌人一条命中记录、播技能动画、照常弹字和倒下。行动序列和普通两条路径都接了（7303 实际走行动序列）。
  - 实测（琼霄 101 施放，敌群 2，三个敌人最大生命 10000，队友一个半血一个倒下）：1 级回复总量 693，开关开时敌人各受 346、关时 0；60 级回复总量 7809，各受 3904、关时 0。
- 新专项 `xiyou_rules10`（58 项，三个开关开／关两支都跑，回退支字面量赋值）；`xiyou_state_effects` 的全关／全开清单补上两个新开关。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 隐月叠层 1323～1327、2521（`core/battler.gd` `state_floors`／`floor_states`，`battle_logic.gd` `_push_row_state`） | 剑饮空月说明「每层隐月 +x% 暴击，可无限叠加」，原版 dsPassiveSkill 已带着就不再挂，恒 1 层 | 命中时已带着就再叠一层，不限层，每层同单层效果（按 CP_StateFloor 多出的层各补一份状态特性）；解除、阵亡、战斗结束后重新从 1 层算 | Kyo 11-04「说明与代码不符一律按说明走」 | `XBattler.FLOOR_YINYUE = false` | cc（八戒） | 待用户决定 |
| O-待定 | 数据错误:暴击 1749（`core/state_effects.gd`，转换器 `EFFECT_FIXES` 的 `FIX_CRIT_1749`） | 调用不存在的 `user.criticalRate()` 报错，整块无效果 | 持有者打出暴击时伤害 + ceil(伤害 × 最终暴击率)，即每 1% 暴击率 +1% 暴击伤害 | 说明「每点暴击率提供 0.01 暴击伤害」，Kyo 11-04 按说明走 | `XStateEffects.FIX_CRIT_1749 = false` | cc（八戒） | 待用户决定 |
| O-待定 | 万古青天一株莲 7303 敌方伤害（`battle_logic.gd` `_lotus_hp`／`_lotus_strike`） | 技能是全体队友回复，说明写的「对敌方全体造成伤害」原版没有 | 放完后对敌方全体造成本次回复总量 50% 的伤害（各队友实际回复的生命之和，乘各敌人对属性 6 的有效度，不暴击，照常过护盾等） | 说明没写数值，总装定 50%（Kyo 11-05 授权按分析方向做） | `XStateEffects.LOTUS_DAMAGE_7303 = false` | cc（八戒） | 待用户决定 |

## 交接板

- 下一步：无新增。可选：战斗界面隐月图标上画层数（原版 CP_StateFloor「Show State Floor」开着，图标角上写「%1层」），归 B 界面车道。
- 用户试玩说明：天虎令等带剑饮空月的角色命中后隐月一层层叠上去，暴击率持续涨；学了「数据错误:暴击」的角色暴击更痛；琼霄倒下放一株莲时敌方全体也会掉血。三条都能用开关回原版。
- 需要用户决定：三个 O-待定 保留还是照原版；隐月是否要设层数上限（现在照说明不限）。另：剑饮空月 10119 说明写「每层 +2%」，但它挂的隐月 2521 数据是 +0.2%（与 7489 的 1323 不同），本期没改，要不要按说明改成 2% 请 Kyo 定。

## 进度账

- 无（规则修正，不改完成度）

## 可优化（流程／工具／效率）

- 建议：隐月层数显示（见交接板），归 B 界面车道，预计半小时。
- 无别的新增。

## 验证

- 语法检查通过；`工具回归.py` 7 项全过。
- 专项 `xiyou_rules10` 58/58。
- 选测（本机，`--skip-generated-check`，差异只是本分支自己的 States.json）30 个场景全部通过（1004 秒）：xiyou_rules10、xiyou_state_effects、xiyou_state_effects_tp、xiyou_pushstate、xiyou_error_data、xiyou_determinism、xiyou_qiongxiao_balance、xiyou_trait_stack、xiyou_param_cache、xiyou_param_states、xiyou_status_power_panel、xiyou_combat、xiyou_battle、xiyou_formula_effects、xiyou_state_js、xiyou_passive、xiyou_custom_damage、xiyou_review_regressions、xiyou_action_sequence、xiyou_actor_p0、xiyou_battle_common_events、xiyou_recover_permanent、xiyou_state_operation、xiyou_event_compare、xiyou_rules、xiyou_smart_ai_d、xiyou_power、xiyou_multi_element、xiyou_loose_fixes、xiyou_floor30_gifts。
- 合 main（76a8341f，改了 actor.gd 与转换器／探针）后重跑 `--补齐`，再跑 xiyou_rules10、xiyou_state_effects、xiyou_pushstate、xiyou_error_data、xiyou_state_effects_tp、xiyou_determinism、xiyou_actor_p0，7 个全过。
- 没跑的：`选测.py main --list` 列出 326 个场景（改了 battle_logic／battler／actor／enemy 等战斗核心，按规则要全部 xiyou_rules* 段、楼层与事件对照）。车道这边没开云端（协调者交代不跑付费云端 CI），本机跑了上面这些和改动直接相关的；其余请总装合并时 `--affected` 一起跑。没改切片和探针，不用重同步。

## 待交叉核查

- 改了原沙僧核心文件：`battle_logic.gd`（`_push_rows`／`_push_row_state`、`execute` 两条路径的一株莲、`_lotus_hp`／`_lotus_strike`）、`battler.gd`（`state_floors`、`floor_states`、`add_state_floor`、`_add_state` 新附加清层）、`actor.gd`／`enemy.gd`（`trait_objects` 补层）、`state_effects.gd`（两个开关）；转换器 `xiyou_export.py`（`EFFECT_FIXES` 加 1749）。

## 本分支提交

- c6a5a963 WIP: 三个开关与专项 xiyou_rules10
- （本提交）回退支字面量赋值、交付单、合 main

