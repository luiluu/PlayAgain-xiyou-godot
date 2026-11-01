# 交付：cc/wukong-events1

- 车道／工作者：悟空（cc），地图事件解释器剩余缺口（第一期：普查＋第一批）
- 基线：从 `cc/wukong-reach-air4` 末端 8c69aacb 切出；交付前合 main（86faf296，main 到 22238e0b3），补齐后在本树跑 `同步正式西游.py --accept-additions`（只多 script_gaps.json 一份新参照，其余 87 份与 main 相同）。
- 状态：可合并

## 一、真实清单（进度账那几条已经过时）

- `内容覆盖检查.py`：7009 页全部可运行，未翻译指令 0、条件分支认不出的条件类型 0、基线 issues 空。进度账写的「静态覆盖 2 项已知未翻译、条件类型 9／10 共 9 处」都已做完（9／10 在 `_condition`，载具图像 323 也已做）；「电影」261 仍是有意的无操作（Godot 放不了 WebM，只缺 CE1514／1516 两段宇智波鼬画面）。
- 内容覆盖只看指令码，看不出**脚本写法**认不认得。本期新加普查场景 `tests/xiyou_script_census`：把切片地图事件页与全部公共事件里的脚本（355＋655）、插件指令（356）、脚本条件（111 类型 12）、变量操作的脚本／游戏数据操作数（122 操作数 4／3）按写法去重，共 **3799 种**，逐种交给解释器同一入口跑，看会不会记进 skipped（运行时就是照原文跳过）。
- 认不出 **142 种**，本期补了 6 种，剩 **136 种**，按「怎么到这里」分类（调用来源是静态扫 117 调用、物品／技能效果 44、切片敌群事件）：

| 分类 | 种数 | 说明 |
| --- | --- | --- |
| A 原版语法错误 | 45 | `node` 编译不过（多是 toaster 少引号／括号）；YEP_CoreEngine command355 try/catch 吞掉，原版也什么都不做，重制跳过＝一致，**不用做** |
| B 手机端按键与云存档 | 18 | MobileUI、HWGOE 云存档（Map072 EV002 调 CE249、并行 CE430）；Mac 版没有，**不做**（要做是另一个功能决定） |
| C 地图事件，玩家看得到 | 2（原 8） | 剩大厅「奇怪的老妪」EV005／006 头顶 10 分钟倒计时（`StarGetRefLAM45Time` setInterval 往事件名字条上画字） |
| D 物品使用或地图事件调用的公共事件 | 9 | 鲲拳 CE1160～（物品 1675 等；第二段脚本只按变量 348 取人）、CE1391 回收魂灯、CE373 补签、CE173 捕获网（地图里用）、洪荒入口 CE1442／1445（大厅 EV041，难度 8 的诅咒自选与压制） |
| E 技能／敌群触发，战斗里跑 | 30 | 战斗事件解释器 XBattleEventRunner 另有一套脚本处理，这次按地图解释器跑，**结果不作准**，要在战斗里另普查 |
| F 静态找不到调用 | 32 | 菜单插件入口（CE6 签到板、CE429 状态图鉴）、装备栏 itemslot、CE988 品质筛选、CE1373／1375 等；要先查插件菜单有没有指向它们 |

完整清单（含位置）见文末「附：剩余清单」，现状存进 `tests/fixtures/script_census_known.json`（键＝写法，值＝分类）：新出现认不出的写法、或清单里已经认得的，普查场景都会挂，补一条删一条。

## 二、第一批（玩家看得到、地图上就能碰到）

