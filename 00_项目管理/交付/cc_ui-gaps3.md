# 交付：cc/ui-gaps3

- 车道／工作者：B 界面／界面三期 FD3（cc）
- 状态：可合并

## 盘点（原版 v0.62.12 全部系统页／菜单／弹窗对重制）

做法：从 `plugins.js` 启用的插件、`js/codex/**` 运行时和 `rpg_scenes.js` 里抽出全部 `Scene_*`（49 个）与 `Window_*`／`Sprite_*` 类（141 个），逐个在重制 .gd 里找（重制注释照例写原版类名）；找不到的 55 个再逐个看原版有没有入口、重制有没有同功能但没写类名。

### 缺口清单（按玩家能看到的程度排）

| # | 原版 | 玩家看到什么 | 结论 |
| --- | --- | --- | --- |
| 1 | MOG_TitleSplashScreen `Scene_Splash_Screen` | 每次启动先放 titles2/Splash_0～2 三张「大脑，在颤抖」（各约 3 秒，确定或点一下可跳） | **没做 → 本期做了**（`ui/splash_screen.gd` XSplashScreen；切片图片表加 3 张） |
| 2 | YEP_X_Autosave `Window_Autosave` | 读档进地图右下角「存档加载成功！」、事件自动存档后「存档成功！」（图标＋黑色渐变底，2 秒淡出） | **没做 → 本期做了**（`ui/autosave_notice.gd` XAutosaveNotice）；原来 `mv_event_core` 注释写着「小字不做」 |
| 3 | v0.27 轮回随机角色 `Window_Draft*`（9 选 5） | 轮回入口选「随机阵容」 | 已知不开放（O-035），入口只给常规阵容，不动 |
| — | installNativeHonghuangRuntime `Scene_PowerKeep` | 旧档权能超上限时进地图强制整理 | 原版只对 MV 旧档触发（新局 free＝[]），重制不迁移 MV 存档，**走不到**；权能遗忘符页已做（`ui/power_forget.gd`） |
| — | StateHelp `Scene_StateHelp` | 战斗队伍指令「状态」 | 参数全空：菜单入口、按键、触摸都是关的，只剩队伍指令窗；OTB 没有队伍指令窗（`battle_scene.gd` 第 12 行），**原版走不到** |
| — | LL_GalgeChoiceWindowMV `Scene_GalgeChoice` | 插件指令开的选择页 | 全部地图／公共事件／敌群没有调用，**走不到** |
| — | `Scene_Name`（事件 303 输入名字） | — | 事件里没有 303，**走不到** |
| — | hc.js `Scene_CraftingSpecific` | 指定类别的制作页 | 重制制作（`ui/crafting.gd`）已覆盖，插件指令走 XCrafting |
| — | `Scene_Gameover`、`Scene_Debug` | — | Gameover 由地图／解释器处理；Debug 不做 |

其余 41 个场景、86 个窗口类在重制里都能找到对应实现（多数窗口是已做场景里的子窗口，只是注释没写原版类名：进阶的 Index／Gold／BottomConfirm、仓库 Title／Option／Category、宠物与合成确认窗、换装确认、图鉴子窗、成就书子窗、MapTransfer 的 MapList／DropDetail、商店 Category、存档页 SaveInfo、整队 PartySelect／Detail、胜利 Items、侧栏 SideBattleUI 各条、VisualHpGauge、选敌名字（WeaknessDisplay 接手）等）。

### 上一期线索（FD2）

修行面板两页简化、流萤进阶大图、改版向导流萤页都已在 main；至臻闪光其余路径原版本来不闪（见 cc/ui-gaps2 交付单）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·开场图空白 | `modes/xiyou/ui/splash_screen.gd` `XSplashScreen` | MOG_TitleSplashScreen create 里 `for (i = 0; …)` 从 0 数，参数表键是 1～10，第 0 项 undefined 不等于 ""，先压进一张空图：开场先黑屏一整轮（淡入 51＋停 90＋淡出 51 帧，约 3 秒）才出 Splash_0 | 去掉这张空图，直接从 Splash_0 放 | 原版 bug（下标错一位），黑屏像卡住 | `XSplashScreen.BLANK_FIRST_V028 = true` | cc（界面 ui-gaps3） | 待用户确认 |

## 变更记录草稿

## 2026-11-07 【cc·界面·未经审查】启动开场图、存读档小字补上；界面缺口重新盘点（dev.待定）

