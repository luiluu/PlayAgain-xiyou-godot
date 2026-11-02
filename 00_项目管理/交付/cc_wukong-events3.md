# 交付：cc/wukong-events3

- 车道／工作者：悟空（cc），屠苏璇进切片（A 车道前置）＋战斗事件脚本第三批＋审查 21 期两条 P3
- 基线：从 `cc/wukong-events2` 末端 1a736398 切出；11-02 events3c 合了 main 96036312（已含屠苏 tusu1～3、谷雨 fix1，无冲突）。events3c 新工作树跑过 `新建工作树.sh --补齐` 和 `同步正式西游.py --accept-additions`（退出 0，新增的 176／177 用例已接受）。
- 状态：**可合并**（events3c 接手做完：选测、屠苏去钉、套装再放一次一族；验证见下）

## 一、屠苏 176、璇 177 进切片（白龙 tusu1 的前置）

- `03_转换工具/xiyou_slice.json` actors 加 176、177（照 174／175）。同步新增参照：actor_passive、help_cards、wtype、slice_d1～d6 都多了两人的用例（新增已接受），script_gaps 见下。
- `03_转换工具/formula_program.py` MODULE_FORMULAS 加 `CodexTusu.damage(a,b,'键')`（10312～10325 十个）→ tusu、`CodexXuan.damage(a,b,'lengguang')`／`CodexXuan.heal(a,b)` → xuan。求值：`XFormulaExecution._run_item` 认 tusu／xuan，走 `XTusuXuan.formula`：屠苏的调屠苏三期的 `XTusu.damage`（events3c 改，删掉本分支先写的一份），璇的 damage／heal 按 X.damage（魔攻×系数）、X.healAmount。
- 屠苏璇进切片后的修补（59698eb7、9af4a8eb、events3c）：说明卡 nowGrowthView 屠苏璇、bindGrowth 浅拷贝不插伤害属性；回光治疗取负；寄星·附身、列星在璇的绑定期合进来前恒不可用（易武那条三期已管，events3c 删掉）。
- 屠苏六项能力值钉子去掉（`tests/xiyou_tusu_battle.gd` 的 TusuActor，白龙 tusu3 留的）：去掉后差两处，都修了——
  - 60 级止戈环没进化：`core/three_growth.gd` SPECS 补 4047 止戈环→太初五兵环、4048 璇玑星盘→周天命星仪（每级成长翻倍、改名、说明，照 installThreeGrowthRelicRuntime 的 specs／texts）。
  - 参照本身前例污染：R.syncItem 会改 `$dataArmors` 原件，同一进程里 devour（60 级进化）之后 low 5 级也按进化算；而且没先同步原件就登记的实例会按旧版倍率去重再补新倍率，多出一条魔攻×1.2（basic 30 级魔攻 1530＝1093×1.4，原版倍率是相加）。`mv_oracle/tusu_battle_probe.cjs` 每例还原三件法宝原件、再像读档一样先同步一次原件；重制照数据库原件的倍率（见优化登记草稿）。夹具重生成。
- help_card dyn2：`character_help._dyn2_view` 对 id＞10287 本来就不改写（两人的技能都在 10312 以上），说明卡按原文；help_card 选测见验证。

## 二、E 类（战斗里跑的脚本）

先查了**影杀等「套装再放一次」**：`for(let i = 1; i < 999; i++){ var actor = $gameActors.actor(i); if(actor && !actor.isDeathStateAffected() && actor._states.includes(345) && actor.hasArmor(…)…) { new Game_Action → setSkill(N) → decideRandomTarget → actor._actions.splice(1,0,action) → BattleManager.forceAction(actor) } }`，共 **34 个公共事件**（CE17 水流、18 锋芒、72～76、88、107 影杀、116、121～123、126、128～130、161、251～255、325、390、512、581、628～631、976～978），技能把状态 345 加给使用者、公共事件找带 345 且穿着套装的人追加一次技能、最后 313 解除 345。**战斗逻辑里没有另做**（全工程没有 345 的处理），是真缺。CE1327／1354／1370 也是同一套 splice＋forceAction。**events3c 做了**，见下「套装再放一次」。

本期补了两种（战斗事件解释器 `battle/battle_event_runner.gd`）：

