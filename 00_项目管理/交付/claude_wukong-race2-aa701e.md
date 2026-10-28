# 交付：claude/wukong-race2-aa701e

- 车道／工作者：C 规则·机制／悟空_63（Claude）
- 状态：可合并

## 期一逐项：原版依据与重制落点

原版文件 `app.nw/js/codex/runtime/installNativeRaceRuntime.js`（下称 R）、`installCombatPowerRuntime.js`（下称 P），冻结 v0.28。

| 项 | 原版依据 | 重制落点 | 结论 |
| --- | --- | --- | --- |
| 1 战力预览种族修正 | R:262–279（resetPowerCycle／startPowerTurn／powerBlood／powerCost／powerAdjust／commitPowerRoot），P:254（expected 末尾 powerAdjust）、P:280／283／295／296／306（循环里重置、费用、每回合、人族行动数、提交）、P:374（神族治疗 ×(1+q)）、P:386（蛮族「蛮骨与反攻」未计入）；钩子 R:150–152 的 power 分支（神族首魔看 godUsed、魔族血契看 powerBlood） | `power.gd`（_cycle／_expected／evaluate）＋ `race_battle.gd`（power_* 函数，capture 认 racePower／raceSuppress 选项） | 做 |
| 4 R.status 文字 | R:280 定义 | — | **死代码**：冻结源里没有任何调用（全目录 grep `CodexRaces.status`／`R.status` 只有定义一处），不做 |
| 5 敌人窗毒鸡汤信息 | R:214 poisonInfo、R:215 Window_BattleEnemy.updateHelp 包装 | `race_battle.gd` poison_info（文字规则，已对照） | 期一做文字；**画面挂接移到期二**：原版选敌时 YEP 帮助窗（Select Help Window true，`Window_Help.setBattler` 画敌人名）整块重制都没有，毒鸡汤是挂在它第二行，得和期二改敌人窗一起补 |
| 6 种族补给 bossReward | R:226–235（setup 记层、endBattle 记胜负、claimSupply、bossReward 包装） | 已在 `dungeon.gd` race_supply（XDungeon 副本服务那次一起接的，提交 9873ea39），但没有参照 | 补参照与测试；规则一致，只差重制建档就补空 `inbox`（原版背包满才建，内容相同，不改） |
| 7 learnSkill 改种族 | R:82 | `race.gd` learn ＋ `actor.gd` learn_skill 一行转交 | 做（原版事件入口只有 Map137 兑换大厅「修复种族技能」546 条 318 指令，不在切片；其余走 learnSkill 的路径要一致） |
| 8 旧式道具与商店（尾巴） | R:83 gainItem、R:237 Scene_Shop.prepare、R:238 Window_ShopBuy.isEnabled、R:44–49 旧档迁移 | 已有：`xstate.gd` gain_item（得旧石换正规 ID）、`item_marks.gd` shop_goods（商品换 ID 去重）与 stone_locked（按进度层锁），参照 shop_buy_probe；旧档迁移不适用（不迁 MV 存档） | 不用做。v0.28 里 Map030／064／118／145／155／182 的商店卖旧石，都在切片里，已走上面这套 |
| 9 人族 996 提示 | R:217 tell(名字+'九九六：额外行动') | 重制 `insert_human` 已写提示，但 `battle_logic.gd:1003` 调用时没传 logs，提示被丢；改成暂存，下一个行动根开始（begin）时吐出 | 做，不改 battle_logic.gd |

## 变更记录草稿

## 2026-10-29 【Claude·悟空·未经Codex检验】种族祝福期二·期一：战力预览的种族修正、学会种族技能改种族、毒鸡汤说明、九九六提示（dev.待定）

