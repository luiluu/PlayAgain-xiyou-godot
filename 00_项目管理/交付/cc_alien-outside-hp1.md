# 交付：cc/alien-outside-hp1

- 车道／工作者：重制收尾车道 B／cc（车道B，总装三十七排期）
- 状态：可合并
- 分道：慢车道（改了参照探针 `alien_affix_probe.cjs`，加 3 例；本树已跑 `同步正式西游.py --accept-additions` 留指纹）

## 变更记录草稿

## 2026-11-11 【cc·车道B·未经审查】异化行动外 gainHp 的镜骸记账照 v0.62.12 补齐（dev.待定）

- 对照 v0.62.12 `installAlienationRuntime.js` 的 wrapHp（Game_Battler／Game_Actor.gainHp）与 Game_BattlerBase.setHp 包装，逐个入口比重制：
  - 行动 apply 帧里、不在 executeHpDamage 里的 gainHp（效果「恢复 HP」负值、伤害公式里的 b.gainHp 等）：逆祷阻断、烈变／小怪加成早已接上（frame_blocks_hp、frame_outgoing）；**缺的是包装末尾的 recordDamage**——这类扣血原版也算进镜骸本次行动的扣血，行动结束反噬。本轮补上：`XAlienBattle.frame_record`，在 `XResourceContext._gain` 里按实际掉的生命记账（不在任何 executeHpDamage 里，对应原版全局的 executeDepth；预演不记）。
  - setHp 包装：原版只阻断与加成、不记账，重制已对齐，不改。
  - 自定义状态效果（customEffectEval）、腐蚀、蚀能、镜骸反噬：原版 withFrame(null, …) 没有行动，不加成、不记账；重制垫的是空行动帧，frame_record 同样跳过。
  - 反击、反射：原版行动根置空且帧类型排除；重制 record 要求来源是行动根的角色，反击者／反射目标不满足，不记。
  - 回合末再生、事件「增减生命」：原版没有帧，三项都不做；重制同。
- 开关 `XAlienBattle.OUTSIDE_HP_MIRROR`（static var，默认 true）：false 回到只记 executeHpDamage 的旧行为。照原版补齐、不偏离原版，不登记 O 号。
- 参照：`alien_affix_probe.cjs` 合成技能的效果多一项 value2（不给为 0，旧例不变），加 `battle.mirror.gain`（角色用定量 −5000 的效果技能打镜骸：反噬 250；同回合第二次不再反噬）、`mirror.gain.enemy`（敌人打镜骸不记；队友 b 打：反噬按 8% 最大生命封顶）、`mirror.gain.mix`（普攻之后再用效果技能：只按普攻那次反噬）。
- 专项 `xiyou_alien_affix`：三例逐步对照；开关关时效果扣血不反噬、不耗充能；普攻只记一次；frame_record 单元例（没有帧、空帧、不是异化、扣 0、累计两次、来源不是行动根）。
- 玩家可见：异化镜骸敌人被技能附带的扣血效果打中时，行动结束同样会反噬。
- 验证：语法检查通过；`xiyou_alien_affix` 2184/2184、`xiyou_alien_battle` 通过；开关默认改成 false 反向跑一次，`xiyou_alien_affix` 挂 3 项（mirror.gain 两步、mirror.gain.enemy 队友那步），确认断言咬得住；选测 50 个场景全部通过（见下「验证」）。
- 提交：见「本分支提交」
- 未完成／已知问题：对照时看到重制 `XAlienBattle.record` 遇到派生行动（`_derived`）直接不记，原版 recordDamage 的排除表里没有 derived（只要求行动者就是行动根的角色）——这是 executeHpDamage 路径的既有行为，本轮没动、也没做参照，留给审查看要不要另派。

## 交接板

- 下一步：重制步骤清单「养成与周边系统」行、审查第 76 期余项的「异化行动外 gainHp／setHp」可以销掉（加成、阻断早已接，记账本轮补齐）；派生行动的镜骸记账差异（见上「已知问题」）如要核，派规则车道加探针例。
- 用户试玩说明：打异化镜骸时，用带扣血效果的技能（不是普通伤害）打中它，行动结束也会被反噬。
- 需要用户决定：无

## 进度账

- 养成与周边系统：异化部分「行动外 gainHp／setHp」余项补齐，完成度按总装核定（本车道不改数）。

## 优化登记草稿

无（照原版补齐，不偏离原版；开关 `XAlienBattle.OUTSIDE_HP_MIRROR` 仍保留可回退）。

## 待交叉核查

- 甲档：`01_Godot工程/modes/xiyou/core/resource_context.gd`（`_gain` 里新加镜骸记账的取值点与调用点）、`01_Godot工程/modes/xiyou/core/alien_battle.gd`（`frame_record`、`OUTSIDE_HP_MIRROR`）。没改 battle_logic.gd、battler.gd、actor.gd、damage.gd、xstate.gd。
- 乙档：`03_转换工具/mv_oracle/alien_affix_probe.cjs` 三例与 synth 的 value2；`tests/xiyou_alien_affix.gd`。

## 验证

- `python3 07_开发环境/语法检查.py`：通过。
- 已合 main（2311a38f2 之后的 dev.462 文档与真气／云裳小改，没碰切片、转换器、探针）。
- 同步：本树 `同步正式西游.py --accept-additions` 退出 0，alien_affix.json 三例新增已接受（不登记），留指纹。
- 选测：`选测.py main --list` 给出的 50 个场景（含 xiyou_alien_affix、xiyou_alien_battle、xiyou_boss_output*、xiyou_shield*、xiyou_event_compare*、xiyou_smart_ai 抽样 4 段等）`并行测试.py` 全部通过，754 秒，无偶发。
- 反向验证：`OUTSIDE_HP_MIRROR` 默认改 false 跑 xiyou_alien_affix，挂 3 项（2181/2184），已还原。
- `工具回归.py`：全部通过（76 秒）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- de3507352 异化行动外 gainHp 的镜骸记账（开关、探针三例、专项）
