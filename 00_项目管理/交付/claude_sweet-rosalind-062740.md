# 交付：claude/sweet-rosalind-062740

- 车道／工作者：B 界面·C 战斗画面／八戒（Claude，重制_八戒_19）
- 状态：可合并

## 变更记录草稿

## 2026-10-18 【Claude·八戒·未经Codex检验】战斗演出：YEP 行动序列画面与 Battle Camera（dev.待定）

- 行动序列的画面部分：`XActionSequence` 照执行顺序记下 `seq_phase`/`seq`/`seq_target`/`seq_end` 画面条目（不改结算）；新 `battle/sequence_player.gd`（XSequencePlayer）逐物理帧复现正式版行动机与日志窗方法队列（DISPLAY ACTION、WAIT 系列、MOTION、FACE、FLOAT、JUMP、OPACITY、HIDE/SHOW BATTLE HUD、PERFORM START/ACTION/FINISH、CAST/ACTION/ATTACK ANIMATION、ANIMATION n、SE、HP/MP/TP show、DEATH BREAK、注释与坏备注行占一帧等）；新 `battle/battle_camera.gd`（XBattleCamera）照 YEP_X_ActSeqPack3 的镜头点、缩放与夹边。
- 原版发现：正式版 WY 插件在输入阶段后把战斗者坐标锁死，序列里的移动、前进、后退、击退画面上都不动，只占等待帧（WAIT FOR MOVEMENT 照等）；Godot 照此只计时。跳跃、浮空、透明、镜头、隐藏界面都照常显示。
- 设置页「Battle Camera」开放（默认 ON，确定切换、右开左关；关时镜头命令直接跳过），33 项开放 29 项。
- 顺带修云端转来的问题：`battler_sprite._body_material()` 不再把场景外观里自带材质的子节点改成用父材质。
- 战斗动作：PERFORM ACTION 的咏唱/技能动作改照 Game_Action.isMagicSkill（技能类型在 System.magicSkills）。
- 参照：`ui_reference` 新增 `__seqRef`（行动序列逐帧读数，先载好动画图）与 `压缩序列参照.py`；正式版 9 段（普攻、幻化龙爪 开/关镜头、开动画、跳跃 104、浮空 161、咏唱 51、附加状态 73）存 `tests/fixtures/action_sequence_oracle.json`。新测试 `tests/xiyou_sequence_visual` 27/27：每条指令执行帧、总帧数、镜头层位置与缩放、窗口层隐藏、日志行数、战斗者不透明度/浮空/跳跃/动作逐帧一致。窗口模式截图在 `04_验证/本地结果/序列画面/`。
- 测试调整：`xiyou_battle_options` 原「各变速档总帧数相同」改为「变速档更短」（YEP 移动与 WAIT 随 battleAniSpeed 缩短，同正式版）；`xiyou_combat` 反击/反射断言先去掉画面条目。
- 验证：合并 main（3d4ba44）并 --补齐 后 检查.sh --oracle 全部通过（worktree 里 generated/oracle 缺主工作区新出的 battle_events.json，已从主工作区复制）；专项 xiyou_battle*、combat、determinism、action_sequence、hangup_options、troop_events、drop*、mv_animation、flow 通过。
- 未完成：序列里的公共事件、变量、开关、EVAL 不执行（ACTION COMMON EVENT 只按 updateEvent 多占一帧）；FADE/FLASH/TINT/SHAKE SCREEN 只占帧不画（切片数据未用到）；动画跟随浮空高度（Sprite_Animation.updateBattlerPosition）未做；敌人 YEP 血条在 OPACITY 时不随敌人变淡（原版归属未核）。O-052 未用到。

## 交接板

- 下一步：序列里的公共事件（ACTION COMMON EVENT、COMMON EVENT）与 CHANGE VARIABLE/EVAL 接到战斗事件解释器时按规则对照（属规则，另派）；八戒审查遗留项照旧。
- 用户试玩说明：战斗里有镜头的技能（如幻化龙爪）会先让其他人变透明、镜头拉近行动者再复位；跳跃类技能角色会跳起；动作切换的时机与正式版逐帧一致。设置里「Battle Camera」可以关掉镜头拉近。
- 需要用户决定：无

## 进度账

- 战斗规则与战斗画面：58% → 61%（八戒初值，待沙僧复核）：行动序列画面部分（镜头、跳跃、浮空、透明、动作、逐段等待）与正式版逐帧一致
- 界面页面：设置页 33 项开放 28 → 29 项（Battle Camera），按半页计不变

## 本分支提交

- 499643c WIP：ui_reference 加 __seqRef 行动序列逐帧读数
- 9509398 战斗演出：YEP 行动序列逐帧演出、战斗镜头、Battle Camera 开关
- 6a87a78 行动序列画面：文档、截图选项、测试随正式版变速调整
- 3d4ba44 合并 main
- 交付单可合并
