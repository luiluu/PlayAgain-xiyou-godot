# 交付：luiluu/cc-t281-smart-ai-fix

- 车道／工作者：T281 智能AI①止血／cc 车道（Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T281·未经审查】天启篇智能战斗AI止血：重构技估伤接通、公共事件技解封、护盾账本（dev.待定）

- 依据：私密仓《天启篇_智能战斗AI评估_Neon_v0.1》第零～二节、实现卡草稿 1（Kyo D236「乙」先卡1 再卡2）。
- 开关 `XSmartAI.o_tianqi_smart_ai`（默认开，O-待定·天启篇智能AI止血）：天启篇存档（`XTianqiSkills.cards_on`）才进新分支，西游档永不进；关掉回原样。
  1. 估伤：`formulaProgram.module` 为 `tianqi_skill`／`gojo` 的重构技不再被 `formula_safe` 一刀切成 0，走原有 `XDamage.eval_formula` 只读预览；段数用改写后的 `yepEffects`（不再叠黄泉／流萤／镜流的旧段数包装）；熟练度读天启篇每级 +3%／上限 10 级；141～166 号不再 ×0.01。
  2. 公共事件技（r1 返修收窄）：只放 `XTianqiSkills.has`（重构表内）且自带伤害／治疗类型的技能（含雷切 5888、张三丰 5848），加白名单入口命运之手 6861（按落点 6862～6867 的平均期望伤害给最小估分）；整条公共事件递归查 117 子事件，出现 102～105、125、201、301～303、340、351～354 任一指令就不放行（重构表内的王八拳 4374 等扣金币技随之不放行）；重构表之外的老技能（如 345 一掷千金）和 68 招纯功能 CE 技仍封。
  2b. r1 返修：重构技（tianqi_skill／gojo 模块）估伤先于旧西游 ai_raw（屠苏 176 不再被 `XTusu.ai_raw` 截成旧系数）；同时不叠旧档案段数／倍率／穿透、`boosts`、`expected_rate`、`crit_bonus`（渡鸦、米拉）。
  3. 护盾：`shield_points` 加 `XShieldLedger.amount`（厚盾队友不再误判濒死急救）；`shield_estimate` 认 `skill_rework.json` 的 `shield.pct`（钟离 5671／5672、立希 5648、云霄 5571）。
  4. 五条悟茈：`XGojo.ai_preview`（只读）开着且没有 `cast` 时按当前苍、赫印对数估，不写状态。
  5. 过时注释已改（smart_ai.gd 头注释、smart_ai_profiles.gd：镜流／饿狼西游档早已移植）。
- 玩家可见：无文字改动；天启篇自动战斗会放主力技、会开护盾、命运之手与雷切进选招。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/battle/smart_ai.gd` `XSmartAI.o_tianqi_smart_ai`；`core/gojo.gd` `XGojo.ai_preview` | 智能战斗 AI 的估伤只认老西游的受限公式，天启篇重构技的模块公式全估 0；带公共事件的技能（命运之手、雷切、治疗复活类）全被拉黑；护盾只读原生护盾；141～166 号估伤 ×0.01 | 天启篇存档里模块公式参与只读估伤、公共事件伤害／治疗技与命运之手放行、护盾算来源账本并估重构护盾技、去掉 ×0.01、熟练度读天启篇口径；西游档不进新分支 | 天启篇自动战斗原本几乎只平 A（Neon 评估 T274） | `XSmartAI.o_tianqi_smart_ai = false` | cc（T281） | 保留 |

## 实跑证据

- 虚拟玩家 explore（`--vp-mode=explore`）：TEST_RESULT 14/14，报错 0。
- 短帧 climb（`--vp-mode=climb --vp-ff --vp-difficulty=jianxian --vp-frames=40000 --vp-seed=2 --vp-pass-after=3`）：到第 5 层（通过 4 层）、TEST_RESULT 6/6、报错 0、无卡死。虚拟玩家是手动打，不走自动战斗。
- 「自动战斗现在会放主力技」的实跑证据：专项 `xiyou_tianqi_smart_ai` 里天启篇档 `XSmartAI.choose` 开关开时逍遥选主力技 4749，关时选平 A（原来全 0 分退回普攻）。

## 交接板

- 下一步：卡 2（统一估伤到 XDamage 预览、元素牌组／总账／烙印）等 Kyo 排期；本单没做。
- 用户试玩说明：天启篇开「智能战斗AI」自动战斗，重构技会被选用，不再只平 A。
- 需要用户决定：无

## 进度账

- 部分：智能AI天启适配 0% → 卡1 完成（止血档），依据：专项 57/57＋旧回归全绿。

## 可优化（流程／工具／效率）

- 建议：卡 1 未做项留给卡 2／3：热循环 RegEx 预编译（评估 #11）、`is_boss` 补天启首领、大炮打蚊子溢出折损、消耗品保护、`longFight` 判定、嘲讽／反伤感知；本单按「最小可用」没碰。
- 更正：流萤 10622／10623 在 skill_rework.json 里已是 tianqi_skill 模块（带 cap_hits 5／9），会走新分支；因新分支不叠 `XSmartAIProfiles.repeats` 且原表 yepEffects 为 1，没有重复乘段数；专项已补两招非 0 断言。cap_hits 的段数口径仍留卡 2 核。
- 带去卡 2（T282）：P2-3 入口技计入 damageScale／best_attack；P3-1 shield_estimate 旧正则先于 tq_shield；P3-2 `_cur_skill` 静态字段只读语义；P3-3 热循环 RegEx 预编译。
- 已知：5.0 以上 5 人组里超强者数量受难度上限限制（专项统一用 lianyu 开局）。

## 本分支提交

- 9a777df32 T281：天启篇智能AI止血（后续有一提交补注释号与交付单）
