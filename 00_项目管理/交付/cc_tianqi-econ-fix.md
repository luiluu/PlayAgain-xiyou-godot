# 交付：cc/tianqi-econ-fix

- 车道／工作者：C 规则·机制／cc（天启篇经济返修，Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【cc·经济返修·未经审查】天启篇掉落、金钱甲档补核 4 项 P2 返修（dev.待定）

- gpt 甲档补核 `cc/drop-rework`（dev.559）与 `cc/tianqi-money`（dev.562）各报 2 项 P2，本轮全修，各带回退开关（O-待定-1）。
- 掉落：没有掉落账的旧档，首次招牌掉落的种子改由存档里的宝珠种子（`orb_seed`，随存档保存；更旧的档由存档内容算出）派生，读同一个档再打结果一样；必掉（p≥1）也算「出了」，已有账的连败清零、总次数推进。
- 金钱：商店买来的装备回售价＝min(品质卖价, 购入价×0.5)，购入单价在成交时记到装备上（`tq_buy_price`），没记的旧货按原价折半；掉落来的装备卖价不变。天平改成只管买时那一层：大厅买时记最高到达层，只在那一层的地图里生效，进了别的层的地图就整条清掉（同层再买翻倍、最多 3 次照旧）。
- 西游档不变（全部只认天启篇存档）。
- 玩家可见：天启篇商店买的装备立刻卖回只能拿回不到一半；天平买的麦／油／酒只在当前冲的那一层有效，去别的层就没了。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi_drop.gd` `XTianqiDrop.SEED_FROM_SAVE`、`PITY_RESET_ON_SURE`；`modes/xiyou/core/tianqi_money.gd` `XTianqiMoney.SELL_BOUGHT_CAP`、`SCALE_FLOOR_ONLY`；`ui/shop.gd`（mark_bought 传单价）；`tests/xiyou_tianqi_drop.gd`、`tests/xiyou_tianqi_money.gd` | 旧档首次掉落种子用全局 randi 可读档重掷；必掉不清连败；商店货按品质卖价可买了就卖套利；天平绑定最高到达层 | 种子由存档种子派生；必掉清连败推进总数；商店货回售封顶购入价一半；天平只在买时那一层生效、离层清掉 | gpt 甲档补核 P2×4；掉落重构方案 v0.8 第六节「出了归零」；金钱重构方案 v0.2 第 122、142 行 | 四个开关各设 false | gpt | 保留 |

## 核查返修

| 问题（gpt 甲档补核） | 修法 | 测试（断言） |
| --- | --- | --- |
| P2 `tianqi_drop.gd` store：无 drop 字段时 `randi()` 建种子，旧档首次掉落可读档重掷 | 种子＝`XOrbs.hash32("tianqi-drop\|"+orb_seed)`；已有掉落账的档种子不变 | `xiyou_tianqi_drop`：`legacy_no_drop`×2、`legacy_reload_same`（无 drop 字段的档 to_dict→from_dict 两次，各掷 20 次结果、种子全同）、`legacy_seed_switch` |
| P2 `tianqi_drop.gd` roll_signature：p≥1 直接返回，不清连败不推进总数 | 已有账的键写成 [0, total+1]；没账的不新建（免存档堆必掉行） | `sure_hit`、`sure_resets_fails`（[7,7]→[0,8]）、`low_after_sure_from_zero`（之后低概率一掷连败从 0 起）、`sure_no_new_row`、`sure_switch_off` |
| P2 `tianqi_money.gd` sell_price：商店货也按品质卖价，买了就卖套利 | 带 `tq_bought` 的回售价＝min(品质卖价, 购入价÷2)；`mark_bought` 记 `tq_buy_price`，没记的按 `price` | `xiyou_tianqi_money`：`bought_price_saved`、`bought_sell_capped`（买入价＝品质卖价的普通武器立刻卖，到手 ≤ 购价一半）、`drop_sell_kept`、`bought_legacy_price`、`bought_cap_switch` |
| P2 `tianqi_money.gd` 天平绑定最高到达层 | 记录买时层；`has_good` 只在 `XDungeon.map_floor(map_id)` 等于该层时生效；人在别的层的地图里时 `scale_sync` 清掉整条记录（大厅不清） | `floor_maps`、`scale_lobby_off`、`scale_same_floor_stays`、`scale20_bought`、`scale20_on`、`scale_floor_switch`、`scale20_off_at5`、`scale20_cleared`、`scale20_gone`；原 `scale_reset` 改为进 11 层地图后验 |

断言数：`xiyou_tianqi_drop` 74→83，`xiyou_tianqi_money` 53→67，全部通过。提交见「本分支提交」。

说明：「当前层」在大厅里没有现成的量，天平买时取最高到达层（对话头显示的就是它）；人在第 N 层地图里买（目前事件只在大厅）则记 N。停手条件「改种子派生让已有天启篇存档的保底账本整体变化」没有触发：只有还没有掉落账的档才走派生，已有账的种子不动。

## 同类盘点（只报告，不修）

`modes/xiyou/core/` 天启篇模块里用全局随机或新熵作种子／兜底的地方：

| 文件:行 | 用途 | 能否读档重掷 | 建议 |
| --- | --- | --- | --- |
| `tianqi_reforge.gd:92` | 单条重铸没传 rng 时 `randf()` 兜底（界面正式调用走这条） | 能：先存档再重铸，不满意读档再来，钱也回来了 | 走存档派生的流：种子＝存档种子＋装备 uid＋`tq_reforges` 次数（同掉落账写法），读档后同一次重铸结果相同 |
| `tianqi_reforge.gd:121` | 锁词条重铸同上 | 能 | 同上 |
| `tianqi_alien_gear.gd:185` | `attach` 没传 rng 时 `randf()` 选异化词条；掉落路径传的是战斗奖励流，`create`／刻印（:366 指定词条，不走随机）等其他调用走兜底 | 能（兜底路径） | 兜底改用存档派生流（存档种子＋异化账本 sequence） |
| `tianqi_alien_gear.gd:331` | 异化词条重抽 `pending.next` 用 `randf()` | 能：重抽前存档，读档再抽换结果 | 用存档种子＋异化账本 sequence／该件重抽次数派生 |
| `tianqi_qiyin.gd:63` | 七印祭坛 `_rng()`：每次 `XRandomStream.fresh_seed()`（首杀掉落、进层、精英掉落等） | 能 | 改为存档种子派生的 XRandomStream＋存档里的计数（domain "qiyin"），别用新熵 |
| `tianqi_qiyin_dragon_run.gd:65` | 龙跑 `_rng()` 同上 | 能 | 同上（domain "qiyin_dragon"） |
| `tianqi.gd:470` | 开局候选 `draw_offer` 没传 rng 时 `randomize()`；抽出后存进 flags.offer | 首次抽前读档可换候选（抽完就固定） | 低优先：开局选人，影响小；要堵就用存档种子派生 |
| `tianqi_qiyin_dragon_run.gd:265` | 招募候选同上，抽完存 offer | 同上 | 同上 |
| `tianqi_qiyin_show.gd:310` | 展示动画抖动（固定种子 7） | 不涉及 | 不用改 |

另：`XState.random_master`（战斗／装备／世界流）注释写明只在运行时、不随存档，所以走战斗奖励流的掉落本身读档也会不同，这是整局的既有设计，不在本表。

## 交接板

- 下一步：同类盘点表里 reforge／alien_gear／qiyin 的读档重掷，由协调另派。
- 用户试玩说明：天启篇商店买的装备立刻卖只能拿回不到一半；天平效果只在当前冲的那一层有效。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 语法检查：840 个 .gd，0 个问题。
- 专项：`xiyou_tianqi_drop` 83/83、`xiyou_tianqi_money` 67/67。
- 选测（本机）：`xiyou_item_marks`、`xiyou_shop_buy`、`xiyou_shop_stock`、`xiyou_map132_shop`、`xiyou_shop_auto_close`、`xiyou_tianqi_reforge`、`xiyou_tianqi_trumpet`、`xiyou_gold_cap`、`xiyou_review_fixes` 9 个全部通过；工具回归 `工具回归.py` 全部通过。
- 未跑：`选测.py` 列出的地图／界面像素／虚拟玩家等大场景（`xiyou_floor_reach*`、`xiyou_ui_pixel`、`xiyou_virtual_player`、`xiyou_script_census` 等）是因 `shop.gd`、`tianqi_money.gd` 被选中；改动只在天启篇存档生效、商店只多传一个参数，留给总装合并时按影响面云端选测。新机制不需要 `--oracle`。

## 待交叉核查

- `core/tianqi_drop.gd`（store 种子、roll_signature 必掉分支、mark_bought 单价）、`core/tianqi_money.gd`（sell_price 封顶、天平 scale_sync／has_good）、`ui/shop.gd` 一行。甲档（存档相关）。

## 本分支提交

- 44091c85c 天启篇经济返修：掉落旧档种子由存档派生、必掉清连败；商店货回售封顶、天平只管买时那一层
