# 交付：claude/bajie-wtype

- 车道／工作者：B 规则／八戒（Claude，重制_八戒_4，沿用）
- 位置：worktree `.claude/worktrees/bajie-flow-test-3b9e3c`，分支 `claude/bajie-wtype`
- 状态：进行中
- 任务（唐僧 2026-10-15 派）：XBattleLogic.can_use 补 MV isSkillWtypeOk（技能要求武器类型），XPower 改用同一实现；严格级参照探针逐例比对 canUse。

## 本分支提交

- （本提交）开工交付单

## 停在哪里（重制_八戒_4，上下文到 60% 停下）

- 已做（上一提交）：`XBattleLogic.wtype_ok`／`wtype_equipped`（MV Game_Actor.isSkillWtypeOk；isWtypeEquipped 经 dsPassiveSkill：被动 <SkETypeAll: t> 装着任一列出类型时全算装着，<SkEquipType: t> 只认该类型，否则看身上武器），`can_use` 调用它；`XHangUpAuto.wtype_ok` 改为转调；XPower 去掉另判。新探针 `mv_oracle/wtype_probe.cjs`（加进 PROBES，输出 wtype.json）：切片角色 10 级 × 默认／裸装／12 种武器类型第一件 × 技能，1036 例；`tests/xiyou_wtype` 武器判断全部一致（1038/1038）。
- canUse 未逐例比：测试搭法下 Godot 角色 10 级 MP 上限（480 等）与正式版（200 等）全部不同（测试打印 MMP_DIFF），费用判断不可比，暂只比武器判断。下一步先查这差 280 的 MP 从哪来（xiyou_power 同样搭法时 MP 相关的出手顺序是对上的——对比两个测试的搭法：power 走 XEquipment.clone＋refresh_passive）。
- `检查.sh --oracle` 未过（39 个通过）：`xiyou_battle_ui`（skill_opens_target、skill_target_cancel_to_list）与 `xiyou_combat`（cooldown_set/tick1/ready 技能 499、counter_logged）失败——夹具让没装对应武器的角色放要求武器的技能，现在按正式版被拦下。下一步：给这两个测试的角色装上对应类型武器或换不要求武器的技能（不改规则）。
- 交接板草稿：用户试玩说明「没装对应类型武器时，要求武器的技能不能用（与原版一致）」。
