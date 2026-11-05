# 交付：cc/bailong-ui11

- 车道／工作者：B 界面／白龙（cc，ui11）
- 状态：验证中

## 变更记录草稿

## 2026-11-05 【cc·白龙·未经审查】战斗者状态 overlay；ui9 余下五页接翻页；Boss 红条拖尾封顶、按键连发照原版、饿狼胜利提示上画面、空袖藏星技能按武器灰掉 ui11（dev.待定）

**状态 overlay**（ui10 发现整块缺失，派单第 0 条）：`XBattlerSprite` 加 `overlay` 子精灵，照 `rpg_sprites` Sprite_StateOverlay＋`YEP_X_VisualStateFX`＋`YEP_X_ActSeqPack2` updateStateSprites：插在身体之后；`States.png` 每格 96×96，锚点 (0.5, 1)；SSEP 节拍 StateOverlay÷BattleSpeed(Default)＝8÷2＝4 帧换一格、0～7 循环，换格时才重读 overlay 号（`states()` 顺序第一个 overlay>0 的，84 个状态带 overlay）；y＝−(图高 − 64×缩放) − ceil((浮空＋跳跃)×图高)。敌人的精英 1.8 倍、呼吸都在原版 Sprite_Enemy 本身上，overlay 跟着缩；y 用不含呼吸的倍率算（原版 updateStateSprites 在 updateScale 之后、updateBreathing 之前），角色 Sprite_Actor 不缩（0.75 只缩身体）。侧视敌人可见性跟 `<Sideview Show／Hide State Overlay>`（参数 true，186 个 SV 敌人都没有隐藏备注）。SV 敌人浮动在 ActSeqPack2 加上又被 AnimatedSVEnemies 减回，净 0，不算。原版读数（冻结 v0.28 战斗夹具，逐帧）存 `tests/fixtures/state_overlay_oracle.json`：敌人 1（图高 60）睡眠＋中毒取 overlay 7、y＝4、每 4 帧一格；角色 y＝0。回退开关 `XBattlerSprite.STATE_OVERLAY = false`（不画，回到原来没有这层）。这是补缺失内容，按派单仍做成开关、登记 O-待定。
- 顺手核：ui10 截图里敌人名右边的「4」是 `Olivia_WeaknessDisplay` 窗口里的状态图标（`Sprite_StateIcon`，中毒图标 916）带的 `YEP_BuffsStatesCore` 剩余回合数，选敌时才看得到。重制选敌时名字旁边**没有这排状态图标**，本期没做（见下「下一期」）。
- 原版小毛病（没照做）：`krz_state_re` 的 `states()` 缓存在 addState 之后要等下一次 refresh 才更新，overlay 会晚一点出现；重制读当前状态。

**ui9 余下的翻页**（派单 0b）：原版这五个窗口都是 Window_Selectable／Window_Command，不接管 pageup／pagedown，所以照 `XMenu.page`／`wheel` 接上 Q／E（PageUp／PageDown）整页翻、滚轮只滚窗口：事件选项窗 `XChoiceWindow`、更衣 `XCostumesScene`、角色进阶名单 `XActorAdvancedScene`（光标变了重画状态）、修炼队员目录 `XTrainingScene`（另补滚轮）、怪物图鉴掉落列表（另补滚轮）。`xiyou_list_paging` 的扫描豁免去掉了四个「待核」。向原版对齐，跟 `XMenu.LIST_PAGING` 一起回退，不占 O 号。

