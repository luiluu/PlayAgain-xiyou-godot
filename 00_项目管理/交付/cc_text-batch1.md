# 交付：cc/text-batch1

- 车道／工作者：文字批1（cc，Sonnet 5.5＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·文字批1·未经审查】文风指南 A 类错字不通（#1、#5 的向导文字、#6、#7；#3 已有修正无需改）（dev.待定）

- 依据：私密仓 `协作交接/天启篇文风指南_v0.1.md` 第三节 A 类；Kyo D103 定「梗不动」，所以 #3 只管 `/n` 斜杠、不改台词，#4（白票）不动；#2 等 D106。
- 改：`core/tianqi_famine_alien.gd`（透支扣 MP 战报，名字与 MP 间补空格）、`core/tianqi_horsemen.gd`（混子小弟 B 退场台词去掉「（倒）」）、`tianqi_data/qiyin_gear.json`（不立文字效果句补「毕业武器」「中」与句号）、`text_fix/overrides.json`（Map004 向导 EV073 两处「金币」→「精魂」）；测试 `tests/xiyou_text_fix` 加 `guide_currency_unit`。
- 玩家可见：战报「透支：莉co MP −20。」不再粘连；瘟疫混子退场不再念出舞台指示；不立文字的说明读得通；方桌商店向导里的货币名与商店、天平一致。
- 验证：选测 xiyou_text_fix、xiyou_tianqi_qiyin_gear、xiyou_tianqi_famine、xiyou_tianqi_famine_reaper、xiyou_tianqi_horsemen、xiyou_tianqi_horsemen_battle、xiyou_tianqi_alien_finale、xiyou_tianqi_death、xiyou_event_compare 共 9 个全过（日志无 SCRIPT ERROR）；语法检查 0 问题。待小A 文字审（Hydrogen）。

## 交接板

- 下一步：小A 文字审本批；#2（D106）、#3 改写与 #4（D103 已定不动）
- 用户试玩说明：见上「玩家可见」
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：清单里 #3、#5 前半过时，小A 读 generated 与 text_fix 前可先对照 `xiyou_text_fix` 已有用例（预计省返工；归小A 文字审流程）。

## 清单逐条（改前／改后／位置）

1. **#1 已改**：`core/tianqi_famine_alien.gd:317`　`"透支：%sMP −%d。"` → `"透支：%s MP −%d。"`。
2. **#3 无需改（已有修正）**：Map004 EV036 的 `/n<天才灵魂>` 已被 `XTextFix.NAMEBOX`（O-490，`core/text_fix.gd`）在加载时改成 `\n<天才灵魂>`，「次塔→此塔」由 `overrides.json` 的 `Map004:ev36` 条改，现成用例 `xiyou_text_fix` 的 `namebox_slash` 逐字断言，本轮通过。`generated/` 里的原文留 `/n` 是对的（转换产物、不入 Git，只在加载时修）。台词本身按 D103 不动。
3. **#5 只改了一半**：
   - EV073（Map004 商店向导）两处：`\c[4]金币\c[0]：阿卡拉…` → `\c[4]精魂\c[0]：阿卡拉…`；`炼器师（金币）` → `炼器师（精魂）`。位置 `text_fix/overrides.json` 新条 `Map004:ev73`（count 2）；用例 `guide_currency_unit`。
   - System `obtainGold`「获得了 %1\G！」**没改**：见下「我不同意的地方」。
4. **#6 已改**：`core/tianqi_horsemen.gd:1193`　`"……阿嚏。（倒）"` → `"……阿嚏。"`（未拆旁白：该处只有台词一行，倒下由战斗事件表现；不新增旁白）。
5. **#7 已改**：`tianqi_data/qiyin_gear.json:1097`　`"揭开时从另外 12 把的独有效果里随机刻上一条"` → `"揭开时，从另外 12 把毕业武器的独有效果中随机刻上一条。"`。

## 我不同意的地方

- **#5 的 `obtainGold`**：`\G` 是 MV 的货币占位，`ui/mv_text.gd:58` 显示时换成 `currencyUnit`（精魂），所以玩家看到的是「获得了 120精魂！」，不是 `G`；而且全工程没有任何代码读 `obtainGold`（rg 零命中），这条消息根本不会出现。换成写死的「精魂」反而让改货币名时漏改，所以不动。若 Kyo／小A 嫌「120精魂」少空格，那是 `\G` 展开后的统一格式，另议。
- **#3**：清单说「仍会导致姓名框标签失效」与现状不符，见上。
- **#6**：没采用「旁白拆分」备选，理由见上。

## 本分支提交

（见 git log）
