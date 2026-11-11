# 交付：cc/review-78

- 状态：可合并
- 车道／工作者：cc（审查，项目线程）

只有文档，没有游戏代码。分支从本地 main ede094cb6 切（`cc/review-77` 是 11-10 21:17 建的空分支、工作树 elated-hellman-886e43 干净无提交，没动它，本期编 78）。只读核，没跑 Godot、没占测试槽；对照 `冻结正式源/v0.62.12`（运行时、`main.js` 装入顺序、Map001 数据）。

## 变更记录草稿

## 2026-11-11 【cc·审查】核查待核查甲档 25 批（审查第 78 期）

- 核查覆盖：cc/rules-mira-raven2、cc/chars-gaps2、cc/chars-gaps3、cc/ui-pixel4、cc/review95-fixes、cc/events-map-m5、cc/distracted-snyder-c6c899、cc/objective-ishizaka-ab3bef、cc/floor-ichigo-cut1、cc/intro-anim-v8、claude/objective-mayer-333ac4、claude/project-thread-d4k4ag（第一、二批）、claude/project-thread-pwq2i3、claude/project-thread-fxqj11、claude/project-thread-z0d29k、cc/update-spike0、cc/update-check1、cc/update-release1、cc/update-install1、cc/update-android-net1（甲）。
- 核查覆盖：总装提交 e226261、04c12dd、1796e05、253f184（甲，文档与规则为主）。
- 甲档结论：P1／P2 无，P3 5 条（见下）。各批开关都在、默认值与优化登记一致，回退路径读码可走通。
  - mira-raven2：itemHit／itemEva／itemCri 三个包装逐行对 `installMiraRavenNumberBoostRuntime.js`（owner 判定、只去闪避与未命中、渡鸦非归属动作压魂海暴击）通过；装入顺序对 `main.js`（数值池先装＝在甚尔里面）通过。外层还读 xparam(2) 的只有 installCritFloor，已登记 O-272。340 中止对 MV `BattleManager.updateEvent`（aborting 阶段只走 checkAbort）、`checkBattleEnd`（checkAbort 恒返回 false 后接着判全灭／全歼）、`updateBattleEnd`（_escaped 时 pop、不复活）逐支通过；`last_battle_escaped` 在 301 与随机遇敌两处都接了。智能 AI 霸体两处（不估控制状态、不估解除 2651）通过；`state_kind` 缓存只缓存数据库原条，破阵视图现算，通过。
  - chars-gaps2：dyn2 的镜流 170、宿傩 10242、云裳 174 三段逐行对 `installDisplayPreferencesRuntime.js` 551～578 行（含 `offensiveGrowth`：n＝min(99,lv)−24、1.88n／0.1888n）通过；listCosts 按卡所在场景判，同原版 `SceneManager._scene instanceof Scene_Battle／Scene_Skill`，通过。
  - chars-gaps3：skills()／meetsSkillConditions 过滤与开战同步对 `installNativeSkillProgressionRuntime.js` 40～53 行通过（顺序见 P3-2）；没招募角色的说明卡用不入档的初始角色（同 `XState.actor` 的建法、照套 actor_ops），通过；谷雨 isValid 不接的理由（OTB 强制、角色不经 processTurn）同审查 76 的核实，通过。
  - ui-pixel4：场所移动淡出类型对 `Scene_Map.fadeOutForTransfer`（0 黑、1 白、2 不淡出）与 fadeSpeed 24 帧通过；白幕之后的黑幕颜色在下一次 transfer_fade 与开场 2002 行都会重设，通过。状态详情只在等指令时开、开时指令窗失活，O-256 已登记。星级仓库漂移回退 `drift_step` 对 HelpExtend 的修正次序通过。
  - review95-fixes：逃跑消息前发 `escape_audio`，收场时 `stop_bgm`／`take_battle_me`／`_replay_map_audio` 再调一次都是幂等的（BGM 已不在暂停、战斗 ME 已停），通过；`audit_due_before_hit` 只对 troop 与事件状态两个探针、到期时跳过缓存和暂存，通过；影响面声明拒重复 to 与环，两处实现一致，通过。
  - 事件／地图四批：events-map-m5 挂机门 `hang_up_gate()` 默认看 `is_active`，回退看运行期 `started_flag`（读档不清，同原版全局标记），探针与 Godot 两侧预设键 hangUp／designations 都进了白名单，声明链 from／to 接上，通过。distracted-snyder 角色状态门（paramPlus→states→hp→mp）两侧次序一致，reached 改按指令对象记的理由成立，通过。ishizaka 轮回不选人只少问一层、结果同原版「常规阵容」，通过。ichigo-cut1 去掉 Map148 EV42／43，通过。
  - 天启篇（d4k4ag 一、二批，pwq2i3、fxqj11、z0d29k、intro-anim-v8、objective-mayer）：没有原版可对，按交付单与数值重构方案核逻辑。第一批 `_legacy_difficulty` 五档逐条对 Map001 EV1 的难度分支（SetID 2～6 后的开关、变量、物品、5980）一致。第二批 `NO_RECRUIT` 拦全部新入队：扫了 v0.62.12 全部 129 入队，非招募的临时入队只在 Map217（轮回）与爱莉／智甚的魂灯转换，入队前 12 条内没有扣钱扣物，拦掉不会白花资源。抽角色候选写进存档、不能重抽，通过。装备栏：删掉的栏靠 `can_equip`→`release_unequippable` 卸回背包，通过。数值表、词条表两批只有数据和查询、没接进流程，`*.json` 在各导出预设的 include_filter 里，通过。启动动画、声明屏只在标题，跳过与按键吞掉都有。
  - 自动更新五批：信任链是「内嵌公钥验清单签名 → 清单里的 SHA-256 → 下载后比字节数和 SHA → 每次启动再比一次 SHA」，补丁只写 user://；补丁编号必须大于正在运行的号，旧清单重放降不了级；重定向不许 https 降到 http；`boot_patch.gd` 不引用带 class_name 的脚本，排在第一个自动加载；启动两次没确认就退回上一份。安卓预设开了联网，导出冒烟查包里有没有 INTERNET。通过，另记 P3-4。
  - 总装文档批：253f184 把「待用户决定」改「保留」与 AGENTS.md 口径一致，另记 P3-5；e226261、04c12dd、1796e05 只动交接板归档、规则、登记与一行注释，通过。
