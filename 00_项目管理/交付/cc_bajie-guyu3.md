# 交付：cc/bajie-guyu3

- 车道／工作者：B 界面（总装十派给八戒）／八戒（cc，八戒）
- 状态：进行中
- 分支从 cc/bajie-relic3 末端 13c7b3dc 切，工作树 `.claude/worktrees/pensive-ardinghelli-6b5eb0`。
- **交接**：这一期还没写代码。这个八戒会话已经接连做完谷雨二期 A、二期 B 和三法宝成长，上下文用得多，界面量也大，所以请开一个新会话接手。下面是已经查好的原版位置和重制挂点，接手照这个做。

## 范围（总装十）

谷雨剩下的界面：转移窗口（现在固定「给出 50%」，改成能选）、储备条（侧栏）、立绘与动作；顺手做说明卡里法宝条目的改写（万象长春盏）。照原版窗口布局与文字。

## 原版要点（冻结 v0.28）

- `js/codex/runtime/installNativeGuyuRuntime.js`：
  - 477 `G.statusText(b)`：侧栏名字后的状态字（「储」＋shortNumber(储备)，归根加「归根N」，另有花荫、待绽、花期等，往下读到 484）；475 `shortNumber`（亿／万）。
  - 485 `G.transferText(b, target, mode, ratio)`：转移窗口的说明文字。
  - 489～500 `Window_BattleSideHP.refresh`／`checkRefreshConditions` 包装：生命条画上储备与花荫（`G.totalShield`），储备与花荫变了就重画。
  - 501～510 `Window_BattleSideName.refresh`：名字行加 statusText。
  - 515～519 `Window_GuyuTransfer`（Window_Command，宽 320）：makeCommandList 按 `G.transferRatios(actor)` 列「给出／收回 × 比例」，不合法的灰掉。
  - 530～562 Scene_Battle 包装：createAllWindows 建窗口（542 位置居中）、onSkillOk 选了转移先开窗口、onActorOk 校验 `transferPreview`、onActorCancel 退回、`guyuUpdateTransferHelp`（选队友时帮助窗显示预览）、isAnyInputWindowActive／endCommandSelection／stop。
  - 565～680 立绘与动作：`queueVisual`（root／regenerate 等）、performAction／performActionEnd 包装、Sprite_Actor 的 startMotion／updateFrame／updateMotionCount／update／setBattler 包装（谷雨原素材待机稳定修复，v0.28 注释）。
- `js/codex/runtime/installThreeGrowthRelicRuntime.js` 76～88 `relicLines`：法宝说明卡条目（专属、等级需求、未进化时的「进化：…」、特效倍率按值分组成对、进化后的特效行、法宝每级四行），写进备注的 `<pos=APs …>`，有 texts 的倒序写入；texts 7912 在 63～75。

## 重制挂点（已查，未改）

- 战斗侧栏：`modes/xiyou/battle/side_status.gd`（生命条、名字行）；储备并进了最大生命（`XGuyu.param`），花荫在 `XGuyu.shield_of`，归根 `XGuyu.rooted`，待绽 `XGuyu.has_bud`。
- 转移的模式与比例：`XGuyu.transfer_mode`／`transfer_ratio`（静态量，默认给出 0.5），`XGuyu.transfer_ratios(b)`、`transfer_preview(b, t, mode, ratio)` 已有；窗口选完写这两个量即可（原版存在 Game_Action 的 _guyuTransferMode／_guyuRatio 上，重制要不要挂到行动上，看战斗输入流程怎么传）。
- 说明卡：`ui/character_help.gd`（一期已做谷雨技能的「成长：」行）；法宝条目要接在装备说明那条路径上，`XThreeGrowth.SPECS` 有名字与两句说明。
- 参照：`ui_reference` 目录有通用界面夹具（README 说明用法）；行为参照可仿 `guyu_battle_probe` 加例量 statusText／transferText／transferPreview 的文字与合法性。

## 变更记录草稿

（待写）

## 验证

（待写）

## 本分支提交

- 交接稿（本提交）
