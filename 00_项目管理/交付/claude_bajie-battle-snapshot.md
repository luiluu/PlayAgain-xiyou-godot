# 交付：claude/bajie-battle-snapshot

- 车道／工作者：B／C 战斗表现／八戒（Claude，重制_八戒_20）
- 状态：可合并

## 变更记录草稿

## 2026-10-19 【Claude·八戒·未经Codex检验】战斗日志数值快照：演出只读日志（架构审查第 6 项，dev.待定）

- 日志写入时记下画面要用的值，表现层不再读战斗者的实时状态（整次行动先结算完才演出，实时状态已是最终值）：
  - `XBattleLogic.view_of／views／move_flags／mark_views`：行动记录带全体读数（HP/MP/TP 与上限、倒下、防御、能否行动、状态图标）；命中记录（含反击、反射）带行动者与目标结算后的读数；再生、IMMORTAL 解除的倒下也带。只在日志写入处加字段，不改公式、随机数与结算顺序（`_apply` 未动）。
  - `XActionSequence._visual_entry`：每条序列指令执行前记全体「能否行动、是否活着」（moves）；FACE 的参照组按执行当时解析（face_group）；HP/MP/TP、状态、BUFF、IMMORTAL 指令执行后记全体读数。
  - `XSequencePlayer`：can_move／PERFORM FINISH 的活着成员改读当前指令的快照；反击致死不再取消此前的跳跃与移动。
  - `XBattleScene.view／show_views／clear_views`：敌人血条与名字颜色、右侧状态栏（`XSideStatus.view`）、待机动作（`XBattlerSprite.view`，倒下／濒危／防御）按日志读数显示，演出结束清空回到实时状态。
- 对正式版读数修正的演出时序（`sequence_player.gd`）：反击／魔法反射照 displayCounter／displayReflection 加一行日志并等 messageSpeed；倒下的命中算状态变化（多排 3 个日志方法）。原来反击致死后的序列快 11 帧。
- 敌人血条照 YEP_X_VisualHpGauge：HP 变了按 Gauge Duration（30）定每帧滑动量 ceil(差/30)，显示值逐帧滑到新值，滑动中保持显示；序列演出中与精灵同帧更新。
- 参照：`ui_reference` 的 `__seqRef` 每帧另记敌人 [实际 HP, 血条显示值]；`suite(列表, 读数名)` 可另起读数名，`run` 加 `prep(角色, 敌人)`；`压缩序列参照.py` 第二个参数为输出文件名并带出 hp。新读数 `tests/fixtures/action_sequence_hp_oracle.json`：s131 多段攻击（角色 10，正式版目标第 4 下倒下），s104_counter_death（角色 10 生命 1、全体敌人反击率 1，首个 ACTION EFFECT 被反击击倒）。原 9 段读数未重采。
- `tests/xiyou_sequence_visual` 27→35 项：反击致死逐帧指令时间与跳跃高度（全 80 帧与正式版一致，首个 ACTION EFFECT 第 45 帧；旧代码为第 36 帧）、结算照旧；多段攻击每下画面 HP＝该下结算值、换值帧与正式版一致（23/36/49/62）、血条滑落规则、演出后回到实时值。旧代码下这几项失败（已实测）。
- `tests/xiyou_flow` 的 `cmd_enter_not_map_action` 修稳：按 ⌘Enter 前先等地图空闲（首次到达的自动事件在满负载时可能超过原来的 600 帧），检查同时要求按前空闲；加 10 个 CPU 满载进程跑两次都过。
- 验证：合并 main 后最终 `检查.sh --oracle` 全部通过（0942fbc 上，rc=0）；另跑 xiyou_battle_ui 37、xiyou_battle 8、xiyou_combat 34、xiyou_action_sequence 109 全过。
- 提交：b6ef3e9 b1380d8 7b741b8 41eade5 644408d
- 未完成／已知问题：正式版敌人血条另有 contentsOpacity 每帧 ±32 的淡入淡出，Godot 仍按 0.5 秒计时显隐；角色状态栏在正式版的换值帧未取读数。O-054 未使用。

## 交接板

- 下一步：删掉「偶发失败待修稳（八戒）：xiyou_flow 的 cmd_enter_not_map_action…」一条（已修）。战斗 58%→61% 的增量待沙僧复核本分支后再认（核查报告第三批的死亡时序问题已修并补正式版参照）。
- 用户试玩说明：多段攻击时敌人血条每一下掉一截并逐渐滑落（原来第一下就显示最后血量）；出招者被反击打倒时，前面的跳跃动作照常播放。
- 需要用户决定：无。

## 进度账

- 战斗：不改（58% 待沙僧复核后决定是否认 61%）。

## 本分支提交

- b6ef3e9 WIP: 战斗日志记下画面快照，演出改读快照
- b1380d8 WIP: 序列演出回归：反击致死跳跃时序、多段攻击血条逐段
- 7b741b8 xiyou_flow：⌘Enter 检查前先等地图空闲
- 41eade5 序列演出对正式版反击致死与多段攻击读数；__seqRef 记敌人 HP
- 644408d 敌人血条照 YEP_X_VisualHpGauge 逐帧滑落
