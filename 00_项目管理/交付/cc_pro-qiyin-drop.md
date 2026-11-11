# 交付：cc/pro-qiyin-drop

- 车道／工作者：C 规则·机制／Pro（cc，云端线程「写七印祭坛掉落逻辑」）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·Pro·未经审查】天启篇七印祭坛里副本掉落逻辑（dev.待定）

- 新增 `modes/xiyou/core/tianqi_qiyin_drop.gd`（`XTianqiQiyinDrop`）和数据表 `modes/xiyou/tianqi_data/qiyin_drop.json`（`draft: true`，来源「七印祭坛方案 v0.4，Kyo 11-12 定稿」）。纯函数：状态字典传进、新状态在返回值的 `state` 里传出，不改传进来的那份；随机数用注入的 `XRandomStream`。只算掉什么、掉几件、印屑多少，**没接**战斗结算、存档、背包、界面。
- 规则照 Kyo 11-12 定稿：里副本前两场各 33% 掉 1 个印屑；Boss 本印套装件 5% 起、每空一次暗里 +2%、掉了归零、连空 20 次后下一次必掉（每印各记），掉了 10% 两连、两连里再 10% 三连、最多 3 件，没掉给 1 个印屑；部位随机，已有部位权重减半（同一次连掉的前几件也算已有）；毕业武器寻常 3%～证道 10%，同一印连空 20 次后必掉；真印每件单独掷（寻常 5%～证道 30%），全局连续 30 件没出后下一件必是；成色每条 普通 50%／上品 30%／极 20%，真印三条全极；神器 0.1% 五选一，不随难度、无保底、不吃加成；物品掉落加成只乘套装件、武器（含野外）几率；躁动每进 3 次抽一印、不连抽、打赢即平息，真印和 Boss 套装件当次几率翻倍；献印屑（5 个，定第一件部位，没掉退 3 个）、献武器（几率翻倍、必同类）；首通再给 1 件；31～35 层守层者首杀必掉揭开那几印各 1 件；野外精英 0.5%、守护者 3%；熔、分解、兑换只做判定和数量；直取只判能不能。
- 新增专项 `tests/xiyou_tianqi_qiyin_drop.tscn`：151 项（规则单测＋固定种子 20000 人统计），云端 24 秒。

## 接口（XTianqiQiyinDrop，全是 static）

| 函数 | 作用 | 返回 |
| --- | --- | --- |
| `new_state()` | 新存档的掉落状态 | 状态字典（字段见下） |
| `on_enter(state, revealed, rng)` | 进一次里副本（任何印都算）：计数 +1，每满 3 次在 `revealed`（已揭开的印）里抽躁动印，不连抽上一次抽中的 | `{state, restless: 这次新抽的印或 ""}` |
| `direct_allowed(state, seal)` | 直取：首通过才能跳过前两场 | bool |
| `roll_elite(state, rng)` | 前两场精英，每场调一次 | `{state, shards}` |
| `offering_check(seal, offering)` | 献的合法性和花费；`offering` 为 `{}`、`{"kind":"shards","part":部位}`、`{"kind":"weapon","wtype":本印武器类型}` | `{ok, reason, shards: 要花的印屑, weapons: 要消耗的武器把数}` |
| `boss_set_chance(state, seal, drop_mult)` | Boss 套装件当次几率（含加成、躁动，不含暗保底），界面提示／测试用 | float |
| `roll_boss(state, seal, difficulty, owned_parts, offering, drop_mult, rng)` | Boss 打赢一次 | `{state, set_pieces:[…], weapon: 武器或 {}, artifact: 神器键或 "", shards: 没掉套装件给的印屑, refund: 献印屑没掉退的, restless: 这场是不是躁动印, error}` |
| `first_clear(state, seal, difficulty, owned_parts, rng)` | 某印首通再给 1 件（只给一次；不吃躁动） | `{state, set_pieces}` |
| `floor_first_kill(state, floor_no, difficulty, owned_parts, rng)` | 31～35 层守层者首杀（只给一次） | `{state, set_pieces, revealed: 这层揭开的印}` |
| `roll_field(state, floor_no, kind, revealed, owned_parts, difficulty, drop_mult, rng)` | 31～35 层野外，`kind` 是 `elite`／`guardian` | `{state, set_pieces}` |
| `melt_check(main, sub, shards)` | 熔的判定 | `{ok, reason, cost}`；reason：kind_mismatch、seal_mismatch、part_mismatch、wtype_mismatch、true_mismatch、same_item、no_shards |
| `dismantle_value(item)` | 分解给几个印屑 | int |
| `exchange(kind, seal, shards, owned_parts, rng)` | 印屑兑换，`kind` 是 `set`／`weapon` | `{ok, reason, cost, item}` |
| `seals()`、`parts()`、`weapon_classes(seal)`、`artifact_keys()`、`floor_seals(floor_no)`、`nice_number_violations()` | 读表 | — |

- 物品字典：套装件 `{"kind":"set", seal, part, true_seal, grades:[3 个成色]}`；毕业武器 `{"kind":"weapon", seal, wtype, true_seal, grades}`。成色键 `putong`／`shangpin`／`ji`。
- `owned_parts`：这一印已有部位的数组，或 `{印: 部位数组}`（守层者首杀 31 层两印时用后者）。
- `wtype` 用表里 `weapon_classes` 的中文类名（方案 5.3 节：白 弓弩／暗器、红 剑／斧、黑 枪械／拳套、灰 太刀／匕首、殉 钝器／矛、震 法杖／书，默印 12 类）。和数据层车道（cc/pro-qiyin-data）的武器键怎么对上，接入时由那边定一张对照或改这张表。
- 参数错（印键、难度键、献的东西不对）时 `roll_boss` 返回 `error` 非空、不抽随机数、状态不变。
- 每个函数的随机数抽取顺序写在函数注释里（`roll_boss`：套装件掉不掉 → 连掉 → 逐件 部位／真印／成色 → 武器掉不掉 → 类型／真印／成色 → 神器），暗保底到点、献定了部位或类型、真印的成色都不抽。

