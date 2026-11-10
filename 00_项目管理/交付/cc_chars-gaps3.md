# 交付：cc/chars-gaps3

- 车道／工作者：C 规则·角色／悟空（cc，GD8）
- 状态：可合并
- 车道路径：/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/objective-torvalds-db9fb5
- 分支从 main fe7591b50 切，已合 main（be2cba134）。

## 四项结论

| # | 项 | 结论 | 证据 |
| --- | --- | --- | --- |
| 1 | 谷雨赠春 isValid 包装 | **原版到不了，不接**，头注释改写 | v0.62.12 `Olivia_BattleSysOTB` 的 Force Battle System 为 true：角色走 `startOTBInput`→直接 `startAction`，不经 `processTurn` 里的 `isValid`（重制 battle_logic `execute` 头注释早已写明、attack_query 参照过）。全源 `.isValid()` 只剩 MV `itemTargetCandidates`（自动战斗 `evaluate`）一处调用；转移 10290 伤害类型 0，`evaluateWithTarget` 恒无值，评分本来就是 0。包装没有玩家可见效果。 |
| 2 | 没招募的云裳说明卡 | **真差，已修，而且不只云裳** | 新探针例实测：原版新局后 `$gameActors._data` 已建好 1～179 **全部**角色，`characterHelpActor` 总能取到真角色，替身预览走不到。所以没招募的角色卡显示的是 1 级初始角色的实际数值（云裳「消耗：99MP」而不是备注原文「66MP＋最大MP×5%」；渡鸦、米拉、宿傩、谷雨同理）。重制改为：没招募时建一个**不入档**的初始角色（`XCharacterHelp._unrecruited`，套 actor_ops、算被动，不登记装备、不写进 actors，按存档与 actor_ops 条数缓存）。开关 `XCharacterHelp.UNRECRUITED_AS_NEW_GAME`（关掉回到替身预览）。照原版，不占 O 号。 |
| 3 | skill_progression 按 unlocked 过滤 | **已做** | 照 `installNativeSkillProgressionRuntime`：`XActor.skills()` 对 167／168 过滤未解锁的专属技能；`XBattleLogic.can_use`（meetsSkillConditions）加 `XSkillProgression.unlocked`；开战（`XBattleLogic.setup`，原 `BattleManager.startBattle` 包装）再同步已建的 167、168。参照探针只调 `BattleManager.setup` 不调 `startBattle` 的专项（xiyou_mira_battle：先同步再忘掉 drop）用 `XSkillProgression.SYNC_ON_BATTLE_START = false` 模拟。同步时写的 `_codexRavenStage` 不另存（raven.gd 直接读 XAdvance.rank），头注释写明。 |
| 4 | 过时头注释 | 两处改对，**一处派单前提不对** | alien_battle：alienation.json 20 个词条（不是 15）逐个对过都已接（夺舍也在），改成「都已接上」。options_scene：灰显只剩测试模式、GM 工具（本机解锁文件可点）和待提交反馈（要原版服务器）三项。**smart_ai：米拉／渡鸦／宿傩 profile 实际没做**——`XSmartAI.profile` 只问甚尔、云裳；Codex_SmartBattleAI 自带的那条 registerProfile（黄泉／流萤溅射、宿傩神灶 holdInLongFight 与伏魔御厨子 futureActor、渡鸦神话封解 futureActor、米拉解放 futureActor＋followup）没接；benefit 里的 Boss 霸体判断（hasHyperArmor）也没接，但 cc/rules-mira-raven2 正在做（审查 76），本分支不碰。头注释只列角色档案这一处，没有动代码；和 rules-mira-raven2 试合（merge-tree）无冲突。 |

## 改了什么

- `ui/character_help.gd`：`actor()` 没招募时用 `_unrecruited`；头注释。
- `core/actor.gd` `skills()`、`battle/battle_logic.gd` `can_use` 与 `setup`、`core/skill_progression.gd`（新 `SYNC_ON_BATTLE_START`、头注释）。
- 头注释：`core/guyu.gd`、`core/alien_battle.gd`、`ui/options_scene.gd`、`battle/smart_ai.gd`。
- 探针 `mv_oracle/character_help_dyn_probe.cjs` 加 `newgame.167／168／170／172／174／175` 六例（不删新局已建的角色，记等级、专属技能、各自技能段的卡行），夹具 `tests/fixtures/character_help_dyn_oracle.json` 22→28 例，旧 22 例逐字未变。
- 专项：`xiyou_character_help_dyn`（124→255 项：六例的卡行、替身角色的等级与专属技能同原版、不写进 actors；`yun.preview` 例关开关走替身）；新 `xiyou_skill_progression`（10 项）；`xiyou_mira_battle` 开战同步关掉（见上）。
- 改到原沙僧核心文件：`battle_logic.gd`、`actor.gd`（请审查重点看）。

