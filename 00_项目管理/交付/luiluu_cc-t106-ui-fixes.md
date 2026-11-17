# 交付：luiluu/cc-t106-ui-fixes

- 车道／工作者：B 界面／cc（Sonnet 5.5＋medium，T106→T107→T129 一条车道顺序做）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·未经审查】T106／T107／T129 界面小修三张（dev.待定）

- T106：新皮肤下 `XToast` 提示栈上沿由 y=30 改到页面上沿之下（`XToast.skin_top()`＝`XUiSkin.TOP`＋4，关新皮肤仍原版 20），不再盖菜单页名与页签；多条提示本来竖排，加断言两条不叠。`xiyou_ui_skin_4b` 加 `toast_below_header_*`（改前红、改后绿，实测）。
- T107：差距清单第 10 项（左上自动／变速圆钮）T125 已做完（74×74 圆钮，截图核过），本卡不重做；第 11 项：队伍紧凑条队长行 Lv 后带当前称号（`XSkinSideStatus.title_text()`，称号是玩家级 `XState.designation`，只挂队长，非队长不带；`SHOW_TITLE=false` 回退，登记 O-待定·队伍条称号）。T096 核 P2：`XSkinBattle.help_open` 每场重置（`XBattleScene._ready` 开战清、`tree_exiting` 收场清，`XSkinBattle.reset_help()`），`xiyou_ui_skin_battle` 加开战与收场两条断言；`xiyou_ui_skin_hud` 加队长称号／非队长／回退三项。
- T129：`xiyou_tianqi_title_flow` 收尾前停掉 `XSound._players` 回放并放流、等 0.3 秒（同 `xiyou_actor_book` 先例），存档目录改按进程号分开（原固定目录，多份同时跑会互踩存档、必红，和泄漏无关）。
- 玩家可见：新皮肤下弹提示不再盖住菜单标题和页签；战斗右侧队伍栏队长一行显示称号。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·队伍条称号 | `modes/xiyou/ui/skin/skin_side_status.gd` | 战斗右侧队伍条 Lv 行只有「Lv · 职业」 | 队长行在 Lv 后带当前称号（`XState.designation`，只挂队长） | 对上界面风格 v0.7 稿「Lv 1 · 断腿狗」 | `XSkinSideStatus.SHOW_TITLE = false` | cc | 保留 |

## 交接板

- 下一步：无
- 用户试玩说明：同上「玩家可见」
- 需要用户决定：无

## 进度账

- 无

## 我不同意的地方／如实说明

- T107 第 10 项已被 T125 做掉，派单当作待做；只核对未重做。第 11 项称号：稿「断腿狗」是玩家称号，队员没有称号数据，所以只挂队长；若稿意是每人一个称号需 Kyo 定。
- T107 称号没有实机截图：测试存档默认没选称号，截图看不到；只有断言覆盖（`party_strip_leader_title`）。T106 截图为 4b 专项新旧并排（`03_notices`，窗口模式），不是进真菜单的图。
- T129 没能复现泄漏：本机把存档目录分开后，修前、修后各 20 次（每批 10 并行，`--headless --verbose`）都是 20/20 通过、无泄漏字样；修的是 T102 查明的原因（退出时音效回放），属于按先例的预防，不是「改前红」实测。

## 可优化（流程／工具／效率）

- 建议：并行测试里固定写 `user://test_*` 目录的专项都可按进程号分目录，才能同场景并行多份（title_flow 已做，其余归总装择机）。

## 本分支提交

- 5fc9cf58d T106
- da13561c4 T107
- （T129 见 git log）
