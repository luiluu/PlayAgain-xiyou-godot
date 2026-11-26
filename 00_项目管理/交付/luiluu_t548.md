# 交付：luiluu/t548

- 车道／工作者：T548 天启篇头顶成长层数窗口（cc，Opus＋medium，P8）
- 状态：可合并

## 结论

天启篇里魔冠「头顶」（7940）胜利涨成长，现在只算 **当前地图层 ≥ 已通主塔层 − 3** 的战斗（Kyo 11-26 事项 79「最高层往下3层内。改到启封档」）。层号来源、深渊／王者副本／七印／终章的口径都直接用 `XTianqiGrowth.floor_ok_facts` 那一套，只把窗口换成头顶自己的 `floor_rule.crown_window＝3`；渡鸦、奈叶、流萤的 5 没动。西游档不判，说明卡逐行不变。

## 改了什么

- `modes/xiyou/core/tianqi_growth.gd`：`floor_ok_facts` 拆出 `_floor_ok_window(f, window)`（三人照旧传 `window＝5`，结果不变）；新增 `CROWN_FLOOR` 开关、`crown_window()`、`crown_floor_ok_facts`、`crown_floor_ok(s, logic)`、`crown_hint()`。
- `modes/xiyou/core/demon_crown.gd`：`finish` 胜利时先判 `crown_floor_ok(s, XRaceBattle.active_logic())`（流萤 `_growth_win` 取 logic 的方式也是这样）；层数不够时这一场照常结算（行 settled、result 照写、遭遇序号＋1、掉落照旧），只是跳过成长。`describe` 在天启篇加一行提示（打头 `※`，重写说明时先去掉旧行）。
- `modes/xiyou/tianqi_data/growth.json`：`floor_rule.crown_window: 3`，`_note` 补一句。
- `03_转换工具/天启篇数据校验.py`：`crown_window` 要是 0～36 的整数（公共规矩 v1.5：改了数据表格式要同步改校验）。
- `07_开发环境/发行空壳特例.json`：`XTianqiGrowth.crown_floor_ok` 放行（空壳返回 true＝西游档行为）。这两个文件不在派单的独占文件里，因为规则和工具要求才改，各只加一行。

## 验收（卡上 5 条）

1. ✓ 天启篇里头顶胜利只在 地图层 ≥ 已通主塔层 − 3 时涨；窗口单独配在 `floor_rule.crown_window`，三人的 `window＝5` 没动（专项 `three_window_5`、`three_abyss_24`、`three_ignore_crown_switch`、`crown_ignores_growth_switch`）。
2. ✓ 西游档零改动：`crown_floor_ok`、`crown_hint` 先看 `XTianqi.active(s)`，西游档恒 true、空串；专项 `xy_note_same`（开关开关两态说明逐行一样、没有提示行）、`xy_low_grows`（西游档低层照涨）；原有 `xiyou_demon_crown` 106/106、`xiyou_demon_crown_compact` 48/48 照过。
3. ✓ 特殊战斗口径与 `floor_ok_facts` 一致（同一个函数，只换窗口）：
   - 主塔、野外：地图层 ≥ 已通主塔层 − 3（已通层＝`XZhenqi.progress_floor`＝变量 20 − 1）。
   - 深渊（地图名以「深渊」开头）：层号 ≥ min(已通主塔层, 29) − 3，层号 0 的深渊不算。
   - 王者难度副本（副本档位 4）、七印里副本（`XTianqiQiyinRule.fight` 非 enemy_only，或七首之龙）、34～36 终局战（四骑士线非开场生存战、鸿钧）一律算。
   - 层号 0 的大厅等地图：0 ≥ 已通层 − 3 才算，开局前三层内算、往后不算（与三人同理）。
4. ✓ 层数不够时：不涨、不减；账本照常结算这一行（不留未结算、读档重打不重掷），死亡减半照旧（专项 `tq_lo_no_grow`、`tq_lo_seq`、`tq_lo_settled`、`tq_low_no_grow`、`tq_low_death_halves`、`tq_low_lose`、`tq_reload_low_no_grow`）。
5. ✓ 回退开关 `XTianqiGrowth.CROWN_FLOOR`（O-待定），两态都测了（`crown_switch_off_facts`、`tq_off_low_grows`、`tq_off_no_hint`）。说明卡在成长行下面加一行提示，卡面顺序由 `tq_hint_card_below_growth` 用 `XHelpCard.content` 实取核过：

   ```
   成长：八项全属性＋1%
   ※只有最高层往下 3 层以内的战斗胜利才会成长
   代价：死亡时失去50%当前累计加成
   ```
   提示文字是草稿，**待小A 审**；窗口改了文字里的数字跟着表走。

