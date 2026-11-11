# 时空漩涡二阶段素材

接入代码 `modes/xiyou/core/rift.gd`（`XRift`，O-待定·漩涡二阶段），回退开关 `XRift.STAGE2 = false`。地图读图走 `XDB.img_path`：转换产物里没有的，再到 `content/rift/` 找同名文件。

| 文件 | 来历 | 尺寸 | 处理 |
| --- | --- | --- | --- |
| `!Codex_Rift_Stage2.png` | 本机 `再刷西游/01_开发工程/Louis/rpg-maker-mac/remake-rift-v06207-20261031/art/`（v0.62.07 大厅漩涡一并做的五阶图，私密仓库 luiluu/Game 分支 claude/project-thread-jfenti 上是同一份） | 1344×576 透明 | 原样拷贝。`!` 开头不偏移、非 `$`：一张 8 格（4×2），每格 3×4 帧，每帧 112×72，8 格×4 朝向＝32 个角度循环旋转 |

三～五阶图（`!Codex_Rift_Stage3～5.png`）同在原目录，以后的阶段再拷。
