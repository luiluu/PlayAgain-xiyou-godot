# 天启篇启动动画

- `tianqi_intro_v8.ogv`：启动动画 O7 v8_cc（Kyo 2026-11-11 定稿）的前 134 帧（0～4.47 秒：指尖撑裂、裂口定住、天启之眼睁开后用自己的眼睑合上）。
  成片后段的警告屏和标题是预览画的，游戏里换成真的 `XWarningScreen` 和标题，所以只剪到合眼为止。
- 1280×720、30 帧每秒、Ogg Theora（Godot 只认这一种视频）。用 Godot 4.7 自带的 Movie Maker 逐帧写出（`--write-movie *.ogv --fixed-fps 30`，`movie_writer/video_quality=1.0`），
  源是本机美术目录里的 `O7_intro_motion_v8_cc.mp4`；与源帧比 PSNR 约 40 dB。
- 接入代码：`modes/xiyou/ui/intro_anim.gd`（`XIntroAnim`），回退开关 `XIntroAnim.ENABLED = false`。
