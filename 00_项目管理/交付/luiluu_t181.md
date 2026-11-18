# 交付：luiluu/t181

- 车道／工作者：C 规则·天启篇发作真换人（cc 车道，claude-opus-5-5＋medium，P8）；T181＝T086-a 逻辑层本体
- 基线：从 main 4bf4727f1 切出（T180 已在 main）
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·T181·未经审查】发作真换人逻辑层（T086-a，开关默认关）：收尾后换、留底挂战斗、结算前两样一起还原、锁定、自动换回、九死临时口子、五条悟离场清领域、助力位衣魂结算（dev.待定）
- 依据：私密仓《天启篇_发作真换人 v0.2》（c285c65）第三～七节、第十节 T086-a；D201 六件；T180 留下的 P3-2；复核 P3-3。
- 开关 `XTianqiBrand.REAL_SWAP`（O-待定·发作真换人，**默认关**）：关着第六种照旧一律断片，和 T086 前逐字节一样。打开之前画面演出 T086-c（T182）必须先合。
- 判定 `XTianqiBrand.swap_possible`：抽到「换人」那一刻先判一次；开关、助力位活着、两边都不在只断片名单（`brand.json` swap.blackout_only，12 个专属模块角色，178、180 不在）、不是心魔被考的人（`XZhenqi.battle.trial.actorId`）、没在锁定、`can_tianqi_swap(a, true)`（含上场上限）。能就记成 `swap`（只这一回合），不能就断片 2 回合。
- 换的时刻：轮到他时 `forced_action` 给 `{tianqi_brand_fit: "swap"}`，`act` 按放弃行动走完、行动收尾全部照跑；`act` 最后（`resolve_collapses` 之后）`XTianqiBrand.after_act` 才和助力位对调。收尾里倒下了不换（这次发作算完）。轮到他时已换不了（同回合别人先换锁住等）在 `forced_action` 当场改断片；收尾之后才换不了（这次行动里助力位倒下）在 `after_act` 改断片并报一句。两种都是**完整的断片**：从这一回合起 2 回合不行动，间隔从断片最后一回合起算（`fit_log` 那一条改记 `blackout`、带 `fallback`）。
- 留底：第一次强制换人之前的出战栏 5 格，挂在这场战斗的 fight 上（`c.swap.snap`），不进存档；另在 `XTianqiBrand._holds`（内存）记「这份存档有一场没收口的战斗带着留底」。
- 锁定 `lock_rounds`＝2（`brand.json`，范围 1～3，换下那回合算第 1 回合）：锁定期间 `can_tianqi_swap` 对谁都返回假（「换人」指令现在是不出现，变灰归 T182），别人再抽到换人改断片。
- 自动换回 `XTianqiBrand.auto_back`（在 `forced_action` 里、行动入口最顶上，挂机／场内自动／回放／虚拟玩家同一个结果）：只在 `logic.auto` 或挂机时；每次现判不挂记号：有留底、助力位正是最近一次被强制换下的人且活着、行动的正是那次被强制换上来的人、`can_tianqi_swap` 过（锁定、上限）。给 `swap_back` 合成指令，同样按放弃行动走完、收尾后对调，不报「发作」。玩家中途自己换过人，条件自然不成立。
- 还原入口 `XBattleLogic.tianqi_restore()`：出战栏 5 格和在场名单（`actors` 按留底前 4 格逐位换回，先记各位下标再换，多次换人整份还原）；可重复调，第二次是空的；留底和出战栏不是同一批人就不还原、`push_warning`。调用处：`rewards()` 开头、`grant()` 开头、`end_battle()` 开头，画面 `_victory()` 第一行。还原后烙印份额、法宝经验、真气、打输复活都按发作前的位置算。
- 心魔判胜：还原前记下那一刻的在场名单（`_pre_restore_actors`），`grant` 里有心魔 trial 时 `XZhenqi.on_victory` 用它判被考的人在不在场、活没活着（玩家把被考的人手动换下歇着，还原后不白捡立境）；神兵试炼、真气照还原后的名单。
- 九死、炼狱临时口子（D201 第 6 件）：`can_tianqi_swap(out, forced)` 的 D57 拦截在 `REAL_SWAP` 开着、且是强制换人或「这一场带着留底、助力位是超强者（换他回来）」时放行；上场上限那条照旧每次判。出战栏超强者清理 `XItemMarks.enforce_party` 在 `XTianqiBrand.swap_hold(这份存档)` 时停手（认这份存档自己那一场）。证道助力位是超强者、场上已满 2 个时弱者抽到换人退回断片。
- 保险：`BattleLogic.setup` 最前 `XTianqiBrand.sweep(s)`：这份存档上还有上一场没收口的留底，先还原出战栏再开打。回放 `XBattleReplay.record` 导出的末态存档出战栏写留底（`patch_save`），`replay` 结束 `release` 放开登记，不残留到下一场。战斗中不存档（`auto_save.gd`），写档那条保险没改 `xstate.gd`（见下「偏离」）。
- 五条悟离场 `XGojo.leave`（新开关 `LEAVE_DOMAIN`，O-待定·五条悟离场清领域，默认开）：`tianqi_swap` 里调，发作换下、手动换下、自动换回都算；领域回合数清零、去掉领域状态、报「某某的无量空处消散了。」（现有文字）；苍印、赫印、自动反转照旧。发作换人的这句并进 `act` 的记录，手动换人由画面 `_tianqi_swap` 先播。
- T180 P3-2 云裳衣魂 `XYunshang.HELPER_GHOST`（O-待定·助力位衣魂结算，默认开）：回合末另扫助力位，衣魂到期照样 `end_ghost`（只结衣魂；赊账、裁身这些照现行下场暂停）；收口 `end_battle` 赊账、衣魂连助力位一起结清。
- 复核 P3-3：`XBattleReplay.replay` 里 `cmd.automatic` 的那一支照 `decide` 给的行动执行（`skill = decision[0]`），不再只取目标、技能按技能表重查。
- 测试钩子 `XTianqiBrand.TEST_FIT`（{角色号: [回合, 花样]}，游戏里恒空）：回合开头点名开一次发作，不掷几率、不取随机数，给专项回放和 T086-d 量数用（设计稿第八节「触发用测试钩子点名」）。
- 画面只做了不报错的最小接线（演出归 T182）：主循环 `act` 之后见到 `tianqi_swap` 记录就调 `_tianqi_swap_view`（复用原手动换人的换图＋现有那句「%s退下，%s上场了！」）；`_tianqi_swap` 拆成逻辑调用＋`_tianqi_swap_view`／`_swap_sprite`／`_swap_sprite_from`；新 `_tianqi_restore_view()` 在 `_victory()` 第一行，按 `tianqi_restore` 返回的逐位对照先摘旧图旧状态行再建新的。
- 测试：新专项 `xiyou_tianqi_real_swap` 69 项（开关默认值、关着断片、真换收尾后对调与记录、留底不进存档键、锁定 2/3/4 回合、收尾倒下不换、两种换不了改完整断片、模块名单读数据、锁定中别人改断片、两样还原、整份还原逐位对照、重复调为空、rewards／grant 开头就还原、同一批核对、心魔两例、自动换回现判与手动不换、玩家换过不误换、九死口子三例与清理停手、证道满额断片、开新一场清扫、回放导出写留底与回放可用、回放不残留、五条悟开关两面、衣魂开关两面、真战斗画面换图与结算前还原换回图）。
- 玩家可见：无（开关关着）。五条悟手动换下领域消散、助力位衣魂到期倒下这两条开关默认开，现在就生效（只在天启篇手动换人时会碰到）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化内容 | 理由 | 回退 | 执行者 | 状态 |
|---|---|---|---|---|---|---|---|
| O-待定·发作真换人 | `core/tianqi_brand.gd` `XTianqiBrand.REAL_SWAP`、`swap_possible`、`after_act`、`auto_back`、`sweep`；`battle/battle_logic.gd` `can_tianqi_swap`、`tianqi_restore`；`core/item_marks.gd` `enforce_party`；`core/battle_replay.gd` | 天启篇新机制（原版无）：烙印第六种「换人」一律断片 | 能换时真换人（收尾后和助力位对调、锁定 2 回合、自动战斗换回、打完还原出战栏＋在场名单） | 发作真换人 v0.2、D201 六件 | 默认就是关的；`XTianqiBrand.REAL_SWAP = false` | cc | 默认关，标定（T086-d）后翻 |
| O-待定·五条悟离场清领域 | `core/gojo.gd` `XGojo.LEAVE_DOMAIN`、`leave`；`battle/battle_logic.gd` `tianqi_swap` | 天启篇新机制（原版无）：五条悟开着领域被换下，领域回合数停住、换回来接着算 | 离场（发作、手动、自动换回）无量空处当场消散 | 发作真换人 v0.2 第四节：领域不能「存」着 | `XGojo.LEAVE_DOMAIN = false` | cc | 保留 |
| O-待定·助力位衣魂结算 | `core/yunshang.gd` `XYunshang.HELPER_GHOST`、`_five`、`_helper_ghost`、`end_turn`、`end_battle` | 云裳 endTurn／endBattle 包装只扫场上（原版没有助力位） | 回合末助力位衣魂到期照样结束；收口赊账、衣魂连助力位一起结清 | T180 P3-2：死期死在助力位触发不渡黄泉，衣魂永不到期 | `XYunshang.HELPER_GHOST = false` | cc | 保留 |

