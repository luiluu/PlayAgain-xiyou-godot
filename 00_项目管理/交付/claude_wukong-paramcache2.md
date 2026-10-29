# 交付：claude/wukong-paramcache2

- 车道／工作者：C 规则·机制（参照探针、参数缓存）＋B 界面小活（ui_reference 工具栏）／悟空_64（Claude）
- 状态：可合并

从 `claude/wukong-selhelp2`（c69ba3df）切出，中途合过 main（9fe6abb1，含 selhelp2 dev.207、八戒 alien-affix3）。没碰 `battler.gd`、`actor.gd`、`battle_logic.gd`；没用优化编号。

## 期一：探针战斗现场帮手

- 新文件 `mv_oracle/shared/battle_host.cjs` 里的 `battleHost(host, {troopId})`：
  - 在 `host.cjs` 的内存新局上走原版 `BattleManager.setup(troopId, true, false)` 和 `startBattle()`。这样敌群、`inBattle`、各战斗者的 `onBattleStart`、云裳等运行时要的现场都齐了。
  - 返回 `actor(i)`、`enemy(i)` 和 `apply(subject, skillId, target, fix)`：走整条 `Game_Action.apply`，命中、回避、暴击可以固定，并照原版设好 `BattleManager._subject` 和 `_action`。
- **和派单的出入**：派单写的是「`shared/host.cjs` 加 battleHost()」，我放成了同目录的新文件。原因是增量同步按 `require` 图记依赖（`incremental_sync.py:218`），改 `host.cjs` 会让 56 个用它的探针全部失去复用、重跑一遍。`host.cjs` 一字没动，现有探针的行为和复用都不受影响。
- 核对上期的模拟：`param_cache_probe` 新增 `apply_real.damage`／`apply_real.pure` 两例，走真 apply（技能 1276，量时把效果临时换成减攻、减防各一层；pure 再临时把伤害类型改成 0）。
  - 带伤害：apply 后当场就是新值，物攻 47→35、物防 20→15。
  - 纯减益：当场仍是旧值 47／20，`refresh()` 后也还是旧值。
  - 和上期用 executeDamage＋applyItemEffect 模拟的结论**完全一致**。上期的模拟两例保留，用来对照。

## 期二：角色侧状态、xparam、sparam 缓存逐项核

### 原版实测（`param_cache_probe` 新增 `actor_cache.*` 8 例，battleHost、角色 1、敌群 2）

每步记 xparam 0～9、sparam 0～9、参数 0～7、krz 的 `need_refresh`。用到的数据：
- 状态 1169：22 号特性，xparam 3（暴避）−0.35
- 状态 1158：23 号特性，sparam 6 ×1.25
- 防具 51 毛布护甲：回避 +0.01，另加物防等

| 例 | 当场读 | 中间事件后 | 下次 refresh 后 |
| --- | --- | --- | --- |
| 加 xparam 状态（读热） | 旧（need 真） | — | 新 |
| 加 xparam 状态（冷读：上次 refresh 后没读过） | **也旧**：states() 列表缓存本身是旧的 | — | 新 |
| 去 xparam 状态 | 旧（仍带 −0.35） | — | 新 |
| 加 sparam 状态 | 旧 | — | 新 |
| 加状态后 `onTurnStart` | 旧 | 旧（只标脏） | 新 |
| 加状态后 `onTurnEnd` | 旧 | **新**（regenerateAll 内 refresh） | 新 |
| 加状态后 `gainHp(-1)` | 旧 | **新**（扣血的 refresh 吃掉加状态标的脏） | 新 |
| 换带 22 号特性的防具 | 旧（回避和物防都旧） | — | 新 |

结论：原版战斗中角色的 xparam、sparam、param 和 `states()` 一样，都是「被包的方法只标脏，下一次 refresh 才变」。当场读到的是旧值；冷读也旧，因为状态列表本身有缓存。

### 重制对照（新专项 `tests/xiyou_param_cache`，读 `generated/oracle/param_cache.json` 的 `actor_cache.*`）

