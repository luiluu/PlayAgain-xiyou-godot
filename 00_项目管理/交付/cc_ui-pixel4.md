# 交付：cc/ui-pixel4

- 车道／工作者：B 界面／白龙（cc，GF8）
- 状态：可合并
- 车道路径：/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/xenodochial-lichterman-07a04a

## 变更记录草稿

## 2026-11-10 【cc·白龙·未经审查】战斗状态详情面板；场所移动淡出 24 帧、认 201 淡出类型；仓库、宝珠镶嵌、称号名牌像素对照（dev.待定）

- 状态详情（installEquipmentStatusRuntime renderStatus）：先查了能不能点开——原版右侧状态格上叠着网页按钮（悬停「名字：状态名；点击查看全部状态」），点了打开「<名字> · 状态详情」；StateHelp 的队伍指令「状态」OTB 不显示、呼出键参数为空，所以点状态格是唯一入口。重制原来没有，现在做了：
  - 新面板 `ui/party_status_panel.gd`（XPartyStatusPanel，沿用 XWebPanel 外观）：胶囊 HP／MP／TP、人物属性与各元素承伤（同战力面板）、页签「异常／增益／常驻／全部 N」（打开在「全部」）、搜索框（alias 后按名字＋说明包含）、每个状态一张卡（名字、「类别 · 时长 · N层」、说明，异常卡左边线红）、底部「显示实际效果、剩余回合和层数。」「返回战斗」，Esc 关。
  - 行内容＝stateRows：时长分「N回合／本回合／常驻／被动常驻／本场战斗／持续生效」，异界腐蚀按回合；强弱化行「物攻强化」等、说明「物攻+50%」；排序同状态格。
  - 说明文字与能否进详情：新工具 `07_开发环境/生成状态详情参照.cjs` 从原版运行时原样取出 text／pct／traitDescription／stateDescription／visibleState，对全部 2791 个状态算一遍（`tests/fixtures/state_detail_oracle.json`），Godot 逐个相同。
  - 战斗：`side_status.gd` 状态格上加透明按钮（(−36,20) 32×32，悬停提示同原版）；`battle_scene.gd` 只在等指令时（`inputting`）能打开，打开期间指令窗失活、关掉恢复；面板放在单独的 CanvasLayer 95，盖住地图的挂机图标与行动顺序条。原版打开时 BattleManager.update 整个停住，重制战斗靠协程推进停不住，所以演出中点状态格不响应（偏差，见优化登记）。
- 淡出淡入（ui-zorder1 记的）：地图事件 221／222 与场所移动 0.3 秒 → 24 帧（0.4 秒，fadeSpeed）；场所移动认 201 的第 6 个参数：1 白幕、2 不淡出（Scene_Map.fadeOutForTransfer／fadeInForTransfer）。数据里 201 共 1978 条，淡出类型 0 有 1976 条、2 有 2 条、1 没有。
- 像素对照四期（用法见 `ui_reference/README.md`）：
  - 角色仓库 7 态、星级仓库 9 态：窗口矩形全部配上；像素差只剩菜单粒子、光标闪烁相位。星级仓库说明卡位置不同：原版 `Window_StarItemList.updateHelp` 不调 updatePos，卡在上次位置上一路累加修正（存入前 (52,32)、存一件后 (104,64)），是原版 bug；重制贴着选中格放（O-008），加回退开关 `STAR_HELP_DRIFT`（O-待定）。卡里属性不同是装备实例的随机浮动（原版页把 Math.random 固定成 0.5）。
  - 宝珠镶嵌 2 态（新原版页 `px4_orb`）：矩形 4／4 配上，像素差 2%（粒子与新局成就弹窗）。原版页一开始直接调 onItemOk，列表没失活，右侧留着装备详情——实玩按确定会先失活，改成 processOk 后与重制相同，不是重制的差。
  - 称号：原版没有独立页（Star_Designation 只有头顶名牌，选称号用普通选项窗）。名牌新做原版位图逐像素对照（`px4_designation` → `tests/fixtures/designation_plate_ref.png`，`xiyou_designation_plate`）：图标、称号、名字三段墨迹框都在 1 像素内；粗体 embolden 0.7 → 0.3（平均差 6.2 → 4.0，剩下的是字形光栅化）。
  - 法宝进化：原版也没有独立页——三角色 60 级法宝进化（installThreeGrowthRelicRuntime）和饿狼破限之心进化都是同步时直接换模板，没有界面；GPT_WeaponEnhancement 强化页插件是禁用的。按口径不算缺口。
