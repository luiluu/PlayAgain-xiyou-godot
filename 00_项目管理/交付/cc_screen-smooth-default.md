# 交付：cc/screen-smooth-default

- 车道／工作者：线程（cc，查 v0.01.06 画质变低）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·线程·未经审查】画面平滑改成各平台默认关：修 v0.01.06 手机画质变低（dev.待定）
- 起因：玩家反馈 v0.01.06「感觉画质变低了」。比对两个发行目录：`dev470_三平台发行` 与 `dev476_三平台发行` 的工程设置、导出预设、贴图（安卓包里 7738 项，除脚本外大小都相同）都没变；多出来的是 dev497 加的「画面平滑」（O-340，`core/screen_scale.gd`）。它在触屏上没设置过就默认开：根窗口改 viewport 缩放，整幅先画 1280×720 再双线性放大，手机屏（如 2400×1080）放大 1.5 倍，文字、图标、地图都发糊。Mac／Windows 默认关，不受影响。
- 改法（O-待定，`XScreenScale.TOUCH_DEFAULT_ON`）：
  - 没选过时各平台都默认关（回到 v0.01 的按屏幕分辨率直接画）；设置页「画面平滑」照旧在，想要柔和的自己开。
  - 老配置：dev497 起配置文件会把触屏默认的 true 连同别的设置一起写进去，分不清是不是玩家选的。新加记号 `codexScreenSmoothChosen`，只在设置页亲手改这一项时写；读配置时没这个记号的 `codexScreenSmooth` 一律不认、按默认关。代价：v0.01.06 上亲手打开过平滑的玩家要再开一次。
  - 回退：`XScreenScale.TOUCH_DEFAULT_ON = true` 回到 dev497（触屏默认开、存过的值都认）；`XScreenScale.ENABLED = false` 照旧整项关掉。
- 测试：`xiyou_feedback_v001` 的画面平滑段改成触屏默认关，加老配置 true 不认、别的设置照读、亲手选过写记号、回退开关三项（触屏默认开、桌面关、老 true 照认）。
- 玩家可见：手机上画面回到 v0.01 那样清晰；觉得太锐的可以在设置里打开「画面平滑」。
- 未完成／已知问题：没在手机实机上截图对比（本机没有安卓设备／模拟器）；只看包内容和代码。最早说「锐化太高」的玩家这次会回到锐的画面，要在设置里自己开平滑。若之后还嫌战斗图硬，可以只给战斗图换线性过滤、不动文字（未做）。

## 优化登记草稿

| O-待定 | `core/screen_scale.gd` `XScreenScale.TOUCH_DEFAULT_ON`；`modes/xiyou/core/xconfig.gd`（`codexScreenSmoothChosen`）；`tests/xiyou_feedback_v001.gd` | dev497（O-340）触屏没选过「画面平滑」时默认开，配置里写进去的 true 都认 | 各平台默认关；只认设置页亲手选过（带记号）的值 | 玩家反馈 v0.01.06「画质变低」：手机上 1280×720 整幅放大发糊 | `XScreenScale.TOUCH_DEFAULT_ON = true` | cc（线程） | 保留 |

## 验证

- `语法检查.py` 通过；`工具回归.py` 全过。
- 专项（本机并行 2）：xiyou_feedback_v001（32/32）、xiyou_hangup_options、xiyou_options_basic、xiyou_options_misc、xiyou_notice_options、xiyou_battle_options、xiyou_platform、xiyou_determinism、xiyou_entry_release、xiyou_key_smoke、xiyou_screen_fx、xiyou_test_mode、ui_smoke，13 个全过。
- 没跑 `选测.py` 列出的其余 170 多个：它们是因为 `xconfig.gd` 被引用而列进来的，这次只改了画面平滑一项的读写，别的键的读法没动（新专项里也核了老配置里别的键照读）。
- 反向验证：把「只认带记号的值」改回「都认」，`smooth_old_true_ignored` 挂，还原后通过。

## 交接板

- 下一步：随下一个玩家版（和内存泄漏修复、究极丹卡顿修复一起）出，等 Kyo「推」。
- 用户试玩说明：手机上画面应和 v0.01 一样清晰；设置里「画面平滑」默认关。
- 需要用户决定：无（优化默认接受）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：发行出包的「体积.md」只比总大小，这次画质回退不是素材变了，而是默认设置变了，体积看不出来。可以在发行说明草稿里把「默认值变了的设置」单列一节（归工具车道）。

## 本分支提交

- e36742afd 画面平滑各平台默认关、老配置没亲手选过的 true 不认
- （本提交）交付单
