# 交付：cc/platform-android3

- 车道／工作者：跨平台（工程）／BH 续（cc，总装二十五派单）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·BH·未经审查】安卓返回键：发行包西游标题页算顶层，两秒内按两次退出（dev.待定）

- 问题：发行包跳过入口菜单（O-199）以后，西游标题上按返回键没反应（`XPlatform.go_back` 只在入口菜单上退出，标题上发 ui_cancel，标题不响应）。
- 原版行为：用 `dexdump` 看了二合一包的 `org.kyo.xiyou.MainActivity.onBackPressed`，只执行 `window.AndroidPort&&AndroidPort.back()`，不调 `super.onBackPressed`，`AndroidPort.back` 只发 120 毫秒的 Esc；MV 标题不响应 Esc，所以原版在标题上按返回键也没反应、不退出。
- 定的做法（O-待定，原版缺陷先改后登记）：顶层按返回，第一次在屏幕下方提示「再按一次返回键退出」，两秒内再按就退出；超过两秒重新提示。顶层是：入口菜单；或 `ReleaseEntry.skips_menu()` 为真时停在标题页的西游标题（`modes/xiyou/entry.tscn`，读档、设置等子页不算，仍当取消键）。入口菜单原来是按一次就退出，一起改成按两次，免得误触。
- `core/platform.gd`：`is_top_level(scene)`、`go_back(now_msec, scene)` 返回 "quit"／"hint"／"cancel"，`quit_requested` 信号，`quit_on_back`（测试关掉）、`BACK_EXIT_ON_TOP` 开关、提示标签。`modes/xiyou/entry.gd` 加 `is_title_page()`（有图片指令＝标题页）。
- 测试：`xiyou_platform` 加 9 项（调试包标题＝取消、入口菜单两次退出、发行标题是顶层而地图不是、提示、两秒内退出、慢了重新提示、子页＝取消、发行但关掉直达＝取消、开关关掉＝取消）；`xiyou_entry_release` 加 1 项（真西游标题场景在发行分支下是顶层）。

## 优化登记草稿（总装合并时换成实际 O 号）

| 编号 | 位置 | 原版 | 重制 | 理由 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `core/platform.gd` go_back | 安卓返回键只发 Esc，标题上没反应、不退出（MainActivity.onBackPressed） | 顶层（入口菜单、发行包西游标题页）第一次提示「再按一次返回键退出」，两秒内再按退出 | 安卓上顶层按返回没反应像卡住；按两次防误触 | `XPlatform.BACK_EXIT_ON_TOP = false`（顶层也只当取消键） | cc（BH 续，总装二十五派单） | 已做，待用户确认 |

## 交接板

- 下一步：安卓真机验收时顺带看标题上按返回的提示位置与两秒节奏。
- 用户试玩说明：安卓发行包在标题上按返回键，下方提示「再按一次返回键退出」，两秒内再按退出；调试／验收包在入口菜单上同样按两次。
- 需要用户决定：无（按两次退出是安卓常见做法，可回退）。

## 进度账

- 跨平台：安卓返回键顶层行为补齐

## 可优化（流程／工具／效率）

- 无

## 验证

- 专项（合 main 后）：xiyou_platform（38/38）、xiyou_entry_release（16/16）、xiyou_event_compare、xiyou_flow、ui_smoke、xiyou_hud、xiyou_floor_run，7 个全过；`工具回归.py` 全过；`语法检查.py` 0 问题。
- `选测.py main --list`：`platform.gd` 列 xiyou_entry_release、xiyou_event_compare、xiyou_platform（都跑了）；`entry.gd` 判「整轮」（拿不准），车道不跑全量，改为跑引用西游标题的全部测试（xiyou_flow、ui_smoke、xiyou_hud、xiyou_floor_run、xiyou_entry_release）。`entry.gd` 只加了一个只读函数，请总装按影响面决定是否并进当天全量。
- 没在真机按过返回键（本机没有安卓设备）。

## 待交叉核查

- 乙：`core/platform.gd` 返回键一段、`modes/xiyou/entry.gd` 一个函数、两个测试。

## 本分支提交

- （见 git log）
