# 交付：cc/party-formation

- 车道／工作者：B 界面＋战斗场景站位（cc，Orca worker，claude-opus-5-5＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·未经审查】战斗我方站位可选：两排错开／菱形／原版竖排（O-待定，dev.待定）

- 玩家可见：设置里新增「战斗站位」（两排错开／菱形／原版竖排，默认两排错开），下一场战斗起生效；编队第 1～4 位固定站阵型的第 1～4 个点，谁站哪靠编队决定。原来 4 人竖排一列、角色放大后叠在一起的问题没了。
- 起因：Kyo 2026-11-15「做菱形和两排错开。设置里面可以更改，位置对应上编队位置」。
- 点位（脚底坐标，1280×720；「前」＝离敌人近＝左）：

  | 阵型 | 1 号 | 2 号 | 3 号 | 4 号 | 5 号（5 人队） |
  | --- | --- | --- | --- | --- | --- |
  | 两排错开 | 前上 (669, 280) | 前下 (669, 480) | 后上 (819, 380) | 后下 (819, 580) | 前中 (669, 430)；5 人时前排 280／430／580、后排 355／505 |
  | 菱形 | 前尖 (579, 430) | 上角 (699, 280) | 下角 (699, 580) | 后尖 (819, 430) | 中心 (699, 430) |
  | 原版竖排 | 照原版 `party_layout`（x 819 一列） | | | | |

  1～3 人：两排 1 人居中 (744, 430)，2 人前上／前下 (669, 330／530)，3 人前上 (669, 300)、前下 (669, 540)、后中 (819, 420)；菱形 1 人 (699, 430)，2 人斜开 (619, 355)／(779, 505)，3 人前尖 (579, 430)、上角 (729, 300)、下角 (729, 560)。6 人以上（目前没有）照原版竖排。
- 布局取舍：整个阵型都在原版竖排那条线（x 819）及其左边，指令窗照原版贴在 x 851 起，所以不会盖住轮到的人、也不伸进右侧状态栏（先试过后排放到 x 950，指令窗把轮到的后排角色整个盖住，改了）。脚底最低 580（行动顺序条约在 610 以下），大体型 ×1.35（宽约 180、高约 215）头顶最高约 65，不碰顶部 Boss 信息框（在左上）。最前一人半身最左约 x 489（菱形前尖）；敌群成员 x 有九成五在 406 以内，极少数敌群（x 500 以上，约 1%）站得靠右时菱形前尖会挨得近。
- `modes/xiyou/battle/party_formation.gd`（新，`XPartyFormation`）：阵型常量与 `points(kind, n)`、`current()`、`text()`、`sanitize()`、`window_anchor()`；回退开关 `static var ENABLED := true`。
- `modes/xiyou/battle/battle_scene.gd`：`_place_battlers` 按 `XPartyFormation.points(current(), 人数)` 定 `home`；新增 `_sort_actor_sprites`，我方精灵按脚底 y 排绘制次序（靠下的画在上面，原版竖排排完不变）；天启篇换人（`tianqi_swap` 那段）新精灵接替原精灵的子节点位置；`_place_near_actor` 经 `XPartyFormation.window_anchor` 定锚点（新阵型 x 固定 851、y 最低 462＝原版竖排 4 人最下那位；原版竖排不变）。出场滑入、前进后退、受击、逃跑、复活、换人、`xuan_tusu_art.gd` 附身回位等都读 `home`，跟着新位置走，没另改。
- `modes/xiyou/core/xconfig.gd`：`DEFAULTS` 加 `codexPartyFormation: 0`；读配置时经 `XPartyFormation.sanitize`（非数字回默认、越界夹住）；新增 `party_formation()`／`set_party_formation()`；`set_flag` 不认这个键。
- `modes/xiyou/ui/options_scene.gd`：「战斗站位」一行排在「进战斗默认自动」后、手机按键设置前（`ENABLED` 关掉时不列）；确定循环三档、左右夹住，存配置。
- 测试：
  - 新增 `tests/xiyou_party_formation.tscn`／`.gd`（77 项）：默认两排错开；三种阵型 1～5 人点位数量、在可用区（不过 x 819 线、右缘不进状态栏、脚底 ≤ 600、大体型头顶 ≥ 60、左缘 ≥ 480）、两两分得开（x 差 ≥ 120 或 y 差 ≥ 150）；编队 1～4 对应点（前后、错开半格、菱形四点）；5 人保留 1～4 号位；设置页确定循环／左右夹住／存配置重读／坏值回默认；三种阵型各开一场战斗核 `home` 与绘制次序；指令窗锚点；回退 `XPartyFormation.ENABLED = false`（设置页不列、站位原版）。窗口模式加 `-- --out=<目录>` 截三张 4 人图。
  - 对照原版站位的 `xiyou_battle_ui`、`xiyou_battle_pixel`、`xiyou_costume_battle`、`xiyou_sequence_visual` 在 `_run` 开头设 `XPartyFormation.ENABLED = false`（回退到原版竖排再比）。
  - `xiyou_hangup_options`：设置行数与末行加上「战斗站位」。
  - `xiyou_xuan_tusu_art`：屠苏化武、璇寄星后原来固定等 4 帧，演出排队帧数随站位距离（与负载）变，改成按条件等、最多 30 帧（原版竖排在并行负载下也偶发过）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/battle/party_formation.gd` `XPartyFormation.ENABLED`；`battle/battle_scene.gd`（`_place_battlers`、`_sort_actor_sprites`、`_place_near_actor`、天启篇换人）；`core/xconfig.gd`（`codexPartyFormation`）；`ui/options_scene.gd`（「战斗站位」）；`tests/xiyou_party_formation.gd` | 我方 1～4 人在 x 819 竖排一列（5 人前后两列交错），角色放大后上下叠在一起 | 设置「战斗站位」三档：两排错开（默认）、菱形、原版竖排；编队第 k 位站阵型第 k 个点；新阵型下我方按脚底 y 排绘制次序、指令窗固定贴阵型右边 | Kyo 2026-11-15「做菱形和两排错开。设置里面可以更改，位置对应上编队位置」 | `XPartyFormation.ENABLED = false`（设置页不列，站位照原版；`tests/xiyou_party_formation.gd` 验回退支）；玩家也可在设置里选「原版竖排」 | cc | 保留 |

## 交接板

- 下一步：无（编队界面显示对应站位见「可优化」）
- 用户试玩说明：设置 →「战斗站位」可选两排错开／菱形／原版竖排，进下一场战斗看效果；编队里的顺序就是站位顺序（两排：1 前上、2 前下、3 后上、4 后下；菱形：1 前尖、2 上角、3 下角、4 后尖）。
- 需要用户决定：无（点位已按画面定；Kyo 看截图觉得哪里要挪，改 `XPartyFormation` 顶上几个常量即可）

## 进度账

- 天启篇界面：战斗站位可选，新增一项设置（不动主表）。

## 截图

有窗口 Godot 实机，敌群 693，队伍渡鸦（神话形态）／五条悟／米拉（黑龙）／宿傩，开战第一个指令窗出来后截（git 忽略目录，车道工作树里）：

- 两排错开：`03_再刷重制_Godot/04_验证/本地结果/party_formation/party_rows.png`
- 菱形：`03_再刷重制_Godot/04_验证/本地结果/party_formation/party_diamond.png`
- 原版竖排：`03_再刷重制_Godot/04_验证/本地结果/party_formation/party_column.png`

重截：`03_再刷重制_Godot/07_开发环境/godot --path 03_再刷重制_Godot/01_Godot工程 res://tests/xiyou_party_formation.tscn -- --out=<绝对目录>`