- 盘点：原版 v0.62.12 启用插件＋Codex 运行时＋rpg_scenes 的 49 个场景、141 个窗口类逐个对重制，真缺两项（下两条），其余已做或原版走不到（清单见交付单 cc_ui-gaps3）。
- 启动开场图（新 `ui/splash_screen.gd` `XSplashScreen`，照 MOG_TitleSplashScreen）：一次运行第一次进西游标题前，黑底上依次放 titles2/Splash_0、Splash_1、Splash_2（1280×740 居中，上下各出界 10）；每张不透明度每帧 +5 到 255、停 90 帧、每帧 −5 到 0；淡入／停留时不透明度 > 60 按确定或点一下就开始淡出、淡完进标题，淡出时按也一样。放完才出标题指令（`entry.gd`），放的时候按键不漏给标题。headless 或命令行带场景／脚本（测试）不放，`XIYOU_SPLASH=1／0` 强制。切片 `extraImages` 加 `titles2/Splash_0～2`（A 车道文件，只动图片表这一段）。
- 原版 bug（O-待定·开场图空白，见上方优化登记草稿）：原版下标从 0 数，先放一张空图（开场黑屏约 3 秒）。重制默认不放；`XSplashScreen.BLANK_FIRST_V028 = true` 回到原版。`XSplashScreen.ENABLED = false` 整个不放。
- 存读档小字（新 `ui/autosave_notice.gd` `XAutosaveNotice`，照 YEP_X_Autosave 的 Window_Autosave）：窗 (1000,648,1280,36)、内边距 0、无框；`\i[907]存档成功！`／`\i[2997]存档加载成功！` 画在 (6,0)，底下两段横向渐变（透明→rgba(0,0,0,0.6)→透明，分界在 6＋ceil(文字宽／2)）；出现时 120 帧内文字每帧 +16，之后每帧 −16；正在显示时再触发不重来。读档（`XSave.load_slot`，以及重制自己的切后台自动存档 `load_auto`）后第一次建地图场景出「存档加载成功！」；事件插件指令 Autosave 存档成功后出「存档成功！」；手动存档清掉读档标记（saveGameWithoutRescue）。`XAutosaveNotice.ENABLED = false` 不显示。复现原版，不登 O 号。
- 新专项 `xiyou_splash_autosave`：开场图逐帧（淡入 50／51、停留 89、一张 191 帧、三张 573 帧结束）、跳过阈值 60、原版空图回退支、存读档标记、窗口矩形、淡入淡出帧数、重复触发、插件指令存档与禁用、回退支。
- 玩家可见：启动时先放「大脑，在颤抖」开场图（可按确定跳过）；读档进地图、剧情自动存档后右下角会提示「存档加载成功！」「存档成功！」。

## 交接板

- 下一步：界面缺口这一轮盘完，原版能走到的系统页都有了；剩下 ui5 千万级血量拖尾等 Kyo、O-035 轮回随机阵容未开放。
- 用户试玩说明：启动会先放三张开场图（按确定跳过）；读档后右下角有「存档加载成功！」。
- 需要用户决定：O-待定·开场图空白（随优化登记待确认）

## 进度账

- 界面页面：补上开场图与存读档提示两处，完成度由总装核定

## 可优化（流程／工具／效率）

- 建议：盘点脚本（抽原版启用插件里的 Scene_／Window_ 类名、在重制 .gd 里找）可以做成 `ui_reference/盘点界面类.py` 常备，下次换源跑一遍就知道新增了哪些界面。本期是临时脚本，没提交；归工具车道。

## 验证

- `语法检查.py` 通过；`工具回归.py` 全过（69 秒）。
- 选测走云端：
  - 72b8e823（`检查.sh --affected main --cloud`，`CHECK_CLOUD_NO_UPLOAD=1`，运行 42419521088）：198 个场景 196 过；挂 `xiyou_splash_autosave`（没上传产物，云端快照里没有新加的三张开场图）、`xiyou_input_handled`（开场图直接调了 set_input_as_handled，守卫要求走 `XKeyMap.handled`）。其余守卫、文档检查全过。
  - 改后本机重跑 `xiyou_export.py --app v0.62.12`（增量写 5 个文件，三张图进 generated），`云端选测.py run --base 72b8e823`（带上传，运行 42422903942）：2 个场景全过。
- 合并提醒：切片 `xiyou_slice.json` 加了 3 行图片（总装同意），可能和 cc/wukong-floor4 冲突，由总装合并时解；合并后要重跑导出才有这三张图（没有图时开场图直接跳过，不会卡）。

## 本分支提交

- 72b8e823 开场图、存读档小字、切片三张图、专项
- e3bcc404 开场图按键走 XKeyMap.handled；.uid；交付单
