# 交付：claude/project-thread-f14v3n

- 车道／工作者：v0.01 玩家反馈修复（地图、标题、商店、战斗画面、设置）／cc（反馈修复，云端容器）
- 状态：进行中

## 变更记录草稿

## 2026-11-12 【cc·反馈修复·未经审查】v0.01 玩家反馈七项：绪绪不见、商店卡、苍龙接流萤、标题默认项、踩上即进门、神话怪大小、画面平滑（dev.待定）

- 来源：Kyo 11-12 转来 v0.01（安卓为主）玩家群截图。治疗技能卡、开战卡、SL 卡归「优化安卓战斗提速」线，本条不碰。
- **买碎片的 NPC 不见**（大厅绪绪 Map4 EV56）：行走图 `1xuxu.png`（800×529）只在左上一格画了人，本页 pattern 0。重制停下 6 帧后一律把帧换回 1（`_walk.stand`），换到空白的第二列，人就没了。原版 `resetPattern` 回的是 `_originalPattern`（事件取本页图的 pattern）。`MVCharacter.original_pattern`／`origin_pattern()`，`MVEvent.refresh` 设本页 pattern；玩家、跟随者照旧回 1。凡本页 pattern 不是 1 的事件（宝箱、门、静物）停下后都回到本页的帧，与原版一致。
- **商店每按一次键都卡一下**：一次按键里 `_buy_data()`、`_sell_data()` 各被调十来次（`_refresh` 无论什么模式都算一遍出售表、说明卡、状态窗、库存行、列表各算一遍；出售表每次把整个背包按分类筛一遍、套标记），背包大时明显。`XShop.DATA_CACHE`（O-待定·商店列表缓存）：`_refresh` 之后到下一次确定／取消／成交之前同一份表只算一次，这三处开头作废。实测见「验证」。
- **流萤和苍龙破晓的解锁过场「冲突」，要出去再进来才出苍龙**：rift2（EV203）原设计在「rift1 播完的同一次进大厅」不播，要等下一次进图。`XRift.CHAIN_AFTER_RIFT1`（O-待定·苍龙破晓接着流萤播）：rift1 放完、地图不忙时自动执行页紧接着播 rift2；两段不会同时跑（自动执行只在没有别的事件时启动，监视页照旧每 30 帧看一次）。
- **点「新的游戏」后再进游戏，标题总停在「新的游戏」**：原版 `Window_TitleCommand.selectLast`：本次运行上回在标题按过的项（`_lastCommandSymbol`），没按过时有存档就选「旧的回忆」。重制新旧两版标题都写死选第一项。`XTianqiTitle.initial_index`／`last_key`，回退 `XTianqiTitle.MV_SELECT_LAST = false`；原版标题（`entry.gd`）共用。
- **8 号当铺进出要在门口按确认**：原版这扇门（Map132 EV7、Map204 EV2）就是「确定键、角色下方、无图、只有场所移动」，键盘、摇杆都要站上去按确定；只有鼠标点那格走过去会自动进（`Game_Player.triggerTouchActionD1`）。两处改动：①重制原先点地走到目的地停下不触发 D1，补上（`MVPlayer.MV_TOUCH_D1`，`touch_target_reached` → `XMapScene._on_touch_arrived`，照原版只查脚下确定键事件）；②`XMapScene.STEP_ON_DOORS`（O-待定·踩上即进门）：这类门踩上就进（`MVEvent.is_plain_door`：指令只有 201 与音效、淡入淡出、等待、色调；挂机走动不进）。v0.62.12 全源同类门 34 处（地下水栽培、超越大厅、方桌大厅出口等），都是图边、墙口的出口。
- **怪物太大了**：神话敌人画 1.8 倍。原版 EliteEnemyPlugins 在 updateBitmap→updateScale 设 1.8 倍，但 YEP_X_AnimatedSVEnemies 的 `Sprite_Enemy.update` 末尾无条件 `updateBreathing`，同一帧把 scale 改回 `spriteScaleX()`＋呼吸量（本源敌人都没有 `<Sprite Scale>` 备注，即 1），屏幕上神话敌人仍是 1 倍。`XBattleScene.ELITE_SCALE = 1.0`（回退 1.8）。神话偏色不变。
- **画面锐化太高**：原版先把整幅画面画在 1280×720 画布上，再由浏览器整体双线性放大到窗口，放大后偏柔；重制 `canvas_items` 按屏幕分辨率直接画，战斗图最近邻放大 1.5、2.25 这类非整数倍，像素宽窄不一，显得硬。新增设置「画面平滑」（`XScreenScale`，O-待定·画面平滑；配置键 `codexScreenSmooth`）：开＝根窗口改 viewport 缩放（先画 1280×720 再整幅柔和放大，同原版，安卓上还少画像素），关＝照旧。**没存过时触屏（安卓）默认开、桌面默认关**（桌面窗口多为 1:1，Retina 原先已按物理像素处理过清晰度）。设置页排在「画面特效」后、「手机按键设置」前。安全区换算（`XPlatform.safe_insets`）改用 `XScreenScale.screen_to_view`，两种缩放都对。回退：`XScreenScale.ENABLED = false`（恒为 canvas_items，设置页不列）。
- 测试：新专项 `xiyou_feedback_v001`（绪绪停步帧、踩上即进门开／关、点地 D1 开／关、普通 NPC 不算门、神话倍数、画面平滑默认值／存读／切换／关开关、viewport 缩放下的屏幕→画面换算）；`xiyou_tianqi_title` 加 selectLast 六项；`xiyou_rift2_canglong` 加接着播一项；`xiyou_tianqi_title_flow`、`xiyou_opening_branches`、`xiyou_tianqi_opening` 进大厅后改等 rift2 也放完（不然退出时协程挂着），标题流程按 selectLast 先上移到「新的游戏」；`xiyou_hangup_options` 设置页行数多一行。
- 玩家可见：大厅卖碎片的绪绪重新出现；商店按键不再一顿一顿；第一次进大厅看完流萤后接着就是苍龙破晓；有存档时标题默认停在「旧的回忆」；8 号当铺等出入口走上去就进出；神话怪物不再放大；新增「画面平滑」设置，手机上默认开，画面更柔和、接近原版。
- 验证：（待写）
- 提交：见「本分支提交」
- 未完成／已知问题：画面平滑在安卓、Mac 全屏上的观感要实机看；苍龙接流萤只在第一次进大厅时有区别；截图里那只大怪没认出是不是神话，若不是神话、怪本身就那么大，原版也一样大。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·踩上即进门 | `modes/xiyou/map/map_scene.gd` `XMapScene.STEP_ON_DOORS`、`_on_player_step`；`map/mv_event.gd` `is_plain_door`；`tests/xiyou_feedback_v001.gd` | 「确定键、角色下方、无图、只做场所移动」的门（8 号当铺进出等 34 处）要站上去按确定，只有鼠标点地走过去才自动进 | 这类门踩上就进（挂机走动不进） | 玩家反馈 v0.01：安卓摇杆走到当铺门口不进，要按确认，出来也是 | `XMapScene.STEP_ON_DOORS = false` | cc（反馈修复） | 保留 |
| O-待定·苍龙破晓接着流萤播 | `modes/xiyou/core/rift.gd` `XRift.CHAIN_AFTER_RIFT1`、`this_visit_seen`；`tests/xiyou_rift2_canglong.gd` | 重制新增内容：rift2（苍龙破晓过场）在 rift1 播完的同一次进大厅不播，要出去再进来 | rift1 放完接着播 rift2（自动执行只在没有别的事件时启动，不会同时跑） | 玩家反馈 v0.01「流萤和苍龙的解锁动画冲突，退出重新切图才刷出苍龙」 | `XRift.CHAIN_AFTER_RIFT1 = false` | cc（反馈修复） | 保留 |
| O-待定·画面平滑 | `core/screen_scale.gd` `XScreenScale`；`core/platform.gd` `safe_insets`；`modes/xiyou/core/xconfig.gd`（`codexScreenSmooth`）；`ui/options_scene.gd`；`entry.gd`；`tests/xiyou_feedback_v001.gd` | 原版整幅 1280×720 画完再由浏览器双线性放大（偏柔）；重制原先 canvas_items 按屏幕分辨率直接画、战斗图最近邻非整数倍放大（偏硬） | 设置「画面平滑」：开＝viewport 缩放（同原版观感），关＝canvas_items；没存过时触屏开、桌面关 | 玩家反馈 v0.01「画面锐化太高」；安卓上还少画像素 | `XScreenScale.ENABLED = false`（恒为 canvas_items，设置页不列） | cc（反馈修复） | 保留 |
| O-待定·商店列表缓存 | `modes/xiyou/ui/shop.gd` `XShop.DATA_CACHE`、`_buy_data`／`_sell_data`／`_drop_cache` | 原版各窗口 refresh 时各算一次商品表；重制原先一次按键里买入表、出售表各重算十来次 | `_refresh` 之后到下一次确定／取消／成交前同一份表只算一次 | 玩家反馈 v0.01「所有 NPC 买东西都有轻微卡顿」 | `XShop.DATA_CACHE = false` | cc（反馈修复） | 保留 |

## 交接板

- 下一步：安卓实机看「画面平滑」开／关两种观感、8 号当铺进出、绪绪、标题默认项；是否推给玩家等 Kyo 另说。
- 用户试玩说明：同变更记录「玩家可见」。
- 需要用户决定：无（四项优化按 Kyo 11-11「优化直接接受」登记为保留；画面平滑桌面默认关，要桌面也默认开改 `XScreenScale.default_on`）。

## 进度账

- 无（反馈修复，不改完成度）。

## 可优化（流程／工具／效率）

- 建议：云端线程取转换产物和导入缓存很慢（`device_stage_files` 单文件 80 MB 约 1～2 分钟、同时传多份会超时；云端 `godot --import` 全量约 40 分钟）。把 Mac 上 `generated` 与 `.godot/imported` 的打包按天放进项目文件夹 `云端测试/`（现有那份是 10-18 的），云端线程开工直接用，可省半小时以上。归总装或工具车道。

## 本分支提交

- （待写）
