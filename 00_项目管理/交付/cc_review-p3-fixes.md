# 交付：cc/review-p3-fixes

- 车道／工作者：C 规则／机制（cc，review-p3-fixes；本单配 claude-sonnet-5-5＋medium，因为规则已定、改动小的修补）
- 状态：可合并
- 车道路径：无（用 Orca 工作树 `review-p3-fixes`）

## 变更记录草稿

## 2026-11-15 【cc·未经审查】补核查出的口径与 P3 小修（dev.待定）

- Kyo 11-15 定的口径：①苍龙破晓号角 274 要等漩涡二阶段过场（`CodexWhisper` 的 rift2）看过之后才上架兑换大厅号角商店，新档买不到；已有 274 号角或 146 已入队（背包／仓库／队伍）的老档不受影响；回退开关 `XImportedBalance.HORN_AFTER_RIFT2`。②瘟疫骑士混子嘲讽维持「全体挑衅，群攻也只能打混子」（只补代码注释与设计稿）。③混子之盾碎后清零重新攒：碎盾当回合剩余与嘲讽解除那一回合打混子的伤害不记入累计，恢复后从 0 起。
- 直接修的 P3：瘟疫骑士不服满 6 层失控传 3 层给队友后，接收方立即再判满 6（递归，每次失控清零，必收敛）；战力页心钢「第 N 阶」改读 `eff_stage`；affix-absorb 三条（`lose_gear` 先 `XAffixAbsorb.real()`；视图缓存满 64 只丢最早一条、不整表清空；`has_absorb_weapon` 改读 `raw_equip_list`）；号卷（trumpet）一条（`forget_paid` 未学会提示在天启篇改说「号卷」）。
- `vegeta_tune.gd` 乙档会连带改 9933「普通一拳」共用的状态 2565：只在代码里写了注释，没改行为（甲档不改，无实际影响），见下「需要用户决定」。
- 私密设计仓（`xiyou-design-docs/重制设定/`，已推送 `3bfe054`）另存新版本：四骑士数值稿 v0.5、词条重构设计稿 v0.4、四线异化与异化装备重构 v0.9、四线剧情与关卡设计稿 v0.5、全角色技能重构 v0.2。
- 验证：语法检查 0 个问题；专项 `xiyou_rift2_canglong`、`xiyou_tianqi_horsemen_battle`（新断言反向验证过：撤掉修复后恰好那几条失败）、`xiyou_tianqi_horsemen`、`xiyou_tianqi_plague`、`xiyou_map132_shop`、`xiyou_lobby_shops`、`xiyou_power`、`xiyou_affix_absorb`、`xiyou_tianqi_trumpet`、`xiyou_power_books`、`xiyou_power_books_boundary`、`xiyou_demon_crown`、`xiyou_sell_lag` 全部通过；其余见下「验证」。
- 提交：见「本分支提交」。
- 未完成／已知问题：#087 乙档的 2565 共用问题、混子之盾累计（已按 Kyo 追加口径做完）、#047（等依据）不属本单。

## 交接板

- 下一步：总装合并后给 #005 #016 #019 #087 #033 #034 #057 及 affix-absorb、trumpet 剩余甲档报告里对应 P3 销账（这些 P3 已处理，见下表）；这批改了 `actor.gd`（一行 `raw_equip_list`）、`xstate.gd`（`lose_gear` 开头一行），请沙僧重点核这两处。
- 用户试玩说明：新档进兑换大厅的号角商店看不到「苍龙破晓号角」，看过漩涡二阶段过场后才会上架；瘟疫骑士战里混子之盾碎后到嘲讽恢复期间的输出不再算进下一面盾。
- 需要用户决定：**#087（请协调问 Kyo）**——切乙档（`XVegetaTune.TIER = "乙"`）会连带把 9933「普通一拳」的终伤／爆伤也从 188% 改成 100%／50%。要不要连「普通一拳」一起改？若只想改贝吉特的「合体赛亚人」9940，需要把 9940 改挂一个复制出来的新状态（改技能备注的 `StartPushState2565` 与状态表追加一行），牵涉状态表和技能表两处。现在是甲档，不改，无实际影响；本单没动行为。

## 进度账

- 部分：天启篇核查 P3 清理；无完成度变化。

## 逐条处理（派单第 1～7 条）

