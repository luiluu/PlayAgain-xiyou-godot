# 交付：luiluu/t215

- 车道／工作者：T215 战斗指令某类技能一个都没有就不显示＋T208／T210 核查遗留（cc，Sonnet＋medium，P6）
- 状态：可合并

依据：Kyo 11-18「渡鸦为什么会有其他？」→ 原版插件把渡鸦／宿傩／饿狼／云裳战斗指令写死 [魔法,战技,其他]，没学到也列；Kyo「渡鸦那个B」：所有角色统一，某类技能一个都没有时不显示。从 main 切出，已含 T208、T210。小A 已核代码（P1 0），本单含其 P2-1、P2-2 补的断言。

## 做了什么
1. **指令过滤**（battle_scene.gd `_stype_have`、开关 `XBattleScene.HIDE_EMPTY_STYPE`）：天启篇存档里，战斗指令的技能类（魔法／战技／其他）点开列表里一个技能都没有就不列。「有没有」照点开列表用的同一份 `logic.battle_skills(a)`（原版 Window_BattleSkill 用 actor.skills()：含装备、状态给的，含冷却／魔法不足灰显的），按 stypeId 分。渡鸦／宿傩／饿狼／云裳写死的 [2,1,5] 次序保留，只去空类；普通角色同规则；屠苏武具态（固定「易武」）不动。
2. T208 P2-1：`boss_info_rect()` 血弧显示首领时把血条矩形并入 300 宽弧区（开关 `BOSS_INFO_MERGE_BAR`）。
3. T208 P3-1：`make_room_for_big` 回退下方中间摆法前，把 `_beside_body` 缩过的列表行数还原（新增 `XSkinBattleSkillList.set_rows`）。
4. T210 P2-1：xiyou_appearance 补 abnormal→dying、sleep→dead 缺帧回落断言。
5. T210 P3-1：battler_sprite.gd 非空旧快照缺 state_motion 键按 0。

## 偏离／要知道
- 派单写「XTianqiBase.on() 下生效」，我用的是 `XTianqi.active(XState.current)`（天启篇存档）：`XTianqiBase.on()` 还挂着默认关的 PHASE4 总开关，用了等于没生效。
- 小A 查清：167～174 九死及以上能正常上场；我测试里上不了是 flags.tianqi 缺 difficulty 致 super_cap=-1，不是 bug。专项因此在西游起的战斗上事后打天启篇标记验证过滤逻辑。
- 天启篇普通角色没学战技时指令会少一项（6 项），xiyou_ring_seven_battle 的 _state 因此补了一个战技才凑满 7 项。

## 测试（--audio-driver Dummy，无头）
xiyou_hide_empty_stype 14/14、xiyou_big_form_menu 136/136、xiyou_appearance 37/37、xiyou_mira_dragon_idle 41/41、xiyou_ring_seven_battle 36/36、xiyou_tianqi_party 33/33、xiyou_tianqi_swap_view 62/62、xiyou_battle_ui 182/182、xiyou_ui_skin_battle 67/67、xiyou_battle_log 77/77；语法检查通过。没跑 检查.sh 全量。


## 变更记录草稿

## 2026-11-18 【cc·T215·未经审查】天启篇战斗指令：某类技能一个都没有就不列；T208／T210 核查遗留（dev.待定）

- 战斗指令的技能类（魔法／战技／其他）：天启篇存档里点开列表一个技能都没有就不列；「有没有」照点开列表用的 `logic.battle_skills(a)`（含装备、状态给的、灰显的）。渡鸦／宿傩／饿狼／云裳写死次序保留、只去空类。开关 `XBattleScene.HIDE_EMPTY_STYPE`。
- T208 核查：`boss_info_rect()` 血弧显示首领时并入血条矩形（`BOSS_INFO_MERGE_BAR`）；回退下方中间摆法前还原列表行数（`XSkinBattleSkillList.set_rows`）。T210 核查：缺帧回落 abnormal→dying、sleep→dead 专项；旧快照缺 `state_motion` 键按 0。
- 新专项 `xiyou_hide_empty_stype`（14 项）；`xiyou_big_form_menu` 140、`xiyou_mira_dragon_idle` 42、`xiyou_appearance` 37、`xiyou_ring_seven_battle` 36 过。
- 玩家可见：天启篇战斗指令里，某一类技能一个都没有时，不再显示这一类。（待小A 审）

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/battle/battle_scene.gd` `XBattleScene.HIDE_EMPTY_STYPE` | 战斗指令按 addedSkillTypes 全列，渡鸦等写死 [魔法,战技,其他]，没学到也列 | 天启篇存档里某类技能一个都没有就不列 | Kyo 11-18「所有角色统一」 | `XBattleScene.HIDE_EMPTY_STYPE = false` | cc（T215） | 保留 |
| O-待定 | `modes/xiyou/battle/battle_scene.gd` `XBattleScene.BOSS_INFO_MERGE_BAR` | （T208 新增）首领信息区宽固定 300 | 并入血条矩形，长信息区时环不压右侧详情按钮 | T208 核查 P2-1 | `XBattleScene.BOSS_INFO_MERGE_BAR = false` | cc（T215） | 保留 |

## 交接板

- 下一步：无
- 用户试玩说明：天启篇战斗里没学到的技能类（如没有「其他」类技能的渡鸦）不再出现在指令里
- 需要用户决定：无
- 备注：我最初测试里 167 渡鸦上不了场，是 flags.tianqi 缺 difficulty 致 super_cap=-1，不是 bug（小A 查清：167～174 九死及以上能正常上场）；专项因此在西游起的战斗上事后打天启篇标记验证过滤。天启篇普通角色没战技时指令 6 项，`xiyou_ring_seven_battle` 的 `_state` 补一个战技凑 7 项。派单写 `XTianqiBase.on()`，实际用 `XTianqi.active(XState.current)`（`on()` 带默认关的 PHASE4）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log luiluu/t215
