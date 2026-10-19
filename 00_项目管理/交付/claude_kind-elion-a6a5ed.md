# 交付：claude/kind-elion-a6a5ed

- 车道／工作者：C 规则／八戒（Claude，重制_八戒_27）
- 状态：可合并

## 变更记录草稿

## 2026-10-19 【Claude·八戒·未经Codex检验】战斗规则三处偏差：必中附加状态、变身后完全回复、完全回复保留常驻状态（dev.待定）

- **必中技能附加状态**（`battle_logic.gd` `_apply_effect` 效果 21）：冻结源 `YEP_BattleEngineCore.js:3541` itemEffectAddNormalState 对必中（hitType 0）的技能／物品不乘状态有效度与幸运差，Godot 原来一律乘。改为：指定状态（dataId≠0）且必中时几率只取效果值；普攻附加状态（dataId 0，itemEffectAddAttackState）照旧乘有效度、attackStatesRate 与幸运差。状态抵抗（特性 14）仍挡住。幸运差公式提成 `_luk_rate`。影响面：冻结源 535 个技能、66 个物品是「必中＋指定附加状态」；对自己或幸运相同、有效度 1 的目标结果不变，其余（敌方幸运高、有状态有效度）几率变为原版值。敌群 462 金角强制 8111 给银角加轮回困难 1460 现在加得上。
- **336 变身后的 334 完全回复**（`enemy_transform`／`enemy_recover_all`，`XBattler.stale_caps`）：冻结源 G_StateParam 的能力值缓存 `_baseParamCache` 在变身时不清（YEP_EnemyLevels 只清自己的 `_cacheBaseParam`），要等 krz_state_re 的 need_refresh（加减状态、回合开始／结束）后的 refresh 才重算；公共事件 1397／1399／1400 第一句就是 334，于是按变身前形态的上限回满。现在变身时把旧 [生命上限, 魔法上限] 记进 `stale_caps`，紧接的 334 用它回满；加减状态、回合开始与结束清掉。玉皇 466 变 538 后 HP 1.8e16（原来 1e17），三十一、三十三层 HP≤10% 例与引路人 794 同理。原版变身时截 HP 也按旧缓存上限，本版按新上限截；冻结源 11 处 336 新形态基础生命上限都不低于旧形态，不会因此不同（已在代码注释说明）。
- **recover_all 保留 `<Permanent>`**：`XBattler.recover_all()` 已在 07c007a（沙僧资源链 WIP）改为保留常驻状态，本轮复测确认交礼后第 1 回合 686 天道*祝福仍在、攻击／魔攻与参照一致，只删登记。
- **测试**：`xiyou_troop_events.gd` 删 KNOWN_STATE_GAPS 与 KNOWN_TRANSFORM_GAPS 及其放行分支，462 两名守层者状态、变身例 hp_after_transform／atk_mat／t1_states 都按参照严格比较；6990/6990。修改前关掉两项登记时失败 25 项（462 十项、变身 HP 十五项）。
- 参照：沿用现有 mv_oracle `troop_event_probe`（462、466～469、794 例），未改探针，同步测量不变。
- 验证：`检查.sh --oracle` 全部通过（worktree 并行 2）。
- 未完成：变身后到下一次 refresh 之间其余能力值（攻击、敏捷等）原版也是旧缓存，本版只模拟了 334 用到的生命／魔法上限；现有参照里这段窗口内没有别的读数。

## 交接板

- 下一步：沙僧协作清单第 6 条、第 7 条划掉（已修）；第 7 条②随 07c007a 已修好。
- 用户试玩说明：三十层起首领变身后回满的生命比之前少（照原版，玉皇变身后约 1.8e16 而不是 1e17）；金角银角战里银角会被加上轮回困难；必中技能对幸运高或有状态抗性的目标附加状态时按原版几率。
- 需要用户决定：无。

## 进度账

- 战斗规则与战斗画面：不单独上调，待 Codex 复核。

## 验证结果

`检查.sh --oracle` 全部通过：`xiyou_troop_events` 6990 项、`xiyou_battle_events` 96、`xiyou_custom_damage` 145、MV 参照引擎与六难度参照同源、内容覆盖无基线外新问题。

- 用了预分配编号：无（O-068 未用，三处都是照原版对齐，不是优化）。

## 本分支提交

- ccb6f8a WIP: 必中技能附加状态不乘有效度与幸运；336 变身后 334 按旧上限回满；删 KNOWN_STATE_GAPS／KNOWN_TRANSFORM_GAPS
- ac903f7 WIP: enemy_transform 注明旧缓存上限与截 HP 差异

可合并。
