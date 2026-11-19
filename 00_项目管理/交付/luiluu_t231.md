# 交付：luiluu/t231

- 车道／工作者：C 规则·机制／cc（T231 弱者专属词条批 2B：张三丰、布兰德瓦登；Opus＋medium，P8）
- 状态：可合并

## 一句话

批 2B 两条专属：`w42` 布兰德瓦登「掷矛邀战」、`w86` 张三丰「护犊」，**默认关**（Kyo 11-19：不接掉落、深渊商人、物品说明）。戴着时按人屏蔽原生触发：布兰德瓦登在 `_invoke` 里扣掉反击 1162 的 30%，张三丰在 `_guard` 里跳过原生护短；反击、追击都在敌人这一根全部结算完（`root_end`）以后出。可引导名单本单只签 1 号普攻。

## 独占文件（开工列）

- 改：`modes/xiyou/core/tianqi_weak_b2.gd`（加 w42／w86 两条规则、`counter_cut`、`masks_guard`、`zhang_live`、`ward_of`，install 挂两条）
- 改：`modes/xiyou/tianqi_data/weak_affix_table.json`（加 `w42`、`w86` 两行；`guidable_skills` 签 `[1]`）
- 改：`modes/xiyou/battle/battle_logic.gd` `_invoke`（反击率扣 `counter_cut`，一处两行）
- 改：`modes/xiyou/core/tianqi_skills.gd` `_guard`（逐人判护短前 `masks_guard` 跳过，一处两行）
- 新：`tests/xiyou_tianqi_weak_b2b.gd／.tscn`
- 派单外的两处小改（必需，写明）：
  - `modes/xiyou/core/tianqi_weak_affix.gd` `guidable()`：表里 JSON 读进来的技能号是浮点，`Array.has(int)` 认不到——之前名单为空没暴露；改成 int、float 都认（一行）。
  - `tests/xiyou_tianqi_weak_affix.gd`：表里签了 1 号普攻后，地基专项拿 1 号当「没签过」的样例会失败；改为 `_table()` 之后把名单清空跑地基断言、收尾 `reload_table()`；表断言 `table_no_guidable_yet` 改为 `table_guidable_attack_only`。

## 协调定的口径（11-19，ask 回复）

1. 可引导名单本单只签 1 号普攻（敌人行动表里 1292/5195 次）；396 个单体伤害技（敌人行动表里 scope 1、伤害类型 HP 伤害／吸收的技能，按 `generated/db/Enemies.json` 的 actions 去重统计）由协调另开审查单，口径照 v0.3 第二节第 1 条「没有特殊语义的单体伤害技」＋第 4 条骑士签表。
2. 关原生 30%：`_invoke` 里对戴专属的人从反击率扣掉 1162 给的 30%（没学 1162 不扣），`counter_rule` 不屏蔽。理由：屏蔽 `counter_rule` 时别的来源给的反击率会退回原版「吞掉这次攻击＋全伤普攻」，比重构版半伤凌空斩更糟；稿 v0.3.1 写的是「别的来源给的反击率不动」。
3. 受邀只留最近一次投掷命中的那一个（v0.3 上限行，v0.3.1 整表替换后没写，保守照旧）。
4. 护犊只在重构护短开着（`XTianqiSkills.GUARD`＋角色卡）时生效；`GUARD` 关回原版 2007 时专属整条不生效（有断言 `zhang_guard_off_inert`）。

## 变更记录草稿

