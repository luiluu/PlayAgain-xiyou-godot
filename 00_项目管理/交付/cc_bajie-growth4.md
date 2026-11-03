# 交付：cc/bajie-growth4

- 车道／工作者：C 规则·机制／八戒（cc，Opus）
- 状态：进行中

（总装十五 growth4：成长装备尾项二期＋审查 31 P3-1。P3-1 先在 growth3 的工作树上做了，已挪到本分支；cc/bajie-growth3 退回 f728eaaa（交付时的样子），没动 main。Kyo 额度 88%，按总装通知做到 P3-1 停。）

## 变更记录草稿

## 2026-11-03 【cc·八戒·未经审查】审查 31 P3-1：谷雨强制归根被死亡抵抗挡下时补 addNewState（dev.待定）

- 问题：`guyu.gd` `root(g, true)` 里，谷雨有死亡抵抗时 `add_state(1)` 被挡下，重制直接 `state_ids.append(1)`；原版这里调 `addNewState(死亡)`＋`resetStateCounts`＋`result().pushAddedState`。所以重制少了 die（清状态与强化、各 die 包装）和魔冠的 addNewState 包装：穿魔冠的谷雨这时成长不减半。
- 改法：`battler.gd` 把 MV 的 addNewState 拆成 `add_new_state(id)`（死亡先 die，再进状态表、排序；魔冠死亡钩子从 `add_state` 挪进这里，同原版包的是 addNewState），resetStateCounts 拆成 `reset_state_counts(id, random)`；`_add_state` 改调这两个，行为不变。`guyu.gd` 被挡下时改调 `add_new_state(1)`、`reset_state_counts(1)`、`push_state_result("addedStates", 1)`。
- 原版参照：`demon_crown_probe` 加 `guyu.root`（20 例无错）：60 级谷雨穿魔冠、实例加死亡抵抗（特性 14／1），赢两场（成长 1.999）后在战斗中代命归根，成长减半到 0.9995、谷雨倒下、状态表只有死亡、本场死亡记一次。
- 原版归根后还有 `clearActions` 与 `rawRefresh`：重制的行动模型不同、原来就没有这两步，本次不动（与抵抗无关，不论有没有抵抗都一样）。
- 审查说 `_forced_run` 新次序不用补参照例，原接续第 4 条撤掉。

## 优化登记草稿

优化登记草稿：无

## 待交叉核查

- 原沙僧核心文件：`battler.gd`（`add_new_state`、`reset_state_counts` 拆出；魔冠死亡钩子从 `add_state` 挪进 `add_new_state`，时机从 add_state 收尾提前到 addNewState 之后、resetStateCounts 之前，同原版包装位置，且在 `_adding_state` 锁里）。
- 另改：`guyu.gd` root、`mv_oracle/demon_crown_probe.cjs`（guyu.root）、`tests/xiyou_demon_crown.gd`、`tests/fixtures/demon_crown_oracle.json`。
- 请重点核：魔冠死亡钩子提前后，别的 add_state 收尾（异化 after_add_state、谷雨 after_add_state）与它的先后有没有影响。

## 交接板

- 下一步：审查 31 P3-1 已修（待审查，可销账）；成长装备尾项二见下面「接续」。
- 用户试玩说明：穿着"头顶"的谷雨带死亡免疫时，代命归根也会让魔冠成长减半（同原版）。
- 需要用户决定：无。

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 无。

## 验证

- `node demon_crown_probe.cjs`：20 例无错（新加 guyu.root）。
- 专项 `xiyou_demon_crown` 106／106；反向验证：guyu.gd 改回 `state_ids.append(1)` 后 guyu.root 两项报错（成长停在 1.999、不减半），改回后通过。`xiyou_guyu_battle` 1637／1637。
- 选测还没跑完：开了一轮 80 个场景（`选测.py main --list` 的 75 个，加 xiyou_determinism、xiyou_guyu*、xiyou_sukuna*、xiyou_black_flash*、xiyou_race_battle、xiyou_raven*、xiyou_enemy_book*），按总装收尾通知停在中途（日志 `03_再刷重制_Godot/04_验证/本地结果/任务/growth3-p3.log`）。下一个会话要重跑这一轮；battler.gd 是核心文件，名单里 xiyou_determinism 一定要有。

## 本分支提交

- 86e6623a P3-1 改码、参照例与专项；f03f0f82 合 main（main 上已有 growth3 的合并 60a1066e）

## 接续

0. 先做：`git merge main`（growth3 合完收尾后）、`新建工作树.sh --补齐`，重跑上面「验证」那一轮选测，过了再往下做。
1. 智能 AI 选巨人吞噬：`Codex_SmartBattleAI.js` 引用 7900，先查 `plugins.js` 确认这个插件启用了。
2. 甚尔抑制行动（`_tojiSuppressed`）不减心钢蓄力。
3. 解锁与锻造锤的提示（$.toaster），心钢、狂妄、锻造锤三处。
4. 战力：渡鸦／米拉／甚尔的专属装备加成。
