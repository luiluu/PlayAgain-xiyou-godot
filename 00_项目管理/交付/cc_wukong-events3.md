# 交付：cc/wukong-events3

- 车道／工作者：悟空（cc），屠苏璇进切片（A 车道前置）＋战斗事件脚本第三批＋审查 21 期两条 P3
- 基线：从 `cc/wukong-events2` 末端 1a736398 切出（带 events2、events1、air4）；**合了 `cc/bailong-tusu1` 98484670**（白龙屠苏璇一期 XTusuXuan，还没进 main；本分支要合它，总装请先合 tusu1 或一起合）。没另合 main（events2 合过 5692e099）。本树跑过 `同步正式西游.py --accept-additions`。
- 状态：**未完（Kyo 14:33 周额度收工）**：代码与同步做完，选测跑到一半停下；沙僧二审 S2-1-02 没开始（接续要点见文末）

## 一、屠苏 176、璇 177 进切片（白龙 tusu1 的前置）

- `03_转换工具/xiyou_slice.json` actors 加 176、177（照 174／175）。同步新增参照：actor_passive、help_cards、wtype、slice_d1～d6 都多了两人的用例（新增已接受），script_gaps 见下。
- `03_转换工具/formula_program.py` MODULE_FORMULAS 加 `CodexTusu.damage(a,b,'键')`（10312～10325 十个）→ tusu、`CodexXuan.damage(a,b,'lengguang')`／`CodexXuan.heal(a,b)` → xuan。**求值没接**：`XFormulaExecution._run_item` 不认 tusu／xuan，照旧按 unsupported_program 不可用（跟进切片前一样），等白龙屠苏三期、璇六期接上模块公式。
- help_card dyn2：`character_help._dyn2_view` 对 id＞10287 本来就不改写（两人的技能都在 10312 以上），说明卡按原文；help_card 选测见验证。

## 二、E 类（战斗里跑的脚本）

先查了**影杀等「套装再放一次」**：`for(let i = 1; i < 999; i++){ var actor = $gameActors.actor(i); if(actor && !actor.isDeathStateAffected() && actor._states.includes(345) && actor.hasArmor(…)…) { new Game_Action → setSkill(N) → decideRandomTarget → actor._actions.splice(1,0,action) → BattleManager.forceAction(actor) } }`，共 **34 个公共事件**（CE17 水流、18 锋芒、72～76、88、107 影杀、116、121～123、126、128～130、161、251～255、325、390、512、581、628～631、976～978），技能把状态 345 加给使用者、公共事件找带 345 且穿着套装的人追加一次技能、最后 313 解除 345。**战斗逻辑里没有另做**（全工程没有 345 的处理），是真缺。CE1327／1354／1370 也是同一套 splice＋forceAction。原版的强制行动细节（splice 到第 2 个行动、forceAction 只记最后一个、checkBattleEnd、随机目标）要先做参照探针再补，**本期没做，留下一期**。

本期补了两种（战斗事件解释器 `battle/battle_event_runner.gd`）：

| 写法 | 位置 | 做法 | 参照（script_gaps） |
| --- | --- | --- | --- |
| `for (var i = 0; i < $gameTroop.members().length; i++) { $.toaster({ message: (i+1)+'号敌人暴闪为' + …cev.toFixed(2)*100 + '%!' }); }` | 投石问路 CE2486（技能 7188） | `_troop_cev_script`：每个敌人一条提示，toFixed(2) 再 ×100 照 JS 数字转字符串 | troopCev（敌群 53：「1号敌人暴闪为5%!」） |
| `for(let i = 1; i < N; i++){ var actor = $gameActors.actor(i); if(actor._states.includes(S) && actor.hasArmor($dataArmors[A])){ …members[i].addState(T); } }` | 猛击 CE78（技能 459） | `_set_armor_troop_state_script`：有人带 S 且穿着 A 就给全体敌人加 T（倒下的加不上） | setArmorState.wear／bare（原版 506 新局穿不上：两边都直接当作穿着） |

剩下 E 类真缺：上面的套装再放一次一族（34＋3）、CE100（技能 206）、CE1321 `CodexFreezeFollowup`（技能 6171）、CE9014／9015 屠苏器谱、璇星谱（模块没移植）。

## 三、审查 21 期插单

- **P3① 猫哥清理存档**：原版在 `js/plugins/zchuli.js`（不是 YEP_ItemCore）：把在队成员身上与背包里的独立装备重编号、其余独立装备条目丢掉（仓库里存的旧编号失效），最后 `updateActorEquips` 给在队成员 `gainHp(mhp)`、`gainMp(mmp)`、`refresh`（倒下的也救起）。重制 `MVScript._cleanup_independent`：回满照做（参照 cleanupHeal：四人全满、8 号倒下也救起）；重编号没有可做的（重制存实例）；**仓库里的武器防具**做成回退开关 `MVScript.o_cleanup_keep_warehouse`（默认 true 留着；false＝照原版按丢掉处理，道具不动），见优化登记草稿。
- **P3④ 普查去重**：`xiyou_script_census` 改成按「种类|完整原文」去重：**4230 种、认不出 182 种**（原按前 80 字是 3799／127）。新清单 `tests/fixtures/script_census_known.json`：原来前 80 字相同的 179 种照原分类，另 3 种真被藏住的（CE1388～1390「极尽升华」：`for (var j = 1; j < $dataActors.length; j++){ … hasSkill(A) → forgetSkill(A)、learnSkill(B) }`，静态找不到调用）归 F。分类计数：A 44、B 18、D 21、E 62、F 37。