| 写法 | 位置 | 做法 | 参照 |
| --- | --- | --- | --- |
| `$gamePlayer._moveSpeed = 3／4／5` | 大厅小盖盖 Map004 EV044「正常／快／极快」 | 新存档字段 `XState.player_move_speed`（默认 4，存档键 playerMoveSpeed，旧档按 4）；`MVPlayer.walk_speed()`＝它＋冲刺 1（realMoveSpeed）；挂机走路同；下载具回 4（getOffVehicle setMoveSpeed(4)） | `script_gaps_probe` moveSpeed.3／4／5：_moveSpeed、走、冲刺、存读档后 |
| `$gameSystem.defeatNumber(66) >= 999／9999` | 戴律茂 Map017 EV004 牛头人／纯爱战士认证 | `MVScript.eval_expr` 认 `defeats(N)`＝`XEnemyBook.defeat_number` | defeat.* 七例（0／998／999／9998／9999）真跑条件分支 |
| `DataManager.cleanupIndependentItems()` | 大厅猫哥 Map004 EV024「清理存档」 | 无操作（重制只存持有的装备实例，没有可清的） | 读 YEP_ItemCore 原意 |

改的游戏代码：`map/mv_script.gd`、`core/xstate.gd`（只加字段与存读档键）、`map/mv_player.gd`、`map/map_scene.gd`（下载具、挂机两处速度）。

注意：重制里移动路线指令 29 给玩家改的速度仍只管当次路线（之前就这样），没跟原版一样常驻；没碰。

## 变更记录草稿

## 2026-11-01 【cc·悟空·未经审查】事件脚本普查与第一批：大厅调速、击败数认证（dev.待定）

- 新普查场景 `tests/xiyou_script_census`：切片 3799 种脚本／插件／脚本条件写法，认不出 142 种，按调用来源分 A～F 六类（45 种是原版本身语法错误）；补了 6 种后剩 136 种，现状清单 `tests/fixtures/script_census_known.json`。
- 大厅小盖盖调移动速度生效：`XState.player_move_speed` 随存档，走路速度＝它＋冲刺；下载具回 4。
- 戴律茂牛头人／纯爱战士认证按怪物图鉴击败数判断（原来脚本条件认不出、一律失败）。
- 猫哥「清理存档」不再记认不出（无操作）。
- 参照 `mv_oracle/script_gaps_probe.cjs`（generated/oracle/script_gaps.json），专项 `tests/xiyou_script_gaps`。

## 验证

- 新专项 `xiyou_script_gaps` 17/17：调速三例与参照逐项一致（_moveSpeed、走、冲刺、存读档后），旧存档没有字段按 4；击败数七例分支与参照一致；真事件页 Map017 EV004 选「认证 牛头人」：999 只开称号 5、成就 121，998 只都不开；清理存档无操作、装备不变。
- 反向：`$gamePlayer._moveSpeed = $gameVariables.value(1)`、`$gameTroop.defeatNumber(66)` 仍记认不出（断言）。
- 普查 `xiyou_script_census` 3/3（3799 种、认不出 136 种，与清单一致；新出现或已认得都会挂）。
- 选测（合 main、同步后）：`xiyou_script` 26/26、`xiyou_event_compare` 5/5、`xiyou_map` 413/413、`xiyou_hangup` 31/31、`xiyou_hangup_auto` 232/232、`xiyou_hangup_options` 57/57、`xiyou_autosave` 10/10、`xiyou_designation` 24/24、`xiyou_enemy_book` 95/95、`xiyou_airship_state` 36/36、`xiyou_airship_fly` 245/245。
- 同步 `--accept-additions`：只多 script_gaps.json（新增参照，不登记），其余参照与 main 相同；`语法检查.py` 通过。
- 选测没跑全：`选测.py main` 按 mv_script／map_scene／xstate 列了 200 多个场景（地图解释器与存档类全组），本期只挑了用到改动的；楼层专项全组留给总装合并后按影响面跑。

## 交接板

- 下一步：事件脚本第二批——D 类鲲拳等物品脚本、C 类老妪倒计时；E 类在战斗解释器里另普查；F 类先查菜单插件入口。
- 用户试玩说明：大厅小盖盖（大厅上方）选「快／极快」后走路明显变快、存档读档后保持；戴律茂（Map017）击败 999 只牛头人后能认证。
- 需要用户决定：无（B 类云存档／手机按键默认不做）。

## 进度账

- 地图事件解释器：静态覆盖 0 缺口；脚本写法 3799 种里认不出 136 种（45 种原版也不执行、18 种 Mac 没有）。