## 参照与反向验证

- 原版参照经占槽跑（`占槽.py --label chdyn`），另有一次临时探针（`.sandbox/tmp_yun_newgame.cjs`，只读、只打印）确认新局已建全部角色。
- 反向验证（手动改→单跑→还原）：关掉 `_unrecruited` → xiyou_character_help_dyn 失败；skills 过滤、meets 判断、开战同步各自关掉 → xiyou_skill_progression 各掉 1 项。

## 验证

- `语法检查.py` 通过；`工具回归.py` 全过（91 秒）。
- 本机专项：xiyou_character_help_dyn 255/255、xiyou_help_card、xiyou_skill_progression 10/10、xiyou_mira_battle、xiyou_raven_battle、xiyou_raven_soul 通过。
- 云端选测通过：`选测.py` 列的 341 个场景、15 片（含 xiyou_determinism、xiyou_rules 全部段、事件对照、smart_ai 抽样），提交 de7d8331f9，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42886456019 。之后只改了 smart_ai.gd 头注释（去掉霸体那条）。

## 变更记录草稿

## 2026-11-10 【cc·悟空·未经审查】角色余项：没招募角色的技能卡、渡鸦／米拉解锁过滤、谷雨 isValid 结论（dev.待定）

- **没招募角色的技能说明卡**：原版新局就建好了全部角色，没招募的角色卡显示的是 1 级初始角色的实际数值；重制原来显示备注原文（如云裳「66MP＋最大MP×5%」，原版是「99MP」）。现在没招募时用一个不入档的初始角色算卡（`ui/character_help.gd`，开关 `UNRECRUITED_AS_NEW_GAME`）。
- **渡鸦／米拉技能解锁**：技能列表和能不能用都按解锁条件过滤（只管本人专属技能），开战前再同步一次，照原版 installNativeSkillProgressionRuntime（`core/actor.gd`、`battle/battle_logic.gd`、`core/skill_progression.gd`）。
- **谷雨转移的 isValid 包装**：核实原版强制 OTB，角色行动不经 isValid，包装没有可见效果，不接；头注释写明证据。
- 头注释：异化 20 个词条都已接；设置页灰显只剩测试模式、GM 工具、待提交反馈；智能 AI 自带的角色档案未接，列准。
- 参照探针 character_help_dyn 加 6 例（28 例），专项 xiyou_character_help_dyn 255 项，新专项 xiyou_skill_progression 10 项。
- 玩家可见：图鉴等处看没招募角色的专属技能卡，消耗行显示实际数值；渡鸦、米拉没解锁的专属技能不会出现在列表里、也用不了（正常同步下本来就一致）。

## 交接板

- 下一步：角色余项这批做完。智能 AI 还差 Codex_SmartBattleAI 自带的角色档案（黄泉／流萤溅射、宿傩神灶与伏魔御厨子、渡鸦神话封解、米拉解放），见 smart_ai.gd 头注释，可派一期（要 smart_ai_probe 加例）；Boss 霸体由 rules-mira-raven2 做。
- 用户试玩说明：没招募的角色（比如云裳）在图鉴里看技能卡，消耗显示成具体 MP 数。
- 需要用户决定：无

## 进度账

- 角色与专属机制：不自报，请核定。依据：派单四项里三项做完或证实到不了；smart_ai 头注释的前提不对，查出角色档案一处真缺口（霸体另一条车道在做）。

## 可优化（流程／工具／效率）

- 盘点「原版是否新局就建了某角色」这类前提时，`tmp_yun_newgame` 这种十几行只读探针很划算（一次 10 秒）；可以考虑在 mv_oracle/shared 加个 `dumpNewGame()` 小帮手，打印新局后已建角色、队伍、开关，省得每次手写。
- 头注释「已做／未移植」常过时（这次三份里一份说反了）：派单里写「头注释过时」前先 rg 一下对应函数是否存在，比较省返工。

## 本分支提交

- e7eea8cc0 说明卡：没招募的角色用不入档的初始角色，参照加 newgame 六例
- 1141d7925 渡鸦／米拉：skills 与 meetsSkillConditions 按解锁过滤，开战再同步；专项 xiyou_skill_progression
- b24aa8187 头注释：谷雨 isValid、异化、设置页、智能 AI
- 合并 main（be2cba134）
