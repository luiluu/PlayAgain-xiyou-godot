# 交付：cc/wukong-battlelog2

- 车道／工作者：B 界面／悟空（cc）
- 基线：总装九派单，从 cc/wukong-battlelog1 末端 85592620 切出（battlelog1 先合的话这里只多出本期）。
- 状态：可合并

## 盘点

| 项 | 原版（冻结 v0.28） | 本期 |
| --- | --- | --- |
| 技能分类·战斗指令 | 渡鸦／饿狼 `Window_ActorCommand.addSkillCommands` 包装：固定 [2,1,5] 三栏（`_skillTypes=[]` 关掉旧的左右翻页）；宿傩 [2,1,5,3]。照次序加，不排序，CP_MagicWeapon 去掉 3～6 的那层被盖掉 | 做了：`XActorModules.battle_skill_types`，`_command_entries` 用 |
| 技能分类·菜单 | `Game_Actor.addedSkillTypes` 包装：渡鸦不在战斗时 [2,1,5,3,4]、宿傩 [2,1,5,3,4]、饿狼 [2,1,5,4]；菜单 Window_SkillType 照 YEP_CoreEngine 再升序。`addedSkillTypesForMenu` 三家都包了，但 My_SkillTypeSwap 不在 plugins.js 里，没人调 | 做了：`XActorModules.menu_skill_types`，`XSkillScene.types()` 用 |
| 渡鸦魂簿说明 | `Window_SkillList.updateHelp` 包装：选中 10137 时 `_helpWindow.setText('灵魂：N　进阶：s/5　进阶印：n\n本阶达X魂得印；进阶后清零')`（五阶为「已完成五阶；灵魂可继续积累」，数字 toLocaleString） | 做了：`XRaven.ledger_help`，技能页说明卡整个换成这两行（字号同 O-007 的其它行） |
| 饿狼进阶原因 | `Scene_ActorAdvanced.onBottomConfirmOk` 包装：条件不足 buzzer＋`$gameMessage.add(原因)`，接着 onBottomConfirmCancel，不走原版的「进阶条件未达成」。菜单场景没有消息窗，这句回地图才出 | 做了：饿狼走蜂鸣，右上角只提示原因（当场出，同 O-094 的做法）。确认后 G.advance 失败那支（几乎碰不到）没动 |
| 饿狼神之触媒消息 | `creditVictory` 在 processVictory 之前 `$gameMessage.add('饿狼突破神之境界，获得神之触媒×1。')`。Olivia_VictorySequenceUI 的 processVictory 之后：下一帧 Window_Message 开始显示；500 毫秒 hideAllWindows 把窗口层全部 hide（消息窗也在内，逻辑照跑）；1000 毫秒建结算窗。按代码推：这句话只露出约半秒就被藏起来，打完字停在等确定，结算画面第一次按确定会被这个看不见的消息窗吃掉（Input.update 清掉触发） | **没做，要用户定**（见下）。这是读代码推的，没有浏览器实测 |
| 宿傩完全体外观 2643 | `Sprite_Actor.updateBitmap` 包装：进阶 3 时往 `_states` 塞 2643（多帧插件按状态选图）、`_mxSVActive` 时主图 y=40、隐藏武器 | 没做，留下一期（要先看重制的多帧战斗图怎么按状态选图） |

## 需要用户决定

- **饿狼神之触媒那句话怎么出**：原版几乎看不见（约半秒后被藏起来，还吞掉结算画面的一次确定）。建议：结算画面关掉之后、回地图之前，用消息窗正常显示一次（做成 O-待定，可回退）。另一个选择是照原版不显示。等 Kyo 定了再做，要做的话先用 `ui_reference` 战斗夹具实测一次原版的时机。

## 变更记录草稿

## 2026-11-01 【cc·悟空·未经审查】渡鸦／宿傩／饿狼技能分类与指令窗、渡鸦魂簿灵魂进度、饿狼进阶原因提示（dev.待定）

- `core/actor_modules.gd`：`MENU_SKILL_TYPES`／`BATTLE_SKILL_TYPES` 与 `menu_skill_types`／`battle_skill_types`（原版三家的 addedSkillTypes 与 addSkillCommands 包装）。
- `battle/battle_scene.gd` `_command_entries`：这三位的技能栏固定几栏、照次序（渡鸦、饿狼「技能·魔法·5 号」，宿傩再加 3 号）；别人照旧。
- `ui/skill_scene.gd` `types()`：这三位的技能分类照固定表升序，没学到的那类也列出；`_paint_text` 把说明卡换成几行字。
- `core/raven.gd` `ledger_help`：魂簿的说明卡写当前灵魂、进阶、进阶印与下一阶门槛。
- `ui/actor_advanced.gd`：饿狼条件不足时蜂鸣，右上角只给原因。
- 专项 `xiyou_battle_log` 加技能分类与魂簿用例（38 项）。

## 验证

- 选测 11 场景（CHECK_JOBS=3，墙钟 3.5 分钟）全过、无偶发：`xiyou_battle_log`（38/38）、`xiyou_battle_ui`、`xiyou_battle_options`、`xiyou_raven_battle`、`xiyou_raven_soul`、`xiyou_sukuna_battle`、`xiyou_garou_battle`、`xiyou_garou_progress`、`xiyou_actor_advanced`、`xiyou_skill_page`、`xiyou_party_skills`。日志 `04_验证/本地结果/并行测试/20261101_034331_9bee2j21/`。
- `语法检查.py` 通过。
- 饿狼进阶原因的蜂鸣与提示没写自动测试（界面按键流程，`xiyou_actor_advanced` 没有饿狼夹具），只看了代码路径。

## 交接板

- 下一步：饿狼神之触媒消息（等用户定，见上）；宿傩完全体外观 2643；饿狼星空外观。交接板「渡鸦遗留」里的灵魂进度行、技能分类与指令窗，「宿傩画面遗留」的技能分类与指令窗，「白龙」条里饿狼的进阶原因提示、技能分类与指令窗可以划掉。
- 用户试玩说明：渡鸦、宿傩、饿狼的战斗指令固定显示几栏技能（宿傩多一栏）；技能页分类照原版；渡鸦技能页选中「魂簿」时说明卡显示当前灵魂与进阶；饿狼进阶条件不够时会蜂鸣并提示原因。
- 需要用户决定：饿狼神之触媒消息怎么出（见上）。

## 进度账

- 专属角色画面遗留：技能分类与指令窗（渡鸦／宿傩／饿狼）、渡鸦灵魂进度行、饿狼进阶原因完成；饿狼神之触媒消息待定；宿傩完全体外观未做。

## 可优化（流程／工具／效率）

- 无。

## 本分支提交

- fce8198e WIP：技能分类、魂簿说明、饿狼进阶原因、专项用例
- 交付单与专项类型修正（本提交）