## 验证

- 本机专项（`并行测试.py --full`，无头）：`xiyou_demon_crown_floor` 43/43（新）、`xiyou_demon_crown` 106/106、`xiyou_demon_crown_compact` 48/48、`xiyou_tianqi_growth` 58/58、`xiyou_tianqi_growth_count` 66/66、`xiyou_three_growth` 110/110、`xiyou_tianqi_gear2` 51/51、`xiyou_tianqi_save` 82/82、`xiyou_tianqi_seed_fix` 77/77、`xiyou_save_seal` 127/127、`xiyou_skill_mastery` 306/306、`xiyou_elemental_king` 1107/1107。
- `语法检查.py` 1244 个 .gd 0 问题；`天启篇数据校验.py` 全部通过；`发行空壳.py check` 退出码 0。
- 云端选测：通过，40 个场景 7 片，提交 d37a159150（之后只加了交付单和 `发行空壳特例.json` 一行，没动 .gd），https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45846342451

## 优化登记草稿

| 编号 | 位置 | 原版 | 重制 | 依据 | 回退 | 执行 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_growth.gd` `XTianqiGrowth.CROWN_FLOOR`；`modes/xiyou/core/demon_crown.gd` `finish`、`describe` | 头顶每场胜利都涨成长，不看在哪层打 | 天启篇只算最高层往下 3 层内（`floor_rule.crown_window`）的胜利，口径同三人 `floor_ok_facts`；低层不涨不减，死亡减半照旧；说明卡加提示行。西游档不变 | Kyo 11-26 事项 79「最高层往下3层内。改到启封档」 | `XTianqiGrowth.CROWN_FLOOR = false` | cc（T548） | 保留 |

## 变更记录草稿

## 2026-11-26 【cc·T548·未经审查】天启篇头顶成长只算最高层往下 3 层内的战斗（dev.待定）

- Kyo 11-26 事项 79：天启篇（启封档）魔冠「头顶」胜利涨成长，只算 地图层 ≥ 已通主塔层 − 3 的战斗；深渊、王者副本、七印、终章口径同渡鸦／奈叶／流萤的 `floor_ok_facts`，窗口单独配 `growth.json floor_rule.crown_window`（3），三人的 5 不动。
- 层数不够：不涨不减，这一场照常结算（不重掷），死亡减半照旧；说明卡成长行下加一行提示（待小A 审）。西游档不判、说明不变。
- 回退 `XTianqiGrowth.CROWN_FLOOR = false`；专项 `xiyou_demon_crown_floor`。
- 玩家可见：天启篇里头顶只在最高层往下 3 层以内的战斗胜利才成长，说明卡有提示。

## 交接板

- 下一步：提示行文字待小A 审；O-待定 合并时换号。
- 用户试玩说明：天启篇里在低层刷怪，头顶不再涨成长；到最高层往下 3 层内（或深渊高层、王者副本、七印、终章）照涨。
- 需要用户决定：无

## 进度账

- 无（规则微调，不动完成度）

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiGrowth.floor_ok_facts` | 非测试 1 处（`git grep -nE 'floor_ok_facts' -- '*.gd' ':!*/tests/*'`：`tianqi_growth.gd` 的 `floor_ok`） | 调用方 1 处逐处结论：只是把窗口判断拆进 `_floor_ok_window`，三人传入的窗口仍是表里 `window`（5），`ENABLED` 关掉仍恒 true；`xiyou_tianqi_growth` 58/58、`xiyou_tianqi_growth_count` 66/66 照过 |
| `XDemonCrown.finish` | 1 处（`battle_logic.gd` 结束战斗） | 调用方 1 处逐处结论：只在胜利时多判一次层数；西游档 `crown_floor_ok` 恒 true，行为不变 |
| `XDemonCrown.describe` | 文件内 5 处（`git grep -nE 'describe[[:space:]]*\(' -- '*demon_crown.gd'`） | 调用方 5 处逐处结论：只在天启篇多一行提示、每次重写先去掉旧提示行，不重复；西游档 `crown_hint` 空串，说明逐行同（`xy_note_same`） |

## 截图

- 无（卡面文字由专项 `tq_hint_card_below_growth` 实取核对，原文见上「验收」第 5 条）

## 本分支提交

- 见 `git log main..luiluu/t548`
