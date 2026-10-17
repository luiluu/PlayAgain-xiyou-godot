# 交付：claude/review25-content

- 车道／工作者：审查·内容与规则／八戒（Claude，重制_八戒_13，中等努力）
- 状态：进行中（检查.sh --oracle 运行中）

## 变更记录草稿

## 2026-10-17 【Claude·八戒·未经Codex检验】进度审查 20%＋25%（内容与规则）

- 范围：15% 基线 dev.015 以后的内容、战斗规则与解释器——dev.022～028（智能 AI、命中、YEP 行动序列、事件对照、按对照补翻译与等级上限）、032～038 中 20% 时没审完的部分（mv_interpreter／mv_script 指令与 JS 翻译、appearance、battler_sprite 外观；敌人等级、敌群事件条件、Establish 已审不重审）、041～042、044～045（含元素吸收）、047～048、050、052～054、057、060、062～063、066、068（四至二十五层、敌群事件、地图循环、开局轮回入口、楼层流程测试）、071（XDungeon、CE714／指令 214／宝箱收获／CE1439、CodexEconomy.redirect、转换器 v15 三元公式）。不审自己的提交。
- 方法：
  - ①对照正式版（冻结 v0.28，mv_oracle 实跑）抽查 6 处：
    1. 规则·三元伤害公式：技能 75／322／2443／10020／3512 在目标 HP 10% 与满血两支，`Game_Action.evalDamageFormula` 实测 vs Godot `formulaGd` 全部一致（10 例）。
    2. 规则·元素吸收（dev.045）：敌人 202／205／209／213 的 `<Element Absorb>`、角色 1 加状态 1371 圣光普照（含元素抗性叠加，吸收得 −1.3）／1392 五雷正法，9 个元素的 elementRate 全部一致（6 组）。原来**没有任何元素吸收测试**。
    3. 规则·命中（dev.023）：角色 1 一级对高闪避敌人 82／129／180／192（命中 0.7812／0.8412）、必中技能、敌人普攻，itemHit／itemEva 全部一致（16 例）。1～3 固化为新测试 `tests/xiyou_element_ternary`＋夹具 `tests/fixtures/element_ternary_oracle.json`，采集脚本在 `04_验证/本地结果/20261017_八戒进度审查25/`。
    4. 事件：在本 worktree 重跑全部地图事件对照（同步脚本重新跑 event_probe）：699 例 681 一致，18 例已知（大厅 Map004 未接的场景与脚本对话 15、属性加点场景 m119、O-027 两条修正），3 例参照报错为登记的例外；ce1440 已变一致但 baseline 没更新（dev.071 合并时漏），已重写。
    5. 副本：同步脚本重跑 dungeon_probe（二层 24 例＋一四六七层各 5 例）→ `xiyou_dungeon` 594/594；另逐项对照 `installNativeEconomyRuntime.js` 的 BOSS_BOOKS／MASTERY／TICKET／FLOOR_DIV／BOOK_RATE 与 XDungeon 常量一致。
    6. 副本／经济·CodexEconomy.redirect：TO_SCORE、TO_ITEM 28 项与正式源逐项一致；原来没有专项测试，已补。
  - ②代码：跨模块查结算位置、随机数、缓存与存档字段（框架维护约定「随重制照做的工程规则」）；③测试：按功能查专项测试；④登记：O-026／027／035／036／038／040 的开关与代码、框架维护约定已实现／目标。
- 发现（逐条带证据）：
  1. **转换器三元公式**（已知待办，已修）：`(x)*float(c)+(y)*float(not c)` 在 Godot Expression 里实测：条件为数字 5 时得 5x；未取的一支为 NaN 时整式为 NaN（`sqrt(-1)*float(false)+2*float(true)` → nan）。现有 15 条公式条件都是比较式，无影响。
  2. **伤害致死后同一行动的「附加状态」**（20% 观察 2，已修）：最终状态原本与 MV 一致（`_die` 清空状态），但 `r.added` 会误记已死目标的新状态；MV `addState→isStateAddable` 要求活着。随机数消耗两边一致（都照常掷）。
  3. **339 强制行动的隐藏敌人**（20% 观察 1，仍成立，扩大）：`XBattleLogic.setup` 直接跳过 `hidden` 成员，不进 enemies，所以 333／339 的敌人序号会错位，335（敌人出现）也无处可接。全游戏只有敌群 824「神劫使」有隐藏成员（6 只 934，其中 5 只隐藏，事件用 111／333／335），不在当前切片。接 824 时要做隐藏成员（留在 enemies、带出现标记、335 出现）。
  4. **XDungeon.battle 不随读档清空**（已修）：最近一场事件战斗的胜负与神秘珠／种族补给「已领」标记是进程内静态变量，换档或新游戏后仍留着上一档的胜利；违反「切换或读取存档时清空依赖上一档的标记」。
  5. **三元公式两支都求值**（记录，不改）：技能 6270 两支都有 `randf()`，Godot 每次多耗一次全局随机数；Godot 战斗随机数不与 MV 同种子，取值分布不变。Expression 没有短路条件写法。
  6. 结算位置：`battle_scene` 只调用 `logic.act／grant／gain_drops`，奖励只在 `_victory` 发一次；掉落在倒下动画结束时抽定（同 MOG_TrPopUpBattle），倒下处理逐条 await，胜利前都已处理；`_regenerate` 不致死。通过。
  7. 预览随机数：智能 AI `safe_damage` 把 `randf()` 换成 0.5、`expected_damage` 缓存只活在一次 choose 内；战力估算 `variance=false`。通过。
  8. 存档字段：`dungeon／bossMastery／raceSupply／ecoFrac` 读档缺省给空字典。通过。
  9. 测试缺口（已补）：元素吸收、命中实测、经济 redirect、三元公式取值、读档清标记。CE714、CE1439 奖励、秘境抽奖、种族补给由 dungeon／事件对照的 delta 覆盖。
  10. 登记：框架维护约定「跨楼层共性系统」标题写「尚未实现」，副本其实已在 dev.071 实现（唐僧转来），已改为分清已实现／目标，四个小节逐个标注，并写明限购／战斗内对话／挑战技能已有冻结参照（shared_system_probe）、Godot 侧未做；页眉更新；「后续工程布局建议」注明实际布局。O-026／027／035／036／038／040 的恢复开关都在代码里。
  11. 工具：在 worktree 跑 `同步正式西游.py` 会重建 generated，`.import` 全部丢失，紧接着跑的专项（如 `xiyou_transfer` 敌人图）会失败；`检查.sh` 先 `godot --import` 所以全量检查不受影响。中途跑专项前要手动 `godot --headless --path 01_Godot工程 --import`。