- 重制照同样时序操作：`_state_add`／`_state_remove`、`param_mark_dirty`（单个 onTurnStart）、`turn_end_battler`、`sequence_gain`、换 `equips` 后标脏，最后 `_refresh_battler`。
- 结果：61/61。
  - 读热行、`onTurnEnd` 行、`gainHp` 行、refresh 后的行**全部和原版一致**。
  - 只有 9 个「当场读」的行不一致：原版旧、重制新。这 9 行列在 `KNOWN`，计数、打印，不算失败：
    - `add_x/now`、`remove_x/now`、`add_s/now`、`add_x_turnStart/now`、`add_x_turnStart/onTurnStart`、`add_x_turnEnd/now`、`add_x_gainHp/now`、`equip_x/now`、`add_x_cold/now_cold`
    - 其中 `equip_x/now` 原版连物防也是旧的（20），重制 26。
- 差异原因：重制角色的 `xparam`／`sparam`／`param` 每次从当前 `state_ids` 和装备现算。`battler.gd` 的 `effect_dirty`／`effect_snapshot` 只管状态「效果阶段」列表（`effect_states`），不管特性；`param_cells` 也只有敌人开着。

### 修法提案（交唐僧定；文件归八戒）

和上期参数缓存的甲／乙是同一个决定，建议合在一起定：

- **甲（复刻）**：
  - `battler.gd`：加角色侧「特性快照」。`param_refresh` 在 dirty 时把 `states()` 加装备的特性对象一起快照；`traits_*` 系列在战斗中读快照。这样 xparam、sparam、param_rate、元素等一起变成「下次 refresh 才新」。
  - `battle_logic.gd`：开战、结束时对角色也 `param_cache_begin`／`param_cache_end`。
  - `actor.gd`：`param` 走 `cached_param`，要分清 krz 内外层（见上期交付单）。
  - 牵动面大：所有会在「加状态后、下次 refresh 前」读角色特性的规则都会变，包括命中、暴击、元素、状态有效度。预计 `xiyou_rules*`、`xiyou_race_battle`、`xiyou_alien_affix`、`xiyou_state_effects`、伤害对照（`--oracle`）都要重核。
- **乙（不复刻，登记优化）**：角色侧保持即时生效。
  - `xiyou_param_cache` 的 `KNOWN` 就是这条优化的回归清单。原版这个现象是性能缓存的副作用：玩家看到的是加了状态、换了装，这一下还没生效。
  - 敌人侧已经复刻缓存，乙方案下敌我两边不一致，这一点也要用户知道。

我倾向乙。甲的工作量和回归面明显大于收益，而且原版这个行为玩家基本感知不到对错，只会觉得「慢一拍」。

## 期三：ui_reference 战斗工具栏两个按钮

`ui_reference/mac-preload-shim.js` 的 `?battle_ref=1` 工具栏，README 也补了说明。
- 「给角色设种族（下次开夹具生效）」：选位次、种族（无／神妖人魔鬼灵蛮）、阶位。夹具在 `BattleManager.setup` 之前照 `race_battle_probe` 的 setRace 设好。实测：1 号位设「妖·3 阶」后开夹具，`_codexRace` 是 `{race:1, rank:3}`，`_codexRaceBattle` 已建。
- 「选目标确认」：填技能号，在指令窗激活时走指令窗→技能窗→onSkillOk，约 20 帧后读各窗口状态，写到工具栏末行和 `window.__selhelpLast`。实测技能 10（全体敌人）：
  - 选敌窗激活、序号 2（最右）；指令窗 opacity 0、停用；技能窗隐藏；说明卡不可见；只亮一只敌人。
  - 和 dev.205／207 手测的结果一致。
- `guard_check.py` 12/12（参照服务守卫没受影响）。

## 优化

没有新增优化。期二的乙方案如果采纳，要另外分配编号（O-110 可用）。

## 变更记录草稿

## 2026-10-29 【Claude·悟空·未经Codex检验】探针战斗现场帮手；角色侧状态／xparam／sparam 缓存逐项核；参照工具栏两键（dev.待定）

- `mv_oracle/shared/battle_host.cjs`：原版 BattleManager.setup＋startBattle 的内存战斗现场，探针能跑整条 Game_Action.apply。放成独立文件，不改 host.cjs，现有探针的增量复用不受影响。用它核过上期「带伤害的减益当场新、纯减益当场旧」，和模拟一致。
- `param_cache_probe` 挂进同步（oracle_additions 按 id）。新增 actor_cache 8 例：原版战斗中角色加、去状态、换装后，xparam／sparam／param 当场仍旧，下一次 refresh（含 onTurnEnd、扣血）才新。新专项 `xiyou_param_cache` 对照重制：其余全一致，9 个当场读差异标为已知。复刻还是登记优化，和上期参数缓存的甲／乙一起待定。
- ui_reference 战斗工具栏加「给角色设种族」「选目标确认」。

