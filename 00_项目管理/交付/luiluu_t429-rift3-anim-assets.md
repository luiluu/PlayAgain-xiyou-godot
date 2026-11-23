# 交付：luiluu/t429-rift3-anim-assets

- 车道／工作者：三阶漫画动画④／小A（T429）
- 状态：可合并

## 变更记录草稿

## 2026-11-23 【小A·演出·未经审查】T429 三阶漫画动画④：全套定稿素材合成与接入 XRift3Anim（dev.待定）

- 玩家可见：二阶到三阶方桌大厅徐凤年回归过场正式升级为 30.5 秒 7 幕 15 格三色动态漫画动画（含新增徐凤年×染紫异化怪 4 格交互、0.00s～4.98s 物理连贯拔刀特写与刀锋纯白寒光、破页挥斩露真大厅、左侧破边立绘残格三连对白与碎页收尾），支持 0.8s 保护期后单次按键／点击跳过并精准补播未读台词；原像素过场仍可通过 `XRift.RIFT3_ANIM = false` 或 `XRift3Anim.ENABLED = false` 一键回退。
- 依据：私密设计仓 `重制设定/二阶到三阶_徐凤年回归动画_分镜_v0.6.md`（30.5s 15 格，5 句台词正文一字不改）；Kyo 定稿素材（T427 11 格、T437 斩怪交互 4 格含 `M9_v2`、`M5a` 定妆图、`M5b_拔刀_gemini_v1.mp4` 严格截取 `0.00s～4.98s` 零穿帮段）；小A·文字审定定稿 3 处新拟声字（P8b「嗖！」、P9a「铿！」、P9b「嗤！」）。
- 素材落盘（`03_再刷重制_Godot/01_Godot工程/content/rift3/`，共 20 个资产＋20 份 `.import`＋`README.md`，合计约 3.51 MB）：
  - `rift3_m1_1.webp`～`rift3_m1_4.webp`：M1 漩涡 4 格图接图（P2 平稳→加速，P3 紫色暴走→裂开）。
  - `rift3_m2_mob.webp`：M2 染紫异化怪透明 RGBA WebP（P5 破框出格＋P7 眼部横条复用）。
  - `rift3_m3_sky.webp`、`rift3_m4_dive.webp`：P6 高空掠影、P8 俯冲追杀安全带裁切。
  - `rift3_m7_p8a.webp`、`rift3_m8_p8b.webp`、`rift3_m9_p9a.webp`（严格采用 `M9_v2`）、`rift3_m10_p9b.webp`：T437 斩怪交互 4 格。
  - `rift3_m5b_sheet_0.webp`～`4.webp`：从 `M5b_拔刀_gemini_v1.mp4` 严格截取 `0.00s～4.98s`（严禁超过 5.0s，左手稳握黑鞘零穿帮），2× 提速均匀抽 30 帧（2.5s @ 12fps，单帧 960×440）拼 5 张 2×3 WebP 图集。
  - `rift3_mid_end.webp`：第 6 页（P9a＋P9b 定格）1280×720 合成尾帧，与引擎第 6 页定格像素级 1:1 对齐，供 P10 实时劈页无缝衔接。
  - `rift3_m6_slash.webp`：`M6_破框挥斩_v1.png` 经 `hflip` 水平镜像转为分镜要求的右上→左下挥斩，保留透明通道。
  - `rift3_m5a_portrait.webp`：M5a 胸像超采样（640×586）供 P11 破边立绘残格复用。
  - `rift3_comic_sfx.ogg`：复用工程既有 BGS（`Darkness`）与 SE 按分镜 v0.6 第 5 节 30.5s 时间轴混音（含 P9 末 0.3s 静音蓄力）。