| 写法 | 位置 | 做法 | 参照（script_gaps） |
| --- | --- | --- | --- |
| `for (var i = 0; i < $gameTroop.members().length; i++) { $.toaster({ message: (i+1)+'号敌人暴闪为' + …cev.toFixed(2)*100 + '%!' }); }` | 投石问路 CE2486（技能 7188） | `_troop_cev_script`：每个敌人一条提示，toFixed(2) 再 ×100 照 JS 数字转字符串 | troopCev（敌群 53：「1号敌人暴闪为5%!」） |
| `for(let i = 1; i < N; i++){ var actor = $gameActors.actor(i); if(actor._states.includes(S) && actor.hasArmor($dataArmors[A])){ …members[i].addState(T); } }` | 猛击 CE78（技能 459） | `_set_armor_troop_state_script`：有人带 S 且穿着 A 就给全体敌人加 T（倒下的加不上） | setArmorState.wear／bare（原版 506 新局穿不上：两边都直接当作穿着） |

### 套装再放一次（events3c）

- 原版（参照 `mv_oracle/battle_common_event_probe.cjs` 加 5 例：recast_armor_worn／half 影杀 CE107、recast_weapon 乱披风 CE325、recast_skill_learned／not 滑稽弹再次 CE628）：技能的动作序列给自己加 345 → 行动后跑公共事件 → 脚本 `for i…{ actor 条件 → new Game_Action → setSkill → decideRandomTarget → _actions.splice(1,0,…) → forceAction }` → 313 解除 345 → **事件跑完后**才执行强制行动（脚本里的 forceAction 不等，`_actionForcedBattler` 只记最后一个）。628 的追加技能 3670 自己的 Setup Action 又加 345，事件后 345 还在。
- 重制：`battle/battle_event_runner.gd` `_recast_script`（条件认 actor 守卫、!isDeathStateAffected、_states.includes、_skills.includes、hasArmor／hasWeapon（基础编号）、hasSkill、`($gameVariables.value(V)==K)`、!checkBattleEnd；读到没数据的角色又没守卫时抛错、后面都不做）；第二种写法 `$gameActors.actor($gameVariables.value(V))` ＋ if／else。记 `logic.pending_force`，`battle_logic._drive_events` 在公共事件跑完时 `_take_pending_force` 结算（倒下或打完就不放），强制行动结算抽成 `_forced_run`（339 也用它）。
- 顺带修：**战斗里的 313 每人最后 clearResult**（`battle_logic._change_actor_state`，原版 command313）。之前不清，解除 345 后同一回合的追加技能 Setup Action 再加 345 会被「本次已解除」挡掉。
- 覆盖：37 个里做了 34 个套装族＋CE1354 冥花葬、1370 斩天拔剑术，另 CE100 三魔术（同写法、带变量条件）；**剩 CE1327 三千烦恼风**（`$gameActors.actor($gameParty._targetActorId)`，重制没有 _targetActorId）。CE76、122、251～255、512 没有技能触发（切片里到不了），写法一样也认。注：之前战斗公共事件盘点没把这一族算作没翻译（落到通用脚本里静默不做），所以盘点数没变（240 个、有跳过的 8 个：942～946、1321、1327、1501）。
- 专项 `xiyou_battle_common_events` 53/53。

剩下 E 类真缺：CE1327（_targetActorId）、CE1321 `CodexFreezeFollowup`（技能 6171）、CE9014／9015 屠苏器谱、璇星谱（模块没移植）。

## 三、审查 21 期插单

- **P3① 猫哥清理存档**：原版在 `js/plugins/zchuli.js`（不是 YEP_ItemCore）：把在队成员身上与背包里的独立装备重编号、其余独立装备条目丢掉（仓库里存的旧编号失效），最后 `updateActorEquips` 给在队成员 `gainHp(mhp)`、`gainMp(mmp)`、`refresh`（倒下的也救起）。重制 `MVScript._cleanup_independent`：回满照做（参照 cleanupHeal：四人全满、8 号倒下也救起）；重编号没有可做的（重制存实例）；**仓库里的武器防具**做成回退开关 `MVScript.o_cleanup_keep_warehouse`（默认 true 留着；false＝照原版按丢掉处理，道具不动），见优化登记草稿。
- **P3④ 普查去重**：`xiyou_script_census` 改成按「种类|完整原文」去重：**4230 种、认不出 182 种**（原按前 80 字是 3799／127）。新清单 `tests/fixtures/script_census_known.json`：原来前 80 字相同的 179 种照原分类，另 3 种真被藏住的（CE1388～1390「极尽升华」：`for (var j = 1; j < $dataActors.length; j++){ … hasSkill(A) → forgetSkill(A)、learnSkill(B) }`，静态找不到调用）归 F。分类计数：A 44、B 18、D 21、E 62、F 37。

