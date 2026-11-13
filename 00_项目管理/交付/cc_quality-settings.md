# 交付：cc/quality-settings

- 车道／工作者：B 界面·画质设置／cc（画质线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·画质·未经审查】设置页加「画质设置」子页（dev.待定）

- 起因：玩家反馈画质变低（原因是「画面平滑」安卓默认开，另一条修复车道在改默认值），Kyo 要给玩家一组画质选项。设计见 [画质设置](../../03_再刷重制_Godot/00_设计/画质设置.md)。
- 设置页在「画面平滑」后加一行「画质设置」，打开子页 `XGraphicsOptionsScene`（样式照「消息提醒」子页）。四项，默认都不干预，没存过设置的玩家画面不变：
  - 整数倍缩放：画面只按整数倍放大、四周留黑边，屏幕比 1280×720 小时不生效；状态显示当前倍数。
  - 帧率上限：跟随屏幕／60／30，只限画面刷新，游戏速度不变。
  - 窗口大小（只桌面）：自动／1280×720／1600×900／1920×1080／全屏。
  - 省电模式：30 帧、画面按 1280×720 画再放大、关画面特效；只覆盖生效值，不改那几项自己存的值。
- 新类 `XGraphics`（`modes/xiyou/core/graphics_quality.gd`），存在配置的 `codexQuality` 一个键里，坏值按默认补；回退开关 `XGraphics.ENABLED`（O-待定-1）。
- 接入处：`XConfig`（默认值、读取校正、`quality()`／`set_quality()`）、`entry.gd`（进模式时生效）、`options_scene.gd`（列表行与打开子页）、`XLobbyCorruption.fx_on` 与 `XRiftAlien` 的特效判断改走 `XGraphics.fx_on()`、`XScreenScale.screen_to_view` 认整数倍。
- 没碰「画面平滑」的默认值与旧配置迁移（归画质回归修复车道）。两条车道都改 `xconfig.gd`、`screen_scale.gd`，我的改动避开了它那几行，合并时若有冲突两边都留。
- 没做的（贴图过滤、HiDPI、渲染比例滑条、特效分档、垂直同步）与理由写在设计文档里。
- 新专项 `xiyou_graphics_options`；`xiyou_hangup_options` 的设置页行数与末行断言跟着加一行。
- 玩家可见：设置里多了「画质设置」，可开整数倍缩放、限帧率、选窗口大小、开省电模式；不动它画面和原来一样。

## 优化登记

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/graphics_quality.gd` `XGraphics.ENABLED` | 没有画质选项 | 设置页加「画质设置」子页：整数倍缩放、帧率上限、窗口大小、省电模式，默认都不干预 | Kyo 11-13 要玩家可调的画质选项 | `XGraphics.ENABLED = false`（存下的设置留着） | cc | 保留 |

## 交接板

- 下一步：实机看一眼子页排版和整数倍缩放（Mac 窗口、安卓各一次）；本轮只跑了无界面测试，没有截图、没上真机。
- 用户试玩说明：设置 → 画质设置。
- 需要用户决定：无。随下一个玩家版本发不发由 Kyo 说「推」。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：新建类之前先 `rg "class_name X名字"`。本轮起名 `XQuality` 撞了装备品质的同名类并覆盖了它的文件，语法检查报出后已用 git 还原、改名 `XGraphics`，没有进提交（归工具车道：`语法检查.py` 可以顺手查重名）。

## 验证

- `语法检查.py` 通过。
- 专项 `xiyou_graphics_options` 通过（含回退开关关掉的一支）。
- 选测名单共 207 个场景（因为改了 `xconfig.gd`、`entry.gd`），车道只跑了直接相关的 18 个，全过：`xiyou_hangup_options`、`xiyou_feedback_v001`、`ui_smoke`、`xiyou_battle_options`、`xiyou_determinism`、`xiyou_entry_release`、`xiyou_key_smoke`、`xiyou_lobby_corruption`、`xiyou_notice_options`、`xiyou_options_basic`、`xiyou_options_misc`、`xiyou_platform`、`xiyou_rift2_canglong`、`xiyou_rift_alien`、`xiyou_screen_fx`、`xiyou_speed_gear`、`xiyou_tianqi_title`、`xiyou_window_rects`。其余没跑，留给合并时的云端选测；理由是其余场景只经 `XConfig` 读别的键，本轮没改那些路径。
- 没做：实机与截图。整数倍缩放在 `canvas_items` 模式下的实际观感、全屏与固定窗口大小只在真窗口里才生效，测试只验了取值、换算和存盘。

## 本分支提交

- e2a2d34e6 WIP: 画质设置（XGraphics）：整数倍缩放、帧率上限、窗口大小、省电模式＋设计文档与专项