- 代码改动：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/rift3_anim.gd`：
    - 四段状态机升级对齐分镜 v0.6：`TOTAL_DURATION=30.5`、`PHASE_P1_END=2.6`、`PHASE_MID_END=19.5`、`PHASE_P10_END=21.8`、`PHASE_P11D_START=29.2`、P11b 框边微紫闪中心 `25.7s`；5 句审定台词直读 `XRift.RIFT3_LINES` 正文一字不改，后 4 句显示与已看全阈值整体顺延 `+4.5s`。
    - 构建 Phase.MID 动态漫画 6 页实时合成舞台（P1 左格留驻＋P2/P3 漩涡图接图与幽紫蚀框裂脉→P4 三块实机大厅残格撕裂＋P5 M2 透明前景真出格→P6/P7 眼部反色闪/P8 红带连环追杀→P8a/P8b 落地对峙与怪扑侧闪→P9 M5b 30 帧 12fps 拔刀图集＋尾段程序柔和径向纯白刀锋光束与纤细四芒十字星芒→P9a/P9b 刀爪硬撼与一刀斩怪化紫雾，末 0.15s 定格像素级无缝移交 P10 劈页）。
    - 新增 3 处审定定稿拟声字独立常量 `SFX_P8B="嗖！"`（套用硬朗瘦劲刀笔斜体 `FontVariation`）、`SFX_P9A="铿！"`、`SFX_P9B="嗤！"`，共 11 处叠字（10 拟声＋1 唯一刀意字「斩」）。
    - 解决 T430 核 P3-2 `available()` 门槛：19 项核心视觉资产全列入 `REQUIRED_ASSETS`，真运行时 `available()` 恒核三层开关与全部资产，全齐即真、缺任一项安全回退 `false`。
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim_player.gd`、`tests/xiyou_rift3_anim_fx.gd`、`tests/xiyou_rift3_anim.gd`：同步 v0.6 30.5s 时间轴、跳过点 `1.0s`/`15.0s`/`27.5s`、11 处叠字、真实仓内零 override `available()==true` 端到端实跑及 6 张关键帧实机截图。
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_e2e.gd`：`_settle()` 补上大厅播放 `XRift3Anim` 时按确定键跳过（模拟真实玩家进大厅按键跳过漫画并翻完补播对话，解决全量云端首轮 793 场景中唯一超时的该项）。
- 专项与验证：
  - 本机实跑（全部加 `--audio-driver Dummy`）：
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim_player.tscn`：**83/83**（0 泄漏）
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim_fx.tscn`（带窗口真机渲染＋截图）：**45/45**
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim.tscn`：**70/70**（0 泄漏）
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_xufeng.tscn`：**53/53**
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_lobby_corruption.tscn`：**139/139**
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_hall_intro.tscn`：**67/67**
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_e2e.tscn`：**60/60**
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_ui_detail_d3.tscn`：**93/93**
  - 静态与空壳检查：`语法检查.py`（1192 个 `.gd` 0 个问题）、`发行空壳.py check`（81 个脚本 782 个函数全过，退出码 0）。
  - 云端选测（提交 `c06a778f23`，基准 `1ed54e63e4`）：**通过**（整轮 793 个场景、16 片全绿，最长一片 18.3 分钟），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45274274763 。
- 真机渲染截图（均已入仓 `00_项目管理/交付截图/luiluu_t429/`）：
  - `00_项目管理/交付截图/luiluu_t429/01_p8b_dodge.png`（P8a 落地对峙＋P8b 怪扑侧闪＋审定瘦劲拟声字「嗖！」）
  - `00_项目管理/交付截图/luiluu_t429/02_p9_draw_blade.png`（P9 M5b 0.00～4.98s 零穿帮拔刀特写＋程序柔和纯白刀锋光束与纤细十字星芒＋「锵——！」）
  - `00_项目管理/交付截图/luiluu_t429/03_p9a_clash.png`（P9a 刀爪相撞 v2＋审定拟声字「铿！」）
  - `00_项目管理/交付截图/luiluu_t429/04_p9b_cleave.png`（P9b 一刀斩怪化紫雾＋审定拟声字「嗤！」）
  - `00_项目管理/交付截图/luiluu_t429/05_p10_slash_split.png`（P10 劈开第 6 页画页露出真实方桌大厅＋碎格粒子＋水平镜像 M6 右上→左下破框挥斩）
  - `00_项目管理/交付截图/luiluu_t429/06_p11a_dialogue.png`（P11a 左侧 M5a 破边立绘残格＋右侧尖尾漫画对白气泡与常驻朱红名签＋真实方桌大厅）

## 交接板

- 下一步：合并 `luiluu/t429-rift3-anim-assets` 后，三阶漫画动画全套正式素材与播放器接线即全链路生效；可进入拆卡 7 甲档核查与 Kyo 实机整片体验验样。
- 用户试玩说明：二阶进三阶方桌大厅触发徐凤年回归过场时，将自动播放 30.5 秒完整三色动态漫画动画（含新增 4 格人怪斩杀交互、零穿帮拔刀与刀锋纯白寒光、破页挥斩露真大厅、残格三连对白与碎页收尾），0.8 秒后随时按键／点击可跳过并精准补播未读台词。
- 需要用户决定：无。

## 进度账

- 西游／三阶过场漫画动画：完成拆卡 4 全套定稿素材合成与接入（`content/rift3/`＋`XRift3Anim` v0.6 升级＋真机截图与全量 793 场景云端通过），主表百分比不变。

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

- 无（未改动 `core/`、`battle/`、`skin/` 下任何共用函数或开关；仅改独占文件 `modes/xiyou/ui/rift3_anim.gd`、`content/rift3/` 及相关测试与截图）

## 云端选测与独占范围

- 云端选测（提交 `c06a778f23`，基准 `1ed54e63e4`）：**通过**（整轮 793 个场景、16 片全绿，最长一片 18.3 分钟），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45274274763
- 截图（6 张全已提交入仓）：
  - `00_项目管理/交付截图/luiluu_t429/01_p8b_dodge.png`
  - `00_项目管理/交付截图/luiluu_t429/02_p9_draw_blade.png`
  - `00_项目管理/交付截图/luiluu_t429/03_p9a_clash.png`
  - `00_项目管理/交付截图/luiluu_t429/04_p9b_cleave.png`
  - `00_项目管理/交付截图/luiluu_t429/05_p10_slash_split.png`
  - `00_项目管理/交付截图/luiluu_t429/06_p11a_dialogue.png`
- 独占范围改动清单：
  - `03_再刷重制_Godot/01_Godot工程/content/rift3/`（20 个素材＋20 份 `.import`＋`README.md`）
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/rift3_anim.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim_player.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim_fx.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_e2e.gd`
  - `00_项目管理/交付截图/luiluu_t429/`（6 张 PNG）
  - `00_项目管理/交付/luiluu_t429-rift3-anim-assets.md`

## 本分支提交

- `0b2b1fb72` T429 三阶漫画动画④：全套定稿素材合成与接入 XRift3Anim（分镜 v0.6，30.5s 15格）
- `c06a778f2` T429 修 xiyou_tianqi_e2e._settle 进大厅遇 XRift3Anim 漫画过场时按键跳过（全量云端 793 仅此 1 处）
