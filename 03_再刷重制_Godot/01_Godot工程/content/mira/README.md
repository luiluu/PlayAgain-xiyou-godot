# 米拉人形新美术（168）

co 出图、Kyo 已确认定稿的人形美术：行走图 u3 定稿（11-15，`$Codex_Mira_Walk_Final.png`）与战斗图 u2 定稿（11-13，`Codex_Mira_SV_u2.png`），代替原版人形行走图与 `UserSV_MiraHuman` 多帧战斗图；黑龙形态见文末「黑龙无剑 21 张＋召剑特效」一节。

- 来源：
  - 行走图：`/Users/kyo/.codex/visualizations/2026/11/12/01a1d218-ec06-7b73-ba92-c1fb2dcae350/local_art/Mira_Dragon_Redo/$Codex_Mira_Walk_Final.png`（u3 定稿，文件名保持不变）。
  - 战斗图：`/Users/kyo/.codex/generated_images/01a1d6f2-3650-7fa0-aa8a-a14f105bdf8f/米拉_重画_u2/`（定稿记录 `米拉人形_u2_定稿记录.md`，文件名保持不变）。
- 接入：
  - `XDB.img_path` 在 `XMira.ART` 开着时，米拉行走 `$BlackDragon_Mira`／`$Codex_Mira_Walk_Final` 与战斗 `Codex_Mira_SV_u2`／`BlackDragon_Mira_SV` 优先读这里，不读 `modes/xiyou/generated/img/`，重跑同步不会盖掉。
  - `XAppearance.sv_form`／`for_look` 对米拉人形（`MiraHuman_u2`）改用 9×6 侧视图 `Codex_Mira_SV_u2`（64×64 格，最近邻、脚底对齐格内第 61 行），黑龙（`MiraDragon`）不变。
  - `XAppearance.PROFILES["Codex_Mira_SV_u2"] = [64, 64, 8, 3, 53, 61]`（以定妆 64×64 待机第 2 帧为准：可见高 58、脚底第 61 行，缩放 `72 / 58`）。
  - `XActorBook.sprite_spec(168)` 在 `XMira.ART` 开着时画 `Codex_Mira_SV_u2`（第 1 行走姿帧，按同一归一档缩放）。
- 回退：`XMira.ART = false`，人形行走回到 `$BlackDragon_Mira`，战斗与图鉴回到 `UserSV_MiraHuman` 多帧。
- 测试：`tests/xiyou_mira_art.tscn`。

| 文件 | 内容 | 尺寸 |
| --- | --- | --- |
| `img/characters/$Codex_Mira_Walk_Final.png` | u3 定稿四方向三帧行走（可见高 47、脚底第 47 行 0-based，与原版同高） | 144×192，每格 48×48 |
| `img/sv_actors/Codex_Mira_SV_u2.png` | 人形战斗图，18 动作×3 帧（脚底第 61 行） | 576×384，每格 64×64 |

## 黑龙无剑 21 张＋头顶召剑特效（Kyo 11-15 通过，开关 `XMira.DRAGON_ART`）

co 出的 `Mira_Dragon_Unarmed_Motions_u1`（21 张，原版文件名，340×280、可见框 [61,58,260,217]、底锚 y=217、alpha 只 0/255）与 `Sword_FX_u2`（128×128，出现／悬停／消散各 3 张＋clear）。来源目录 `/Users/kyo/.codex/visualizations/2026/11/12/01a1d218-ec06-7b73-ba92-c1fb2dcae350/local_art/Mira_Dragon_Redo/`，说明 `README_Unarmed21_SwordFX_u2.md`。

- `img/sv_actors/sv/UserSV_MiraDragon/`：21 张，`XDB.img_path` 在开关开着时优先读这里（外观按 `sv_actors/sv/UserSV_MiraDragon/UserSV_MiraDragon<动作>_<帧>` 取），站姿归一档 `UserSV_MiraDragon` 不变。`dragon_unarmed_manifest.json` 是 co 的动作映射。
- `fx/sword_u2/`：召剑特效 10 张＋`manifest.json`（中心锚 [64,64]，相对龙底锚 [160,217] 偏移 [-40,-200]；出现、消散每帧 100ms，悬停 140ms 循环）。
- 召剑是独立层 `XMiraSwordFx`（`modes/xiyou/battle/mira_sword_fx.gd`），挂在 `XBattlerSprite` 下；`SKILLS = [10151]`：**只有 10151 黑日焚界召剑**，平时不挂剑（Kyo 11-15 定，D34）。`battle_scene._perform_action` 末尾调 `on_skill`，行动收尾调 `vanish_all`。
- 回退：`XMira.DRAGON_ART = false` → 回到原版带剑 `UserSV_MiraDragon`，召剑层也不建；人形开关 `XMira.ART` 另算。
- 测试：`tests/xiyou_mira_dragon_art.tscn`（窗口模式加 `-- --out=<目录>` 存与原版并排的截图）。
- 不在本批：放大倍数。升空变身演出见下一节（u7）。

## 升空变身 u7（Kyo 11-15 通过 D35，开关 `XMira.LIFT_ART`）

co 出的 `米拉_黑龙升空变身_u7`（来源 `/Users/kyo/.codex/generated_images/01a1d6f2-3650-7fa0-aa8a-a14f105bdf8f/米拉_黑龙升空变身_u7/`，说明 `接入说明.md`、`时间轴.json`）。

- `fx/lift_u7/`：8 张过渡姿势（340×280，锚 [160,217]：MiraLift／MiraHover／MiraWingHuman／MiraHybrid／MiraAir／MiraDescend／MiraTouchdown／MiraSettle）＋4 张火屑（256×256，中心锚：MiraEmberLift／Arc／Scatter／Landing），共 12 张 288 KB，与来源逐字节相同。人形起点直接取 `img/sv_actors/Codex_Mira_SV_u2.png` 第 1 行第 1 列格（来源 human.png 就是这一格），Final 直接用 `UserSV_MiraDragon0_0.png`（来源 dragon.png 字节相同），不另拷。
- 只拷运行时要的：116 张帧序列（body／fx_back／composite）、GIF、母图、脚本都没进工程。按时间轴拼（`XMiraLiftFx`，`modes/xiyou/battle/mira_lift_fx.gd`），关键帧照 `时间轴.json` 写在代码常量里。
- 接线：`XBattlerSprite.swap_look` 末尾 `XMiraLiftFx.on_swap`：人形→黑龙（2592 加上后外观键变）时挂层开演；只是画面，状态与结算不等它。「显示技能动画」关着（默认关）或快速战斗直接是黑龙。
- 回退：`XMira.LIFT_ART = false`（外观一变直接换成黑龙，同接入前）。
- 测试：`tests/xiyou_mira_lift.tscn`（窗口模式加 `-- --out=<目录>` 存 6 张变身过程截图）。
