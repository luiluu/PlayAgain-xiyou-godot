# 交付：cc/pro-newgame-back2

- 车道／工作者：B 界面·新游戏三页返回键／cc（Pro，云端线程）
- 状态：可合并

> 派单：Kyo 2026-11-14「把 cc/pro-newgame-back 的修法搬到当前 main」。**取代 `cc/pro-newgame-back`（落后 main 两百多个提交，没合），本分支合后可删旧分支。** 分支从 `origin/main` `2f87155` 切出，按当前 `entry.gd` 结构重写同样的修法（没有整份照搬旧文件）；只推本分支和 `ci/cc/pro-newgame-back2`，不合并、不推 main。

## 变更记录草稿

## 2026-11-14 【cc·Pro·未经审查】新游戏三页认取消键：Esc、X／K、手柄 B、虚拟取消键、安卓返回键都退回上一页（dev.待定）

- 问题（PR #32 `xiyou_tianqi_e2e` 发现，11-11 修在 `cc/pro-newgame-back` 但一直没合）：标题「新的游戏」进选存档位、选难度、随机阵容页（连同已有存档的覆盖确认页）后，按取消键不退回，只能点页里的「返回」。原因是 `modes/xiyou/entry.gd` `_unhandled_input` 开头 `if _commands.is_empty(): return`，`_window` 建的窗口页没有自己的取消处理；安卓返回键在子页发的就是 `ui_cancel`（`XPlatform.go_back`），所以一样没反应。
- 修法：`entry.gd` 加 `_back`（窗口页的「返回／取消」去处）和 `_add_back(text, fn)`：加按钮（名 `WindowBack`）的同时登记取消键去处；`_clear` 换页时清掉；`_unhandled_input` 在没有图片指令（即窗口页）时认 `ui_cancel`，标已处理后调 `_back`。去处与页里按钮一致：选格页→标题，覆盖确认→选格（同「换一格」），难度页→选格，阵容页→难度页（仍是原来那格）。
- 顺手（当前 main 上四页都还在，一起改）：导出选档、导入选格、一句话结果页（`_notice`）、「继续」自动存档确认也改用 `_add_back`，取消键＝点「取消／返回」回标题，原先同样不认取消键。没有已不存在或本来就能退的页。
- 不受影响：标题页（新标题 `XTianqiTitle` 与原版图片指令）不设 `_back`，取消键照旧不换页；发行构建下安卓返回键在标题页照旧是顶层（提示「再按一次退出」）；读档页、游戏设置页、成就页、检查更新页各自处理取消，不经过 `_back`；声明屏、启动动画在进标题前，不经过窗口页；进大厅后 Esc 照旧开、关主菜单。
- 新专项 `tests/xiyou_newgame_back`：Esc、X、`ui_cancel` 动作、安卓返回键（`GameApp.platform.go_back`，模拟发行构建）四种来源各走一遍：覆盖确认→选格（旧档逐字不变）、阵容→难度→选格→标题；新标题与原版图片指令标题各测：三种取消键不换页、返回键提示再按一次退出、确认键照旧开新游戏；顺手四页 Esc 回标题；退回难度页再开局存档位仍是 3 号；进大厅 Esc 开关主菜单。
- 玩家可见：新游戏的选存档位、选难度、随机阵容页可以按 Esc 或手机返回键退回上一页了。

## 交接板

- 下一步：合并后删旧分支 `cc/pro-newgame-back`（本分支取代它）。旧交付单提到 PR #32 `xiyou_tianqi_e2e` 的 `ESC_BACK` 开关：11-14 查 main 上没有这个专项（PR #32 没合），本分支不涉及；以后 #32 若再合，要把 `ESC_BACK` 改成 true。
- 用户试玩说明：新游戏三页（选存档位、选难度、随机阵容）按 Esc／X／K、手柄 B 或安卓返回键退回上一页；已有存档的覆盖确认页按取消＝「换一格」。
- 需要用户决定：无。

## 进度账

- 无（修 bug；天启篇扩展账不变）。

## 选测对照（`选测对照.json`，本分支没改，请总装合并时加）

- 派单限定只改 `entry.gd` 与本专项，所以没动 `选测对照.json`。建议 `entry` 组 `scenes` 加 `xiyou_newgame_back.tscn`（旧分支这样改过；`refs: true` 下它引用 `entry.gd` 的私有方法，大概率已被自动选中，加上更稳）。

## 验证

- GitHub Actions 云端选测（推 `ci/cc/pro-newgame-back2`，提交 `9dcaf78`，[run 43534769788](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/43534769788)）：选中 15 个场景全过：`xiyou_newgame_back` **68/68**、`xiyou_tianqi_title` 46/46、`xiyou_tianqi_title_flow` 43/43、`xiyou_platform` 155/155、`xiyou_input_handled` 10/10、`ui_smoke` 24/24、`xiyou_entry_release` 16/16、`xiyou_key_smoke` 7/7、`xiyou_reincarnation_entry` 94/94、`xiyou_save_page` 42/42、`xiyou_flow` 50/50、`xiyou_event_compare` 14/14、`_b`／`_c`／`_d` 各 6/6。
- 本线程云端容器（Linux，Godot 4.7.2；转换产物取自 `refs/ci/generated/main`，只读）：`xiyou_newgame_back` 68/68。
- 反向验证（手工，改完用备份还原 `entry.gd`，没提交）：让 `_unhandled_input` 不认 `ui_cancel` → **22 项失败**（四种来源 × 四步退回 16 项、原版标题选格页退回 1 项、顺手四页 4 项、退回后开局仍是 3 号格 1 项），标题页「不换页／返回键提示」各项照旧通过。
- 专项 68 项构成：存旧档 1；四种来源 × 10 步＋返回键子页走取消 1；新标题 6（不设 _back、三种取消键不换页、返回键提示再按一次退出、确认键照旧开新游戏）；原版图片指令标题 7；顺手四页 8；开局进大厅 5。
- 没跑：全量 `检查.sh`（车道不跑）；没在 Mac、安卓实机上试。

## 可优化（流程／工具／效率）

- 已做：旧专项第一步查「标题选中在『新的游戏』」，当前 main 有 selectLast（有存档先停「旧的回忆」），改成先选回第一项再回车。
- 已做：`entry.gd` 其余四个窗口页一并认取消键（同一个 `_add_back`，回退就是把那几处换回 `_add(XUI.button(…), fn)`）。

## 本分支提交

- （见分支 `cc/pro-newgame-back2`）
