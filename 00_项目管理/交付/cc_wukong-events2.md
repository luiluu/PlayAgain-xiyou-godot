# 交付：cc/wukong-events2

- 车道／工作者：悟空（cc），事件脚本第二批（D、C 类＋战斗版普查＋审查 19 P3①）
- 基线：从 `cc/wukong-events1` 末端 591e70e7 切出（带 events1、air4）；交付前合 main（aa4cc652，main 到 5692e099；main 改了 mv_script.gd 的小猫试炼，自动合并无冲突），补齐后本树跑 `同步正式西游.py --accept-additions`。
- 状态：可合并

## 本期

### 审查 19 期 P3①：reach115 大菠萝发奖

`tests/xiyou_floor_reach115.gd`：战斗一结束（掉落已进包、事件发奖之前）在 finished 回调里先数一次，自身掉落＝结束时−战前（0 或 1），事件发奖＝跑完−结束时，**必须正好 1**；三支（rare3、normal5、rare7）都这样核。原来 normal5 按「多 0～1」区间断言，发奖漏发会被大菠萝自身掉的 2855 盖住。

### D 类（物品／地图调用的公共事件）

| 写法 | 位置 | 做法 | 参照（script_gaps） |
| --- | --- | --- | --- |
| `for (var i = A; i < B; i++) { $gameParty.loseItem($dataItems[i], n, true); }` | CE1391 失去剩余伙伴号角（用鼬号角 CE1511 时调） | MVScript 整段认：逐个扣 n（不够扣到 0） | loseHorns：2700／2806 不动、范围内扣 |
| `var actor = $gameActors.actor($gameVariables.value(N));` 后跟 learnSkill／forgetSkill／removeState 和读同一变量角色名的 `$.toaster` | CE1313 六灭秘本（四支）、鲲拳 CE1160～1185 每支开头 | `_actor_by_variable` 认 toaster；只有一句声明的段＝无操作；变量里没有角色时整段不做（原版读 null 抛错、YEP 吞掉） | actorVar.learn.1／.0、actorVar.declareOnly |

剩下的 D 类 7 种不是翻译能补的：洪荒入口 CE1442／1445（大厅 EV041，难度 8 的诅咒自选、压制被动，5 种）是没移植的洪荒功能；补签信 CE373 `Star.SignBoard.ConductItemMakeUpSign`（签到板没移植）；捕获网 CE173 物品只能战斗里用，战斗解释器已认（XPetCapture）。

### C 类（地图事件）

大厅奇怪的老妪 Map004 EV005／006、CE817 的 `StarGetRefLAM*Time` 计时器：Star_LotteryAnimation 只把**备注以 LotteryAnimation 开头**的事件名字条加进画面，正式版一个这样的事件都没有（冻结源全图搜过），倒计时画在看不见的位图上；MVScript 认作无操作（只认整段只读计时器、名字条、mapId、变量、游戏时间的；夹了改状态的写法仍记认不出）。

### E 类：战斗版普查

`xiyou_script_census` 加一遍：清单里分类 E 的写法再交给 `XBattleEventRunner`（技能／物品公共事件、敌群页在战斗里跑的那套）跑。**26 种里战斗里认得 16、真缺 10**（输出 CENSUS_BATTLE 行）：

| 真缺 | 位置 | 玩家看得到吗 |
| --- | --- | --- |
| `for(let i = 1; i < 999; i++) { var actor = $gameActors.actor(i); if(actor && … _states.includes … hasArmor …) { … forceAction }` | CE17／18／72／107（影杀）／116／121 等，36 处 | 是：套装触发的追加行动；要先查这些效果有没有在战斗逻辑里另做（不走 CE） |
| `for(let i = 1; i < 30; i++) { var actor = $gameActors.actor(i); if(actor._states…/!actor.is…` | CE78、CE100 | 是（技能 459、206） |
| `CodexFreezeFollowup.takeCaster()` | CE1321（技能 6171） | 是 |
| `var actor = $gameActors.actor($gameParty._targetActorId／$gameVariables.value(881／884)); if(actor.hasSkill(…` | CE1327、1354、1370 | 是（技能 6181、6229、2826） |
| `for (var i = 0; i < $gameTroop.members().length; i++) { $.toaster(…` | CE2486（技能 7188） | 是（提示） |
| `CodexTusu.openForge()`、`CodexXuan.openStarchart()` | CE9014／9015 | 屠苏、璇模块没移植 |

