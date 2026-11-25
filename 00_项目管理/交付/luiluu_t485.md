# 交付：luiluu/t485

- 车道／工作者：T485 元素效果B2：敌方施效接线（敌打我方）（小A，Neon＋high，P8），从 github/main @ 89c342295（dev.908，已含 T479/T484 体质表与 T480 我方打敌接线）开出
- 状态：可合并

## 改动摘要（对照卡上 5 条验收）

1. **敌打我方记账入口、§4.4 判定（含我方体质）、§5.3 施效预算**：
   - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_element_effects.gd`：放宽 `_side_ok` 为敌我跨边（`(src is XActor and t is XEnemy) or (src is XEnemy and t is XActor)`，不认自伤／友伤），敌打我方共用同一套行动帧、段记录、状态号段（10940～10951）与 `_try_apply`／`_try_holy`。
   - **§4.4 我方作受者判定顺序**：硬免疫（`TRAIT_STATE_RESIST`，查 `sid` 与 `borrow`）→ 体质免疫（读 `actor_nature.json`，同 §4.2 矩阵、不读种族、转换书不改体质）→ 状态有效度（`_actor_state_rate`：装备／被动 `TRAIT_STATE_RATE` × 天启篇异常抵抗词条，不含六维韧性、避免重乘）→ 停手类（麻痹／冰冻）再乘一次六维韧性 `XTianqiSixDim.control_state_rate`（×0.90～×1.10，只乘一次）。必中招（`hitType == 0`）不绕过判定；被硬免疫／体质免疫／0% 有效度挡下不耗冷却、不占敌方预算；水体质首次迟缓即冻（每场最多 1 次）、雷电 ×1.5（与浸湿取高不连乘）、自然体质灼烧 ×1.5（仍受每跳 5% 生命上限封顶）。
   - **§5.3 敌方几率与施效预算**：新增 `effect_elite(logic, t)`（非首领的 `e.elite`／化形异化／名字含【精英】／`six_dim.json` `class == "elite"`）并修正 `effect_boss(logic, t)` 先判 `is_boss_enemy` 再判 `zhongyan`（守层者带化形仍算首领）。敌方统一用 `enemy_effect_rules.base_chance`（11%，首领不加成）：普通怪每行动最多 1 个停手（群体冰打多个浸湿目标时第 2 个退回迟缓）；精英／化形另每场对同一角色最多 2 次停手（`elite_stun_per_battle = 2`）；首领（含终焉级）每行动最多 1 个新效果（全目标合计，免疫／挡下不占预算）、雷电麻痹一律换软版「感电」（1 回合，我方受伤 +11%）、冰冻不施给我方（只挂 2 回合迟缓）。
   - **我方感电增伤落地**：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_affix_battle.gd` `_damage_ops` 里 `b is XActor` 分支补读 `XTianqiElements.combined_exposure_pct(logic, b, 0.0)`，与敌人共用同一易伤格，首领感电挂到我方后实伤真 +11%。
   - **§3.5 敌方神圣·圣护镜像**：`note_hit` 与 `holy_ally_skill(skill, u)` 支持敌方己方目标技（`exclude` → `skills` 白名单补敌方专用 `680`/`3968` 圣光术 → `by_nature` 查敌方自然体质含神圣）；敌方神圣打我方给施放敌人自己（D285② 甲案镜像）；敌方圣护盾挡我方施加的可解除减益；首领一侧（战局中任一敌人为 `effect_boss`）每场最多 3 次（`holy_boss_per_battle = 3`）；盾碎时当场 `_sync_unit` 起算冷却。
