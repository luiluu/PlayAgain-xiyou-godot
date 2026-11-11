# 交付：cc/update-input-fix1

- 车道／工作者：自动更新（工具与平台）／cc（update-input-fix1）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·update-input-fix1·未经审查】修 xiyou_input_handled：检查更新页改用 XKeyMap.handled（dev.待定）

- 现象：云端整轮里 `xiyou_input_handled` 的 `no_direct_set_input_as_handled` 挂，指向 `modes/xiyou/ui/update_page.gd`。
- 原因：是我在第①批写检查更新页时的问题，不是测试规则新增。那条规则（11-06 起）要求按键标已处理一律走 `XKeyMap.handled(self)`（节点不在树上就跳过），不许直接写 `get_viewport().set_input_as_handled()`：发行版对已摘下树的节点这样调会空指针闪退。`update_page.gd` 的 `_input` 里有两处直接调用。
- 修法：两处都换成 `XKeyMap.handled(self)`。行为不变。
- 为什么交付前没发现：第①批改了 `project.godot`，`选测.py` 判成整轮，我只挑了几个相关场景跑，没有 `xiyou_input_handled`。之后新加带 `_input` 的界面脚本，交付前要带上这个场景。
- 验证：`xiyou_input_handled`、`xiyou_update_check`（54 项）、`xiyou_update_install`（49 项）全过；`语法检查.py` 通过。
- 合并顺序：排在自动更新各批之后（spike0 → check1 → release1 → install1 → cloud1 → android-net1 → input-fix1）。
- 待交叉核查：乙档，两行。

优化登记草稿：无

## 交接板

- 下一步：无新增。
- 用户试玩说明：无。
- 需要用户决定：无。

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 建议：`选测对照.json` 给界面脚本（`modes/xiyou/ui/*.gd`）的规则里带上 `xiyou_input_handled`（它是全工程静态扫描，几秒），这样新界面脚本的选测名单里一定有它；归工具车道。

## 本分支提交

- （见 git log cc/update-android-net1..cc/update-input-fix1）
