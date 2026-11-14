# 交付：cc/tianqi-elements

- 车道／工作者：B/C 规则与界面／Antigravity（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【cc·Antigravity·未经审查】天启篇元素系统重做 v0.7（dev.待定）

- 核心与数据（[tianqi_elements.gd](../03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_elements.gd)、[elements_table.json](../03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/elements_table.json)）：
  - **60/60/20 楼层牌组与体质约束（O-待定-2）**：按存档种子确定性发牌并持久化，10 枚基础元素各占 6 弱/6 抗/2 免（27 层双弱双抗＋6 层单弱单抗），1~5 层无免疫、6~33 层共 20 枚单免疫；严格避开守层者体质禁用与同层弱/抗/免冲突；读档自动将 JSON 浮点配列归一化为整数。
  - **固定入口与异化怪规则（O-待定-2）**：34 层鸿钧（2 弱/2 抗/1 免，弱点排除圣/暗）、35 层影子（2 弱/2 抗/1 免）、36 层骑士三阶段（每相 1 弱/2 抗/1 免且连续相位弱点不重复）、里副本 Boss 与塔外首领独立发牌；化形/终焉级异化怪仅继承当前楼层免疫；七印精英等普通怪不带弱/抗/免。
  - **物理无属性化与战斗倍率（O-待定-2）**：物理（1）在天启篇下按无属性（0）结算（保留 `hitType=1`）；移除天启篇旧属性克制网（`XDamage.matchup`）与原版守层者吸/免/抗；弱点 +50%（1.5）、转换书命中的弱点 +25%（1.25）、抗性 -33%（0.67）、免疫 0%（0.0 并跳过 0 伤害跳字触发「无效」弹字）。
  - **弱点暴露（O-待定-3）**：首次以弱点或高阶元素命中首领/守层者后挂起本回合「弱点暴露」（+11%），与词条「破绽」取 `max` 不叠加，回合末清除。
  - **高阶元素特性与七印无视抗性（O-待定-4）**：11 虚空（+25%，当场挂起「吞没」并清除目标本回合 -33% 抗性，保留免疫 0%）、12 混沌（随机 +11%/+22%/+33%，preview 取保底）、13 空间（+25%，净扣血量触发 `floor(net_hp_loss * 15%)` 真实空蚀，全被护盾吸收时不触发、无二次触发）；七印天卷 `resist_down` 在天启篇下改走无视首领 -33% 抗性（免疫仍为 0%）。
  - **技能/被动转属与转换书生态（O-待定-5）**：接管甲/乙/高阶改招、8 个自然物攻物理转水/风（默认方案 A 单水/单风，`PHYSICAL_DUAL_KEEP_NEUTRAL = false` 可切回方案 B 双属性）及被动 `<passiveELUP>` 转属，并同步更新 `skill_rework.json` 13 条技能说明；1039 改名「元素转换:自然」（CE 641 改名「元素自然」）；新增合成转换书 `3101~3105`（技能 `11201~11205`、公共事件 `9101~9105`），8 号当铺（Map204）上架水/风，炼狱/证道首领/守层者战按单档每本限 1 次几率掉落虚空/混沌/空间；新旧全部 13 个转换技能学得时自动互斥遗忘。
- 界面与检验（`battle_scene.gd`、`boss_status_panel.gd`、`help_card.gd`、`status_page.gd`、`map_hud.gd`、`map_transfer.gd`、`party_scene.gd`、[天启篇数据校验.py](../03_再刷重制_Godot/03_转换工具/天启篇数据校验.py)）：
  - 战中技能栏显示 `[弱点]`/`[抗性]`/`[免疫]`/`[高阶]` 徽标、Boss 状态面板动态高度展示 P1/P2/P3 与弱/抗/免明细、地图 HUD/传送列表/队伍面板与帮助卡补齐楼层/高阶提示。
  - 新增专项测试 [xiyou_tianqi_elements.tscn](../03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_elements.tscn)（41/41 通过），联跑 19 个关联场景全过（含 `xiyou_event_compare.tscn` 西游原版不回归），`语法检查.py`、`天启篇数据校验.py`、`发行空壳.py check`、`工具回归.py`（18 项）全通过。
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

## 本分支提交

- a601e98e1 天启篇元素系统重做 v0.7 实装与专项测试
