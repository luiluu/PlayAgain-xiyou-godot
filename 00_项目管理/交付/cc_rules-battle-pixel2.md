# 交付：cc/rules-battle-pixel2

- 车道／工作者：C 规则·战斗画面／八戒（cc，GB11）
- 状态：可合并
- 车道路径：/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/unruffled-margulis-e6543b

分支从 main d206fecc5 切（dev.433 收尾之后）。

## 做了什么

接一期 rules-battle-pixel 没比的战斗场面：敌我站位、技能动画层、胜利镜头与结算画面、全灭，外加右侧状态格的轮换内容（状态图标余项）。原版 v0.62.12 无头截图对 Godot 窗口截图。

- 参照 `ui_reference/battle_pixel_ref.cjs` 加第二个参数选场景（默认 p1＝一期，读数格式不变）：`layout`／`anim`／`victory`／`defeat` 都用敌群 2（三只嘤嘤怪），每个场景开一个新的无头 Chrome。另记右侧状态格 `_cqRows`。
  - 顺手修了参照夹具的竞态：等地图场景时只看「是 Scene_Map」，地图还没建好窗口就 push 战斗，第二个场景起偶尔报 `Scene_Map.stop` 读 `_messageWindow` 出错。现在等到 `isActive` 且消息窗已建。
- Godot `tests/xiyou_battle_pixel.gd`：一期场面跑完后依次开四场新战斗，截同名图（43 项，无头 32 项）。技能动画改成手动推进、按动画自己的帧对齐截图（原先按物理帧等，截图前多走一帧，看着像「重制早一帧闪屏」，其实是测量差）。
- `battle_pixel_compare.py` 加二期区域。

## 结论（逐场面，修后）

| 场面 | 结论 |
| --- | --- |
| 敌我站位 | 一致。三只嘤嘤怪原位 (262,331)／(353,409)／(201,463)，角色 x 819、y 230／329／427／526 两边相同；精灵墨迹框四边差 ≤3px（呼吸缩放相位） |
| 技能动画层 | 一致。动画 14（突刺/冰，含全屏闪）打敌人、动画 1 打 1 号角色，第 4／12／24 帧平均差 0.4～2.7、墨迹框差 ≤1px |
| 胜利镜头 | 一致。第 60 帧镜头 (652,380) 放大 1.2，第 300 帧 (700,460)×2，角色墨迹框差 ≤1px |
| 胜利结算画面 | 标题、精魄／经验值、四行角色（等级提升字样的淡出、经验条、数字）一致（平均差 ≤8，墨迹框差 ≤1px）。**修了**底部「ESC 或者 点击屏幕 退出界面」整行偏右 6～7px |
| 全灭 | **修了**：原版是底部整宽消息窗「狗逍遥的队伍被击败了。」（TextManager.defeat，等按键），重制原来在战斗日志行闪 1.2 秒「全军覆没……」。修后消息窗墨迹框四边差 0 |
| 右侧状态格 | **修了**轮换内容：原版只轮 visibleState 的状态（有说明的），再接强弱化、层数大于 1 时画数字；重制原来凡带图标的状态都轮。另有顺序差、全灭当下内容差没改（见「没做的」） |

两边截图里固定不同、不算差的：原版左上角挂机界面（重制是「自动／变速」按钮，一期已核层次）、行动条顺序（两边随机数不同）、原版无头时结算画面出现时刻靠 setTimeout 真实时间（帧数不准，结算截图按画面出现后的帧数比）。

## 改了什么

- `modes/xiyou/battle/battle_scene.gd`：全灭抽成 `_defeat()`／`defeat_text()`／`_defeat_message()`，照原版用消息窗显示 `TextManager.defeat`（%1＝队名，同逃跑的 `XPreempt.party_name`），快速战斗照旧跳过；删掉只剩它在用的 `_say()`。
- `tests/xiyou_battle_end_ce.gd`、`tests/xiyou_review_fix.gd`：快速战斗子类原来覆写 `_say` 跳过失败信息，改成覆写 `_defeat_message`（不然会停在消息窗等按键）。
- `modes/xiyou/ui/victory_screen.gd`：提示窗宽＝文字宽＋textPadding×2（原来只加 6）。
- `modes/xiyou/battle/side_status.gd`：新 `XSideStatus.cell_rows()`（installEquipmentStatusRuntime stateRows：去重、visibleState、接强弱化、层数），状态格画层数；回退开关 `XSideStatus.CELL_FILTER`（false 回原来的「带图标全轮」）。按状态号缓存 visibleState。
- `modes/xiyou/battle/battle_logic.gd`：画面快照 `view_of` 的 `icons` 换成 `cell_rows`（只有右侧状态格读它）。**战斗核心文件**，只动了画面快照这一处，不碰规则。
- 参照、对照脚本、`ui_reference/README.md` 一段用法。

## 优化登记（表格行草稿）

