# 交付：cc/tianqi-elements

- 车道／工作者：B/C 规则与界面／Antigravity（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【cc·Antigravity·未经审查】天启篇元素系统重做 v0.7（dev.待定）

- 核心与数据（`tianqi_elements.gd`、`elements_table.json`）：
  - **60/60/20 楼层牌组与体质约束（O-待定-2）**：按存档种子确定性发牌并持久化，10 枚基础元素各占 6 弱/6 抗/2 免（27 层双弱双抗＋6 层单弱单抗），1~5 层无免疫、6~33 层共 20 枚单免疫；严格避开守层者体质禁用与同层弱/抗/免冲突；读档自动将 JSON 浮点配列归一化为整数。
  - **固定入口与异化怪规则（O-待定-2）**：34 层鸿钧（2 弱/2 抗/1 免，弱点排除圣/暗）、35 层影子（2 弱/2 抗/1 免）、36 层骑士三阶段（每相 2 弱/2 抗/1 免且三阶段弱/抗/免各自全不重复）、里副本 Boss 与塔外首领独立发牌；化形/终焉级异化怪仅继承当前楼层免疫；七印精英等普通怪不带弱/抗/免。
  - **物理无属性化与战斗倍率（O-待定-2）**：物理（1）在天启篇下按无属性（0）结算（保留 `hitType=1`）；移除天启篇旧属性克制网（`XDamage.matchup`）与原版守层者吸/免/抗；弱点 +50%（1.5）、转换书命中的弱点 +25%（1.25）、抗性 -33%（0.67）、免疫 0%（0.0 并跳过 0 伤害跳字触发「无效」弹字）。
  - **弱点暴露（O-待定-3）**：首次以弱点或高阶元素命中首领/守层者后挂起本回合「弱点暴露」（+11%），与词条「破绽」取 `max` 不叠加，回合末清除。
  - **高阶元素特性与七印无视抗性（O-待定-4）**：11 虚空（+25%，当场挂起「吞没」并清除目标本回合 -33% 抗性，保留免疫 0%）、12 混沌（随机 +11%/+22%/+33%，preview 取保底）、13 空间（+25%，净扣血量触发 `floor(net_hp_loss * 15%)` 真实空蚀，全被护盾吸收时不触发、无二次触发）；七印天卷 `resist_down` 在天启篇下改走无视首领 -33% 抗性（免疫仍为 0%）。
  - **技能/被动转属与转换书生态（O-待定-5）**：接管甲/乙/高阶改招、8 个自然物攻物理转水/风（默认方案 A 单水/单风，`PHYSICAL_DUAL_KEEP_NEUTRAL = false` 可切回方案 B 双属性）及被动 `<passiveELUP>` 转属，并同步更新 `skill_rework.json` 13 条技能说明；1039 改名「元素转换:自然」（CE 641 改名「元素自然」）；新增合成转换书 `3101~3105`（技能 `11201~11205`、公共事件 `9101~9105`），8 号当铺（Map204）上架水/风，炼狱/证道首领/守层者战按单档每本限 1 次几率掉落虚空/混沌/空间；新旧全部 13 个转换技能学得时自动互斥遗忘。
- 界面与检验（`battle_scene.gd`、`boss_status_panel.gd`、`help_card.gd`、`status_page.gd`、`map_hud.gd`、`map_transfer.gd`、`party_scene.gd`、`天启篇数据校验.py`）：
  - 战中技能栏显示 `[弱点]`/`[抗性]`/`[免疫]`/`[高阶]` 徽标、Boss 状态面板动态高度展示 P1/P2/P3 与弱/抗/免明细、地图 HUD/传送列表/队伍面板与帮助卡补齐楼层/高阶提示。
  - 新增专项测试 `xiyou_tianqi_elements.tscn`（41/41 通过），联跑 19 个关联场景全过（含 `xiyou_event_compare.tscn` 西游原版不回归），`语法检查.py`、`天启篇数据校验.py`、`发行空壳.py check`、`工具回归.py`（18 项）全通过。
