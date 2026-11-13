# 交付：cc/quality-settings

- 车道／工作者：B 界面·画质设置／cc（画质线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·画质·未经审查】设置页加「画质设置」子页（dev.待定）

- 起因：玩家反馈画质变低（原因是「画面平滑」安卓默认开，另一条修复车道在改默认值），Kyo 要给玩家一组画质选项。设计见 [画质设置](../../03_再刷重制_Godot/00_设计/画质设置.md)。
- 设置页在「画面平滑」后加一行「画质设置」，打开子页 `XGraphicsOptionsScene`（样式照「消息提醒」子页）。六项。前两项是优化、默认开；后四项默认不干预：
  - 像素柔边（默认开）：战斗图放大到 1.5 倍这类非整数倍时，原先最近邻采样像素宽窄不一、发硬；现在身体着色器取相邻四个像素自己混，像素一样大、只在交界的一个屏幕像素里过渡。采样器仍是最近邻，文字和界面不受影响。回退 `XGraphics.CRISP`（O-待定-2）。
  - 顺滑移动（默认开）：逻辑每秒 96 步、屏幕 60 帧，跑步时画面一帧挪 12 像素一帧挪 24 像素（原版同样）。用引擎物理插值在两步之间补位置，只对地图场景开、根节点关；一步挪一格以上（传送、定位、循环回卷）不补。回退 `XGraphics.MOTION`（O-待定-3）。
  - 整数倍缩放：画面只按整数倍放大、四周留黑边，屏幕比 1280×720 小时不生效；状态显示当前倍数。
  - 帧率上限：跟随屏幕／60／30，只限画面刷新，游戏速度不变。
  - 窗口大小（只桌面）：自动／1280×720／1600×900／1920×1080／全屏。
  - 省电模式：30 帧、画面按 1280×720 画再放大、关画面特效；只覆盖生效值，不改那几项自己存的值。
- 新类 `XGraphics`（`modes/xiyou/core/graphics_quality.gd`），存在配置的 `codexQuality` 一个键里，坏值按默认补；回退开关 `XGraphics.ENABLED`（O-待定-1）。
- 像素柔边接在 `battler_sprite.gd` 的身体着色器（`crisp` 参数）与 `_apply_smooth`；顺滑移动接在 `map_scene.gd` 的 `_ready`（`XGraphics.smooth_node`）与 `mv_character.gd` 的 `_sync_position`（传送时重置插值）。
- 接入处：`XConfig`（默认值、读取校正、`quality()`／`set_quality()`）、`entry.gd`（进模式时生效）、`options_scene.gd`（列表行与打开子页）、`XLobbyCorruption.fx_on` 与 `XRiftAlien` 的特效判断改走 `XGraphics.fx_on()`、`XScreenScale.screen_to_view` 认整数倍。
- 没碰「画面平滑」的默认值与旧配置迁移（归画质回归修复车道）。两条车道都改 `xconfig.gd`、`screen_scale.gd`，我的改动避开了它那几行，合并时若有冲突两边都留。
- 没做的（贴图过滤、HiDPI、渲染比例滑条、特效分档、垂直同步）与理由写在设计文档里。
- 新专项 `xiyou_graphics_options`、`xiyou_crisp_scale`；`xiyou_hangup_options` 的设置页行数与末行断言跟着加一行。
- 玩家可见：战斗里的人物和怪物放大后像素更均匀、不发硬；地图上走路和镜头移动更顺。设置里多了「画质设置」，这两项可关，另可开整数倍缩放、限帧率、选窗口大小、开省电模式。

## 优化登记

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/graphics_quality.gd` `XGraphics.ENABLED` | 没有画质选项 | 设置页加「画质设置」子页：整数倍缩放、帧率上限、窗口大小、省电模式，默认都不干预 | Kyo 11-13 要玩家可调的画质选项 | `XGraphics.ENABLED = false`（存下的设置留着） | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/graphics_quality.gd` `XGraphics.CRISP` | 战斗图最近邻采样，非整数倍放大时像素宽窄不一 | 身体着色器四点混合：像素均匀，交界一个屏幕像素过渡；文字界面不变 | Kyo 11-13 问「又清晰又流畅」；玩家反馈过画面发硬 | `XGraphics.CRISP = false` | cc | 保留 |
| O-待定-3 | `modes/xiyou/core/graphics_quality.gd` `XGraphics.MOTION` | 每秒 96 步对 60 帧屏，跑步时每帧挪 12／24 像素交替 | 地图场景开物理插值，两步之间补位置，每帧稳定 19 像素 | 同上 | `XGraphics.MOTION = false` | cc | 保留 |

## 交接板

- 下一步：实机看一眼子页排版、整数倍缩放，以及顺滑移动下的传送、场所移动、事件定位有没有滑一下（Mac 窗口、安卓各一次）。地图没问题后，战斗里的移动也可以照样开插值（这次没开）。
- 用户试玩说明：设置 → 画质设置。
- 需要用户决定：无。随下一个玩家版本发不发由 Kyo 说「推」。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：新建类之前先 `rg "class_name X名字"`。本轮起名 `XQuality` 撞了装备品质的同名类并覆盖了它的文件，语法检查报出后已用 git 还原、改名 `XGraphics`，没有进提交（归工具车道：`语法检查.py` 可以顺手查重名）。

## 验证

- `语法检查.py` 通过。
- 专项 `xiyou_graphics_options`、`xiyou_crisp_scale` 通过（各含回退开关关掉的一支）。
- 像素柔边：真窗口 1920×1080（1.5 倍）开、关各截一张，放大对比看过：关时眼睛、衣纹的像素宽窄不一，开时均匀、边缘一像素过渡，文字照旧锐利。图在 `03_再刷重制_Godot/04_验证/本地结果/像素柔边/`（不入库）。
- 顺滑移动：真窗口固定 60 帧步长，按住方向键跑，逐帧量画面横移。关：24、24、12、24、12……；开：每帧 19。临时量具没入库（无界面下取不到画面）。
- 选测名单共两百多个场景（改了 `xconfig.gd`、`entry.gd`、`map_scene.gd`、`mv_character.gd`、`battler_sprite.gd`），车道跑了直接相关的，全过：`xiyou_hangup_options`、`xiyou_feedback_v001`、`ui_smoke`、`xiyou_battle_options`、`xiyou_determinism`、`xiyou_entry_release`、`xiyou_key_smoke`、`xiyou_lobby_corruption`、`xiyou_notice_options`、`xiyou_options_basic`、`xiyou_options_misc`、`xiyou_platform`、`xiyou_rift2_canglong`、`xiyou_rift_alien`、`xiyou_screen_fx`、`xiyou_speed_gear`、`xiyou_tianqi_title`、`xiyou_window_rects`、`xiyou_walk_speed`、`xiyou_sv_smooth`、`xiyou_actor_sv_compare`、`xiyou_battle_ui`、`xiyou_advance_v108`。其余留给合并时的云端选测。
- 没做：安卓真机；传送／场所移动在顺滑移动下的实际观感（只按逻辑做了重置，没有眼看）；整数倍缩放、全屏与固定窗口大小的真窗口观感。无界面测试里物理插值不生效（入口才调 `XGraphics.apply`），所以地图类测试覆盖不到它。

## 本分支提交

- e2a2d34e6 WIP: 画质设置（XGraphics）：整数倍缩放、帧率上限、窗口大小、省电模式＋设计文档与专项
