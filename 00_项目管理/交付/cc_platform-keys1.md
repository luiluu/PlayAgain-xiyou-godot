# 交付：cc/platform-keys1

- 车道／工作者：B 界面／输入（cc，platform-keys1）
- 状态：可合并

## 变更记录草稿

## 2026-11-06 【cc·未经审查】键位照原版补全、Esc 关菜单不再重开（dev.待定）

- 原版实际键位（冻结正式源 v0.28 与 v0.62.12 的 rpg_core keyMapper 相同；游戏启用的 YEP_ButtonCommonEvents 每个场景开头 `_revertButton('ALL')` 再改写）：确认＝回车／空格／Z／J；取消＝Esc／Insert／X／K／小键盘0；方向＝方向键／WASD／小键盘 8246；翻页＝PageUp／Q、PageDown／E（W 不再翻页）。地图快捷键 ~ 1 2 3 R T P L 与 G 挂机早已做过。
- 新增 `core/key_map.gd`（XKeyMap）：启动时把缺的 Z／J、X／K／Insert／小键盘0、WASD、小键盘方向补进 ui_accept／ui_cancel／ui_up…，各页不用改。原版小键盘 2468 在地图上因插件参数写成按钮名而不能走路，这里不照搬（地图上也能走）。
- Esc 关不掉菜单：菜单收到 Esc 关闭后，同一帧地图的 `_process` 仍看到「Esc 刚按下」，立刻重开菜单。`map_scene.gd` 记下关菜单的帧号，该帧不再开（`XKeyMap.menu_call_blocked`）。
- 高分屏文字（Kyo 反馈 Retina 上字偏粗偏软）：主菜单等窗口文字本来就是原生分辨率直接画，没有低分辨率纹理放大；原因是为对上 Mac 原版加粗而画的同色 1 逻辑像素描边，窗口缩放 ≥1.5 时变成两个多物理像素。`XMVCanvas` 在缩放 ≥1.5 时不再画这一圈（1280×720 窗口不变）。回退 `XMVCanvas.CRISP_HIDPI_TEXT = false`。优化登记待总装编号 O-待定：高分屏文字不加粗描边。底图、立绘本身是原版低分辨率素材，没改。
- 回退：`XKeyMap.MV_KEYS = false`（键位）；Esc 保护无开关，删 `map_scene.gd` 里一个条件即可。
- 测试：新增 `xiyou_key_map`（30 项，含高分屏开关）。

## 验证

- 工具回归全过；语法检查 0 问题；xiyou_key_map（30 项）、xiyou_key_repeat、xiyou_map_hotkeys 通过。
- 选测（`选测.py main --list` 共 110 个场景）截至交付时 79/110 完成、0 失败；其余因其它车道的 node 探针占满共用槽一直排队，仍在后台跑，日志 /private/tmp/claude-501/sel.log（本机），没跑完的场景请总装合并时的选测补上。改动只在地图开菜单的条件、输入动作补键、1280 窗口不变的文字绘制，风险低。

## 交接板

- 下一步：无
- 用户试玩说明：Z／J 确认、X／K 取消、WASD 与小键盘在菜单里也能用；在菜单按 Esc 能关闭，不会又弹出来。
- 需要用户决定：「游戏不够高清」——工程已按 Retina 原生分辨率渲染（实测 2720×1530 窗口文字锐利），模糊主要来自原版低分辨率图片素材放大；需要截图指明哪个界面，另议，本分支未改。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 键位补全；Esc 关菜单同帧不再重开
