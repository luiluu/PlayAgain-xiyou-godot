# 宿傩新美术（172）

Kyo 2026-11-13 审过的新图，代替同步出的原版旧图。宿傩是原版角色，这批图随 0.01.08 进玩家补丁（Kyo 11-13「这个也进0.01.08」）。

- 来源：Codex 交的 `Sukuna_Godot_Integration.zip`（隔离工程 101 项检查通过），原样拷进来，目录照 `img/` 的相对路径。
- 接入：`XDB.img_path` 在 `XSukuna.ART` 开着时，`Codex_Sukuna_*` 先读这里，不读 `modes/xiyou/generated/img/`，重跑同步不会盖掉。
- 归一档：两态待机可见高都是 58、脚底都在第 61 行，`XAppearance.PROFILES` 换成新档（包里的 `宿傩战斗锚点.patch`）；旧档留在 `SUKUNA_OLD_PROFILES`，`XAppearance.profile_of` 按开关选。
- 回退：`XSukuna.ART = false`，旧图和旧档一起回来。
- 测试：`tests/xiyou_sukuna_art.tscn`。

| 文件 | 内容 | 尺寸 |
| --- | --- | --- |
| `img/characters/$Codex_Sukuna_Walk.png` | u4 四方向三帧行走 | 144×192，每格 48×48 |
| `img/sv_actors/Codex_Sukuna_SV.png` | 常态战斗图，18 动作×3 帧 | 576×384 |
| `img/sv_actors/sv/Codex_Sukuna_QFull/` | 四手完全体逐帧，待机 1 张、其余 17 动作各 3 张，共 52 张 | 64×64 |

八帧左走样段是独立预览，没进工程。
