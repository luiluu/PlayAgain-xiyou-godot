# 交付单 T215：战斗指令某类技能一个都没有就不显示（＋T208/T210 核查遗留）

分支 luiluu/t215。执行者 cc（Sonnet＋medium）。核查：待审查。

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
dev.待定｜T215｜战斗指令：天启篇里某类技能一个都没有就不列（HIDE_EMPTY_STYPE）；T208 首领信息区并入血条（BOSS_INFO_MERGE_BAR）、列表回退摆法还原行数；T210 缺帧回落专项、旧快照缺 state_motion 按 0。玩家可见句（待小A 审）：「天启篇战斗指令里，某一类技能一个都没有时，不再显示这一类。」

## O-待定登记草稿
- O-待定A｜战斗指令空技能类隐藏｜XBattleScene.HIDE_EMPTY_STYPE（false＝回原版全列）｜状态：保留
- O-待定B｜首领信息区并入血条矩形｜XBattleScene.BOSS_INFO_MERGE_BAR（false＝回 300 宽）｜状态：保留

## 补（小A 核后）
xiyou_big_form_menu 加 set_rows 还原断言（140/140）；xiyou_mira_dragon_idle 加旧快照缺 state_motion 键按 0 断言（中毒场景）。
