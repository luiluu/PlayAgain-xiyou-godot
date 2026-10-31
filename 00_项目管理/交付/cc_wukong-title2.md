# 交付：cc/wukong-title2

- 车道／工作者：B 界面（C 车道接）／悟空（cc）
- 基线：从 cc/wukong-title1 末端 fa95126d 切出。
- 状态：进行中

## 变更记录草稿

## 2026-10-31 【cc·悟空·未经审查】称号二期：地图头顶名牌（dev.待定）

- **原版**（Star_Designation `Sprite_Character.initialize`／`updateOther`，单机分支；读码）：玩家和每个载具的精灵各挂一张 180×78 的名牌画布，anchor (0.5, 1)，在精灵原点上方 `offsetY`（参数 48）；字号 16、粗体、黑色描边。画布内：图标 `drawIcon(icon, 58, 0)`（Star 版 drawIcon 再右移半格，实际 x 74、32×32）、称号名 y 32 行高 22 居中（称号颜色）、开局名字 `$gamePlayer.SaveActorName` y 54 行高 22 居中（白色）。玩家精灵透明时随精灵隐藏；载具那张只在玩家坐着它、位置重合时显示。installDisplayPreferencesRuntime 另有一张名牌，只在精灵没有 `_nameSpriteOL` 时画；单机时玩家和载具都有，所以它不出现。
- **重制**：新 `map/designation_plate.gd`（`XDesignationPlate`，继承 XMVCanvas），常量照上；`map_scene.gd` 给玩家与飞艇各挂一张，`_process` 里 `_update_plates` 摆位置（精灵原点上方 行走图上移 6＋48＋78）、显隐、按「名字｜称号｜图标｜颜色」变化重画。
- **测试**：`xiyou_airship_view` 加两条：走路时名牌在玩家上、位置 (-90, -132)、180×78，飞艇那张藏着；乘上飞艇后玩家那张藏、飞艇那张显示。
- **没量成**：参照引擎里 Sprite 是桩（`new Sprite_Character` 没建出名牌），画面参数是读码；没跑 ui_reference 截图对照，像素级（描边宽度、粗体笔画）待界面车道用 ui_reference 核。kyo 专属的 `K.updatePlayerName`（成就 143 拥有者的名字特效）没移植。

## 抽奖动画 Star_LotteryAnimation 盘点（不写代码）

| 部分 | 原版 | 冻结源里的用法 | 建议 |
| --- | --- | --- | --- |
| 事件头顶文字 | Scene_Map.createDisplayObjects 给每个地图事件建一张 300×100 画布（`_eventsName[事件ID]`），事件名 `名字@颜色`；只有事件备注以 `LotteryAnimation` 开头（`LotteryAnimation@图片@false`）的才画字、加进场景 | **全部地图 0 个事件带这个备注**（有备注的事件共 19 个，都不是） | 原版看不到，不做 |
| 抽奖滚动 | `Star.LotteryAnimationLoad(候选数组, 事件ID, 最终文字, 复原)`：60 次随机换字（间隔 max(16, 80−i) 毫秒）、停在最终文字 2.5 秒后复原 | **没有任何事件或公共事件调用** | 不做 |
| 冷却倒计时 | createDisplayObjects 里按地图号起 62 个 `setInterval`（Map004 事件 5／9 变量 162／163，Map069、186、187、217～219 等），每秒把「分:秒」画进对应事件的画布；Map004 EV5／EV6、CE817「时间刷新」也直接画 | 画布只有「已启用的事件」才加进场景，而没有事件启用，所以**倒计时画进了看不见的画布** | 原版看不到；若要做冷却显示，算优化，先问 Kyo |
| 存档 | 无（只读变量 162、163、321 等与游戏时间） | — | — |
| 副作用 | 每次进地图清掉旧的 interval 再起新的；离开对应地图时 interval 自己清 | — | 不做 |

结论：v0.28 里这个插件**画面上没有可见效果**（读码＋全数据扫描：没有 LotteryAnimation 备注、没有 LotteryAnimationLoad 调用）。建议登记为「原版无可见效果、不移植」；如果 Kyo 想要大厅 NPC 的冷却倒计时，另立优化。

## 交接板

- 下一步：称号名牌的像素对照（ui_reference，B 车道）；抽奖动画按上表，不移植（待总装／Kyo 确认）。
- 用户试玩说明：地图上玩家头顶会显示名字和选中的称号（图标＋彩色称号名），坐飞艇时显示在飞艇上。

## 优化登记草稿

优化登记草稿：无。

## 进度账

- 养成·称号：逻辑、存档、头顶名牌完成（像素对照未做）。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 专项：`xiyou_airship_view`（含名牌两条）、`xiyou_airship_fly`、`xiyou_airship_state` 通过。
- 相关场景：待写
- 改动：`map_scene.gd`（两个名牌变量、创建处各两行、`_update_plates` 与 _process 一行）；新 `map/designation_plate.gd`。没改 actor／xstate。

## 本分支提交

- 994b1d7c 头顶名牌与断言
