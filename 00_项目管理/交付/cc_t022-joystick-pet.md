# 交付：cc/t022-joystick-pet

- 车道／工作者：T022 摇杆白块（cc，Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·未经审查】触屏摇杆头行走图不再显示成白块（dev.待定）

- 现象：原版虚拟摇杆（Mehmet_GhostButtons 风格）的摇杆头正中本应画队长行走图，实际是一块淡色方块。
- 根因：`XTouchControls._draw_ghost_knob` 直接拿行走图 `CompressedTexture2D` 做 `draw_texture_rect_region`，该贴图在读过 `get_image()` 之前画出来是一整块白（1280×720、`1-XiaoMing`／`Actor1` 都复现；多次重画、等 30 帧都不好，读一次 `get_image()` 就好）。
- 修法（`core/touch_controls.gd`）：把摇杆头要画的那一格取成 `ImageTexture` 缓存（`_knob_cell`，键＝贴图路径＋格子），再用它画；取不到图时退回原写法。几何、裁切、透明度不变。
- 验证：1280×720 带窗口 Godot（`--audio-driver Dummy`）修前截图白块、修后连截 3 次逐字节相同且行走图正常（`1-XiaoMing` 与调色板型 `Actor1` 都试过）；`xiyou_platform` 155/155。截图在 `00_项目管理/归档/交付截图/cc_t022-joystick-pet/`（`knob_before.png`、`knob_after.png`、`knob_after_actor1.png`、`knob_after_font130.png`＝字体大小 130% 档）。
- 玩家可见：触屏摇杆头正中显示队长行走图，不再是白块。

## 交接板

- 下一步：无
- 用户试玩说明：触屏模式看摇杆头里有没有队长小人。
- 需要用户决定：无

## 进度账

- 无变化（缺陷修复）

## 可优化（流程／工具／效率）

- 已做：无。
- 记一条工具坑：新建工作树里 `07_开发环境/当前Godot.app`、`引擎` 不会自带，`godot` 包装脚本直接报找不到；本单手动软链到主工作区的 `引擎/4.7.2-stable`（`引擎` 已写进 `.git/info/exclude`，未提交）。建议 `新建工作树.sh --补齐` 顺带补这个软链（归工具车道）。
- 记一条查明的事：`start_troop_4/5` 挂的原因是守层者 4/5 触发 `XRiftAlien.ALIGN_LOBBY` 的侵染前缀（「侵染·」），main 8d354958c 已修（原写「新树缺 generated」不成立，总装 11-16 照协调更正）；合后在 main 上 `pet_capture` 连跑 5 次确认。

## 本分支提交

- 见 `git log main..cc/t022-joystick-pet`