- 已修：
  - 转换器 v16：三元式改译成 `[(y), (x)][int(bool(c))]`（JS 真值、NaN 支不参与运算）；本 worktree 跑同步：**测量不变**（备份 `04_验证/本地结果/自动同步/20261017_024511_v0.28-v0.28`）。`xiyou_formulas` 加 5 条取值检查。
  - `XBattleLogic._effect` 21：目标已死时照常掷随机数但不附加；`xiyou_review_regressions` 加致死／存活两例（修前失败、修后通过）。
  - `XState._become_current`：新游戏、读档时清 `XDungeon.battle`；`xiyou_dungeon` 加 `load.clears_battle`。
  - 新测试 `xiyou_element_ternary`（33 项）；`xiyou_review_regressions` 加 redirect 两项；事件对照 baseline 重写（699／681／18）。
  - 框架维护约定标题与页眉。
- 验证：同步正式西游（worktree）测量不变；专项 xiyou_formulas、xiyou_review_regressions 29/29、xiyou_dungeon 594/594、xiyou_element_ternary 33/33、xiyou_event_compare 5/5、xiyou_transfer 38/38；检查.sh --oracle：（待填）。
- 提交：47de5f5、d0fa816、aadd9e0、727bfc9、de34355、0a39445、10e5fe5、0de4a3b
- 遗留：见下「交接板」。
- 给沙僧的完成度提示：
  - 楼层：四至二十五层主线算作完成，但大厅（Map004）有 8 个功能事件仍是未接的场景或脚本（仓库、换装、契约绑定、镶嵌图鉴、破阵·投影名单、闭关之所、修行建议，及 Map119 属性加点），事件对照里一直是已知不一致；副本只做了一、二、四、六、七层。
  - 敌群：隐藏成员与 335 未实现（敌群 824）；敌群事件 101 对话、336 变身仍是目标（框架维护约定）。
  - 难度：洪荒（8）的 Codex 脚本（grantTicketBonus／rollPower）在 Godot 落入未识别；轮回「随机角色」模式未做（O-035）。
  - 跨楼层共性系统里限购、守层者变体覆盖、战斗内对话、挑战技能只有参照没有实现，不应计入完成度。

## 交接板

- 遗留（建议归属）：
  - 敌群 824 隐藏成员＋335 敌人出现（车道 A 接到该敌群时做；规则级，先补 troop_event 参照）。
  - 同步脚本在 worktree 跑完后自动 `godot --import`，或在 AGENTS.md「车道交付」写明（工具，沙僧或唐僧定）。
  - `mv_script._statements` 每条语句都现编译十几个 RegEx（性能小项，可改成静态缓存；不影响结果）。
- 需要用户决定：无新增 O 项（预分配的 O-043、O-044、O-046 未使用）。

## 进度账

- 不改（完成度由沙僧复核，提示见上）。

## 本分支提交

- 47de5f5 转换器 v16 三元公式改按条件下标取值，补公式测试
- d0fa816 伤害致死后同一行动的附加状态不再生效，补回归测试
- aadd9e0 抽查：三元伤害公式与元素吸收按冻结 v0.28 实测对照（新增 xiyou_element_ternary）
- 727bfc9 框架维护约定：跨楼层共性系统分清已实现与目标，页眉更新
- de34355 事件对照 baseline：ce1440 已一致，重写登记
- 0a39445 读档／新游戏清空 XDungeon.battle，补测试
- 10e5fe5 补测试：CodexEconomy.redirect
- 0de4a3b 抽查：命中／闪避实测对照并入 xiyou_element_ternary
