# 交付：luiluu/t371

- 车道／工作者：T371 战技说明栏名牌遮挡（cc，Sonnet＋medium）
- 状态：进行中

## 变更记录草稿

## 2026-11-22 【cc·天启篇·未经审查】战斗战技列表压在敌人名牌之上，说明栏第一行不再被名牌挡住（dev.待定）

- 依据：T360 目测发现（敌人名牌「嘤嘤怪A宝宝」画在战技列表上面，压住说明栏第一行前几个字，20:9 更明显），非 T360 引入。
- 原因：敌人名牌／血条画布 `battle_scene.gd` `_make_enemy_gauge` 是 z 5，战技列表窗口 z 0，两者重叠时名牌盖在列表上。
- 改法：`skin_battle_list.gd` `XSkinBattleSkillList.create_list` 把列表窗口设 z 6（`GAUGE_Z`）；行动顺序条、消息窗 z 8、说明卡 z 10 仍在它上面。只改列表窗口，名牌、说明卡、行动条不动。
- 回退开关：`XSkinBattleSkillList.ABOVE_GAUGES = false` 回到 z 0。
- 测试：`xiyou_ui_skin_battle` 加 `list_above_enemy_gauge_t371`、`list_above_gauge_switch_off_t371`，并截新／旧层级对照图（`t371_gauge_under_list`、`t371_gauge_over_list_old`）。
- 玩家可见：战斗里选战技时，敌人名字不再盖在说明栏文字上。

## 交接板

- 下一步：无
- 用户试玩说明：战斗选战技，列表和敌人名字重叠时，列表在上、名字在下，说明栏文字完整。
- 需要用户决定：无

## 进度账

- 部分：无进度变化，小遮挡修复。

## 可优化（流程／工具／效率）

- 已做：`ABOVE_GAUGES` 回退开关。要登记优化登记（总装并入）：`modes/xiyou/ui/skin/skin_battle_list.gd` `XSkinBattleSkillList.ABOVE_GAUGES`｜战技列表被敌人名牌盖住说明栏｜列表 z 6 压在名牌之上｜T360 目测｜`XSkinBattleSkillList.ABOVE_GAUGES = false`｜cc｜保留。
- 没做：战技 130% 字号没单独截图（z 层级与字号无关）；命令环（`cmd_win`）与物品列表以外的窗口是否也被名牌压，没查，建议总装目测。

## 截图

- `00_项目管理/归档/交付截图/T371_战技说明栏名牌遮挡/`：改前／改后各 16:9、20:9（把列表摆在敌人名牌上，等价 T360 截图的摆法）。

## 本分支提交

- 见 `git log`