2. **与 B 共用事件与状态接口**：零新增状态号、零新增战斗钩子入口，全部复用 T480 的 `frame_begin`/`frame_end`/`note_hit`/`act_end`/`take_skip`/`pending_skip`/`tick_dot`/`out_mult`/`crit_mult`/`has_shock`/`shield_blocks`。效果名、状态名与日志模板沿用现稿未改。
3. **高等三系本轮不扩到敌打我方（D285③）**：敌人虚空／混沌／空间打我方只走受击者原 `element_rate(e)`，不触发吞没／无序／空蚀、不掷十系效果（已写专项断言）。
4. **回退开关与西游档零改动**：沿用 `XTianqiElements.EFFECTS`（O-664）与 `XTianqi.active` 守卫，开关关或西游档下敌打我方不建 meta、不取子流、主流逐位一致；未改西游档逻辑。
5. **T480 复核遗留三件**：
   - ① `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/elements_table.json`：`5513`（「仪式:转化」）挪进 `holy_ally.exclude`（`[749, 5513]`），并在测试名单核实返回假。
   - ② P3-3：`03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_element_effects.gd` 反射反例改用真实神圣伤害技 `2704`（阿语「仪式:神光」，先断言 `holy_ally_skill == true`）经属性反射回打自己，末尾 `pop_back()` 还原全局 `States` 表；另补 `reflected_segment_not_recorded` 直接测 `note_hit` 在 `r.reflected`／`logic._reflecting` 为真时不记跨边伤害段。
   - ③ P3-4：`frame_end` 改为先 `_settle` 再 `fx.frames.pop_back()`，并在 `_add` 内挂 `_add_src` 供 `shield_blocks` 优先读取，根治敌人反击嵌套结算挂元素减益时误读外层我方帧主导致圣护漏挡的问题；已补 `p3_4_enemy_counter_element_debuff_blocked_by_actor_shield` 固定断言。
6. **数据校验同步**：`03_再刷重制_Godot/03_转换工具/天启篇数据校验.py` 补 `enemy_effect_rules` 四个字段校验，`03_再刷重制_Godot/03_转换工具/测试天启篇数据校验.py` 补 4 条反例。

## 验证记录

- 本机前台单跑（一律 `--audio-driver Dummy`，隔离 `HOME`）：
  - `xiyou_tianqi_element_effects.tscn`：**75/75**（在 T480 原 53 条上新增 22 条，覆盖敌打我方十系、我方体质免疫与增幅、§4.4 判定顺序与六维韧性只乘一次、必中不绕过、§3.6 我方行动位停手、§5.3 普通／精英／首领施效预算与感电实伤 +11%、敌方圣护镜像与首领 3 次上限、D285③ 高等不扩、回退开关与西游档零改动、T480 遗留三件）
  - `xiyou_tianqi_elements.tscn`：**57/57**
  - `xiyou_tianqi_swap_view.tscn`：**62/62**
  - `xiyou_combat.tscn`：**36/36**
  - `xiyou_tianqi_affix_battle.tscn`：**86/86**
  - `xiyou_tianqi_six_dim_resist.tscn`：**69/69**
- Python 工具检查：
  - `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：全部通过，退出码 0
  - `PYTHONPATH=03_再刷重制_Godot/03_转换工具 python3 -m unittest 03_再刷重制_Godot/03_转换工具/测试天启篇数据校验.py -q`：**152/152 OK**，退出码 0
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：84 个脚本 825 个函数全过，退出码 0
- **云端选测**（`gh run watch 45545663339 --exit-status` 前台等完）：
  - https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45545663339 — **success**，提交 `f6bbd3874c`（基准 `89c3422953`），26 个场景分 5 片全部通过（最长一片 3.7 分钟）。

## 变更记录草稿

## 2026-11-25 【小A·未经审查】T485 天启篇元素独特效果 B2 敌打我方接线与 T480 遗留修复（dev.待定）
- 在 `XTianqiElementEffects`（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_element_effects.gd`）放开敌打我方双向入口，共用 T480 事件契约、状态号段（10940～10951）与 `XTianqiElements.EFFECTS` 回退开关（西游档零改动）。落地设计稿《天启篇_元素独特效果_v0.3》§4.4 我方判定（硬免疫 → `actor_nature.json` 体质免疫、不读种族 → 状态有效度 → 停手类六维韧性只乘一次，必中不绕过）与 §5.3 敌方施效预算（统一 11% 不加成；普通／精英单行动最多 1 停手；精英／化形每场同角最多 2 停手；首领单行动最多 1 效果、麻痹换 1 回合感电且 `XTianqiAffixBattle._damage_ops` 令我方承伤 +11%、不冻我方；敌方圣护镜像、首领一侧每场最多 3 次）。高等三系本轮不扩到敌打我方（D285③）。
- 清完 T480 复核遗留三件：`5513` 仪式:转化进 `elements_table.json` `holy_ally.exclude`；反射反例改用真实技 `2704` 并补 `note_hit` 反射段直测与 `States` 表还原；`frame_end` 先 `_settle` 再 `pop_back`（并加 `_add_src` 守卫）防敌人反击嵌套帧误读外层帧主漏挡盾。
- 同步 `天启篇数据校验.py` 对 `enemy_effect_rules` 的结构校验及单测；`xiyou_tianqi_element_effects.tscn` 扩充至 75/75 全过。
- 玩家可见：天启篇里敌人的基础十系伤害也有几率给我方挂上灼烧、迟缓、碎甲、麻痹、感电等元素效果（受我方原生体质免疫、状态抗性与六维韧性影响），敌方神圣技也会给敌方挂圣护盾（文字沿用 T480 现稿，未新增文案）。

