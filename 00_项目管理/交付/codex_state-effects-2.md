# 交付：codex/state-effects-2

- 车道／工作者：翻译／核查 · Codex（沙僧）
- 状态：进行中
- 独占：battler.gd、damage.gd、core/state_effects.gd、battle_logic.gd 的状态接线、state_effects_probe 与测试、转换器状态效果解析；不碰切片、角色测试、界面和工具脚本。

## 变更记录草稿

## 2026-10-22 【Codex·沙僧】核查 dev.122 与 wukong-35

- 核查覆盖：claude/bajie-44、claude/wukong-35、0a5ec4c、36696e3；文档登记 1f5e218、4835d00、5efdd50、fc79c3e、4aab2c4、4d5e9c6。
- 报告：[本批核查](../核查报告_20261022_dev122.md)。bajie-44 通过。wukong-35 的图片编码与敌群 163 误删两项 P2 已由 0a5ec4c／36696e3 修复；图片修复又使 8 项工具测试夹具报错，仍需八戒处理。最终同步确认六个难度各保留敌群 163 的 351 条伤害参照，不再沿用中途副本的 315 条口径。
- 发布状态：两批已合入本机 main；收尾实查 main 为 36696e3，GitHub main 为 4d5e9c6，尚未推送，总装统一检查仍在进行。
- 混合批只核 Claude 的合并登记；沙僧自己的报告、formula-rest 仍待 Claude，不能以本条自销。

## 2026-10-22 【Codex·沙僧·未经Claude检验】状态效果第二期第一小期：生命周期／热缓存与旧 op 迁移（dev.待定）

- **行为**：新增状态只发一次 apply；重复附加只续时长，不重复 apply；FIX 全局锁拒绝 apply 内再次 add_state。remove／leave 在状态已移除后触发，来源保留到两段结束，自然到期中的嵌套驱散继承 leave 范围。保留角色既有 remove_state 签名，以 remove_state_auto 专门承接到期，未改角色实现。
- **KRZ 缓存**：角色与敌人各持有状态效果快照、各 phase 热列表与 dirty。add/remove 结束标脏，param_refresh 消费脏标记时才更新；phase 入口不自动刷新，已移除状态可留在旧热列表中继续触发。battle/胜逃败仍按单位直接列表分发。预览读取已有列表或私下算列表，不热身真实缓存、不调用 observer。
- **统一旧 op**：damage.gd 的 confirm/react 倍率与 battle_logic.gd 的 establish 参数追加伤害都转给 XStateEffects 同一路径；固定减伤仍夹在 confirm 与 react 之间，respond／establish 在实际伤害结算后。既有额外伤害的资源上下文、记录量和最后弹字约定保留，不双跑。每状态调用使用自己的 user/target/origin/value/critical 与上下文栈。Math.round 走 JS 取整（含负半整数），已有 Math.ceil/floor 次序不改。
- **先参照后实现**：state_effects_probe 加 actor/enemy 生命周期（重复／不存在的移除／自然到期／嵌套 add 与 leave／来源保留）及原生 Math.round 边界，原 14 例保持不变。Godot 专项扩成完整 action 四段＋伤害四段，并把原先“热缓存差异”改为严格比较；克隆预览不写缓存有专项断言。
- **范围与尾巴**：仅迁两个旧 op，没有翻译任何新 js 形状；crit、OTB action_end 按原版不触发；13 个畸形标签漏导、重复同 phase 脚本合槽、状态私有数据／永久参数／公共事件、错误数据与奈叶等留后续分期。转换器本期未改，未把原版报错变成有效效果。2652 的不续时长特例、完整 Reapply Rules 与资源层直接清状态等既有差异不在本小期宣称完成，需后续专门参照，不能据此开放依赖它们的新形状。
- **验证**：九个相关专项全过：state_effects 60、actor_p0 3124、determinism 372、formula_effects 908、formula_rest 1352、imported_balance 273、rules 124138、shield 565、transform_params 249；本轮 311 秒，无偶发。rules 单场 311 秒超过 300 秒提示，属本机满载，未改工具／角色测试。额外 Establish／记录专项和同步结论收尾补入。
- **维护**：新 shape 必须整块匹配、先有有效源参照；不要把本期诊断过的 js 计作已实现。车道只跑专项，合并后全量由总装统一检查。

## 交接板

- 新问题：0a5ec4c 已修素材格式，但测试转换器写入.py 的假图片夹具令 8/8 项报错，需工具车道更新夹具并补格式正规化回归。敌群 163 的 P2 已由 36696e3 恢复且同步确认保留；先前仅按运行时判断为 P3 的口径已更正。沙僧不修改这些独占范围外文件。
- 状态效果本期：先生命周期／热缓存与既有 op 统一，不翻译新 js 形状；原版报错与不触发继续保留。

## 进度账

- 不自行调整完成度；角色加回估值未复核入账。

## 本分支提交

- 见本分支历史。
