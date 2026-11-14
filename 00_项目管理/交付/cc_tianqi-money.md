# 交付：cc/tianqi-money

- 车道／工作者：C 规则·机制／cc（金钱重构）
- 状态：可合并

金钱重构方案 v0.2（私密仓库 xiyou-design-docs `重制设定/天启篇_金钱重构方案_v0.2.md`，Kyo 11-14 00:44「全可以，按你的建议来，9的话根据难度调整」）第四节 1～5 步。只对天启篇存档生效，原版档不变；合进本地，不推玩家。

## 变更记录草稿

## 2026-11-14 【cc·金钱重构·未经审查】天启篇金钱重构：场钱定价、卖价按品质、加成递减、重铸涨价与锁词条、进阶四阶价、修炼重做、天平（dev.待定）

- 起因：Kyo「西游的钱没什么用，要重构」。盘点：钱 10 层起花不完，好东西都用别的货币，100 万到 1 亿之间没有去处，修炼一级 2 亿起买不起。
- 规则表 `tianqi_data/money_table.json`（数是草案，等虚拟玩家实测），代码 `core/tianqi_money.gd`（`XTianqiMoney`，O-待定-1），只认天启篇存档。
- 场钱：最高到达层（变量 20）一场随机遇敌的平均金钱 × 难度奖励倍率。1～27 层按方案盘点的锚点平滑补齐，28 层起按 ×1.2 补到 36 层。新增消耗都按场钱标价，再乘各档价格倍数（寻常 0.6、艰险 0.8、九死 1、炼狱 1.5、证道 1.7）；算出的价取两位有效数字、避开 4。
- 难度奖励倍率：`balance_table.json` 每档 `scaling.reward`（1／1.1／1.3／1.5／1.8），`XTianqiBalance.reward_mult`，金钱和掉率共用（掉落线合进来后改读这里，见下）。
- 战斗金钱（`INCOME`）：全队（上场＋助力位）被动 passiveGRUP、套装、词条阅历、金钱翻倍全部相加，再按 合计×200÷(合计＋200) 递减（同掉落），乘难度奖励倍率。原版难度被动（普通难度等 6 个）不算；牢妲改的难度号金钱倍率（Vitsuno Drop Rate）不算。原版算出 0 的（神兵试炼）照旧 0。`battle_logic.rewards` 末尾一行。
- 卖价（`SELL`）：装备按品质 0.1／0.2／0.3／0.5／1／1.5／2 场钱（普通～神话），不看原价；物品（奖碑、古董等）照旧。`XItemMarks.selling_price` 开头一行，商店、一键出售、挂机出售、说明卡都跟着变。
- 重铸（`REFORGE`）：一条 3 场钱 × 阶系数（1／2／3／5）；同一件每重铸一次 ×1.3、封顶 10 倍（装备记 `tq_reforges`）；新加「锁第 N 条洗其余」，其余各条起步价之和 ×3。异化工坊页每条多一个按钮、底下写已重铸几次。关掉回到 reforge.json 的老价。
- 进阶（`ADVANCE`）：四阶 10 万／30 万／60 万／100 万（多于四阶的照最后一档），不乘价格倍数；材料不动。`XAdvance.row` 换金钱。
- 修炼（`TRAINING`）：原表 65 项在天启篇不用，换成八项各 10 级、全队共享、每 3 层开 1 级（30 层开满）；第 1 级 30 场钱，每级 ×1.3。每级加本体基础值 1%（占位，等数值线定；练满每项 +10%）。照用原修炼页，行文写「全队…+1%　下一级费用」或「本层开到 N 级」。存档 `flags.tianqi.money.training`。
- 天平（`SCALE`）：大厅「动保协会成员」（Map004 EV043，卖奇兽捕捉许可证，天启篇宠物全隐藏）在天启篇换成天平对话：麦（本层每场开战全队回满生命、魔法）、油（承伤 −10%）、酒（出伤 ＋10%），每样 30 场钱，同一层第 n 次买 ×2^(n−1)、最多 3 次；饥荒线贵五成；最高到达层变了就清掉。油、酒乘进 `XTianqiCombat` 的出伤／承伤，麦在 `battle_logic.setup`。
- 专项 `xiyou_tianqi_money` 53 项；云端选测（基准 main 2f87155a7）412 个场景全过；`xiyou_tianqi_reforge` 开头关 `XTianqiMoney.REFORGE`（它测的是老定价）。
- 和方案的出入（我的读法，Kyo 可改）：「同一层再买一次价格翻倍、最多 3 次」读成三样合计 3 次、第几次买就翻几倍，每样一层只能买一次；「锁一条」读成锁一条、其余全洗；修炼开放层和场钱都按最高到达层（变量 20）算；天平借用 EV043 的位置和行走图（没新做 NPC 图）。
- 没做：牢妲改难度号的入口没关（它还管经验，归影响审查线），只让金钱不吃它；28 层以上场钱、修炼每级加值、天平 10%、各档倍数都等实测；请虚拟玩家线学会花钱（方案第 6 步）。
- 玩家可见（只在本地）：天启篇卖装备按品质给钱；重铸越洗越贵、能锁一条；进阶四阶价变了；修炼换成全队八项、跟着楼层开；大厅动保协会成员的位置变成天平。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi_money.gd` `XTianqiMoney.ENABLED`、`INCOME`、`SELL`、`REFORGE`、`ADVANCE`、`TRAINING`、`SCALE`；`tianqi_data/money_table.json`、`balance_table.json`（scaling.reward）；`battle/battle_logic.gd`（rewards、setup 各一行）、`core/item_marks.gd`（selling_price）、`core/advance.gd`（row）、`core/training.gd`、`core/tianqi_reforge.gd`、`core/tianqi_combat.gd`、`core/tianqi_balance.gd`、`map/map_scene.gd`（run_event）、`ui/alien_workshop.gd`；`tests/xiyou_tianqi_money.gd` | 金钱 10 层起花不完；加成连乘；卖价看原价；重铸不涨价；修炼一级 2 亿起；进阶价乱序 | 天启篇存档：场钱定价＋各档价格倍数、加成相加递减＋难度奖励倍率、卖价按品质、重铸涨价＋锁一条、进阶 10/30/60/100 万、修炼八项全队共享、天平 | Kyo 11-14「全可以，按你的建议来，9的话根据难度调整」；金钱重构方案 v0.2 | 各开关设 false | cc | 保留 |

## 交接板

- 下一步：掉落线（cc/drop-rework）合进来后对接两处——`XTianqiDrop.difficulty_mult` 改读 `XTianqiBalance.reward_mult`（drop_table.json 的 difficulty 段可删），`_auto_sell` 折钱那行改调 `XTianqiMoney.sell_price`，`xiyou_tianqi_drop` 的 difficulty_mults、pieces_difficulty、filter_sells_below_gate 三项跟着改（谁后合谁改，两边已约好）。请虚拟玩家线学会花钱（重铸、修炼、天平），实测每层收入和余额，回来校 `money_table.json`；修炼每级加值等数值线定。
- 用户试玩说明：天启篇新档：卖装备看品质给钱；异化工坊重铸能锁一条；修炼页是八项全队共享；大厅左边动保协会成员的位置是天平。只在本地。
- 需要用户决定：无

## 进度账

- 无（重构项）。

## 可优化（流程／工具／效率）

- 无

## 待交叉核查

- 改了核心文件 `battle/battle_logic.gd`（rewards 末尾、setup 各加一行）。

## 本分支提交

- fdcdf8058 场钱表、卖价、收入、重铸、进阶、修炼、天平
- 0e1f9aa82 专项 xiyou_tianqi_money
- 9e6efa5b2 交付单