- 发现：P3 5 条。
  - **P3-1（d4k4ag 第二批）战斗中换上来的助力位不做开战初始化**：`tianqi_swap` 只换 actors 与行动顺序，换上来的人没走 setup 里的开战段：不移除 removeAtBattleEnd 状态、不给初始 TP（上一场 clearTp 后是 0）、没有技能预热（start_warmups）、开战状态效果、种族祝福本场数据、心钢开战蓄力。换下去的人战后照常清理（end_battle 走 state.members()），没有残留。天启篇新玩法，没有原版可对，建议定一下换上来的人要不要补这一段（至少初始 TP 与预热）。
  - **P3-2（chars-gaps3）解锁过滤的位置比原版靠外**：原版 installNativeSkillProgressionRuntime 在心钢、云裳、异化之前装（在它们里面），重制把过滤放在异化之后。异化百相借来的技能、心钢换的技能如果落在 10122～10167 且没解锁，原版留着、重制会滤掉。现有数据里借不到这段技能，走不到。
  - **P3-3（ishizaka）`事件有意删除.json` 两组的 o 还是占位**：「O-待定·地图死代码」「O-待定·轮回不选人」，优化登记里已是 O-269、O-270，合并工具只换了登记表。建议随手改成实号。
  - **P3-4（update-check1）静默检查发现撤回时直接退回，没有页面那道「已登记待重启」的判断**：`XUpdateClient.check()` 在页面没开时见 revoked 就 `rollback(false)`；页面先看 `pending_code()`，已登记新补丁就不再查。若玩家装好修正补丁、没重启，又碰上一次静默检查（隔天进标题），会把刚登记的那份退回到上一份。眼下只有隔天不重启才碰得到。建议静默路径同样先看 `pending_code()`。
  - **P3-5（253f184）优化登记还有 49 行旧状态、24 行没编号**：改「保留」时只认了「待用户决定」，「待用户确认」48 行（O-113～O-243，含 6 行 O-待定）、「待 Kyo 确认」1 行（O-242）没改。登记表里还有 24 行首格是「O-待定·名字」（如角色HP包装、深渊商人、词条难度浮动），状态写「编号待总装分配」，一直没发号；代码注释里也照写 O-待定。重制步骤清单进度账开头一句仍写「下次审查 75%，之后 95%」，与同段「三个都已做」矛盾。另：e226261 把一次性的 `清理旧工作树_20261109.sh`（带本机绝对路径）放在仓库根目录，用完可删。
- 规则：`协作与核查.md` 无改动。核查天启篇这类没有原版的批，按交付单与方案核逻辑，已写在上面各条里。
- 玩家可见：无。

## 已核／未核
已核：上面 25 批甲档的游戏代码改动（modes／core 下全部 .gd 差异）、优化登记新增行、探针与同步工具的改动段；原版对照见各条。
未核：Godot 场景一个都没跑（各批交付单的云端选测与本机专项照信）；party_status_panel.gd、warning_screen.gd、intro_anim.gd 的画面只读码没看图；`发布补丁.py` 只读了签名、检查与暂存部分，没实跑；乙 11 批、丙 37 批不在本期（不计上限）。

## 交接板
- 下一步：P3-1 交天启篇线程（要不要给换上来的助力位补开战初始化，Kyo 的新玩法，先问一句）；P3-3、P3-5 总装顺手改；P3-4 派自动更新车道（update-*）补一行判断；P3-2 记着，有借技能的数据再说。
- 甲档待核查清零后可恢复派新功能车道。

## 待交叉核查
无（审查线程自己的文档分支）。

## 优化登记草稿

优化登记草稿：无

## 可优化
- `待核查.py` 现在把带新 .gd 的天启篇批都算甲档（tianqi_balance.gd、tianqi_affix_table.gd 只有数据和查询、没接进流程）。可以在 `待核查分档.json` 给 `modes/xiyou/core/tianqi_*.gd` 中未被别处引用的定乙档，少占上限；归哪条车道：工具（哪吒）。