## 验证

- 新专项 `xiyou_party_formation`：77/77（无头）；有窗口带截图 77/77。
- 相关选测（本地并行 2）全过：`xiyou_party_formation xiyou_battle_options xiyou_costumes xiyou_graphics_options xiyou_hangup_options xiyou_list_paging xiyou_notice_options xiyou_options_basic xiyou_options_misc xiyou_platform xiyou_power xiyou_power_hidden xiyou_smart_ai xiyou_test_mode xiyou_window_rects xiyou_battle_ui xiyou_gear_ui xiyou_party xiyou_super_deploy xiyou_battle_pixel xiyou_costume_battle xiyou_sequence_visual xiyou_xuan_tusu_art xiyou_popup_multi xiyou_tusu_ui xiyou_merchant29 xiyou_orb_shop_ui xiyou_yunshang_shop xiyou_determinism`（`xiyou_hangup_options` 改后单跑过）。
- 战斗画面类选测 28 个全过：`xiyou_battle_bgm xiyou_battle_end_ce xiyou_battle_enter_exit_lag xiyou_battle_events xiyou_battle_lag xiyou_battle_log xiyou_battle_me xiyou_battle_pace xiyou_battle_speed xiyou_battle_state_batch xiyou_battle_transition xiyou_battleback_save xiyou_gojo xiyou_gojo_trials xiyou_guyu_ui xiyou_mira_art xiyou_mv_animation xiyou_popup_overlap xiyou_race_battle xiyou_raven_fx xiyou_regen_popup xiyou_sukuna_fx xiyou_tianqi_party xiyou_tusu_battle xiyou_ui_pixel xiyou_victory_text_flow xiyou_vsfx xiyou_yunshang_ui`。
- `xiyou_xuan_tusu_art` 改成按条件等之后连跑 3 次都过。
- `语法检查.py`：878 个 .gd，0 个问题；`工具回归.py` 全过。
- 没跑：`选测.py main --list` 列出 236 个场景（battle_scene.gd 牵涉面大），上面只跑了站位／设置／战斗画面相关的 55 个左右；建议总装合并用 `--affected --cloud` 跑全。没碰战斗计算，不需要 `--oracle`。

## 可优化（流程／工具／效率）

- 建议：编队界面（`XPartyScene` 出战栏）在每个位子旁标出当前阵型的站位名（`XPartyFormation.SLOT_NAMES`，如「前上」「后尖」），玩家排编队时就知道谁站哪；本单没做，归 B 界面车道，Sonnet＋medium 即可。
- 建议：几个战斗画面专项（`xiyou_xuan_tusu_art` 一类）用「等固定帧数」判演出结果，站位或负载一变就偶发；可以统一换成「按条件等、设上限」的辅助函数。

## 本分支提交

- 见 `git log main..cc/party-formation`