## 优化登记草稿

| O-待定 | 猫哥清理存档时仓库里的武器防具（`map/mv_script.gd` `_cleanup_independent`，zchuli.js cleanupIndependentItems） | 原版只给身上与背包的独立装备重编号，仓库（PHWarehouse）里记的旧编号失效：存着的武器防具丢掉或变成别的装备；NPC 自己也提示先取出来 | 重制存的是装备实例，不会失效，仓库里的照旧留着 | 原版的清理是为了解决数组过长卡顿，丢仓库装备是副作用，不是本意 | `MVScript.o_cleanup_keep_warehouse = false`（按全部丢掉近似原版；原版里落在新编号范围内的会变成别的装备，这点不重现） | cc（悟空） | 待用户确认 |

## 变更记录草稿

## 2026-11-01 【cc·悟空·未经审查】屠苏璇进切片；战斗事件投石问路、猛击；猫哥清理存档回满（dev.待定）

- 切片 actors 加 176 屠苏、177 璇；两人的伤害／治疗公式登记为模块公式（求值等后续）。
- 战斗里投石问路（CE2486）给出每个敌人的暴闪提示；猛击（CE78）这类「带标记且穿着套装就给全体敌人加状态」生效。
- 大厅猫哥「清理存档」照原版给在队成员回满生命、魔法（倒下的也救起）；仓库里的武器防具默认留着（O-待定，可回退成照原版丢掉）。
- 事件脚本普查改按完整写法去重：4230 种、认不出 182 种。
- 参照 `mv_oracle/script_gaps_probe.cjs` 加 4 例（共 20）。

## 验证

- 已过：`xiyou_script_gaps`（含本期 4 例与清理存档两档开关）、`xiyou_script_census`（全文去重后 4230／182）；`回退开关覆盖.py` 新开关已覆盖；`语法检查.py` 通过。
- 同步 `--accept-additions` 退出 0（新增：actor_passive、help_cards、wtype、slice_d1～d6 的 176／177 用例，script_gaps 20 例）。
- **没跑完**：收工时选测（script、event_compare、battle_events、battle_common_events、troop_events 五段、help_card、actor_p0、determinism、wtype、tusu、actor_modules、xiyou_rules 全难度，共 42 个）在跑，完成 6/42 时停手；日志在 `04_验证/本地结果/并行测试/` 最新一个目录（任务在后台跑完会写全）。接手先看那份结果，没跑完的重跑。

## 交接板

- 下一步：E 类「套装再放一次」一族（37 个公共事件）：先做强制行动参照探针（splice＋forceAction），再在战斗事件解释器补；屠苏璇公式求值等白龙。
- 用户试玩说明：猫哥「清理存档」后在队成员回满；战斗里用投石问路会弹出每个敌人的暴闪。
- 需要用户决定：O-待定 猫哥清理存档时仓库装备（默认留着）。

## 进度账

- 事件脚本写法（按全文）：4230 种里认不出 182 种。
- 角色：切片 actors 加 176、177（机制按白龙的分期）。

## 可优化（流程／工具／效率）

- 普查的 KNOWN 清单键现在是完整原文，有的很长；以后可以改成「规范化全文的哈希＋前 80 字」方便看 diff。

## 待交叉核查

- `battle/battle_event_runner.gd`：`_troop_cev_script`、`_set_armor_troop_state_script`（共用战斗解释器）。
- `map/mv_script.gd`：`_cleanup_independent`、`o_cleanup_keep_warehouse`。
- 切片 actors 176／177、formula_program.py MODULE_FORMULAS。

## 本分支提交

- 7fe61181 合并 cc/bailong-tusu1（98484670）
- WIP：切片 176／177、MODULE_FORMULAS
- WIP：投石问路、猛击
- WIP：script_gaps 调整
- WIP：审查 21 期 P3①④
- 交付单（本提交）

## 接续要点（下一位悟空）

1. 先看选测结果（上面「验证」），有挂的先修，尤其 xiyou_rules／help_card／wtype（切片加了 176／177）。
2. **沙僧二审 S2-1-02（P2，Kyo 同意修）还没做**：CE1431／1432 的 `for (var j = 1; j < 999; j++){ var actor = $gameActors.actor(j); if(actor)actor.learnSkill(8101); }` 被 `mv_script.gd` `_actor_loop` 的 `\b(if|else)\b` 检查拒掉，退回逐个直接学、不写 actor_ops，`casino_batch.gd` 第 125 行按 actor_ops 增量数 hit_proof，达标次数恒为 0。已查：全工程这种写法只有 CE1431／1432 六处（8101、8102、8091 各两处），所以可以让 `_actor_loop` 先去掉紧跟 `actor.` 之前的 `if(actor)`（原版 actor(j) 为 null 只在没有该角色数据时，add_actor_op 本来就只对有数据的角色）。参照：`mv_oracle/casino_batch_probe.cjs` specs 加一例 Math.random 固定 0.99（五次单抽，原版达标 4 次、新获证明为真），case 里 newGame 后 `w.eval('Math.random=function(){return 0.99;}')`；Godot 侧 `tests/xiyou_casino_batch.gd` 第 33 行固定 0.5，要按用例的 random 字段设 `MVEventCore.fixed_random`。产物手工复制到 `tests/fixtures/casino_batch_oracle.json`（这个探针不进同步）。选测带 xiyou_casino_batch、xiyou_script、xiyou_event_compare。
3. 套装再放一次一族（见二）留给之后。
