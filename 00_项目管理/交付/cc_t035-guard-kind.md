# 交付：cc/t035-guard-kind

- 车道／工作者：T035 T015×T016 合后联调（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·T035·未经审查】护短归 COUNTER、segment_target 只认 ROOT（dev.待定）

T015（弱者专属词条地基 XTianqiWeakAffix）与 T016（技能重构欠账：张三丰护短）合进 main 后的两处交叉，小A 核 T015（ctx_d524543b600e）语义交叉 1/2 ＋ P3。

- `XTianqiSkills._guard`：护短在敌人这一根的 `end_action` 里跑，那时种类已被 `set_kind(FOLLOW)` 改成 FOLLOW，`not_own_action` 不认 FOLLOW，张三丰的太极拳打到混子会记「这次行动打过混子」（不服）。现在 `_cast` 前后包 `push_kind(COUNTER)`／`pop_kind`：护短是队友对敌人行动的反应，跟原生反击同类，打混子盾照扣、不记。回退走现成的 O-525 `XTianqiWeakAffix.COUNTER_NO_HUNZI_MARK`（关掉时原生反击、护短打混子都照记）。
- `XTianqiWeakAffix.segment_target`：开头当前种类不是 ROOT 就原样返回。之前根执行完以后的追加（FOLLOW_FULL 有序列走 `XActionSequence`）、再释放、反击、派生打到引导者，也会拿这一根的引导判「引导者不合法→改打原目标」并摘掉引导标签。
- `BattleLogic.execute` 非序列多段：`segment_target` 的结果放局部 `seg`，不再写回循环变量 `t`（与序列路 `_action_effect` 对称）。行为等价（见下「我不同意的地方」），是可读性修正。
- 专项：`xiyou_tianqi_skill_debt` 加 `guard_hunzi_fixture`、`guard_hunzi_follow_marks`（夹具咬得住：追加阶段直接放太极拳会记）、`guard_hunzi_no_mark`（护短实际触发 15 次左右、混子不记、护短后种类 pop 回 FOLLOW），31/31；`xiyou_tianqi_weak_affix` 加 `seg_root_reverts`、`seg_follow_passthrough`、`seg_follow_no_reuse_guide`（序列路实跑：追加打倒下的引导者跳过，不回头打原目标）、`seg_native_recast_passthrough`／`seg_native_counter_passthrough`／`seg_derived_passthrough`、`seg_rep_seq_symmetric`（非序列、序列四段打到的人逐段一样），101/101。
- 反向验证：撤掉三处代码改动单跑两专项，`guard_hunzi_no_mark`、`seg_follow_passthrough`、`seg_follow_no_reuse_guide`、三条 `seg_*_passthrough` 共 6 条失败；`seg_rep_seq_symmetric` 修前修后都过（第 3 项本就等价）。
- 西游档：`segment_target` 在非天启篇档第一行就返回 `t`，护短只在天启篇角色卡（CARDS）开着时跑，`push_kind` 没有根时什么都不做；西游档不变。
- 改了原沙僧独占核心文件：`battle/battle_logic.gd`（只 execute 非序列多段循环 7 行）。

## 我不同意的地方

1. **第 3 项（`t` → `seg`）不是 bug，只是写法**：原写法 `t = gt` 在引导回退后把 `t` 换成原目标，下一段 `segment_target(原目标)` 因不是引导者原样返回，结果与每段从 `t` 重判一样；战真印 `redirect` 取「第一个活着的、不是这个死人的敌人」是确定的，持久改 `t` 与每段重判打到同一个人。所以这一项只有对称性断言、没有能在修前失败的断言，不要把它当成行为修正去核。
2. **护短算 COUNTER 而不是 FOLLOW**：同意派单。FOLLOW 在设计表里是「主动根出手者行动执行完后的追加」，出手者是根的出手者自己；护短是对面（张三丰）对这次敌人行动的反应，本质是反击，记 COUNTER 才和原生反击打混子不记一致。设计稿 v0.3 第二节第 2 条那张表没点名护短，建议下次改稿时补一句「技能重构的护短算原生反击」，免得以后再有人按「在追加阶段跑」归 FOLLOW。
3. **segment_target 只认 ROOT 的代价**：根里嵌套的原生反击（COUNTER）同样直接返回 `t`。现阶段引导只在敌人打我方时成立、反击是我方打敌人，碰不到引导者，没影响；将来要是有「敌人反击我方」也想吃引导，得另开口子。

## 交接板

- 下一步：无新增
- 用户试玩说明：无（弱者专属词条表为空、角色卡 CARDS 默认关，玩家看不到变化）
- 需要用户决定：无

## 进度账

- 无变化（联调修正）

## 可优化（流程／工具／效率）

- 无

## 验证

- `语法检查.py`：968 个 .gd 0 问题
- 本机专项：`xiyou_tianqi_skill_debt` 31/31、`xiyou_tianqi_weak_affix` 101/101；反向验证见上
- `检查.sh --affected main --cloud`：退出码 0；云端整轮 644 场景 16 片全过（cfb5ae422，偶发 1 个：`xiyou_step_encounter_stop` 单跑通过，与本改动无关）；非 Godot 检查全过

## 本分支提交

- cfb5ae422 护短归 COUNTER、segment_target 只认 ROOT、非序列多段不覆写 t