## 可优化（流程／工具／效率）

- 普查场景只跑地图解释器；E 类要一个战斗版普查（XBattleEventRunner 的 355 先走它自己的几种写法），建议下一期做。
- 普查里只 CE 的调用来源是静态扫的，插件菜单（YEP_MainMenuManager 等）调的公共事件没算进去，F 类可能有菜单入口。

## 本分支提交

- WIP：普查场景
- WIP：第一批、参照探针、专项
- 86faf296 合并 main
- 交付单（本提交）

## 附：剩余清单

### A 原版语法错误（YEP command355 吞掉报错，原版也什么都不做）：45 种

出现在：CE859×40、Map004×4、CE860×4、Map195×2、Map145×1、CE513×1、CE817×1。多是 toaster 引号或括号没配对。


### B 手机端按键与云存档（Mac 版没有）：18 种

| 写法（前 60 字） | 出现位置 | 怎么到这里 |
| --- | --- | --- |
| script：`HWGOE.save.cloudSaveGame(HWGOE.save.latestSavefileId());` | CE249 | Map072/EV002 |
| script：`HWGOE.save.cloudSaveGame(1);` | CE249 | Map072/EV002 |
| cond：`HWGOE.save.saveStatus() === -1` | CE430 | 自动/并行触发 |
| cond：`HWGOE.save.saveStatus() === 0` | CE430 | 自动/并行触发 |
| plugin：`MobileUI hide DPad` | CE7 | 静态找不到调用 |
| plugin：`MobileUI hide ok` | CE7 | 静态找不到调用 |
| plugin：`MobileUI hide fh` | CE7 | 静态找不到调用 |
| plugin：`MobileUI hide Control` | CE7 | 静态找不到调用 |

### C 地图事件里，玩家看得到：2 种

| 写法（前 60 字） | 出现位置 | 怎么到这里 |
| --- | --- | --- |
| script：`if(window.StarGetRefLAM45Time) clearInterval(window.StarGetR` | Map004/EV005/p1, Map004/EV006/p1 | Map004/EV005/p1; Map004/EV006/p1 |
| script：`window.StarGetRefLAM45Time = setInterval(function(){ if($gam` | Map004/EV005/p1, Map004/EV006/p1 | Map004/EV005/p1; Map004/EV006/p1 |

### D 物品使用或地图事件调用的公共事件，玩家看得到：9 种

| 写法（前 60 字） | 出现位置 | 怎么到这里 |
| --- | --- | --- |
| script：`var actor = $gameActors.actor($gameVariables.value(348));` | CE1160, CE1161, CE1162 等 | I1675; 静态找不到调用 |
| script：`for (var i = 2701; i < 2806; i++) { $gameParty.loseItem($dat` | CE1391 | CE1511←I2791 |
| script：`// 洪荒诅咒：15 种全列，自选 5 种（v0.5 S3） var arr=[1,2,3,4,5,6,7,8,9,10` | CE1442 | Map004/EV041 |
| script：`var t=$gameTemp,p=t._hhCursePicked,left=t._hhCurseOffer.filt` | CE1442, CE1442, CE1442 等 | Map004/EV041 |
| script：`var p=$gameTemp._hhCursePicked;for(var k=0;k<5;k++)$gameVari` | CE1442 | Map004/EV041 |
| script：`for(var j=1;j<$dataActors.length;j++){if($dataActors[j].name` | CE1442, CE1442, CE1442 等 | Map004/EV041 |
| script：`// 洪荒压制（2026-10-07 方案B）：全员学会带 <CodexHonghuangSuppress> 标签的被动` | CE1445 | Map004/EV041 |
| script：`Star.PetSystem.PetGet()` | CE173 | I200 |
| script：`Star.SignBoard.ConductItemMakeUpSign(true); ` | CE373 | I632 |

### E 技能／敌群触发，战斗里跑（战斗事件另有一套脚本翻译，这次按地图解释器跑，不作准，另核）：30 种