**优化四条**（派单 1～4，每条一个 O-待定、一个开关）：
1. Boss 血条红条拖尾：原版每帧走 1+差/160，差越大越慢收拢（一下打掉五成血要上千帧）→ 每次目标血量变了重新计 90 帧，每帧至少走「剩余差÷剩余帧」，最迟约 1.5 秒追上；小伤害原版本来更快，照原版。`XBossHpBar.RED_TRAIL_CAP = false` 回原版。
2. 按住键连发：重制菜单靠系统按键回显，节奏随玩家的系统键盘设置 → 照 rpg_core `Input.isRepeated`：按下触发，按住满 24 帧后每 6 帧一次，只认最后按下的键（正式版没有插件改这两个数）。做法：`GameApp` 下加 `XKeyRepeat` 节点，在 `_input` 吞掉系统回显、按帧数自己补回显事件，各页 `_unhandled_input` 写法不变。用 `_input` 自己收键的四页（胜利结算、赌场、网页面板、Boss 状态面板）不受影响。`XKeyRepeat.MV_REPEAT = false` 回到系统节奏。
3. 饿狼神之触媒等胜利提示：原版塞进战斗日志，只露约半秒、还吞一次确定；重制原来干脆没上画面（`victory_texts` 只存不显示）→ 结算画面关掉后用消息窗显示一次，按确定关；挂机直接回地图时不弹。`XBattleScene.VICTORY_TEXT_MESSAGE = false` 回到不显示。
4. 云裳空袖藏星借技能：天衣铺选技能时不看穿的人的武器 → 云裳当前武器用不了的技能行灰掉、选不了，行尾写「（需装备剑／刀）」这样的缺什么武器；能用的照常；借来技能本身的武器要求不改。说明写在行尾（选项窗没有说明卡）。`XYunshangShop.BORROW_WTYPE_FILTER = false` 回原版。

## 优化登记草稿

| 编号 | 位置 | 原版 | 现在 | 理由 | 回退 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 战斗者状态 overlay（`battle/battler_sprite.gd`） | 有（VisualStateFX） | 重制原来没有，照原版补上 | 缺失内容 | `XBattlerSprite.STATE_OVERLAY = false` | cc（白龙） | 待用户决定 |
| O-待定 | Boss 血条红条（`battle/boss_hp_bar.gd` `red_step`） | 每帧 1+差/160，千万级要拖几十秒 | 每次掉血 90 帧内追上，小伤害照原版 | 拖尾过长 | `XBossHpBar.RED_TRAIL_CAP = false` | cc（白龙） | 待用户决定 |
| O-待定 | 按住键连发（`core/key_repeat.gd`） | 24 帧后每 6 帧（重制原来随系统设置） | 照原版 24／6 帧 | 节奏一致 | `XKeyRepeat.MV_REPEAT = false` | cc（白龙） | 待用户决定 |
| O-待定 | 胜利提示（`battle/battle_scene.gd` `victory_messages`） | 日志里露半秒、吞一次确定 | 结算后消息窗显示一次 | 看不清 | `XBattleScene.VICTORY_TEXT_MESSAGE = false` | cc（白龙） | 待用户决定 |
| O-待定 | 空袖藏星选技能（`ui/yunshang_shop.gd` `borrow_pool`） | 全列，不看武器 | 用不了的灰掉并写缺什么武器 | 借来多半用不了 | `XYunshangShop.BORROW_WTYPE_FILTER = false` | cc（白龙） | 待用户决定 |

## 下一期

- 选敌时名字旁的状态图标排（`Olivia_WeaknessDisplay`：`Sprite_StateIcon` 带剩余回合数）：重制没有，归界面车道。位置读数：窗口 640×72、图标在窗口内 (392, 16)（敌人 0，名字居中）；要做时再用战斗夹具读几种状态数量下的排法。

## 交接板

- 下一步：选敌名字旁的状态图标排（见「下一期」）；胜利结算背景仍等 Kyo 定。
- 用户试玩说明：战斗里中毒、睡眠、混乱等状态会在角色／敌人头上显示原版那种动画图（如睡眠的「ZZZ」）；Boss 血条被大量扣血时红色拖尾最多约 1.5 秒就追上；菜单里按住方向键，连发节奏和正式版一样（按住约 0.4 秒后每 0.1 秒一格）；饿狼拿到神之触媒时，结算画面关后会弹一句提示、按确定关；天衣铺给云裳配空袖藏星时，她当前武器用不了的技能是灰的，后面写着要什么武器；选项窗、更衣、角色进阶、修炼、图鉴掉落列表能按 Q／E 翻页。
- 需要用户决定：五个 O-待定（见上表）。

## 进度账

- 战斗规则与画面：补上「状态 overlay（84 个状态）」这一项缺口。
- 界面页面：零散细节 +0（翻页补齐与核实）。

## 可优化（流程／工具／效率）

- 新加 `class_name` 的脚本，`并行测试.py` 跑之前要先 `godot --import` 刷全局类表，不然测试报「找不到类型」白跑一轮（这次踩到）。建议 `并行测试.py` 开跑前比一下 `.godot/global_script_class_cache.cfg` 与工程里的 `class_name`，缺了自动补一次 import；小，归工具车道。

## 验证

（跑完填）

## 本分支提交

（跑完填）