- 玩家可见：天启篇档 1~33 层守层者与固定首领启用随机元素弱/抗/免牌组（物理改无属性、弱点 +50%/转换书 +25%/抗性 -33%/免疫 0%「无效」），新增弱点暴露与虚空/混沌/空间高阶特性，8 号当铺上架水/风转换书，炼狱/证道首领战限定掉落虚空/混沌/空间转换书；原版西游档不变。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi_elements.gd` `XTianqiElements.ENABLED`、`core/xdb.gd`、`core/battler.gd`、`core/damage.gd`、`battle/battle_logic.gd`、`battle/battle_scene.gd`、`battle/boss_status_panel.gd`、`ui/help_card.gd`、`ui/status_page.gd`、`map/map_hud.gd`、`ui/map_transfer.gd`、`ui/party_scene.gd`；`tianqi_data/elements_table.json`；`tests/xiyou_tianqi_elements.gd` | 天启篇沿用原版属性克制网与守层者旧抗/免/吸配置 | 天启篇元素系统重做总开关（独立表驱动，原版西游档与发行关闭状态不改动） | 天启篇元素体系设计定稿（v0.7），先实装并可整套一键回退 | `XTianqiElements.ENABLED = false` | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/tianqi_elements.gd` `XTianqiElements.DECK`、`core/damage.gd`、`core/battler.gd`、`core/tianqi_horsemen.gd`、`core/tianqi_qiyin_rule.gd` | 物理技能带属性 1、旧 `matchup()` 与原版吸/免/抗参与天启首领战 | 天启篇启用 1~33 层 60/60/20 牌组、固定入口/三阶段骑士发牌、化形/终焉仅承免，物理 1→无属性 0 并移除旧克制网与吸收 | 避免物理穿元素抗且让十基础元素在 33 层轮换上场 | `XTianqiElements.DECK = false` | cc | 保留 |
| O-待定-3 | `modes/xiyou/core/tianqi_elements.gd` `XTianqiElements.WEAK_EXPOSURE`、`core/tianqi_affix_battle.gd`、`battle/battle_logic.gd` | 首领受弱点攻击无额外暴露易伤 | 首次以弱点或高阶命中首领后本回合挂起「弱点暴露」+11%，与词条「破绽」取 `max` 不叠加 | 奖励抓弱点构筑同时避免乘区膨胀 | `XTianqiElements.WEAK_EXPOSURE = false` | cc | 保留 |
| O-待定-4 | `modes/xiyou/core/tianqi_elements.gd` `XTianqiElements.HIGHER_EFFECTS`、`core/tianqi_qiyin_effects.gd` | 虚空/混沌/空间仅有基础倍率，七印降抗仍按原版加伤走 | 11 虚空 +25%+吞没清抗、12 混沌 +11%/+22%/+33%、13 空间 +25%+15% 真伤空蚀；七印 `resist_down` 无视首领 -33% 抗 | 让三高阶元素与七印天卷拥有独立破局机制 | `XTianqiElements.HIGHER_EFFECTS = false` | cc | 保留 |
| O-待定-5 | `modes/xiyou/core/tianqi_elements.gd` `XTianqiElements.SKILL_SHIFTS`、`PHYSICAL_DUAL_KEEP_NEUTRAL`、`core/actor.gd`、`map/mv_interpreter.gd`、`tianqi_data/skill_rework.json` | 缺水/风/高阶专项技能分布与对应转换书，1039 为「元素转换:风」 | 实装技能/被动转属与 13 条说明同步、1039 更名自然、合成 3101~3105 转换书与 11201~11205 互斥、当铺与炼狱/证道首领限次掉落 | 让水/风与高阶技能/转换书形成完整闭环且不污染原版档 | `XTianqiElements.SKILL_SHIFTS = false`（物理双属性开关：`XTianqiElements.PHYSICAL_DUAL_KEEP_NEUTRAL = true`） | cc | 保留 |

## 交接板

