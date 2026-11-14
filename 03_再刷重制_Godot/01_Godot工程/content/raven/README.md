# 渡鸦神话形态新美术（167）

Kyo 2026-11-15 定稿（`Raven_Myth_Final_Motions/UserSV_RavenMythic/`）的 18 动作 20 帧逐帧战斗图，代替同步出的原版 `UserSV_RavenMythic` 多帧战斗图；渡鸦普通形态（`Raven_Normal_SV`）与行走图保持不变。

- 来源：`/Users/kyo/.codex/visualizations/2026/11/12/01a1d218-ec06-7b73-ba92-c1fb2dcae350/local_art/Raven_Myth_Final_Motions/UserSV_RavenMythic/`（说明 `README.md`、`manifest.json`），文件命名严格保留 `UserSV_RavenMythic动作_帧.png`。
- 规格：20 张 340×280 二值透明（alpha 仅 0/255）PNG，全部可见框包含于 `[61, 58, 259, 217]`，脚底统一第 217 行（`0_0` 站姿格可见框 `[66, 58, 255, 217]`，可见高 159，归一缩放 `72 / 159`，与黑龙 `UserSV_MiraDragon` 一致）。
- 接入：
  - `XRaven.ART`（默认 `true`）开启时，`XDB.img_path` 将 `UserSV_RavenMythic*` 优先指到 `res://content/raven/img/sv_actors/sv/UserSV_RavenMythic/`，不覆盖也不删除 `modes/xiyou/generated/img/` 原版图，重跑同步不会盖掉。
  - `XAppearance.PROFILES["UserSV_RavenMythic"] = [340, 280, 66, 58, 255, 217]`（340×280 画布、脚底 217 行、可见高 159，同黑龙尺寸／脚底对齐）。
- 回退：`XRaven.ART = false`，`XDB.img_path` 回到 `modes/xiyou/generated/img/sv_actors/sv/UserSV_RavenMythic/`，`XAppearance.profile_of("UserSV_RavenMythic")` 回到 `RAVEN_OLD_PROFILE`（`[380, 280, 84, 55, 268, 211]`）。
- 测试：`tests/xiyou_raven_myth_art.tscn`。

| 文件 | 源动作号 | 帧数 | 覆盖动作 |
| --- | --- | --- | --- |
| `UserSV_RavenMythic0_0..3.png` | 0 | 4 | `walk` / `wait` / `chant` / `escape` |
| `UserSV_RavenMythic3_0.png` | 3 | 1 | `guard` |
| `UserSV_RavenMythic4_0.png` | 4 | 1 | `damage` |
| `UserSV_RavenMythic5_0.png` | 5 | 1 | `evade` |
| `UserSV_RavenMythic7_0..3.png` | 7 | 4 | `thrust` / `swing` / `missile` |
| `UserSV_RavenMythic10_0..3.png` | 10 | 4 | `skill` / `spell` / `item` |
| `UserSV_RavenMythic13_0.png` | 13 | 1 | `victory` |
| `UserSV_RavenMythic14_0.png` | 14 | 1 | `dying` |
| `UserSV_RavenMythic15_0.png` | 15 | 1 | `abnormal` |
| `UserSV_RavenMythic16_0.png` | 16 | 1 | `sleep` |
| `UserSV_RavenMythic17_0.png` | 17 | 1 | `dead` |