## 优化登记草稿

| O-待定-1 | 猫哥清理存档时仓库里的武器防具（`map/mv_script.gd` `_cleanup_independent`，zchuli.js cleanupIndependentItems） | 原版只给身上与背包的独立装备重编号，仓库（PHWarehouse）里记的旧编号失效：存着的武器防具丢掉或变成别的装备；NPC 自己也提示先取出来 | 重制存的是装备实例，不会失效，仓库里的照旧留着 | 原版的清理是为了解决数组过长卡顿，丢仓库装备是副作用，不是本意 | `MVScript.o_cleanup_keep_warehouse = false`（按全部丢掉近似原版；原版里落在新编号范围内的会变成别的装备，这点不重现） | cc（悟空） | 待用户确认 |
| O-待定-2 | 屠苏／璇／谷雨法宝的特效倍率（`core/three_growth.gd`；installThreeGrowthRelicRuntime R.syncItem） | 原版对新登记的法宝实例按旧版倍率去重再补新倍率：本次启动里法宝原件还没同步过（新开局、没读档、没给 175～177 升级）就拿到的那件会多一条特效，屠苏魔攻 1.4 倍（应 1.2）、谷雨生命 1.6、物防 1.4；先同步过原件再拿到的不多。结果看启动后的先后 | 按数据库原件的倍率（屠苏魔攻 1.2、谷雨生命 1.3），不分先后 | 原版的去重是给旧存档的旧倍率换新用的，新实例多出那条是副作用；同一角色两次开局能力值不同 | 没做开关（原版结果取决于启动后的先后，没有确定的一种可回退）；要照原版的「新开局那件」可以另做 | cc（悟空） | 待用户确认 |

## 变更记录草稿

## 2026-11-02 【cc·悟空·未经审查】屠苏璇进切片；战斗事件投石问路、猛击、套装再放一次；猫哥清理存档回满（dev.待定）

- 切片 actors 加 176 屠苏、177 璇；两人的伤害／治疗公式登记为模块公式（求值等后续）。
- 战斗里投石问路（CE2486）给出每个敌人的暴闪提示；猛击（CE78）这类「带标记且穿着套装就给全体敌人加状态」生效。
- 影杀、乱披风、滑稽弹再次等「穿着套装（拿着武器、学会某技能）就再放一次」的 36 个公共事件生效：事件跑完后追加一次强制行动（剩三千烦恼风）。战斗里事件解除角色状态后清掉本次结果，同回合可以再加上。
- 屠苏、璇的法宝 60 级进化（每级成长翻倍、改名）；法宝特效倍率按数据库原件（O-待定-2）。
- 大厅猫哥「清理存档」照原版给在队成员回满生命、魔法（倒下的也救起）；仓库里的武器防具默认留着（O-待定-1，可回退成照原版丢掉）。
- 事件脚本普查改按完整写法去重：4230 种、认不出 182 种。
- 参照 `mv_oracle/script_gaps_probe.cjs` 加 4 例（共 20）；`battle_common_event_probe.cjs` 加 5 例；`tusu_battle_probe.cjs` 每例还原法宝原件。

## 验证

- 云端选测（`云端选测.py run`，基准 main 96036312，提交 21dade59）：**217 个场景，216 过**，挂 `xiyou_wtype`（屠苏易武 10302～10310 五个：测试量 canUse 时没登记战斗，XTusu.meets 不生效；探针那边 inBattle 为真）。修在 5caa20c9（只改测试），本地单跑 `xiyou_wtype` 过。偶发：`xiyou_floor_reach080`（并行失败、单跑过，首次）。运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41388614981
- 本地专项：`xiyou_battle_common_events` 53/53、`xiyou_battle_events`、`xiyou_battle_common_event_child`、`xiyou_tusu_battle` 992/992（去钉后）、`xiyou_tusu` 314/314、`xiyou_guyu_battle` 1528/1528、`xiyou_three_growth` 92/92、`xiyou_wtype` 全过。
- 新断言咬得住（手动反着看过，没跑反向验证.py）：没有事件后结算时 recast_*.forced 挂；313 不 clearResult 时 recast_skill_learned.state345 挂；去钉前三法宝没进化时 devour 各项挂。
- 同步 `--accept-additions` 退出 0（events3c 新工作树重跑；新增 176／177 的 actor_passive、help_cards、wtype、slice_d1～d6 用例，script_gaps 20 例）。`内容覆盖检查.py`：新 0、解决 0，不用更新基线。`探针登记检查.py`、`语法检查.py` 通过。
- 先前已过：`xiyou_script_gaps`、`xiyou_script_census`（4230／182）、`回退开关覆盖.py`（o_cleanup_keep_warehouse）。
- 探针产物手工拷进夹具（两个都不进同步）：`battle_common_event_oracle.json`（加 5 例，旧 4 例的公共事件记录多一个 marked 字段）、`tusu_battle_oracle.json`（每例还原法宝原件后重生成）。

