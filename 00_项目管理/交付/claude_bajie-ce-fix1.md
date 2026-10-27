# 交付：claude/bajie-ce-fix1

- 车道／工作者：C 规则·解释器／八戒（Claude，八戒_78）
- 状态：进行中

## 变更记录草稿

## 2026-10-27 【Claude·八戒·未经Codex检验】效果型公共事件脚本补翻译：选中角色技能书、藏宝图、超强者招募、CE367 更衣、指令 323／261（dev.待定）

接悟空期十二（claude/wukong-pending1）登记的 113 个公共事件不一致：本期消掉 95 个，事件对照登记只剩 18 项（2 项老的 m4e73p0、m189e1p0；专属角色号角 CE9002～9018 共 13 个留下一期；「其他」里的 765、823、824）。

- **新原版探针 `mv_oracle/common_script_probe.cjs` → `generated/oracle/common_scripts.json`（428 例）＋专项 `tests/xiyou_common_scripts`**：事件对照只能在「没有选中角色、玩家在大厅 0,0」下跑这些公共事件，脚本多半第一行就出错。新探针给出真实使用时的前提（选中角色及其已学技能、变量、开关、物品、所在格、预掷池、已挖宝点、更衣解锁表、随机数），用正式 Game_Interpreter 跑同一公共事件，记提示／场景／选项、关心的变量和物品数、选中角色技能、队伍、预约公共事件、预掷池用量、已挖宝点、更衣解锁。Godot 侧以同样前提跑 MVInterpreter 逐项比较，428 例全一致。已加进 `同步正式西游.py` PROBES 与 `oracle_additions.py`。
- **选中角色的技能脚本**（`MVScript._target_actor_script`，元素转换 CE637～644、小药丸 645～648、技能书／心法／鲲拳／换装卡等共 90 来个读 `$gameParty._targetActorId` 的公共事件）：翻译 `var j = $gameParty._targetActorId`、`for (var i = A; i < B; i++)`、`if (actor.hasSkill(x) [& …]) {…} else {…}`、`break`、`$gameVariables.setValue(N, j)` 等这一族写法；选中角色取 `XState.item_target_actor_id`（物品界面选人时已设）。先整段检查写法、认得才执行，不会执行一半再交给通用翻译。没有选中角色时照原版：读 null 的 actor 抛错、YEP command355 吞掉，本段其余语句不执行。`_actor_by_variable` 补 `actor.removeState(N)`（心法 CE1003～1018）；`$.toaster` 拼字补 `$gameActors.actor($gameVariables.value(N)).name()` 与 `$dataSkills[N].name`。
- **遗忘河之水 CE83**（`Star.RunForgetSkill()` → Star_Scene_ForgetSkill）：新 `XForgetSkillScene`，列选中角色已学的技能类型 1／2／5 技能，确定在「未遗忘／已遗忘」间切换（遗忘／重新学会），取消关闭；地图宿主 `open_forget_skill`。外观暂用通用选择窗，原版是居中 400 宽命令窗（见遗留）。
- **藏宝图**（`XTreasureMap`，CE117、174～189、1381～1384 的 `Star.RomGetItems.RunGetFun(a,b)`）：照冻结源 Star_RomGetItems——预掷池长度不是 20 或已用超过 15 就重掷 20 个；a～b 里找第一个本轮没挖过的宝点，站在那一格就「挖宝成功」并按 `RomGet[RomGetNum] % 80` 发物品／防具／武器／预约公共事件（先扣藏宝图，候选为空时还回并提示失败），否则提示当前与目标的地图名和坐标；一轮挖完全部清掉重来。挖过的宝点记 `XState.rom.m`（随存档，旧档没有为空）。
- **超强者招募 CE2501～2526**：翻译 `if (!$gameParty.hasItem($dataXxx[n], true)) $gameParty.gainItem(…)`（背包或队员身上有就不给）；指令 129 被「超强者仅限地狱及以上难度获取。」挡下时提示改走解释器（地图宿主 `toast`），与原版事件里的顺序一致（`XState.add_actor` 加可选的提示去处）。另补 installImportedBalanceRuntime 的停用角色：143～145、157、160 的 addActor 直接不入队（超强者检查在外层，先提示）。
- **CE367 牛头人酋长**：更衣写法 `if(indexOf(-33)==-1){push(-12)}` 判断号与写入号不同，照原文：-33 不在表里才解锁 -12；`xiyou_reward_branches` 的 `KNOWN_CLOTHES_GAPS` 清空。
- **指令 261 播放电影、323 更改载具图像**：MVEventCore 空实现（WebM 影片 Godot 不能放；重制没有载具，只影响飞艇外观）。内容覆盖基线删 14 项（`未翻译|CE0487～0498、0500|指令 323`、`未翻译|CE1516|指令 261`）。
- 事件对照替身：玩家位置照参照放在事件所在格（公共事件在 0,0），补 `open_forget_skill` 记录。

## 交接板

- 下一步：事件对照登记剩 18 项——专属角色号角 CE9002～9018（接 `_module_recruit`，下一期）；CE765、823、824 逐个看；m4e73p0、m189e1p0 照旧。
- 用户试玩说明：元素转换、小药丸、心法、技能书等「对选中角色」的物品现在照原版生效；遗忘河之水能打开遗忘界面；藏宝图会提示坐标、站到点上能挖宝；超强者号角在地狱以下提示后不入队（装备照给）；牛头人合剂解锁对应形象。
- 需要用户决定：无。

## 进度账

- 无变化（没有新地图）。

## 验证

- `xiyou_common_scripts` 430/430（新专项，428 例原版对照；改前 61 例不一致，见本分支 WIP 提交说明）。
- `xiyou_event_compare` 5/5，5753 例一致 5735，不一致 18 全在登记（`--update-baseline` 删 95 项，无退步）。
- `内容覆盖检查.py --check` 新增 0、删 14（`--update-baseline`）。
- 其余专项：见下一节补写。

## 遗留

- 遗忘界面外观未做界面对照（原版 Window_Command 400 宽居中、右侧「未遗忘／已遗忘」），归界面车道。
- 播放电影两段（CE1514「血轮眼开」、CE1516「幻术世界」）不播放，要播得先把 WebM 转 Theora（.ogv），只影响画面。
- CE1561 迎天劫（全体学技能后接演出）没进新探针（帧上限内跑不完），走原来的全体角色写法。

## 可优化（流程／工具／效率）

- 已做：`common_script_probe` 照 event_probe 的 NEW_GAME_SNAPSHOT 只真开一局、之后换回开局对象，单跑 5 分钟→1 分 20 秒，产物与每例真开局逐字节相同（回退：`freshGame` 里改回直接 `newGame()`）。

## 本分支提交

- 见 `git log main..HEAD`
