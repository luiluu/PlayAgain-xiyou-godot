# 交付：codex/state-effects-2b

- 车道／工作者：翻译／核查 · Codex（沙僧）
- 状态：进行中
- 基点：main 09ebfb0（合并 codex/state-effects-2），按用户要求新建工作树。
- 范围：第二期第二小期。完整伤害链上下文贯通，先接整块匹配的四种常量加成子形状；余项下一期。
- 独占与停手：照本聊天用户分工，不碰 actor.gd、切片、角色／界面／工具测试；某期必须改范围外核心先写提案跳下一期，连续两期无可交付成果停。
- 原版行为：每种新形状先补 mv_oracle；原版报错与不触发不自动修复。

## 变更记录草稿

## 2026-10-22 【Codex·沙僧·未经Claude检验】状态效果第二期第二小期（dev.待定）

- 原版参照已通过：新增 bonus.native_blocks，四种整块子形状、28 个状态 confirm 槽 × 7 个 value × 4 个伤害类型 × 2 个暴击布尔，共 1568 行；探针总 18 例，退出 0，无 errors。旧 17 例与本工作树 generated/oracle 中的既有参照逐项相等。产物在本树 03_再刷重制_Godot/03_转换工具/mv_oracle/.sandbox/state_effects.json，尚未改翻译器或运行时。
- 接续：重制_沙僧_40 在同一工作树接力，实现四类整块常量加成（local bonus；finalRate；finalRate＋critical bonusRate；前者后接独立 floor 语句）。保持每一步基于已更新 value，负系数也原样，不能合并总倍率；原 127 个旧 op 输出不变。用 1568 行逐项比对并补半匹配不能接受的拒绝断言。
- 完整伤害链仍需做：贯通资源／结果槽、vars／switches／RNG 与 critical 上下文，预览不写真实状态与诊断。注意 BSC 的 confirm/react 位于 executeDamage，makeDamageValue 只做数值计算；当前 _damage_value 直接 finish，测试 xiyou_drop_record 子类覆写它会绕过 confirm/react，统一时要保留这个覆写签名，不改该角色外测试。respond 的返回 value 在原版会传给 establish，现 _establish 丢弃返回值，这也是本小期挂点改动要覆盖的边界。不得动 certain_hit()。
- 核查交付另见 codex/review-dev122-123（最新 157e08e），main 新的 dev.123 收尾 5c1bf82 仅登记／版本变化，需随核查单补登记。09ebfb0 的沙僧实现仍待 Claude，不自核。

## 交接板

- 本期不调整进度账。

## 本分支提交

- 见历史。

## 后续期与边界提醒

- 第二期其余形状接着做；每种先有原版参照，整块匹配，不把未知副作用吞掉。
- 第三期 param_add 必须接 actor.param_plus／保存加载，actor.gd 被用户明确排除；若确认无法在现有接口完整实现，按停手规则写具体提案到该期单并跳第四期，不擅自改 actor.gd。
- 第四期原版 reserveCommonEvent 是覆盖单槽；若预约消费必须改 battle_event_runner 或 XState 等范围外核心，同样具体提案后跳第五期。连续两期无可交付成果则停手回报，不能为了触达第五期违反条件。
- 第五期只做1741～1749状态效果：1741/1742的this.user、1743畸形结束标签、1747括号语法错、1748 attackCount、1749 criticalRate都要先量实际无效／报错；1744～1746无 Custom 块。108奈叶归悟空。
- 本聊天临时等待跟进已删除（条件已触发），没有活动自动化；不要另开重复监视。主工作区和其他车道保持原样。未提交改动为无，当前无长任务仍在跑。