## 2026-11-19 【cc·T231·未经审查】天启篇弱者专属词条批 2B：布兰德瓦登掷矛邀战、张三丰护犊（dev.待定）
- 规则在 `modes/xiyou/core/tianqi_weak_b2.gd`（XTianqiWeakB2，`Brand`／`Zhang`），表 `weak_affix_table.json` 的 `w42`／`w86`，**默认关**。
- `w42` 布兰德瓦登「掷矛邀战」（设计稿 v0.3.1 第三节 42 整表替换）：戴着时反击率扣掉反击 1162 的 30%（`counter_cut`，`battle_logic._invoke` 调；别的来源不动，剩下的照走重构版半伤凌空斩）；投掷 1159 直接有效命中敌人甲 → 甲「受邀」到本自然回合结束（只留最近一个；走地基 `mark_guide`），甲的可引导根行动改打他；甲带标签期间任何一根直接有效命中他（被引导的、本来就选他的、全体技、四骑士主动技），甲这一根全部结算完他反击一次半伤凌空斩（`pct` 50）：不回 TP、专属派生（打混子盾照扣不记账）、每自然回合 1 次；他倒下、被控、甲已倒：不反不扣次数；反击后挂牛马之魂（`_arm_next`，原本就每回合最多 1 次）。
- `w86` 张三丰「护犊」（设计稿 v0.3 第四节 86＋v0.3.1 第三节 86）：只在重构护短开着时生效；戴着时 `XTianqiSkills._guard` 跳过他（`masks_guard`）；每自然回合开始在场上活着的队友（不含他）里按生命比例最低选被护者，平局取出战栏靠前的，中途倒下不重选；被护者被敌方主动根直接有效命中，敌人这一根全部结算完他对出手者追一次半伤太极拳 5860（`pct` 50，打满段数，去掉效果 44：不带太极再释放、不攒太极之力），每自然回合 1 次；他倒下、被控、出手者已倒：不追不扣。
- 可引导名单 `guidable_skills` 签 1 号普攻；`XTianqiWeakAffix.guidable` 认 JSON 浮点号（之前名单空没暴露）。
- 角标只写状态：受邀敌人头顶「受邀」、被护者头顶「受护」（复用 T230 `XTianqiWeakBadges`）。
- 玩家可见：无（条目默认关）。

## 验收逐条（卡上 7 条）

1. ✓ 两人按 v0.3.1 实装，默认关（`table_two_entries_off`）；关着时：`brand_off_cut_zero`、`brand_off_native_counter`、`brand_switch_off_native`（投掷不邀、普攻照打原目标）、`zhang_switch_off_native_guard`（原生护短照旧约 30%）。
2. ✓ 按人屏蔽：布兰德瓦登戴着被打 100 次 0 反击、0 次被吞（`brand_no_throw_no_counter`，反击率扣 30% `brand_cut_30`）；张三丰戴着别的队友被打 60 回合原生护短 0 次（`zhang_other_ally_no_chase_native_off`）。别人装上不生效（`brand_not_owner`）。
3. ✓ 反击／追击都在这一根全部打完后出（`brand_after_all_segments` 五段打完、`zhang_five_segments_once`、`zhang_chase_after_root`）；本人被控不触发不扣、解控后同回合再触发（`brand_stunned_no_counter_no_charge`、`zhang_stunned_no_chase_no_charge`）；反击不回 TP（`brand_counter_no_tp`，稿写死不回）；受邀者用不可引导技能本来就打中他也反击（`brand_direct_hit_counters`），全体技打到他反击 1 次且目标不改（`brand_aoe_counters`）；骑士主动技（`horseman_strike`）通知两人都认（`brand_horseman_strike_counters`、`zhang_horseman_strike_chases`）。
4. ✓ 派生打混子：盾照扣、不记出手者（`brand_counter_hunzi_no_mark`、`zhang_chase_hunzi_no_mark`，同 T230 的伪造瘟疫骑士夹具）。
5. ✓ 角标、日志复用 T230 出口（`brand_badge_invited`、`zhang_badge_ward`）；文字列在下面「文字」节，待小A 审。**没截图看实机**。
6. ✓ 专项 49/49（含关开关、GUARD 关、西游档 `xiyou_save_off`）；虚拟玩家 explore 14/14、短帧 climb 6/6，卡死 0、违规 0、僵局 0、SCRIPT ERROR 0。
7. ✓ `发行空壳.py check` 通过；西游 `battle_logic` 新调的只有 `XTianqiWeakB2.counter_cut`，空壳按 float 给 `0.0`（`show XTianqiWeakB2` 核过）＝不扣反击率，与西游档真脚本结果一样，**不用登记特例**。`masks_guard` 只在天启篇脚本 `tianqi_skills.gd` 里调（整份换空壳）。

