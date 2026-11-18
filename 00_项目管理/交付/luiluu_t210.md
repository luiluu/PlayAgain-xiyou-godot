# 交付：luiluu/t210

- 车道／工作者：T210 战斗待机动作选择跟原版对齐（cc，Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·T210·未经审查】战斗待机动作按原版顺序选：防御排在濒死前，补上中毒等异常、睡眠、状态倒地三档（dev.待定）

- 依据：T206 交付单「建议」两处（防御／濒死先后、VisualStateFX `stateMotion >= 4`），协调 11-18 回复选 B（顺带补 stateMotion 1/2/3）。原版 v0.62.12 `Sprite_Actor.refreshMotion`：YEP_X_VisualStateFX:434 先判输入／行动中、再判 `stateMotion >= 4`，其余交给 YEP_BattleEngineCore:3197：输入／行动中 walk → 状态动作 3 倒地 dead → 2 sleep → 咏唱 chant → 防御 guard → 1 abnormal → 濒死 dying → 未决定 walk → 否则 wait。敌人那一版（YEP_X_AnimatedSVEnemies:2649）同顺序、没有咏唱。
- 重制原先只有 dead → dying → guard → walk：生命低于 1/4 时防御压不过濒死；中毒、眩晕、石化、睡眠这类状态在画面上完全不显示（原版带 motion 的状态 80 多个）。
- 改动：`XBattlerSprite._idle_motion` 照原版顺序：阵亡或状态动作 3 → dead，2 → sleep，防御 → guard，1 → abnormal，濒死 → dying，否则 walk（T206 输入／行动中 walk 仍排第一）。状态动作取 `XBattler.state_motion_index()`（＝`Game_BattlerBase.stateMotionIndex`：按优先级降序、同级 ID 升序的第一个 motion 非 0 的状态）；演出快照 `XBattleLogic.view_of` 多记一项 `state_motion`，演出期间按快照判，跟 hp／guarding 同口径。美术缺 abnormal／sleep 帧的照 `XAppearance.FALLBACK`（abnormal→dying、sleep→dead）。
- ② `stateMotion >= 4`（`<State Motion:x>`／`<Custom Motion:x>` 自定义动作）不做：原版 States.json、重制 generated、天启篇数据里一个这种标签都没有，照搬是死代码。
- 样张夹具：`tests/xiyou_big_form_sizes.gd`、`tests/xiyou_battle_actor_size.gd` 的 `_big_forms` 换黑龙后回满血（进阶 3 与 2592 上限 ×2 之后生命停在一成多，照规则会趴濒死）。
- 回退：`XBattlerSprite.GUARD_FIRST = false`（濒死压过防御）、`XBattlerSprite.STATE_MOTION = false`（不看状态动作）。
- 原版对照：`04_验证/T210_待机动作对照/refresh_motion_oracle.cjs` 直接执行原版两份插件的 refreshMotion 源码（存根角色＋原版 States.json），8 种情形输出见同目录 `原版输出.txt`，跟专项断言逐条一致（低血＋防御 guard、中毒 abnormal、中毒＋低血 abnormal、中毒＋防御 guard、睡眠＋中毒＋防御 sleep、中毒＋炎爆暴击同优先级 abnormal、破阵 1043 dead、中毒＋低血＋轮到输入 walk）。
- 测试：`tests/xiyou_mira_dragon_idle.tscn` 加 guard_first.*、state.* 与两条回退共 17 项（41/41）；云端选测见「验证」。
- 玩家可见：战斗中角色中了中毒、眩晕、石化等异常会换成难受的待机姿势，睡着会躺下，有些控制状态会直接倒地；生命不到四分之一时下了防御，摆防御姿势，不再趴着。（待小A 审）

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化内容 | 理由 | 回退 | 执行者 | 状态 |
|---|---|---|---|---|---|---|---|
| O-待定·待机防御先于濒死 | `battle/battler_sprite.gd` `XBattlerSprite.GUARD_FIRST`、`_idle_motion` | 原版 refreshMotion 防御排在濒死之前；重制原先濒死压过防御 | 照原版：防御中摆防御姿势，低血也一样 | 对齐原版（T206 建议①） | `XBattlerSprite.GUARD_FIRST = false` | cc | 保留 |
| O-待定·待机状态动作 | `battle/battler_sprite.gd` `XBattlerSprite.STATE_MOTION`、`_idle_motion`；`core/battler.gd` `state_motion_index`；`battle/battle_logic.gd` `_view_now` 的 `state_motion` | 原版按状态的 motion（1 异常、2 睡眠、3 倒地）换待机动作；重制原先不看 | 照原版顺序补三档（咏唱、wait／walk 不做） | 对齐原版（T206 建议②的同一函数，协调 11-18 定 B） | `XBattlerSprite.STATE_MOTION = false` | cc | 保留 |

## 交接板

- 下一步：米拉黑龙 abnormal（15_0）、dying（14_0）两帧龙角跟待机不一致（T207／T213 在做）；本单补上状态动作后中毒等状态会更常露出 15_0，那两单合了就好。
- 用户试玩说明：中了中毒、眩晕、石化、麻痹等状态的角色待机姿势会变；睡眠躺下；低血时防御摆防御姿势。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 没做 / 没验

- 没做：VisualStateFX `stateMotion >= 4` 自定义状态动作（数据里没有标签）。
- 没做：咏唱 chant（`isChanting`＝等待中且下了魔法技能，OTB 下轮到就行动，基本走不到）、`isUndecided` walk／否则 wait 的区分（重制一律 walk，原版不轮到且已决定时是 wait）、原版「当前是防御动作且不在输入阶段就不刷新」那条黏住守卫。
- 没验：没在真实战斗流程里看状态加上后的那一刻（refresh_idle 由行动收尾、回合刷新触发，专项是直接调 refresh_idle）；没逐个角色看 abnormal／sleep 帧美术（缺帧走回落链）；渡鸦的 abnormal 没走渡鸦替换表（原版替换表也只有 damage、dying）。

## 验证

- 语法检查 1040 个 .gd 0 问题；工具回归全过；`xiyou_mira_dragon_idle` 本机 41/41。
- 云端选测（86aef4abb，基准 9fa19b58b）：346 个场景全过（含 xiyou_mira_dragon_idle、xiyou_big_form_sizes、xiyou_battle_actor_size、xiyou_determinism、xiyou_rules 全段）。

## 本分支提交

- 80c9f2614 WIP：防御排在濒死前（GUARD_FIRST）、样张夹具回满血、专项
- 86aef4abb WIP：状态动作 1/2/3（STATE_MOTION）、演出读数带 state_motion、原版对照脚本