## 状态字典的字段

| 字段 | 意思 |
| --- | --- |
| `set_miss` | `{印: 次数}` Boss 连续没掉套装件的次数，掉了归零 |
| `weapon_miss` | `{印: 次数}` Boss 连续没掉毕业武器的次数 |
| `true_miss` | 全局连续没出真印的件数（套装件、武器共用，首通／守层者首杀／野外掉的也算） |
| `enter_count` | 进里副本总次数 |
| `restless` | 当前躁动的印，`""` 是没有或已平息 |
| `restless_last` | 上一次抽中的躁动印（不连抽用，平息后也留着） |
| `first_clear` | `{印: true}` 首通记录 |
| `floor_kill` | `{"31": true}` 守层者首杀记录 |

## 统计结果（固定种子，20000 人，艰险刷白印）

起手：31 层守层者首杀（白印那件）和首通各 1 件，已有部位减半，不献、不躁动，打到 5 个不同部位为止，数 Boss 场次（首通那一场不算，同设计测算 `套装凑齐.py`）。

| 项 | 跑出来 | 设计测算 | 测试容差 |
| --- | --- | --- | --- |
| 平均 | 32.63 | 约 33（脚本 32.64） | 30～36 |
| 中位 | 30 | 30 | 27～33 |
| 十分位 | 16 | 约 16 | 13～19 |
| 九十分位 | 52 | 约 52 | 47～57 |
| 两连占掉落（≥2 件） | 9.89% | 10% | 9%～11% |
| 三连占掉落 | 1.00% | 1% | 0.7%～1.3% |
| Boss 平均几次掉一回套装件 | 7.30 | 约 7（理论 7.32） | — |
| 真印占全部件 | 10.22% | 10% | — |
| 套装件、武器最长连空／真印最长连空 | 20／20／24 | ≤20／≤20／≤30 | 断言 |

- 和设计测算差别：四个分位都对上（随机流不同，平均差 0.01）。统计里「Boss 平均 14.93 次掉一把武器」偏高，是因为每人凑齐就停，最后没掉的那段也算进了场次；理论值是 13.19（5%、第 21 次必掉），和方案「约 13 次」一致，所以没给它设断言。
- 2000 人时两连只有 8.5%，会挂两连那条；20000 人才稳。20000 人在云端只要 24 秒，不用降到 5000。可用 `-- --people=N` 改人数。

## 验证

- `godot --headless --path <工程> res://tests/xiyou_tianqi_qiyin_drop.tscn`：151/151 通过（云端 Linux Godot 4.7.2，24 秒）。
- 反向验证（手动改一处、单跑、还原）：套装暗保底 20→21、两连 0.1→0.2、真印保底 30→31、同次连掉不更新已有部位、躁动不翻套装几率、躁动不平息，各自都有断言挂。
- `语法检查.py --base origin/main`：713 个 .gd 0 个问题。
- `选测.py origin/main --list` 选中 `xiyou_tianqi_qiyin_drop` 和 `xiyou_event_compare*`。事件对照没跑：云端没有转换产物导入（首次导入 30 分钟以上），而且本车道只加新文件、没有任何已有文件引用 `XTianqiQiyinDrop` 或 `qiyin_drop.json`，对事件对照零影响；请总装合并时按选测照常跑。
- `工具回归.py`：失败 1 项「选测替身与 检查.sh 解析」，在 origin/main 上同样失败（云端容器已知问题，见项目记忆），与本分支无关。

## 读法和假定（需要时请 Kyo 改）

- 兑换来的套装件和武器不算「掉落」：不掷真印、不动真印暗保底，成色照常掷；兑换套装件的部位照掉落规则（已有部位减半）。「100 个换一把自选流派的毕业武器」读成玩家选印（流派），类型在该印里随机。
- 躁动只作用于 `roll_boss`：首通额外那件不吃躁动翻倍。躁动印打赢 Boss 就平息（套装件掉没掉都算）。
- 献印屑指定的部位只定第一件；同一次两连、三连的后几件照常随机。
- 野外掉落吃物品掉落加成（属于套装件几率）；连掉几率（10%）不吃加成。
- 守层者首杀、首通、野外掉的件也计入全局真印计数。

## 交接板

- 下一步：七印祭坛接入（另派）：把 `XTianqiQiyinDrop` 接进里副本战斗结算、背包与存档（状态字典进 `XState`），武器类名对上数据层的武器键。
- 用户试玩说明：无（纯逻辑，玩家还看不到）。
- 需要用户决定：无（上面「读法和假定」按默认继续）。

## 进度账

- 天启篇七印祭坛：掉落逻辑 0% → 逻辑层完成（未接入），依据：本分支专项 151/151。属天启篇扩展账，不写主表。

## 可优化（流程／工具／效率）

- 建议：`语法检查.py` 走 `07_开发环境/godot`（只认 Mac 的 `当前Godot.app`），云端要先手动把 Linux 版 Godot 链进 `当前Godot.app/Contents/MacOS/Godot`（已忽略，不入库）才能跑；可以让它先认 `GODOT` 环境变量，和 `检查.sh` 一样（工具车道，几分钟）。

## 本分支提交

- 76a406040 七印祭坛里副本掉落逻辑：XTianqiQiyinDrop＋qiyin_drop.json＋规则与统计专项
可合并