## 文字（玩家可见；草稿，待小A 审）

- 头顶角标：`受邀`（受邀敌人）、`受护`（张三丰的被护者）
- 战斗日志：`%s 受邀，攻击将引向 %s`（敌人名、布兰德瓦登）；`邀战反击！`；`护犊：本回合守护 %s`（每回合第一根收尾时出一次）；`护犊：%s 追击 %s`（张三丰、敌人名）

## 验证

- 专项 `xiyou_tianqi_weak_b2b`（新）49/49：表 3；布兰德瓦登 24（关着 30% 照给、扣 30%、⑨ 100 次 0 反 0 吞、别人装不生效、投掷受邀＋日志＋角标、只留最近、② 引导改打他且打完反 1 次、挂牛马之魂、同回合不再反、③ 不可引导不改目标、本来就打中也反、⑤ 全体技、⑥ 五段打完才反、⑧ 不回 TP、骑士主动技、⑦ 被控不反不扣解控再反、甲已倒、回合末摘标签、半伤比 0.38～0.62、混子不记、开关关）；张三丰 19（屏蔽原生、平局取前、比例最低、角标、① 追太极拳四段、只太极拳不带 44、太极之力 1204 不变、守护日志、追在根后、② 同回合不追、③ 别人被打不追且原生关、⑤ 五段 1 次、⑥ 全体 1 次、骑士主动技、⑧ 被控不追不扣解控再追、④ 被护者倒下不重选、出手者已倒、半伤比、混子不记、GUARD 关不生效、开关关原生照旧）；西游档 1。
- 本机相关专项（`--headless --audio-driver Dummy`，`并行测试.py --full`）：`xiyou_tianqi_weak_b2b` 49/49、`xiyou_tianqi_weak_b2` 60/60、`xiyou_tianqi_weak_b1` 31/31、`xiyou_tianqi_weak_affix` 101/101、`xiyou_tianqi_skills` 245/245、`xiyou_tianqi_skill_debt` 31/31、`xiyou_determinism` 372/372、`xiyou_counter_guard` 27/27、`xiyou_tianqi_horsemen_battle` 142/142、`xiyou_tianqi_plague` 98/98、`xiyou_tianqi_affix_battle` 86/86、`xiyou_battle_ui` 182/182、`xiyou_ui_skin_battle` 67/67、`xiyou_tianqi_qiyin_effects` 63/63、`xiyou_otb` 34/34、`xiyou_battle` 9/9，全过。
- 虚拟玩家（本机，条目默认关＝回归）：explore（种子 1）14/14、卡死 0、违规 0；短帧 climb（40000 帧，种子 1）6/6、卡死 0、违规 0、僵局 0；两局日志 SCRIPT ERROR 0。climb 这局第 1 层守层者全灭 1 次（条目全关，与本单无关）。
- 没跑云端选测、没跑全量 `检查.sh`。

## 要 Kyo 定

- 无。

## 异议

- 无（三处口径已 ask，协调按我倾向定）。

## 交接板

- 下一步：8 条样板实装齐（默认关），等 Kyo 统一开放；396 个敌人单体伤害技的「可引导」签表另开审查单（协调已应）。
- 用户试玩说明：无（默认关）。
- 需要用户决定：无。

## 进度账

- 天启篇弱者专属词条：8 条样板 6/8 → 8/8（批 2B，默认关）。

## 可优化（流程／工具／效率）

- 建议：`XTianqiWeakAffix` 其余读表名单（如 `casts.has(float)`／`has(int)` 两头查的写法）可以统一在 `data()` 读表时把技能号整数化，省得每处两头查；本单只修了 `guidable`。

## 本分支提交

- dd710c81a WIP：两条规则＋专项 49/49
- d39ab99fa 交付单
- 新专项 uid（见 git log）
