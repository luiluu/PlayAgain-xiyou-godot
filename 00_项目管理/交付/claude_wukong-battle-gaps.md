# 交付：claude/wukong-battle-gaps

- 车道／工作者：C 规则（暂由 A 车道接）／悟空（Claude）
- 状态：可合并

## 变更记录草稿

## 2026-10-31 【Claude·悟空·未经Codex检验】战斗核心三条：百分比 MP 消耗进实扣、角色能力上限、黄泉 3.9% 查明（dev.待定）

- **百分比 MP 消耗（白龙_6 报：说明卡对、实扣偏少）**：`XBattleLogic.skill_cost` 原来只用数据库的 `mpCost`，`<MP Cost: x%>` 只在说明卡（`XCharacterHelp._cost`）里加。改成和原版同一条链：
  - YEP_SkillCore 备注（`note_costs`，照原版正则：逐行、冒号后恰一个空格、只认整数）：`<MP Cost: n>`／`<TP Cost: n>` 改基础消耗，`<MP Cost: n%>`／`<TP Cost: n%>` 记最大 MP／TP 比例；skillMpCost＝⌊(基础＋最大MP×比例)×消耗率⌋、不低于 0，skillTpCost＝⌊基础＋最大TP×比例⌋，再接原有的 dsPassive 减耗、米拉禁忌、异化缄默、鬼族。
  - installSkillCostRuntime 第 5 节（最外层）：角色的技能带最大 MP 比例、合计减耗低于 −100%（挑战加耗）时，按原减耗与按 −100% 各算一次，再按比例部分所占份额合成（`percent_share`、`PERCENT_FLOOR`）。
  - 说明卡 `XCharacterHelp._cost` 改为直接调 `skill_cost`，两边不再各算一套。
  - 原版正则的两处边界照原版：7225 降众天华写的是 `<MP Cost: 7.5%>`，原版认不出（比例 0），所以带比例的技能是 43 个不是 44 个（原来说明卡按 7.5% 算，和原版不一致，这次一并对上）；9944 元气蛋 `<TP Cost: 200>` 把基础 TP 从数据库的 100 改成 200（原来重制按 100 扣）。
- **角色能力上限（白龙_6 报）**：`XBattler.param_max` 原来是 1e30（不夹）。`XActor.param_max` 改为 YEP_CoreEngine 的 Actor MaxHP／MaxMP／Parameter＝99999999（8 项都一样，在 G_StateParam 的 param 那一层夹，外层包装照旧），饿狼 173 照 installNativeGarouRuntime 的 paramMax 包装放到 999999999999。米拉、宿傩、小猫剑圣原来就按 `param_max` 夹，跟着生效。敌人上限没动（原版敌人生命／能力 1e45、魔法 1e21，重制 1e30，实战够不到）。
- **黄泉 55 级伤害低约 3.9%（白龙_5 报）**：查明是**五乘区修正**，不修。正式引擎 CodexDamage 的 breakdown 逐环对照（黄泉 55 级、敌群 3 第一只、10171～10174）：公式值、熟练度（0 级）、技能倍率、加算 1.88、元素 1.77、攻防比、抗性、受伤率、暴击、防御都一致，只有成长修正 growth＝1.0408107741923882（原版 origins「五乘区修正 ×1.04」；CodexZones 的 top 只有「人物自身·分档系数（P3）」一项，真气 rate 与天道补偿都是 1）。重制 growth 写死 1，是用户 2026-10-27 定的「五乘区维持不移植」（交接板已定事项），所以这 3.9% 是已定的刻意差异；四个技能比值相同也对得上（修正值只按角色算，与技能无关）。
- **参照 `mv_oracle/battle_gaps_probe.cjs`（新，定向、不接全量同步）**：真实冻结插件、全内存新局；产物 `.sandbox/battle_gaps.json` 拷成 `tests/fixtures/battle_gaps_oracle.json`。222 例：43 个比例技能 × 5 种（基础／最大 MP 加 87654／消耗率 0.63／减耗 30／加耗 600），加 7225、9944 两个备注边界；能力上限 5 例（加值未超／加值超／加值未超但比率 ×10 后超／饿狼超 1 亿／饿狼超上限）。
- **新专项 `xiyou_battle_gaps`**：逐例比实扣 `skill_cost`、说明卡 `_cost`、最大 MP；能力上限比 8 项 param、上限、mhp／mmp。
- **测试放开上限**：46 个楼层／流程测试拿装备把队伍属性堆到 1e13～2e19 好一回合打完守层者（`item.params = [1.0e14, …]`），上限夹住后打不过（云端首轮 floor_run_b／c、reach225 失败）。加 `XActor.test_param_max`（大于 0 时代替上限，只在测试里设），这 46 处堆属性的下一行设 1e30，测试意图不变。

