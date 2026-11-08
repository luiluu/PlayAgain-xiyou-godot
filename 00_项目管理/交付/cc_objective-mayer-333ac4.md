# 交付：cc/objective-mayer-333ac4

- 车道／工作者：界面·开场声明屏／cc（项目线程）
- 状态：进行中

## 变更记录草稿

## 2026-11-08 【cc·界面·未经审查】开场声明屏取代三张开场图（dev.待定）

- Kyo 2026-11-08 定（天启篇改版）：去掉开场三张图（titles2/Splash_0～2），换成仿老录像带片头警告的声明屏：黑底、红底白字警告条「警 告 / WARNING」、等宽大字、细扫描线；正文写本游戏免费、严禁倒卖收费，带一行英文。文字与排版原创，不用任何机构徽章或标志。
- 新文件 `modes/xiyou/ui/warning_screen.gd`（`XWarningScreen`）：淡入 32 帧、停 480 帧（变速齿轮下约 5 秒）、淡出 32 帧后进标题；显示满 48 帧后任意键、确定或点一下直接淡出（防开机连按误跳）。放不放仍走 `XSplashScreen.wanted()`／`shown`（一次运行一次、测试不放）。
- 开关 `XSplashScreen.WARNING_SCREEN`（默认 true）；`entry.gd` 按它分流。设 false 回到原版三张开场图（O-待定·开场声明屏，见优化登记）。
- 测试 `xiyou_splash_autosave` 加声明屏一段（淡入、停留、自动结束、早按不跳、跳过、回退开关），原三张图的测试保留；54 项全过。
- 玩家可见：开游戏先看到「免费游戏、禁止倒卖」声明屏，约 5 秒或按键进标题，不再放三张开场图。

## 交接板

- 下一步：无
- 用户试玩说明：开游戏先出红条警告声明屏，约 5 秒自动进标题，半秒后按任意键可跳过。
- 需要用户决定：无（声明文案 Kyo 11-08 回「可以」定稿）

## 进度账

- 无（天启篇改版，不计重制完成度）

## 可优化（流程／工具／效率）

- 无

## 验证

- `语法检查.py` 通过。
- 选测（`选测.py main --list` 全部 10 个）：ui_smoke、xiyou_entry_release、xiyou_event_compare、xiyou_flow、xiyou_input_handled、xiyou_key_smoke、xiyou_platform、xiyou_reincarnation_entry、xiyou_save_page、xiyou_splash_autosave：（待写）
- 工具回归：（待写）

## 待交叉核查

- 乙档：`ui/warning_screen.gd`、`ui/splash_screen.gd`（加开关）、`entry.gd`（分流）、`tests/xiyou_splash_autosave.gd`。

## 本分支提交

- db35283f7 WIP: 开场声明屏取代三张开场图