- 下一步：天启篇元素系统重做（dev.待定）已并入并验证，按需根据用户答复决定是否补 UI 提示或切换 `PHYSICAL_DUAL_KEEP_NEUTRAL`。
- 用户试玩说明：天启篇存档 1~33 层守层者与固定首领启用随机元素弱/抗/免牌组（弱 +50%、转换书 +25%、抗 -33%、免 0%「无效」），物理技能改无属性，虚空可吞没抗性、混沌随机倍率、空间附带 15% 真伤空蚀；8 号当铺上架水/风转换书，炼狱/证道首领战几率掉落虚空/混沌/空间转换书（单档限 1 本）；原版西游档无变化。
- 需要用户决定：
  1. 【元素系统 UI 提示口径】是否还需要在常规说明页或特定界面（如人物图鉴、商店面板）追加高阶特性与「弱点暴露」细节提示？（当前已在 `HelpCard`、`StatusPage`、`MapHUD`、`MapTransfer`、`PartyScene`、`BattleScene` 与 `BossStatusPanel` 接入；未决定前按当前展示继续）。
  2. 【物理转水/风技能双属性确认】`elements_table.json` 中 8 个自然物攻技能当前默认采用方案 A（纯单水 14 / 单风 15，`XTianqiElements.PHYSICAL_DUAL_KEEP_NEUTRAL = false`）；是否需要切换为方案 B（保留 `[0, 14/15]` 无属性+水/风双属性取最高）？（未决定前按默认方案 A 继续）。

## 进度账

- 天启篇扩展账：元素系统重做 v0.7 已完成实装与验证（主表完成度不变）。

## 可优化（流程／工具／效率）

- 建议：`03_再刷重制_Godot/07_开发环境/选测对照.json` 目前对 `modes/xiyou/tianqi_data/elements_table.json` 与 `skill_rework.json` 会因找不到直接同名词加载测试而触发整轮，后续可由工具车道补充精准映射，减少选测误扩整轮。

## 核查返修（gpt 甲档「修完再合」3 项 P2，2026-11-14，cc）

专项 `tests/xiyou_tianqi_elements.gd` 新增 `_test_review_fixes`，42 → 53 条断言全过；修法与测试同在提交 3d2923a1b。

1. **首次建牌组用全局 `randi()`**（`core/tianqi_elements.gd` `store`）→ 新增 `derived_seed(s)`：由存档自带宝珠种子 `orb_seed`（新游戏随机、随存档保存；无 `orbSeed` 的旧档读档时按存档内容算出）加难度取 `XOrbs.hash32`，不吃全局随机流与战斗随机流。旧天启篇档（无 `elements` 字段）不存档重读，牌组不变。测试：`review1_first_deck_no_global_randi`、`review1_old_save_reload_same_deck`、`review1_seed_follows_save`（3 条）。
2. **Boss 面板不传 logic，影子／生存战回落成 knight 牌组**（`battle/boss_status_panel.gd`）→ 面板加 `logic_source`，`battle_scene.gd` 建面板时传本场 `logic`，`_tq_profile` 按实际结算模式取牌组：35 层影子显示 yingzi 2弱2抗1免，生存战不显示牌组（面板隐藏元素行）。测试：`review2_panel_shadow_shows_yingzi`、`review2_panel_survival_no_knight_deck`（2 条）。
3. **免疫命中仍走 respond／establish**（`battle/battle_logic.gd` `_apply`）→ 新增 `XTianqiElements.immune_hit()`（条件与 `after_apply` 免疫分支一致：天启篇 `on()`、角色打敌人、HP 伤害 1／5 型、`best_row` 为 immune 且倍率 0），命中时跳过 `_establish`（respond／establish 状态回调）；`after_apply` 照旧标 `element_immune` 和「无效」弹字。`on()` 为假（西游档、`ENABLED=false`、发行关闭）恒为假，西游档零改动。测试：`review3_immune_skips_establish`、`review3_switch_off_establish_runs`、`review3_west_zero_damage_establish_runs`（3 条，用子类记 `_establish` 调用次数）。

顺带补证：
- 新编号不撞生成数据库：`review_new_ids_no_db_clash`（Items 3101～3105、Skills 11201～11205、CommonEvents 9101～9105 原表为空或在表外，且不被 `XTianqiSkills` 表外补招占用）、`review_new_ids_resolve_to_synthetic`（2 条）。
- 牌组存取往返与浮点归一：`review_save_roundtrip_deck_equal`（`to_dict`→JSON→`from_dict` 后层牌组、固定入口、种子一致）、`review_fixed_entries_float_normalized`（1 条＋1 条）。补证时发现固定入口（hongjun／yingzi／knight／dungeon_boss）读档后弱抗免是浮点、原只归一层牌组，已加 `_norm_entry` 在 `fixed_deal` 里一并归一。