## 交接板

- 下一步：无新增（五乘区维持不移植，已定）。
- 用户试玩说明：渡鸦、米拉、哪吒等带「最大 MP×%」消耗的技能，战斗里实扣的 MP 和说明卡一致了（原来实扣少了百分比那部分）；挑战加耗很高时，百分比那部分最多 ×2。元气蛋按 200 TP 扣。角色生命、魔法和各项能力最高 99999999（饿狼 999999999999）。
- 需要用户决定：见下「优化登记草稿」O-待定（7225 的 7.5% 要不要按作者本意算），默认照原版。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 7225 降众天华 MP 消耗（XBattleLogic.note_costs） | 备注写 `<MP Cost: 7.5%>`，YEP 正则只认整数，比例为 0，只扣基础 1000 MP；同门 7226 山泽麟迹 15% 照常 | 未做：建议认小数（按 7.5% 收） | 作者显然想按最大 MP 收费，原版写法失效 | 不做即原版 | Claude（悟空） | 建议，等用户定（默认照原版） |

## 进度账

- 战斗规则：补三处小缺口，完成度不变（量小）。

## 可优化（流程／工具／效率）

- 建议（规则车道）：**YEP 技能 HP 消耗没移植**：17 个技能写了 `<HP Cost: n>`／`<HP Cost: n%>`（834、2358、3913、3926～3929、4780、5633、5635、5637、5757、5763、6037、7471 等），重制 `skill_cost` 没有 HP 这一项，能不能用和付费都不看生命；原版 canPaySkillCost 要生命大于消耗、paySkillCost 扣生命。预计一条小车道（费用、能否施放、技能页显示），参照沿用 battle_gaps_probe 的写法。
- 建议（规则车道）：谷雨按最大 MP 比例收费（installCombatPowerRuntime 的 `CFG.mp`：⌈mmp×比例×mcr⌉ 再吃通用减耗）没移植，谷雨上线时一起做。
- 建议：生命心钢（installNativeHeartsteelRuntime）算生命上限的副本 paramMax(0)＝∞，心钢上线时注意它要绕开这次的 99999999。

## 验证

- 参照：`node battle_gaps_probe.cjs` 222 例、无报错（正式冻结 v0.28）。黄泉对照用临时脚本（同 yomi_battle_probe 的 battle()，调 `CodexDamage.calculate(…, {preview, isolated})` 取 breakdown），数据见上，脚本没入库。
- 专项 `xiyou_battle_gaps` 891/891。反向验证：不算最大 MP 比例 461/891；不设 −100% 下限 805/891；上限放回 1e30 880/891；复原 891/891。
- 云端选测：首轮 260 场景 29 个失败，其中 26 个（xiyou_rules 六难度各段、xiyou_equipment、xiyou_mira_battle）是本工作树的转换产物还停在技能树分支的 TOOL_VERSION 21，`--补齐` 重转后本机通过；另 3 个（floor_run_b／c、reach225）是上面的测试堆属性，加 `test_param_max` 后本机通过。第二轮（4a0d9fc3）云端整轮 268 个场景全部通过，偶发 1 个（xiyou_floor_reach080，单跑通过）。
- 改动的原沙僧核心文件（请审查重点看）：`battle_logic.gd`（`skill_cost` 拆成 `note_costs`／`percent_share`／`consume_reduce`／`_skill_cost`）、`actor.gd`（`param_max`、`test_param_max`）。另改 `ui/character_help.gd`（`_cost`）。白龙_6 渡鸦的钩子在 `battler.gd` 的 `_add_state`，本分支没碰 battler.gd。
- 没改切片、转换器、同步探针清单，不需要重同步。

## 本分支提交

- bcf828c0 百分比 MP 消耗进实扣、角色能力上限、定向参照与专项
- 4a0d9fc3 流程测试的队伍属性放开上限（test_param_max）
- （本提交）交付单可合并
