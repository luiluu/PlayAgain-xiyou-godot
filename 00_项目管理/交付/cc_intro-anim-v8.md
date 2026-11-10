# 交付：cc/intro-anim-v8
- 车道／工作者：B 界面／cc（天启篇启动动画）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·未经审查】天启篇启动动画 v8 接入游戏（dev.待定）
- Kyo 2026-11-11 定稿的启动动画 v8_cc 接进西游（天启篇）标题：开场先放 4.47 秒动画（指尖撑裂、裂口撑满后定住、天启之眼睁开再用自己的眼睑合上），合眼后 0.1 秒压黑，接已有的开场声明屏（XWarningScreen，O-259），声明屏结束后标题用 1.2 秒从黑里淡入。
- 视频只取成片前 134 帧（到合眼为止）：成片后段的警告屏和标题是预览画的，游戏里换成真的声明屏和标题。转成 Ogg Theora（Godot 只认这一种视频），用 Godot 4.7 自带 Movie Maker 逐帧写出，1280×720、30 帧每秒、1.5 MB，与源帧比 PSNR 约 40 dB；放在 `content/intro/`（来历写在同目录 README）。
- 美术进公开仓库照 11-05 应用图标的先例（天穹巨眼图标从本机美术目录拷进 `content/app_icon/`）。
- 新类 `XIntroAnim`（`modes/xiyou/ui/intro_anim.gd`）：时间按真实秒计，变速齿轮（time_scale 1.6）下视频和淡入不跟着变快；任意键、确定、点一下跳过（直接压黑接声明屏，声明屏自己的 0.5 秒防连按照旧）；放不放跟声明屏同一套（一次运行一次、测试与按键冒烟不放、XIYOU_SPLASH 强制），另外要天启篇开着（`XTianqi.ENABLED`，O-260 回退到原版开局时不放）。入口菜单和「新版」入口不动。
- 回退：`XIntroAnim.ENABLED = false` 回到只放声明屏、标题直接出（O-待定·启动动画，已登优化登记）。
- 选测对照加 `content/intro/*` → 新组 `intro_video`（只跑 xiyou_splash_autosave），免得改视频落到整轮。
- 玩家可见：启动游戏先看到天启之眼撕开画面、眨眼的开场动画（可按任意键跳过），再是免费声明，然后标题从黑里亮起。

## 交接板
- 下一步：无新增。标题上的眼睛睁开（成片里 T1 标题底图＋眼睑）没接：游戏标题仍是原版 titles1 底图，换天启篇标题底图／Logo 另排。
- 用户试玩说明：启动游戏先放天启之眼开场动画（约 4.5 秒，任意键跳过）→ 免费声明屏 → 标题淡入。
- 需要用户决定：无（视频进公开仓库照应用图标先例，Kyo 不同意的话合并前撤掉 `content/intro/` 并把 `XIntroAnim.ENABLED` 改 false 即可）。

## 进度账
- 无（天启篇新增，不在主表）

## 验证
- `语法检查.py` 通过；`工具回归.py` 全部通过（74 秒）；`回退开关覆盖.py` 通过。
- 选测（`选测.py main --list` 13 个场景）：ui_smoke、xiyou_entry_release、xiyou_event_compare、xiyou_event_compare_b／c／d、xiyou_flow、xiyou_input_handled、xiyou_key_smoke、xiyou_platform、xiyou_reincarnation_entry、xiyou_save_page 通过；xiyou_splash_autosave 首轮挂在我自己写错的跳过断言（一步 0.2 秒已经压黑完），改成 0.02 秒后单跑 72/72 通过。
- 本机 Movie Maker 录了一遍真实流程（XIYOU_SPLASH=1 进西游标题，480 帧）：动画 → 0.1 秒压黑 → 声明屏 → 标题约 1.1 秒从黑里亮起，画面对。

## 可优化（流程／工具／效率）
- 已做：选测对照给 `content/intro/*` 单独一组（回退：删这条规则，落回整轮）。
- 建议：Movie Maker（`--write-movie` ＋ `--fixed-fps 30`）录真实开场流程比截图好核时序，可做成开场类改动的专项工具（界面车道）。

## 本分支提交
- 见 `git log main..cc/intro-anim-v8`
