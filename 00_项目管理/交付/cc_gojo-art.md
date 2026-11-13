# 交付：cc/gojo-art

- 车道／工作者：天启篇五条悟正式美术／cc（五条悟线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·五条悟·未经审查】五条悟换正式美术、无量空处领域背景（dev.待定）

- Kyo 11-12 定稿的五条悟美术（源 `02_内容与素材/新美术/五条悟/`，Git 排除）用新工具 `03_转换工具/五条悟美术导出.py` 导出到 `content/gojo/`（来源、尺寸见该目录 README）：头像抠绿缩 144 放进头像表第 1 格；技能 9、被动 4、进阶 3、眼罩 1 共 17 个图标抠绿缩 128；行走图、战斗图换成定稿文件；领域背景原样。
- 图标号 `XGojo.ICON_BASE`（320000）＋定稿任务号，`XUI.icon_texture` 分流到 `XGojo.icon_texture`；技能、状态（苍印、赫印、无量空处、觉醒）、眼罩开表时用新号，进阶四用领域图标。
- 无量空处领域背景：战斗画面（`battle_scene`）在战斗背景上加一层，我方五条悟的领域开着时淡入（约半秒），结束淡出。
- 没接：被动图标 14A「共用黑闪」——黑闪 10225 是甚尔、宿傩共用的原版技能，换图会改到原版档，要换另说。
- 回退开关 `XGojo.ART`（O-待定-1）：false 照旧借图、不铺领域背景。
- 玩家可见：无（天启篇只在 Kyo 本地）。

## 交接板

- 下一步：无（五条悟设计、机制、开放、美术都齐了）。
- 用户试玩说明：天启篇里五条悟的头像、技能和眼罩图标是新图；放无量空处时战斗背景换成宇宙背景。
- 需要用户决定：共用黑闪的新图标（14A）要不要连原版档的甚尔、宿傩一起换。

## 优化登记

| 编号 | 位置 | 原版 | 重制 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/gojo.gd` `XGojo.ART` | 没有五条悟 | 五条悟正式头像、17 个图标、无量空处领域背景 | Kyo 11-12 美术定稿 | `XGojo.ART = false` | cc | 保留 |

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 语法检查通过；`xiyou_gojo` 74/74（新加图标号、17 张图标都能取到且是 128×128、领域背景在、领域开着时 domain_shown）。
- 选测 16 个全过：`xiyou_gojo`、`ui_smoke`、`xiyou_battle_ui`、`xiyou_battle_log`、`xiyou_battle_pixel`、`xiyou_battle_bgm`、`xiyou_battle_events`、`xiyou_black_flash_ui`、`xiyou_actor_sv_compare`、`xiyou_tianqi_skills`、`xiyou_rift2_canglong`、`xiyou_xuan_battle`、`xiyou_actor_book`、`xiyou_actor_advanced`、`xiyou_skill_mastery`、`xiyou_determinism`。
- 没做：实机截图核对（无头测试不出画面），图标、头像、领域背景在 Kyo 本机开天启篇看一眼即可。

## 本分支提交

- （见 git log）
