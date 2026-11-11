# 天启篇标题页素材

游戏用的成品图，接入代码 `modes/xiyou/ui/tianqi_title.gd`（`XTianqiTitle`），回退开关 `XTianqiTitle.ENABLED = false`。
源文件在本机新美术目录 `TianqiTitle_v1`（Git 排除，原稿不进仓库），这里只放游戏真正读的文件。

| 文件 | 美术编号与版本 | 尺寸 | 处理 |
| --- | --- | --- | --- |
| `bg.png` | T1 标题底图 v2（`T1_title_background_v2_1280x720.png`） | 1280×720 不透明 | 原样拷贝 |
| `logo.png` | T2 书法 Logo v2（`T2_logo_calligraphy_v2.png`，原图 1600×500 透明） | 1220×381 透明 | Lanczos 缩到 1220 宽（游戏里显示宽 610、左上 (335,7)，与启动动画 v8 成片相同，2 倍图省体积） |
| `cmd_new_game.png` | T3「新的游戏」v3（`T3_new_game_button_v3_200x105.png`） | 200×104 透明 | 两态竖排：上半选中（亮色）、下半未选中。原图高 105，第 52 行（两半之间）全透明，删掉这一行，高度变偶数、上下各 52 |
| `cmd_load.png` | T3「旧的回忆」v2（`T3_old_memories_v2_200x105.png`） | 200×104 透明 | 同上 |
| `cmd_options.png` | T3「游戏设置」（`T3_game_settings_200x105.png`） | 200×104 透明 | 同上 |
| `cmd_achievements.png` | T3「游戏成就」（`T3_game_achievements_200x105.png`） | 200×104 透明 | 同上 |
| `cmd_check_update.png` | T3「检查更新」（`T3_check_updates_200x105.png`） | 200×104 透明 | 同上 |
| `cursor.png` | T4 三角光标 v2（`T4_cursor_triangle_v2_36x50.png`） | 36×50 透明 | 原样拷贝（游戏里缩到 0.4 倍） |
| `eye_0.png`～`eye_6.png` | 标题睁眼帧（占位） | 307×297 不透明 | 启动动画 v8 合成脚本的眼睑算法对 T1 算出的 7 帧，闭合度依次 1.0、0.88、0.7、0.5、0.3、0.14、0.04；是底图 (611,132)～(918,429) 的切片，盖在底图同位置。等美术拆好五层眼再换 |

- 「新的游戏」「Logo」「底图」「光标」已定稿；另外四个按钮和菜单动效 v2 还没看稿，换图只换同名文件。
- 进场时间线照启动动画 v8 成片后段（30 帧／秒）：1.2 秒从黑里亮起 → 第 26 帧起逐帧睁眼 → 第 36～56 帧 Logo 上浮 8 像素淡入。