顺带修的连带失败：云端整轮（c114ae41f，577 场景）只挂 `xiyou_fabao_rework` 的 `guardian.elem_resist`——首版交付后天启篇档 `element_rate` 走元素牌组，这条直接读 `element_rate(1)` 期望旧一刀切 0.5；实战 `XDamage` 在元素重做开着时不调 `XGuardianRework.resistance`，不是结算问题。改测试：这条在 `XTianqiElements.ENABLED=false` 下测 ELEM 回退路径（86/86）。`xiyou_flow` 云端偶发、本机单跑 50/50。
另把本交付单里 4 个 `../03_…` 相对链接改成代码字（交付单在 `交付/` 下，检查.sh 文档链接检查报失效；其余 20 个失效链接在旧核查报告里，是本工作树没有 `04_验证/本地结果` 的本地文件，与本分支无关）。

验证：专项 53/53；`检查.sh --oracle --keep-going --affected 5331d152f --cloud`：云端整轮 577 场景除上述外全过，MV 参照引擎、事件对照、内容覆盖、守卫均过；修后本机复跑 `xiyou_fabao_rework`／`xiyou_tianqi_elements`／`xiyou_flow` 全过。

## 本分支提交

- a601e98e1 天启篇元素系统重做 v0.7 实装与专项测试
- 3d2923a1b 天启篇元素：gpt 核查 3 项 P2 返修＋补证专项

## 骑士弱点数按设计稿改 2（小A）

- **改动内容**：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/elements_table.json`：`fixed_entries.knight.weak` 由 `1` 改为 `2`。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_elements.gd`：`_deal_knight` 缺省值改为 `2`，新增 `_deal_knight_phase`、`_pick_from_pool` 与 `_knight_needs_redeal`。在基础十系与每阶段 2 弱／2 抗／1 免的约束下，**三阶段做到弱点 6 系全不重复、抗性 6 系全不重复、免疫 3 系全不重复，且同一阶段内弱／抗／免 5 系互不重复**（代码同时保留若未来配置超容时退化为至少相邻阶段不重复的保底逻辑）。仍由存档 `seed` 确定性派生，不用全局随机。
  - 首领面板（`boss_status_panel.gd`）与换阶段提示（`on_horsemen_phase`）均走 `format_profile_line`，无写死「1 个弱点」处，无需改动。
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_elements.gd`：更新 `knight_3_phases_2w_2r_1i_no_repeat_weak`，新增 `knight_same_seed_reload_unchanged`、`knight_legacy_1w_save_redeals_deterministically`。
- **老存档处理**：`fixed_deal(..., "knight")` 通过 `_knight_needs_redeal` 检查 `knight:1..3` 的弱／抗／免数量是否符合当前配置（2/2/1）。若已有存档里存的是按旧规则掷好的 1 弱点牌组，读取时自动用原存档 `seed` 确定性重掷为 2 弱点并写回 `st.fixed`；重掷后规格匹配，后续读档保持不变。
- **测试结果**：
  - `xiyou_tianqi_elements.tscn`：55/55 通过；`xiyou_boss_status.tscn`：57/57 通过；`xiyou_fabao_rework.tscn`：86/86 通过；`xiyou_event_compare.tscn`（14/14）及 `_b/_c/_d`（各 6/6）全过。
  - `语法检查.py`（842 个 `.gd`，0 问题）、`天启篇数据校验.py`、`发行空壳.py check`、`工具回归.py`（18 项）、`反向验证.py`（2 项均咬住）全部通过。
  - 说明：`选测.py main --list` 因 `elements_table.json` 无精准映射及父分支 `cc/tianqi-elements` 尚未并入 `main` 而判定整轮（584 场景）；相对父分支 `cc/tianqi-elements` 仅涉上述 6 场景，按「不跑全量」且父分支 `3d2923a1b` 已跑过云端整轮，本单在本机跑完直接关联的 7 个场景。
- **分道**：快车道（不动切片、转换器、参照探针）。