| 写法（前 60 字） | 出现位置 | 怎么到这里 |
| --- | --- | --- |
| script：`for(let i = 1; i < 30; i++) { var actor = $gameActors.actor(` | CE100, CE100, CE100 | S206 |
| script：`var actor1 = $gameActors.actor(82); actor1.addState(896);` | CE1094 | S4941 |
| var：`{"code":122.0,"indent":0.0,"parameters":[318.0,318.0,0.0,3.0` | CE110, CE124, CE423 | S824; 静态找不到调用 |
| script：`var actor = $gameActors.actor($gameVariables.value(348)); ac` | CE1313 | S6127 |
| script：`var actor = window.CodexFreezeFollowup && CodexFreezeFollowu` | CE1321 | S6171 |
| script：`var actor = $gameActors.actor($gameParty._targetActorId); if` | CE1327 | S6181 |
| script：`var actor = $gameActors.actor($gameVariables.value(881)); if` | CE1354 | S6229 |
| script：`var actor = $gameActors.actor($gameVariables.value(884)); if` | CE1370 | S2826 |
| script：`// 获取上阵的四个角色对象 var actor1 = $gameParty.battleMembers()[0]; v` | CE1393 | T794 |
| script：`for(let i = 1; i < 999; i++) { var actor = $gameActors.actor` | CE17, CE18, CE72 等 | S785; S939 |
| var：`{"code":122.0,"indent":0.0,"parameters":[1341.0,1341.0,0.0,3` | CE2486 | S7188 |
| script：`for (var i = 0; i < $gameTroop.members().length; i++) {     ` | CE2486 | S7188 |
| script：`var actor1 = $gameActors.actor(13); var actor2 = $gameActors` | CE43, CE236, CE904 等 | S521; S73 |
| script：`for(let i = 1; i < 30; i++) { var actor = $gameActors.actor(` | CE78 | S459 |
| script：`CodexTusu.openForge();` | CE9014 | S10332 |
| script：`CodexXuan.openStarchart();` | CE9015 | S10349 |
| script：`var actor1 = $gameActors.actor(14); var actor2 = $gameActors` | CE92 | S543 |

### F 静态找不到调用（菜单插件入口或没用到）：32 种

| 写法（前 60 字） | 出现位置 | 怎么到这里 |
| --- | --- | --- |
| script：`var actor = $gameActors.actor(12); for(var i=2807;i<2814;i++` | CE1373 | 静态找不到调用 |
| script：`// 定义一个数组，存储半人马角色的id var invalidActorIds = [41, 42, 43, 44];` | CE1375 | 静态找不到调用 |
| script：`if(!Star.PetSystem.STimeRefGTE){   Star.PetSystem.isrefreshG` | CE232 | 静态找不到调用 |
| script：`if ($gameParty.GTWar && $gameParty.GTWar.level < 50){   var ` | CE241, CE242, CE243 | 静态找不到调用; 静态找不到调用 |
| script：`Star.SignBoard.ConductItemMakeUpSign(true);` | CE330 | 静态找不到调用 |
| script：`SceneManager.push(Scene_StateBook) ` | CE429 | 静态找不到调用 |
| script：`$gameParty.openItemSlotMenu();` | CE478 | 静态找不到调用 |
| plugin：`itemslot show` | CE485 | 静态找不到调用 |
| plugin：`itemslot hide` | CE485 | 静态找不到调用 |
| plugin：`pingbizhuangbei` | CE486 | 静态找不到调用 |
| script：`SceneManager.push(Scene_StarSignBoard)` | CE6 | 静态找不到调用 |
| script：`if(window.StarGetRefLAM101Time) clearInterval(window.StarGet` | CE817 | 静态找不到调用 |
| var：`{"code":122.0,"indent":0.0,"parameters":[687.0,687.0,0.0,3.0` | CE947 | 静态找不到调用 |
| script：`var arr = $gameParty.weapons(); for(var i=0;i<984;i++){ if(a` | CE988 | 静态找不到调用 |
| script：`var arr = $gameParty.armors(); for(var i=0;i<870;i++){ if(ar` | CE988 | 静态找不到调用 |