无。三处修都是改回原版的样子，不登 O 号；`CELL_FILTER` 是改回原版的回退开关。

## 验证

- 语法检查 667 个 .gd 0 问题；工具快速回归 70 秒全过。
- `xiyou_battle_pixel` 窗口模式 43/43、无头 32/32（新：站位原位、动画剩余帧对齐原版 45／37／25、胜利镜头 300 帧放大 2、全灭文字与消息窗、状态格图标集合对原版读数、visibleState 藏越战越勇、强化层数、CELL_FILTER 回退）。
- 本机选测：`xiyou_battle_ui xiyou_battle_end_ce xiyou_review_fix xiyou_victory_text_flow xiyou_battle_pixel xiyou_flow` 6 个全过（181 秒）。
- 云端选测（`选测.py main --list` 312 个，含 xiyou_determinism、xiyou_rules 全段、事件对照）：提交 ba19e0ed3，结果见下行。
- 云端结果：通过，312 个场景 16 片，最长一片 9.8 分钟；偶发 1 个 `xiyou_floor_reach080`（并行失败、单跑通过，与本分支改动无关的楼层场景）。运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42791410027

## 变更记录草稿

## 2026-11-10 【cc·八戒·未经审查】战斗画面像素对照二期：站位、技能动画、胜利结算、全灭、状态格（dev.待定）

- 接一期没比的战斗场面，原版 v0.62.12 对 Godot 截图对照（敌群 2）：参照 `battle_pixel_ref.cjs` 加场景参数（layout／anim／victory／defeat，每场新开无头 Chrome，修了地图没建好就进战斗的竞态），`xiyou_battle_pixel` 依次跑同样四场，`battle_pixel_compare.py` 加二期区域。
- 一致：敌我站位、技能动画层（按动画帧对齐后平均差 ≤3）、胜利镜头、结算画面主体。
- 修：全灭照原版在底部消息窗显示「<队名>被击败了。」等按键（原来日志行闪 1.2 秒「全军覆没……」）；胜利结算底部「ESC 或者 点击屏幕 退出界面」偏右 6～7px；右侧状态格只轮有说明的状态并接强弱化、画层数（原来带图标的全轮，原版有 275 个带图标状态不进状态格；回退 `XSideStatus.CELL_FILTER`）。
- 玩家可见：全军覆没时出现消息窗，要按一下才继续；胜利画面右下角提示位置对齐原版；右侧角色头像左边的小状态格不再轮到没有说明的状态，强化／弱化也会轮到，叠层的显示层数。
- 验证：语法检查 0 问题；工具回归全过；`xiyou_battle_pixel` 窗口 43/43；本机选测 6 个全过；云端选测 312 个通过（偶发 1 个 xiyou_floor_reach080）。
- 未完成／已知问题：状态格里被动状态的轮换顺序与原版不同（原版按被动来源顺序）；全灭当下原版战斗结束清掉状态后格子是「i」，重制仍显示状态；胜利、全灭音乐的 ME 没核。

## 交接板

- 下一步：无新增。
- 用户试玩说明：全军覆没时屏幕下方出现「××的队伍被击败了。」，按一下继续；胜利画面右下角「ESC 或者 点击屏幕 退出界面」位置对齐原版；右侧状态小格子只轮有说明的状态，也会轮到强化／弱化。

## 进度账

- 战斗画面像素对照：站位、技能动画层、胜利结算、全灭、状态格内容补齐对照（不改完成度百分比，只补依据）。

## 没做的

- 状态格被动状态轮换顺序：原版 _cqRows 是 995→1691→1631（被动来源顺序，优先级都是 50），重制 `states()` 按号排成 995→1631→1691。要改得动 `XBattler.states()` 的顺序，牵涉战斗核心，没做；只差轮到哪个图标的先后。
- 全灭当下的状态格：原版 processDefeat 里 endBattle 清掉战斗状态，0.5 秒刷新后格子是「i」；重制全灭时状态还在（显示状态图标）。只影响全灭那一下，没改。
- 胜利 ME（victoryMe）与失败 ME（defeatMe）：重制都没放（胜利只放 Olivia 的结算 BGM）。不是画面，没在本车道做，可派给音频。
- 状态格原版还能点开看状态详情（installEquipmentStatusRuntime 的弹窗）；重制没有，没查。

## 可优化（流程／工具／效率）

- 已做：参照脚本每个场景新开无头 Chrome，并修了等地图场景的竞态（一期单场景时碰巧没撞上）。回退：删 runScene 回同页导航。
- 建议：截图对照里「按动画自己的帧对齐」比「按物理帧等」稳得多；别的逐帧截图测试（如 popup_multi）如果出现「重制早一帧」，先看是不是截图等待多走了一帧。

## 本分支提交

- ba19e0ed3 WIP：参照四场景、Godot 截图、三处修
- （本交付单提交）