## 交接板

- 下一步：T182（T086-c 画面）接在本单的钩子上，见下「给 T182」；T182 合了才能翻 `REAL_SWAP`（T086-e 跟烙印翻开关一起）；T086-d 量数用 `XTianqiBrand.TEST_FIT` 点名触发。
- 用户试玩说明：无（开关关着）。
- 需要用户决定：无。

## 给 T182（T086-c 画面）

- 发作换人、自动换回的记录：`act` 返回的日志最后一条 `{"type": "tianqi_swap", "out": 下场的人, "in": 上场的人, "forced": true}`（自动换回是 `"auto": true`），之前是发作那句（`tianqi_fit`）和可能的「无量空处消散」。主循环现在在 `_play(logs)` 之后对每条这种记录调 `_tianqi_swap_view(out, in)`：换演出就改 `_tianqi_swap_view`（手动换人也走它）。`_play` 本身不认这条类型（match 没有分支）。
- 收尾之后换不了的那句是 `battle_text`、带 `tianqi_fit`（`XTianqiBrand.TEXT_SWAP_FALLBACK`）。
- 结算前还原：`_tianqi_restore_view()` 在 `_victory()` 第一行，`logic.tianqi_restore()` 返回 `[[还原前在这一位的人, 还原后的人], …]`；现在只换图和状态行、不演出，要加演出在这里改。打输、逃跑、事件中止撤退不经过画面还原（画面马上收掉），由 `end_battle` 还原逻辑。
- 锁定：`XTianqiBrand.swap_locked(logic)`、`swap_data(logic).lock_until`（最后一个锁定回合）、`last_out`／`last_in`（角色号）；现在锁定时 `can_tianqi_swap` 为假，「换人」指令不出现，变灰和原因由 T182 做（可以直接读 `swap_locked` 判是不是因为锁定）。
- 测试钩子：`XTianqiBrand.TEST_FIT = {角色号: [回合, "swap"]}` 可在真战斗画面里点名触发。