## 交接板

- 下一步：CE1327 三千烦恼风（_targetActorId）、CE1321 冻结术再释放（CodexFreezeFollowup）；屠苏四期（支援施放与效果、统一伤害钩子）照白龙分期。
- 用户试玩说明：猫哥「清理存档」后在队成员回满；战斗里用投石问路会弹出每个敌人的暴闪；穿齐套装（如冰雪丝绸两件）用影杀类技能会再放一次；屠苏、璇 60 级法宝进化。
- 需要用户决定：O-待定-1 猫哥清理存档时仓库装备（默认留着）；O-待定-2 法宝特效倍率（默认按数据库原件，不复现原版多出的那条）。

## 进度账

- 事件脚本写法（按全文）：4230 种里认不出 182 种。
- 战斗公共事件「套装再放一次」：37 个里 36 个可用（剩 CE1327）。
- 角色：切片 actors 加 176、177（机制按白龙的分期）；屠苏、璇法宝进化可用。

## 可优化（流程／工具／效率）

- 普查的 KNOWN 清单键现在是完整原文，有的很长；以后可以改成「规范化全文的哈希＋前 80 字」方便看 diff。
- 战斗公共事件盘点（`xiyou_battle_common_events` 的 _inventory）只数「落到 skipped 的指令」，脚本被通用 MVScript 静默吞掉的不算，套装再放一次一族因此一直没进清单。可以让 355 在战斗里没被任何写法认出时也记一笔（不影响行为），盘点才准。
- 有状态的参照探针（会改 `$dataArmors` 等原件的模块）同一进程多例会互相污染；tusu_battle 这次每例还原原件，别的探针（guyu_battle 等用到三法宝的）可以照样查一次。

## 待交叉核查

- `battle/battle_event_runner.gd`：`_troop_cev_script`、`_set_armor_troop_state_script`、`_recast_script`／`_recast_cond`／`_recast_meets`（共用战斗解释器）。
- `battle/battle_logic.gd`（原沙僧核心文件）：`pending_force`、`_take_pending_force`（`_drive_events` 公共事件跑完时结算）、`_force_action` 抽出 `_forced_run`、`_change_actor_state` 每人最后 clearResult、`_clear_event_cursor` 清 pending_force。
- `core/three_growth.gd`：SPECS 补 4047／4048。`core/tusu_xuan.gd`：formula 改调 XTusu.damage、meets 去掉易武那条。
- `map/mv_script.gd`：`_cleanup_independent`、`o_cleanup_keep_warehouse`。
- 切片 actors 176／177、formula_program.py MODULE_FORMULAS。
- 参照探针：`battle_common_event_probe.cjs`（recast 5 例，releaseUnequippableItems 在实例上停掉）、`tusu_battle_probe.cjs`（每例还原法宝原件再同步）。
- 测试：`xiyou_tusu_battle` 去掉 TusuActor、`xiyou_wtype` 登记 XBinding 战斗、`xiyou_battle_common_events` 加 _recast。

## 本分支提交

- 7fe61181 合并 cc/bailong-tusu1；cf0c38b8 切片 176／177、MODULE_FORMULAS；b4d9fa45 投石问路、猛击；044fdfc9 script_gaps 调整；44f62a7f 审查 21 期 P3①④；be23a37f events3 收工
- caae48a4 S2-1-02 参照用例（修正本身已随 main 进来，`mv_script.gd` `_actor_loop` 去 if(actor)）；59698eb7、9af4a8eb 176／177 进切片后的选测修补
- events3c：1f7f5cc8 合 main；4535b346 XTusu.damage、去钉；057d20bb 套装再放一次参照；215af056 解释器与 313 clearResult；21dade59 屠苏能力值（三法宝 4047／4048、探针还原原件）；5caa20c9 wtype 测试；交付单（本提交）

可合并。
