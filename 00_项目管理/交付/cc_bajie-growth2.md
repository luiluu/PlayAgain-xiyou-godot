# 交付：cc/bajie-growth2

- 车道／工作者：C 规则·机制／八戒（cc，Opus medium）
- 状态：进行中

## 接续（growth1 会话上下文已过交接线，没开工；请新会话照这里做）

开工：`git switch --ignore-other-worktrees cc/bajie-growth2`，等 growth1 合并推送后 `git merge main`＋`新建工作树.sh --补齐`。派单见总装 growth2 交代：
1. 利维坦锻造 `installNativeLeviathanForge.js`（213 行）＋杰作无我锻造（`installNativeHubrisRuntime.js` 的 forge 段）。
2. 魔冠 `installNativeDemonCrownRuntime.js`：先确认来源走得到。
3. 尾项：两件动态说明（`help_card.gd`）、智能 AI 选巨人吞噬（`Codex_SmartBattleAI.js` 引用 7900）。

growth1 已查到的事实（省重读）：
- 锻造锤 2867：`H.awardCore`，Map176 胜利、来源地图 ∈ {108, 165}（`H.unknownCoreOrigin`：没记来源按变量 107：1→164、2／3→165，0→0）、敌群 570～575、20%（`H.coreDropRate`）、每场一次；掷在心钢 `clearReward` 之后（同一个 endBattle 包装）。重制 `XHeartsteel.clear_reward` 在 `battle_logic.end_battle` 末尾，锻造锤接在它后面、狂妄之前。注意 awardCore 认 108 而 unknownCoreOrigin 缺省给 164——原版疑似对不上，要探针量。
- 解锁：`H.unlockForge`／`U.unlockForge`，第一次拥有（背包或穿着）心钢／狂妄实例时设 `$gameParty._codexLeviathanUnlocked`／`_codexAtaraxiaUnlocked`、学配方 457／458，读档与 gainItem 时检查；`resetKnownRecipes` 后补学。growth1 探针 reward.* 例里已量到 recipes／unlocked（专项 PENDING_FIELDS 里跳过了，做完把它们从 PENDING_FIELDS 删掉）。
- 杰作无我锻造：`U.canForge`（战斗外、已解锁、选的是自己的狂妄实例、2530×200、2867×5），`U.previewForge` 把实例改成 7903（params 按两件原件差加、名字狂妄→杰作无我、图标、说明、note 里四行 pos 文字替换、meta 标记），`U.forge` 事务（失败回滚）；配方对象 `r.getMaterialCount`／`craftable`／`craft` 被改写。利维坦锻造应是同一套（看 Forge 文件 60 行以后）。
- 心钢／狂妄的说明行文字：`H.helpRows`／`U.helpRows`／`H.skillHelpView`（growth1 未移植）。
- 运行时：`core/heartsteel.gd` XHeartsteel、`core/hubris.gd` XHubris；专项 `tests/xiyou_heartsteel.gd`，探针 `mv_oracle/heartsteel_probe.cjs`（新例可加在这个探针或另开 forge 探针）。

## 变更记录草稿

（待写）

## 本分支提交

（待写）