## 改过的玩家可见句子（供小A 文字审）

| 位置 | 改前 | 改后 |
|---|---|---|
| 收尾之后换不了，`XTianqiBrand.TEXT_SWAP_FALLBACK`（新） | — | 「%s 没能退下，断片了！」（角色名） |
| 五条悟离场 `XGojo.leave` | — | 复用现有「%s的无量空处消散了。」 |
| 发作换人、自动换回的画面 | — | 暂时复用现有手动换人那句「%s退下，%s上场了！」，T182 定演出 |

## 没做／偏离

1. **`core/item_marks.gd` 改了一行**（不在派单独占文件里）：`enforce_party` 开头 `if XTianqiBrand.swap_hold(s): return false`。不加的话九死临时口子开不了：战斗里任何一处 `battle_members()` 都会把坐助力位的超强者清掉并从后备补人（验收第 4 条）。设计稿第七节接口表本来就列了它。
2. **`tianqi_data/brand.json` swap 一行加了 `lock_rounds`、`lock_rounds_range`、`blackout_only`、`note`**：设计稿第七节接口表列的，派单没单列。
3. **写档保险没改 `xstate.gd`**：战斗中不存档；能把战斗中的出战栏导出去的只有回放，已在 `battle_replay.gd` 换成留底；另有开战清扫兜底。真要战斗中写档时再加。
4. **画面改动比「只留钩子」多一点**：不接线的话发作换人后 `sprites` 里没有上场的人，下一次轮到他画面就报错，所以复用原手动换人的换图做了最小接线（不加演出），结算前还原换回图也一样。
5. 「战斗中读出战栏的二十多处」只 `grep` 过一遍（`battle_slots`、`helper()`），没看到会被「九死超强者临时坐助力位」弄错的；没逐个读。领袖旗标认第 1 格，和手动换人一样，第 1 格被换下去战斗里领袖效果跟着没、还原后回来。
6. 复核 P3-3 那一行没有专项能咬住：现有回放场景里 `decide` 给的行动和按技能号重查的一样，改不改结果相同。
7. 烙印份额「被换下去的人打赢后拿 1 份」只断言到「`rewards`／`grant` 开头已还原在场名单」，没起一场真的首领战算份额（烙印、法宝、真气都直接读 `actors`）。

