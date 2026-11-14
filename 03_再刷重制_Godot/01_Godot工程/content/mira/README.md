# 米拉人形新美术（168）

co 2026-11-13 出图、Kyo 已确认定稿的人形 u2 美术，代替原版人形行走图与 `UserSV_MiraHuman` 多帧战斗图；黑龙形态仍用原版 `UserSV_MiraDragon` 多帧。

- 来源：`/Users/kyo/.codex/generated_images/01a1d6f2-3650-7fa0-aa8a-a14f105bdf8f/米拉_重画_u2/`（定稿记录 `米拉人形_u2_定稿记录.md`），文件名保持不变。
- 接入：
  - `XDB.img_path` 在 `XMira.ART` 开着时，米拉行走 `$BlackDragon_Mira`／`$Codex_Mira_Walk_u2` 与战斗 `Codex_Mira_SV_u2`／`BlackDragon_Mira_SV` 优先读这里，不读 `modes/xiyou/generated/img/`，重跑同步不会盖掉。
  - `XAppearance.sv_form`／`for_look` 对米拉人形（`MiraHuman_u2`）改用 9×6 侧视图 `Codex_Mira_SV_u2`（64×64 格，最近邻、脚底对齐格内第 61 行），黑龙（`MiraDragon`）不变。
  - `XAppearance.PROFILES["Codex_Mira_SV_u2"] = [64, 64, 8, 3, 53, 61]`（以定妆 64×64 待机第 2 帧为准：可见高 58、脚底第 61 行，缩放 `72 / 58`）。
  - `XActorBook.sprite_spec(168)` 在 `XMira.ART` 开着时画 `Codex_Mira_SV_u2`（第 1 行走姿帧，按同一归一档缩放）。
- 回退：`XMira.ART = false`，人形行走回到 `$BlackDragon_Mira`，战斗与图鉴回到 `UserSV_MiraHuman` 多帧。
- 测试：`tests/xiyou_mira_art.tscn`。

| 文件 | 内容 | 尺寸 |
| --- | --- | --- |
| `img/characters/$Codex_Mira_Walk_u2.png` | u4 四方向三帧行走（脚底第 45 行） | 144×192，每格 48×48 |
| `img/sv_actors/Codex_Mira_SV_u2.png` | 人形战斗图，18 动作×3 帧（脚底第 61 行） | 576×384，每格 64×64 |