## 交接板

- 需要用户决定：参数缓存甲／乙那条补一句：角色侧的状态、xparam、sparam 也有同样的「当场旧、下次 refresh 新」，见 `xiyou_param_cache` 的 KNOWN；甲方案牵动面更大，建议一起定。
- 可优化那条（悟空 dev.204／205 交付单的 ui_reference 两键）：已做，删掉。

## 验证

悟空_64，2026-10-29，已合 main（9fe6abb1）：

- 同步：`同步正式西游.py --accept-additions --accept-changes 04_验证/测量接受/claude_bajie-alien-affix3.json`，退出码 0，产物指纹已留。
  - 新增 `param_cache.json`（30 例），作为新增收下。
  - 唯一的既有改变是合 main 带进来的 `alien_affix.json`：例数 7→12、`hostScope` 改了。这是八戒 alien-affix3 的改动，按 main 上八戒的接受单接受，不是本分支改的。
  - 第一次只加 `--accept-additions` 时因为这一处退出码 2，加上接受单重跑才过。
- 选测（`并行测试.py … xiyou_param_cache xiyou_battle xiyou_status_power xiyou_param_states`）：12 个场景全过，没有偶发，45 秒。
  - `xiyou_param_cache` 61/61（`KNOWN_DIFFS=9`）
  - `xiyou_param_states` 582/582
  - `xiyou_status_power` 36/36、`xiyou_status_power_panel` 11/11
  - `xiyou_battle_ui` 108/108
  - `xiyou_battle` 8/8、`xiyou_battle_events` 108/108、`xiyou_battle_options` 92/92、`xiyou_battle_start_event` 50/50、`xiyou_battle_common_events` 22/22、`xiyou_battle_common_event_child` 13/13、`xiyou_battleback_save` 5/5
- ui_reference：`guard_check.py` 12/12；两个新按钮在原版页面上实测过（见期三）。
- 没跑全量 `检查.sh`（车道规矩）。
- 已清理：参照服务（serve.py:8766）已停，浏览器窗格已关。scratchpad 里的原版截图、测试日志、同步日志和临时脚本已删。`.sandbox/param_cache.json` 在 .gitignore 里。

## 遗留

- 换装只测了一件防具；武器、法宝、套装的特性快照时序没测（甲方案定了再补）。
- `xiyou_param_cache` 的单个 onTurnStart 行：重制没有单个战斗者的 onTurnStart，专项里只调 `param_mark_dirty` 模拟 krz 的标脏。

## 待交叉核查

- 新文件：`mv_oracle/shared/battle_host.cjs`、`tests/xiyou_param_cache.gd`（＋`.tscn`／`.uid`）。
- 改了：`mv_oracle/param_cache_probe.cjs`（apply_real、actor_cache）、`同步正式西游.py`（PROBES 加一行）、`oracle_additions.py`（加一行）、`ui_reference/mac-preload-shim.js`、`ui_reference/README.md`。
- 没碰 battler／actor／battle_logic 等核心文件。
- 请沙僧重点核：battleHost 的 startBattle 现场和真实开战有没有缺项（这里没有 Scene_Battle 和 spriteset，开战公共事件只预约不执行）；`xiyou_param_cache` 里重制侧时序的对应关系是否合理。

## 可优化（流程／工具／效率）

- 探针要读「绕过缓存的现算值」时，现在得直接调 `krz.restate.Game_Actor_param`。xparam 这么做没意义：内层还读缓存的 states()。可以在 battleHost 加 `fresh(b)`：先存 need 标记、强制 refresh、读完再还原。等甲方案真要逐项对照时再做。

## 本分支提交

- 3c?（WIP）battle_host 与真 apply 核对
- （WIP）actor_cache 8 例、挂同步、新专项 xiyou_param_cache
- 合并 main（9fe6abb1）
- bd58496e（WIP）ui_reference 两键
- （本提交）交付单、可合并