本期补的是原来也算在 E 类、战斗里也不认的一种（补完后算进上面「认得 16」）：**战斗里按角色号加／解状态**（`var a = $gameActors.actor(K); a.addState(S);`，CE43「PUA」给 13～15 加 708、CE92、CE1094 给 82 加 896～899）→ `XBattleEventRunner._actor_states_script`：在战斗里的走战斗加状态（抗性、倒下照 sequence_add_state），不在队的直接加在角色身上（参照 actorStates.inParty／notInParty：原版两种都加上）。

改的游戏代码：`map/mv_script.gd`、`battle/battle_event_runner.gd`。原版不合理处：无（这几处照原版做，没有回退开关）。

普查清单 `tests/fixtures/script_census_known.json` 减到 **127 种**（A 44、B 18、D 7、E 26、F 32）。

## 变更记录草稿

## 2026-11-01 【cc·悟空·未经审查】事件脚本第二批：伙伴号角清理、按变量学技能提示、战斗里按角色加状态；战斗版普查（dev.待定）

- 用鼬号角时失去其余伙伴号角（CE1391）照原版扣掉。
- 六灭秘本等「按变量取人学技能」的脚本带上角色名提示；鲲拳每支开头的声明段不再记认不出。
- 大厅老妪头顶倒计时：原版画在看不见的名字条上，按无操作。
- 战斗里 PUA 等「按角色号加状态」的公共事件生效（CE43、92、1094）。
- `tests/xiyou_script_census` 加战斗版：E 类 26 种里战斗里认得 16、真缺 10（清单见交付单）；清单剩 127 种。
- `tests/xiyou_floor_reach115`：大菠萝发奖先扣自身掉落再断言正好一件（审查 19 期 P3①）。
- 参照 `mv_oracle/script_gaps_probe.cjs` 加 6 例（共 16）。

## 验证

- 合 main 后、同步后选测 13 个场景全过（1302 秒）：`xiyou_script_gaps` 27/27、`xiyou_script_census` 3/3、`xiyou_script` 26/26、`xiyou_event_compare` 5/5、`xiyou_floor_reach115` 74/74、`xiyou_battle_common_events` 23/23、`xiyou_battle_common_event_child` 13/13、`xiyou_battle_events` 108/108、`xiyou_troop_events`（含 _b／_c／_d／_half）全过。
- 反向（断言）：声明后跟认不出的语句（`actor.gainExp`）整段仍认不出、不学；倒计时段夹了 `$gameVariables.setValue` 仍认不出；战斗按角色加状态段夹了 `a.gainHp` 仍记认不出。
- 同步 `--accept-additions` 退出 0；script_gaps 在本期多 6 例（loseHorns、actorVar ×3、actorStates ×2），同步提示本树与主工作区的 script_gaps 不同（主工作区是 events1 的 10 例），合并时按新增接受。
- `语法检查.py` 通过。没跑：楼层全组、`xiyou_map`（本期没动地图场景与存档字段）。

## 交接板

- 下一步：E 类真缺 10 种里能翻译的 8 种（另 2 种是屠苏、璇模块没移植）——先查影杀等套装追加行动有没有在战斗逻辑里另做，没做的按战斗解释器补；F 类先查菜单插件入口；洪荒、签到板是功能移植，不归事件翻译。
- 用户试玩说明：用「伙伴号角：鼬」后其余伙伴号角会被收走（照原版）；战斗里放 PUA（技能 73）后 13～15 都带上状态 708。
- 需要用户决定：无。

## 进度账

- 事件脚本写法：3799 种里认不出 127 种（44 种原版也不执行、18 种 Mac 没有、7 种是没移植的功能入口）。

## 可优化（流程／工具／效率）

- 普查的战斗版只拿清单里 E 类的写法跑；技能公共事件里地图解释器认得、战斗解释器不认的（反过来那种）没查，要的话把战斗版扩到全部技能触发的 CE。

## 本分支提交

- f63c3767 WIP：reach115、D／C 类
- ccff8612 WIP：战斗按角色加状态、战斗版普查
- aa4cc652 合并 main
- 交付单（本提交）
