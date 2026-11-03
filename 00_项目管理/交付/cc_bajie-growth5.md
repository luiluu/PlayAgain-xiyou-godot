# 交付：cc/bajie-growth5

- 车道／工作者：C 规则·机制／八戒（cc，Opus）
- 状态：进行中

（接 cc/bajie-growth4 的接续第 1～4 条：成长装备尾项二。growth4 只交审查 31 P3-1；本分支从它切出。）

## 变更记录草稿

## 2026-11-03 【cc·八戒·未经审查】成长装备尾项二：智能 AI 巨人吞噬、甚尔封印不减蓄力、提示、专属法宝战力（dev.待定）

- 智能 AI：`Codex_SmartBattleAI.js` 在 `plugins.js` 里启用，它给巨人吞噬 10227／10228 单独估伤；重制原来公式不认，估出 0，AI 不会选。`smart_ai.gd` 加同一分支，走 `XHeartsteel.ai_damage`（按技能号定档、用当前最大生命、乘阶数、物防最多减一半、不取整）。
- 甚尔封印 2634 让主动技能失效（`_tojiSuppressed`）时，原版心钢不减蓄力、狂妄不计行动；重制原来两边都照算。`battle_logic.gd` 失效分支调 `XHeartsteel.suppressed`、`XHubris.suppressed`。失效的巨人吞噬照原版进冷却 3。派单只写了心钢，狂妄是同一个判断（原版同一行），一并改了。
- 提示（`$.toaster`）：第一次得到心钢／狂妄一族报「已解锁打造配方：杰作利维坦／杰作无我」（读档、补查不报，同 `unlockForge(false)`），掉落报「获得神武：心之钢！／狂妄！」「获得锻造材料：锻造锤！」；次序同原版（解锁在 gainItem 里，先于获得）。锻造锤这句归「掉落」类，跟消息提醒开关走。
- 战力：`XPower._exclusive_gear` 补渡鸦 4001 专属固定属性、米拉 4577 元素 2 增伤＋20%、甚尔 4580 物理池 ×1.11，按底子认。
- 原版参照：`heartsteel_probe` 加 ai.*（3 例）、suppress.*（3 例）、toast.*（2 例），`growth_help_probe` 加 powerOnly（3 件）；两个探针都不进同步，只更新 `tests/fixtures`。

## 优化登记草稿

优化登记草稿：无

## 待交叉核查

- 原沙僧核心文件：`battle_logic.gd`（封印失效分支加两行）。
- 另改：`smart_ai.gd`、`heartsteel.gd`、`hubris.gd`、`growth_forge.gd`、`power.gd`、`tests/xiyou_heartsteel.gd`、`tests/xiyou_growth_help.gd`、`tests/xiyou_growth_forge.gd`、两个探针与两份 fixture。
- 请重点核：`XHeartsteel.suppressed` 清 `_started`、`_cast` 后，endAction 直接跳过，这和原版「_codexHeartsteelFinished 照设、只是不减」有没有别的差别。

## 交接板

- 下一步：成长装备尾项二已做（待审查）。
- 用户试玩说明：穿心钢、利维坦时，智能 AI 会用巨人吞噬了；中了甚尔封印的角色技能失效时不再减蓄力；第一次拿到心钢／狂妄、掉到锻造锤会弹提示；渡鸦、米拉、甚尔专属法宝的战力变高，同原版。
- 需要用户决定：无。

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 无。

## 验证

## 本分支提交

- e0687255 改码、参照例与专项。