- 战力（`power.gd`＋`race_battle.gd` power_*）：照 installCombatPowerRuntime 调的 CodexRaces.resetPowerCycle／startPowerTurn／powerBlood／powerCost／powerAdjust／commitPowerRoot——人族 ×(1+q/2) 且每回合期望多 q/2 次行动；鬼族上回合同组技能 ×(1+q)（每回合一次）；神族本回合首次魔法才无视 q/2 魔防、治疗辅助分 ×(1+q)；魔族血契费用加 3% 最大生命、×(1+q/2)；妖族群攻按「一体 60%」拆开只给一体猎物加成；蛮族在未计入里列「蛮骨与反攻」。伤害钩子 capture 认 racePower／raceSuppress 选项（预演不读战斗行动根）。战力缓存签名加上种族数据（换族、开关血契后重算）。
- 学会种族技能（`race.gd` learn，`actor.gd` learn_skill 开头转交）：不走原 learnSkill——没数据按该技能建、同族阶位取较大、别族不变，再 sync。
- 毒鸡汤说明（`race_battle.gd` poison_info）：「毒鸡汤（回合末） 名字：量；…」，本回合、目标还挂着毒鸡汤才列，按角色编号排；画面挂接见期二。
- 九九六提示：排行动顺序处（battle_logic 不传提示列表）中了就暂存，下一个行动开始时补出「名字九九六：额外行动」；之前这句提示被丢了。
- 种族补给（XDungeon.race_supply，已有）补参照。
- R.status 冻结源里没有调用处，不移植；旧式道具与商店已有，不用做。
- 参照：`race_battle_probe.cjs` 新增 power.*（角色 1／8 各族 15 例）、supply、learn、poisonInfo，共 49 例；专项 `xiyou_race_battle` 520→610。

## 交接板

- 下一步：悟空_63 种族期二·期二（妖族群攻手选猎物、战斗指令「血契：开／关」，以及选敌 YEP 帮助窗＋毒鸡汤第二行）
- 用户试玩说明：选了种族的角色，状态页／技能页的战力会随种族变（人族、魔族开血契、鬼族、妖族等）；人族九九六中了，回合开始后第一次行动会弹「九九六：额外行动」
- 需要用户决定：无

## 进度账

- 种族祝福：「未移植」清单 9 项里本期做完 1、7、9，5 做了文字规则，6、8 确认已有（6 补了参照），4 是死代码；剩 2、3 和 5 的画面（期二）

## 验证

- 选测＋专项（2026-10-29，合 main 后）：`并行测试.py … xiyou_race_ xiyou_power xiyou_status_power xiyou_dungeon xiyou_guide xiyou_actor_p0 xiyou_skill_share xiyou_bonds xiyou_pets`，12 个场景全过，无偶发：
  xiyou_race_battle 610/610、xiyou_race_menu 66/66、xiyou_power 137/137、xiyou_power_books 6136/6136、xiyou_power_books_boundary 55682/55682、xiyou_power_books_menu 1068/1068、xiyou_status_power 36/36、xiyou_status_power_panel 11/11、xiyou_dungeon 6954/6954、xiyou_guide 63/63、xiyou_actor_p0 3322/3322、xiyou_pets 29/29（skill_share、bonds 没有同名场景）。
- 同步：工作树里 `同步正式西游.py --accept-additions` 通过（race_battle_probe 重跑 46 秒、其余 60 个复用，校验无问题），用同步产出的参照再跑 xiyou_race_battle 610/610。
- 没改切片、界面，不涉必跑项。

## 待交叉核查

- 改了的核心文件：`actor.gd`（learn_skill 开头一行转交 XRace.learn）；`power.gd`（_cycle／_expected／evaluate／_signature）。没碰 battle_logic.gd、damage.gd、alien_battle.gd、alienation.gd。

## 可优化（流程／工具／效率）

- 已做：无。优化登记 O-107 本期没用上（期一都照原版），留给期二。
- 临时输出已清理（本车道的并行测试日志目录、scratchpad 日志）；同步留下的产物指纹保留给总装。
- 建议：选敌时整块 YEP 帮助窗（敌人名）重制没有，期二补时顺带；如总装另有界面车道排期，可改派 B 界面车道（归期二本车道即可）。

## 本分支提交

- 3228075f WIP：期一主体（战力、learn、毒鸡汤说明、九九六提示、补给参照）
