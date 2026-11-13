# 交付：cc/feedback-qq-group

- 车道／工作者：界面·反馈群入口／cc（Kyo 11-13 让玩家加 QQ 群反馈）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·界面·未经审查】游戏里加反馈 QQ 群入口：标题右下角点击复制、警告屏、检查更新页、发行说明（dev.待定）

- 起因：Kyo 让玩家加 QQ 群 1097315054 反馈，要显眼又不打扰的入口。协调给了几个落点，按推荐方案 A 做（标题＋警告屏＋更新页＋发行说明；设置页照原版像素对照，没加）。
- 新增 `core/feedback.gd`（XFeedback）：群号只写这一处；`make_button()` 是不抢焦点的扁平按钮，点一下 `DisplayServer.clipboard_set` 复制群号（Mac／Windows／安卓都可用），两秒内显示「已复制群号」，计时器挂在按钮下（换页不会回调到已释放的按钮）。回退开关 `XFeedback.SHOW = false`：标题、警告屏不放群号行，更新页不加复制按钮。
- 标题（`entry.gd` `_add_feedback`，新旧两种标题都加）：右下角版本说明上方一行金色小字「问题反馈 QQ 群：1097315054（点击复制）」，不进键盘选单。
- 开场警告屏（`warning_screen.gd`）：英文行下方一行金色字，只显示（这一屏点一下是跳过）。
- 检查更新页（`update_page.gd`）：`GROUP_HINT` 带上群号（「请到 QQ 群 1097315054 的群文件下载」，整包、下载失败、查不到三处都用它）；关闭按钮下面加复制群号按钮。
- 发行说明（`发行出包.py` `notes_text`）末尾加「问题反馈、新版本下载：QQ 群 1097315054」；`测试发行出包.py` 比对它跟 `feedback.gd` 的群号一致。
- 没做：游戏里没有单独的出错／卡死弹窗，启动失败自动退回的说明就在检查更新页里，已覆盖。
- 验证：语法检查 0 问题；专项 xiyou_update_check（74）、xiyou_splash_autosave（78 窗口跑）、xiyou_tianqi_title_flow（42）全过；选测其余 ui_smoke、xiyou_entry_release、xiyou_flow、xiyou_input_handled、xiyou_key_smoke、xiyou_platform、xiyou_reincarnation_entry、xiyou_save_page、xiyou_tianqi_title、xiyou_update_install 全过；测试发行出包.py 全过。xiyou_event_compare×4 没跑：entry.gd 只在标题加了一个按钮，不碰地图事件。窗口截图看过标题、警告屏、更新页三处位置不挡东西。
- 玩家可见：标题右下角、开场警告屏和检查更新页都写了问题反馈 QQ 群 1097315054，点一下就能复制群号。

## 交接板

- 下一步：无新增
- 用户试玩说明：标题右下角金色小字点一下复制群号；开场警告屏、检查更新页也有群号。
- 需要用户决定：无（落点按方案 A；Kyo 想再加设置页入口另说）

## 进度账

- 无（新功能，不涉原版完成度）

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log
