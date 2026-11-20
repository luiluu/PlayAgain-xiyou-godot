# 交付：luiluu/cc-t294-reserve-exp

- 车道／工作者：B 界面／cc（Sonnet＋medium，P6；T294）
- 状态：可合并

路径前缀 `G/` ＝ `03_再刷重制_Godot/01_Godot工程/modes/xiyou/`。

## 变更记录草稿

## 2026-11-20 【cc·T294·未经审查】角色仓库右牌写上替补经验（dev.待定）

- 新皮肤角色仓库右牌：存入时加一句「在仓库中不会获得战斗经验。」；取出时按 System 的 `optExtraExp` 实际值写「未出战也可获得全额战斗经验。」或「未出战不会获得战斗经验；编入出战位（天启篇加『或助力位』）才能获得。」。只改 `G/ui/skin/skin_actor_warehouse_page.gd` 的 `card_data`，旧页（`ENABLED＝false`）不动。
- 玩家可见：角色仓库右牌多一行经验说明。

## 经验来源核对（验收 1）

| 来源 | 谁拿 | 仓库角色 | 后备（队伍里没出战） | 出处 |
|---|---|---|---|---|
| 战斗经验 | `state.members()`（只有队伍） | 不拿 | `optExtraExp` 开＝100%、关＝0 | `G/battle/battle_logic.gd:3877-3883`；`G/core/xstate.gd:662`（members＝party）；出战位拿满 `:3882`，天启篇助力位 `G/core/xstate.gd:692` |
| 法宝经验（战斗后；不是角色经验） | 队伍里戴法宝的人，出战满额、其余按「Exp Rate Not Battler」 | 不拿 | 按该参数 | `G/battle/battle_logic.gd:3886`；`G/core/magic_weapon.gd:191-202` |
| 物品 | 无「加角色经验」效果：效果表里没有，物品只能涨法宝经验（喂食） | — | — | `G/core/fabao_feed.gd:82`（法宝）；全库 `gain_exp(` 调用只有战斗、配方、测试 3 处 |
| 事件「增减等级」316 | 指定角色按编号（`s.actor(id)`，不看在不在队伍，仓库角色可被点名）；角色 0＝全队 | 点名才有；「全队」不含 | 全队含 | `G/core/mv_event_core.gd:431-439`、`:814-819`（`_actors_ex`）、`:563`（`_party_members`＝members） |
| 事件「增减经验」315 | 没移植（全库没有 changeExp 事件分支） | — | — | `G/core/mv_event_core.gd` 无 315 分支 |
| 合成配方经验（pxp） | `s.members()` 全员满额 | 不拿 | 拿满 | `G/core/crafting.gd:200-202` |
| 宠物 bonus_actors（含 saved_actors） | 只是属性加成接收名单，不涉及经验 | — | — | `G/core/pets.gd:172-177,303` |
| 真气 | 战斗后只给活着的出战成员涨真气，不是等级经验 | 不拿 | 不拿 | `G/core/zhenqi.gd:312-350` |
| 修炼场 | 花精魂加属性，不涨经验 | — | — | `G/core/training.gd:126-131` |
| 天启篇宗门「平均等级」入队同步 | 新入队角色直接 `change_level_mv` 到队伍平均等级 | 仓库不参与平均 | 参与 | `G/core/tianqi_sect.gd:615-628`（`ren_sync`） |
| 测试模式加经验 | 只加给队伍成员，不乘经验率 | 不拿 | 拿 | `G/core/test_mode.gd:279-296` |

结论：「仓库角色不拿经验」除事件 316 点名外成立；右牌那句只写战斗经验，不夸大。

## 验收

1. 如上表。
2. 右牌文字见下「文字」节；取出一句随 `optExtraExp` 实际值（专项 `wh.exp_note_opt_on／off` 改 System 值核）。
3. 截图已入仓：`00_项目管理/归档/交付截图/luiluu_cc-t294-reserve-exp/`（取出页 800×450／1000×450 字号 100%，存入页 800×450／1000×450 字号 130%）；专项 `screenshot_size_*` 断言真尺寸、`screenshot_*` 全过。四张都看过（取出页 100%×2、存入页 130%×2），都不溢出、不遮按钮。
4. 开关关：未动旧页；`wh.gate.rollback_old` 仍过。

## 文字（待小A 审）

- 存入：「在仓库中不会获得战斗经验。」
- 取出（`optExtraExp` 开，现行西游数据）：「未出战也可获得全额战斗经验。」
- 取出（关，原版档）：「未出战不会获得战斗经验；编入出战位才能获得。」天启篇档：「未出战不会获得战斗经验；编入出战位或助力位才能获得。」

## 验证

- `xiyou_ui_skin_card_j` 192/192（本机并行测试＋带窗口截图各一次，均 Dummy 音频）；语法检查 1101 个 .gd 0 问题。
- 没跑 `--oracle`、没跑全量（只改一页右牌文字）。

## 交接板

- 无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 `git log`