- 测试本身：`xiyou_star_warehouse` 原来没隔离配置，窗口模式下读本机 options.json，学徒斗篷画成金色、4 项失败，改用 TestEnv.isolate。
- 测试：新 `xiyou_party_status_panel`（19 项）、`xiyou_designation_plate`（窗口模式 6 项，headless 3 项）；`xiyou_battle_ui` 加点状态格开关面板 5 项；`xiyou_transfer` 加 24 帧、白幕、不淡出 4 项；`xiyou_star_warehouse` 加说明卡漂移回退 3 项。
- 玩家可见：战斗里点右侧角色左边的状态格，打开状态详情（等指令时）；地图淡出淡入稍慢一点（同原版 0.4 秒），两处「不淡出」的传送不再黑一下；头顶称号名牌的字细一点。

## 交接板

- 下一步：界面像素对照还没做的：屠苏器谱、璇的星谱（选项窗页，如果「法宝进化页」指的是这两页）。状态详情面板的网页外观没拍原版截图（只对了行内容），要做可在战斗夹具里点状态格截原版 DOM。
- 用户试玩说明：同上「玩家可见」。
- 需要用户决定：无（O-待定两条按默认继续）。

## 进度账

- 界面页面：98% → 99.5%（+1.5）。依据：状态详情弹窗做完（审查 76 列的余项）；星级／角色仓库、宝珠镶嵌像素对照做完，无新真差。剩「过时头注释」不在本车道。
- 装备系统：99.5% → 100%（+0.5）。依据：宝珠镶嵌对照做完；法宝进化原版无独立页，按口径记满。
- 养成与周边系统：称号像素对照做完（名牌逐像素），星级仓库对照做完。

## 优化登记

| 编号 | 位置 | 原版 | 重制 | 理由 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·星级仓库说明卡 | `modes/xiyou/ui/star_warehouse.gd` `XStarWarehouseScene.STAR_HELP_DRIFT` | `Window_StarItemList.updateHelp` 只 setHelpWindowItem 不调 updatePos，说明卡每次 setItem 在上次位置上累加修正，从左上角一路漂移 | 贴着选中格放（同 O-008） | 原版 bug（卡的位置与选中格无关、越点越偏）；Kyo 11-07「原版 bug 要修」 | `STAR_HELP_DRIFT = true` | cc（白龙） | 待用户决定 |
| O-待定·状态详情只在等指令时开 | `modes/xiyou/battle/battle_scene.gd` `_open_status` | 状态格按钮随时能点，打开时 BattleManager.update 停住战斗 | 只在等指令时能打开，演出中点了不响应 | 偏差，不是优化：重制战斗由协程推进，没有整体停住的入口 | 无（要对齐需给演出各处加暂停点） | cc（白龙） | 待定（偏差记录） |

## 可优化（流程／工具／效率）

- 已做：`生成状态详情参照.cjs` 从原版运行时源码原样抽函数算参照（不用起浏览器），以后别的「运行时纯函数」参照可照这个做（回退：删工具与夹具）。
- 建议：`语法检查.py` 没查出 `XPartyStatusPanel.open(parent: Control)` 传 CanvasLayer 的类型错（Godot 加载时才报），可考虑加一轮 `--check-only` 编译（工具车道，小）。
- 建议：ui_reference 的服务端口没有占用检查，我第一次起服务时 8779 已被别的车道占着，node 脚本就连到了别人的服务上；`review_system_pages.cjs` 可以先核对服务的 SHOTS 目录或页名再跑（工具车道，小）。

## 验证

- 语法检查通过（675 个 .gd，0 问题）；工具回归全过（67 秒）。
- 本机并行：`xiyou_party_status_panel`、`xiyou_battle_ui`、`xiyou_side_status_order`、`xiyou_transfer`、`xiyou_star_warehouse`、`xiyou_actor_warehouse`、`xiyou_orb_ui` 全过。
- 本机窗口模式 `--out`：`xiyou_battle_ui` 213/213、`xiyou_party_status_panel` 19/19、`xiyou_actor_warehouse` 26/26、`xiyou_star_warehouse` 96/96（加漂移检查后 99/99）、`xiyou_orb_ui` 39/39、`xiyou_designation_plate` 6/6。
- 云端选测：见下。

## 本分支提交

- 从 main（fe7591b50）切出，交付前合过 main。
- 2fd83b2a3 场所移动淡出 24 帧、认 201 淡出类型；状态详情面板
- WIP 状态详情页签排版、面板层次；仓库与宝珠镶嵌对照、说明卡漂移开关；称号名牌对照