## 交接板

- 下一步：C 卡（T481）按当前全角色与敌打我方实测校准 `effect_tier_of` 与敌方试测参数（场景 #1～#7，含场景 #4 按我方体质分组统计）；E 卡（T483）Kyo 拍板 4 处命名后统一改 `SPECS` 名称。
- 用户试玩说明：天启篇里敌人打出火、冰、雷等元素伤害也会按几率给我方挂状态（首领雷电会挂感电让承伤略增、不冻我方），我方按角色原生元素体质可免疫对应效果；神圣盾在敌人反击挂减益时也能正常挡掉。
- 需要用户决定：无（效果名与状态名照现稿，等 Kyo 在 4 处命名拍板）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：`XTianqiElementEffects.shield_blocks` 盾碎后当场 `_sync_unit(lg, b)` 起算冷却，不依赖回合末同步（去掉该行即可回退）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiAffixBattle._damage_ops` | 2 处（`git grep -nE '[^[:alnum:]_]_damage_ops[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 2 处逐处结论：仅 `damage_ops` 内部调用；`b is XActor` 分支只在目标挂了 `ST_SHOCK` 时才把 `incomingMultiplier` 乘 `1.11`，没挂或西游档／开关关着时 `combined_exposure_pct` 为 0、乘数不变，`xiyou_tianqi_affix_battle` 86/86 与 `xiyou_combat` 36/36 全过 |
| `XTianqiElementEffects.effect_boss` | 8 处（`git grep -nE '[^[:alnum:]_]effect_boss[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 8 处逐处结论：均在 `tianqi_element_effects.gd` 与专项测试内；先判 `is_boss_enemy` 再判终焉级异化，守层者带化形仍判首领、普通怪带化形仍判非首领，语义更贴合 §4.3 并集定义 |
| `XTianqiElementEffects.frame_end` | 16 处（`git grep -nE '[^[:alnum:]_]frame_end[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 16 处逐处结论：2 处在 `battle_logic.gd`（`execute`、`_counter_attack`），其余在专项测试；改为先 `_settle` 再 `pop_back`，签名和返回值不变，修复嵌套反击结算时 `shield_blocks` 误读外层帧主 |
| `XTianqiElementEffects.note_hit` | 10 处（`git grep -nE '[^[:alnum:]_]note_hit[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`，含同名模块函数） | 调用方 10 处逐处结论：`XTianqiElementEffects.note_hit` 在 `battle_logic.gd:3092`（1 处）及专项测试（3 处），签名不变；放开敌打我方与敌方神圣己方技记账，西游档与开关关着直接返回 |
| `XTianqiElementEffects.holy_ally_skill` | 8 处（`git grep -nE '[^[:alnum:]_]holy_ally_skill[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 8 处逐处结论：仅本模块与专项测试；新增可选参数 `u = null`，原有单参调用全部兼容，`u is XEnemy` 时按敌方自然体质判定 |
| `XTianqiElementEffects.shield_blocks` | 2 处（`git grep -nE '[^[:alnum:]_]shield_blocks[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 2 处逐处结论：仅 `battler.gd:505` 调用，签名不变；优先认 `_add` 传入的 `_add_src`，盾碎时立即 `_sync_unit` 起算冷却，西游档无记账直接返回假 |

## 本分支提交

- f6bbd3874 T485：天启篇元素独特效果 B2 敌打我方接线＋T480 复核遗留三件