| 条 | 处理 |
| --- | --- |
| 1 苍龙号角挂 rift2（#005） | 做了：`imported_balance.gd` 新增 `canglong_horn_on_sale()`＋`HORN_AFTER_RIFT2`，`item_marks.gd` 的 `shop_goods` 里过滤；新档看不到、`whisper_mark('rift2')` 后能买、已有 274／146 入队的档不受影响、开关关回「解放即上架」都有断言（`xiyou_rift2_canglong`） |
| 2 嘲讽全体挑衅（#016） | 不改行为；`tianqi_horsemen.gd` `filter_targets` 补注释；设计稿四骑士 v0.5 写明「混子嘲讽为全体挑衅，群攻也只能打混子（与异化挑衅者不同）」 |
| 2＋追加：盾碎后清零重攒（#016 :668～680） | 做了：`_shield_hit` 在 `broken_turn >= 0`（碎盾后到嘲讽恢复前）不记累计，恢复时再清一次；断言：碎盾回合、窗口回合全力打混子累计仍为 0，嘲讽恢复后第一下不再碎；设计稿 v0.5 同节写明 |
| 3 不服传递再判（#016 :664） | 做了：传过去改走 `_defiance` 递归；断言：全员 4 层、攒满者失控传 3，队友 7 层也立即失控且没有人停在 ≥6 |
| 4 战力页心钢（#019） | 做了：`power.gd:333` 改读 `eff_stage`（页面现在藏着，无需新断言） |
| 5 #087 2565 共用 | 看清：9933「普通一拳」也 `StartPushState2565`，乙档会误伤；甲档不改。拿不准怎么改（涉及复制状态），只在 `vegeta_tune.gd` 写注释，问协调（见上） |
| 6 乙档数值小差 | 按「以代码现值为准」回写设计稿，不改代码：终焉分解能量 8（异化 v0.9、剧情稿附录 v0.5 改成 1／2／5／8）；净化退还 1／1／3／5 其中终焉 5（异化 v0.9）；万剑归二 13.9（技能重构 v0.2）；词条闪避／生命回复／敏捷／魔法回复／吸血／再释放／恢复／全能整数化后现值回写进词条稿 v0.4，并写明回复类量级是稿 v0.3 的 4 倍（生命回复极 2%→8%/回合），回复类量级若要再收待实测后单独改 |
| 7 剩余甲档 P3 | 修了 4 条：affix-absorb 三条（见上）、trumpet 一条（`forget_paid` 提示）。没有牵涉规则、需要问的 |

## 可优化（流程／工具／效率）

- 建议：交付单「验证」里 `选测.py main --list` 在碰 `actor.gd`／`xstate.gd` 时会扩出 500+ 个场景，车道本机跑不动；这类小改动应有「受影响但只改一行」的缩小口径，由总装在合并时 `--affected --cloud` 跑全。无本单可做的实现。

## 验证

- 语法检查：876 个 .gd，0 个问题。
- 本机专项（全部通过）：见变更记录草稿里列的 13 个，另跑了 `xiyou_determinism`、`xiyou_imported_balance`、`xiyou_vegeta_tune`、`xiyou_item_marks`、`xiyou_heartsteel`、`xiyou_power_hidden`、`xiyou_status_power`、`xiyou_growth_forge`、`xiyou_warehouse`、`xiyou_equipment`、`xiyou_tianqi_death`、`xiyou_tianqi_war`、`xiyou_tianqi_save`、`xiyou_hidden_actors`、`xiyou_shop_buy`（15 个全部通过）；工具快速回归 `工具回归.py` 全部通过；交付自检 `交付自检.py` 通过（快车道）。
- 没跑：`选测.py main --list` 给出的 575 个场景（改了 `actor.gd`、`xstate.gd` 被扩成战斗核心＋全部引用面）。原因：本机跑不动，且这两处只是一行替换（`raw_equip_list`、`lose_gear` 开头规范化），按规则交给总装合并时 `--affected --cloud`。合并碰 `actor.gd`：这两处不是原版移植逻辑本身（吸取视图是重制自有层），不加 `--oracle`。

## 待交叉核查

- `actor.gd`（`has_absorb_weapon` 一行）、`xstate.gd`（`lose_gear` 开头一行）：原沙僧核心文件，请重点核。
- 本分支提交的改动都在 `tianqi_horsemen.gd`、`imported_balance.gd`、`item_marks.gd`、`power.gd`、`power_books.gd`、`affix_absorb.gd`、`vegeta_tune.gd`（仅注释）。

## 本分支提交

- b54a3186b 核查 P3 小修（代码、测试）
- 本交付单提交（见 git log）
