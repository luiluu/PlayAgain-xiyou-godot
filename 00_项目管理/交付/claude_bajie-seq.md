# 交付：claude/bajie-seq（一期：行动序列画面余项）

- 车道／工作者：B 界面·工具／八戒（Claude，八戒_46）
- 状态：可合并

## 变更记录草稿

## 2026-10-22 【Claude·八戒·未经Codex检验】行动序列画面：动画随目标浮空／跳跃抬高，动画按正式版帧序推进（dev.待定）

- 清点：切片全部技能／物品的 yepSeq 指令（28041 条 WAIT FOR MOVEMENT 起共 130 种写法）对照 `sequence_player.gd`，画面部分 dev.087 起已做齐。移动、前进、后退、击退仍按正式版 WY 插件锁死坐标只计时（冻结源 `js/plugins/WY.js`：输入阶段后每帧把精灵 x/y 拉回出生点、清 _offsetX/_offsetY）；跳跃、浮空、透明、镜头、缩放、隐藏界面、逐段动画照常。剩下的画面缺口是 dev.087 记下的「动画跟随浮空高度」，本期补上。
- 动画随目标浮空／跳跃抬高（YEP_X_ActSeqPack2 `Sprite_Animation.updateBattlerPosition`）：头上／中心的动画每帧再抬高（浮空率＋跳跃率）× 战斗者精灵图高。敌人图高是原图（侧视取整一格），角色是 YEP_BattleEngineCore `Sprite_Actor.updateFrame` 建的一格大小 Bitmap，所以角色也抬高。原版这里调 `getFloatHeight` 会让浮空多走一步，所以身上有动画时浮空变快（投掷 414：浮空 2000% 本该第 35 帧到顶，开动画时第 33 帧到顶），照原样复现（`XBattlerSprite.anim_lift`，`battle_scene._start_animation` 的 follow）。
- 动画推进照正式版帧序（`sequence_player.gd` `_tick_anims`、`mv_animation.gd` `external`／`tick`）：演出期间由行动机在战斗者精灵之后、日志窗之前推进动画，先移除上一帧播完的，再推进其余；本帧新建的下一帧才开始推进（正式版 Sprite_Battler.updateAnimation 新加的子节点本帧 forEach 走不到）。原来动画自己在 `_physics_process` 推进，开始早一帧、移除晚一帧，两头抵消所以 WAIT FOR ANIMATION 时间一直对，但动画位置与浮空读数差一帧；演出结束后还在播的动画交回自己推进。
- 敌人 YEP 血条在 OPACITY 时不变淡：已核原版归属，`YEP_X_VisualHpGauge` 把血条窗口加在 `this.parent.parent`（战场的父层），不是敌人精灵的子节点，不随敌人透明度；Godot 血条本就挂在 `field` 上，一致，dev.087 的「原版归属未核」销掉。
- 参照：`ui_reference` 的 `__seqRef` 每帧另记战场上的 Sprite_Animation（目标、位置、_duration、_delay）；`压缩序列参照.py` 收进 `anims`（相对目标精灵的位移）。新读数 `tests/fixtures/action_sequence_float_oracle.json`（`__seqRef.suite([...], 'action_sequence_float_oracle')`）：s414_anim 投掷（动画 1 播着时浮空）、s463_anim 升龙拳（动画 302 播着时跳跃）、s161_anim（角色自己浮空时身上放动画 129）、s414 关动画。
- 测试：`tests/xiyou_sequence_visual` 54→70 项：新 4 段逐帧比指令时间、帧数、镜头、日志行、不透明度／浮空／跳跃／动作，另逐帧比动画相对目标的位置（`*_anim_follow`）。旧 9 段与反击致死、多段血条、攻击动画镜像仍全过。
- 验证：`并行测试.py` 跑 `xiyou_sequence_visual` 70、`xiyou_mv_animation` 21、`xiyou_battle*`（battle 8、battle_events 108、battle_options 92、battle_ui 58、battleback_save 5）、`xiyou_combat` 34、`xiyou_drop_dh` 12、`xiyou_drop_record` 26、`xiyou_action_sequence` 115、`xiyou_determinism` 372、`xiyou_flow` 48、`xiyou_hangup*`（25／226／57）、`xiyou_otb` 22，全过。没改切片、转换器、探针，不用重跑同步。
- 未完成（属结算，本期不做）：序列里的公共事件（ACTION COMMON EVENT／COMMON EVENT 只占帧）、CHANGE VARIABLE／SWITCH、EVAL 不执行；FORCE CRITICAL（3 条）、CAT BEGIN（4 条）照不认识的行占一帧，规则效果未核。FADE／FLASH／TINT／SHAKE SCREEN 切片未用到，仍只占帧。

## 交接板

- 下一步：第 3 条「YEP 行动序列的画面部分（移动/跳跃/镜头/逐段动画）」改为已完成（移动按原版锁坐标只计时，动画随浮空／跳跃 dev.待定）；剩「序列里的公共事件/变量/EVAL」（结算，另派，不归八戒表现层）。
- 用户试玩说明：开「技能动画」时，把敌人抛起或跳起的招式（投掷、升龙拳等），动画会跟着被抛起的敌人走，不再留在原地。
- 需要用户决定：无

## 进度账

- 不加点（演出细节与参照）。

## 本分支提交

- 64c04ad 序列演出：动画随目标浮空／跳跃抬高，动画按 MV 帧序由行动机推进（含参照工具、读数、测试）
- 本交付单