## 可优化（流程／工具／效率）

- 无

## 验证

- `python3 07_开发环境/语法检查.py`：0 个问题。
- `xiyou_tianqi_real_swap` 69/69。
- 反向验证（`反向验证.py`，基线 69/69 先过）：14 处改坏全部咬住——收尾倒下照换、不锁定、换人挪到行动开头、只还原出战栏不还原在场名单、心魔用还原后名单、出战栏清理不停手、五条悟不清领域、助力位衣魂不扫、开新一场不清扫、回放导出不写留底、中途断片不补齐 2 回合、自动换回不判自动、九死口子不开、结算前不还原。
- 本机（`并行测试.py`，新 HOME）：`xiyou_tianqi_real_swap` 69/69、`xiyou_tianqi_brand` 234/234、`xiyou_tianqi_doom_follow` 74/74、`xiyou_tianqi_swap_init` 15/15、`xiyou_tianqi_weak_clear` 46/46、`xiyou_gojo` 84/84、`xiyou_yunshang` 1675/1675、`xiyou_battle_actor_size` 157/157。
- `工具回归.py`：全部通过（93 秒）。
- 云端选测第一轮（dd4a8a1fa8，454 场景 16 片）：`xiyou_tianqi_weak_clear` 挂在 `slot_write_choke`（还原、清扫直接下标写出战栏，绕过 `set_battle_slot`），已改成走 `set_battle_slot`（2fec084c7）；`xiyou_tianqi_real_swap` 当时偶发（回放那例新配置下敌人两下就倒、指定的人轮不到，已改全员点名，493cbd9a8）；`xiyou_battle_actor_size` 偶发（本机单跑 157/157，本单没碰它）。
- 云端选测第二轮（2fec084c7）：454 个场景、16 片全过（基准 4bf4727f14）。`--oracle` 对照没跑（派单写合并时由总装跑）。

## 待交叉核查（甲档，请重点看这些核心文件）

- `modes/xiyou/battle/battle_logic.gd`：`can_tianqi_swap`（锁定、临时口子）、`tianqi_swap`（五条悟离场）、`tianqi_restore`／`_trial_actors`、`act` 最后 `after_act`、`rewards`／`grant`／`end_battle` 开头还原、`setup` 清扫。
- `modes/xiyou/core/tianqi_brand.gd`：`_start_fit` swap 分支、`forced_action`、`perform`、真换人一节、`TEST_FIT`。
- `modes/xiyou/battle/battle_scene.gd`：主循环换图、`_tianqi_swap` 拆分、`_tianqi_restore_view`、`_victory` 第一行。
- `modes/xiyou/core/battle_replay.gd`、`core/gojo.gd`、`core/yunshang.gd`、`core/item_marks.gd`。

## 本分支提交

- 1b5b96ab6 WIP：逻辑层
- dd4a8a1fa 专项＋TEST_FIT（见 git log）
- 493cbd9a8 回放专项改全员点名
- 2fec084c7 还原、清扫走 set_battle_slot
- （本交付单提交）
