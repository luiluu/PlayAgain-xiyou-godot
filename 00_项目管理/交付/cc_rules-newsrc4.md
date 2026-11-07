# 交付：cc/rules-newsrc4

- 车道／工作者：C 规则／rules（cc）
- 状态：可合并
- 基于集成分支 `cc/newsrc-switch` 的 58340027，合回集成分支，**不合 main**。产物、导入缓存从集成工作树 recursing-shamir 克隆（同一提交）；探针 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`。派单 DA（第十四批）。

## 做了什么

| 项 | 结论 | 改了什么 |
|---|---|---|
| ① 穿透口径 | 口径已报总装、批了（见协调消息）。战斗端（actor.gd refresh_passive、damage.gd）newsrc1 已同口径；敌人原版就没有穿透（parsePassiveTags 里那段注释掉了）。xiyou_rules d1 去掉更新日志指纹后 61678/61678，之前记的「抗性 1.0 对 0.8」「成长乘区」没再出现 | 见下两行 |
| ①a 战力去重 | installCombatPowerRuntime v0.51：同一对象里元素号＋值写法完全相同的穿透标签只计一次 | `core/power.gd` 穿透循环加 `dep_seen`。xiyou_power 139/139（改前 137） |
| ①b 说明卡穿透行 | installDamageElementRuntime 第 381～402 行：百分比、固定分两组（「X穿透 N%」「X固定减伤穿透 N」），同对象同写法去重，全部元素同值写「全部穿透」，两位小数，有百分比时末尾「穿透合计≥100%才能击破完全免疫」 | `ui/help_card.gd`：**只动穿透段**，第 663～667 行原来那 5 行（旧「减伤穿透」`_group`）换成一行 `_pierce_lines(lines, note)`，`_migrated_element` 前新加 `_pierce_lines`（第 675～718 行）。开工前已合集成分支（Already up to date）。两件随机词缀装备（布腰带 12、草帽 52）内容已对上（逐行按多重集比完全相同），剩的只有特效按品质排序（v0.41），归界面 |
| ①c PIERCE_FIX 旧档迁移 | **不做**：原版 v0.57 读档时把四件（1360、1416、1763、2583）不带元素号的穿透写法换掉；重制不导入 MV 旧档，重制自己的档也不会有不带元素号的旧写法（总装定） | — |
| ①d gear_search | 3 项还挂，**不是穿透**：差在「随机／附加」对「固定」的词条归类（专武词缀，悟空 newsrc7「专武不当词缀」、DB ① 专武前缀读档还原），战力差跟着这个走 | — |
| ② 角色被动缓存随状态重建 | dsPassiveSkill v0.51：addState／removeState／eraseState／clearStates 置脏、按签名重建；角色只在开战构建阶段（Scene_Battle.start 里 okadd 置真之前）不建。Godot 角色原来只在装备、技能、等级变化时刷新 | `core/actor.gd` `passive_cache()` 读时比状态列表（同 newsrc3 的敌人）。xiyou_passive 加 `state_rebuild`（252 的 harmRe 500 增删，角色、敌人各一组），**旧代码挂 actor.added**。state_effects 复活实战那批是探针现场（只 BattleManager.setup、没跑 Scene_Battle.start，okadd 一直假）：测试用 `XActor.passive_state_rebuild = false` 照现场比（默认 true，游戏不受影响），回到 155 行 |
| ③ source_identity | 归哪吒 CY，本单只列清单，没改工具 | 见「source_identity 清单」 |
| ④ O-待定·角色HP包装 并开关 | 总装批了：一个开关 `XResourceContext.o_actor_hp_wrappers`，沿用 O-待定·角色HP包装 | 删 `XShieldLedger.ACTOR_HP_LEDGER`、原 `o_actor_sethp_wrappers`；`set_resource` 回退支只跳过异化、谷雨，账本照调 `hp_gain`（回退支在里面按原生合计白挡）——**补上原来的洞**：回退支 setHp 整段跳过 hp_gain，角色带账本护盾时跟原版对不上。`shield_ledger_probe.cjs` 在 v0.62.12 重出成 `tests/fixtures/shield_ledger_oracle_v062.json`，xiyou_shield_ledger 在回退支下逐步比 9 例；**旧写法挂 native.v062.5／6.set**。测试改名：guyu_battle、alien_affix、xuan_auto。优化登记「O-待定·流萤遮住角色 setHp」并进 O-待定·角色HP包装 一行，仍「待用户确认」 |

改的原沙僧核心文件：无。请审查重点看 `actor.gd` 的状态签名重建（影响所有战斗里带 passive 标签的状态挂到角色身上）和 `resource_context.gd`／`shield_ledger.gd` 的开关合并。

## source_identity 清单（③）

- 本树 generated/oracle 下 104 份带 sourceIdentity 的参照，**全部**只差同样的 26 份 `data/PlayerChangelog/v0.37～v0.62.json`；releaseVersion、runtimeInputs、其它 data 文件都对得上。
- 原因：转换器 e7713aa7（A，改版向导日志）用 `self.read` 读更新日志，把它们记进 `manifest.inputs`；探针 `source_identity.cjs` 只算 data 下一层文件。是**工具口径**，不是规则，重出夹具也没用。
- 会因此挂的测试（比全部 data 输入的）：`xiyou_rules`（全部 65 段，第一项 `d1.source_identity` 挂了就不往下比）、`xiyou_equipment`（`data_identity`）。其余参照测试只比 runtimeInputs 或版本，不受影响。
- 总装已交哪吒 CY：转换器读日志不记进 inputs，探针 5 处不动。

## 验证（本机，新源产物，`--skip-generated-check`）

- `语法检查.py` 通过。
- 本机跑了相关的 50 个场景（newsrc3 那 40 个去掉 xiyou_rules，加 shield_ledger、xuan_auto、power、help_card、gear_search、actor_bonus、actor_modules、raven_soul、yunshang_ui、zhenqi、heartsteel、status_power_panel）：失败 7 个，**都是改前就有**（换回 58340027 的 .gd 重跑一样，或同 newsrc3）：
  - actor_p0 2 项（流萤号角 3063、recruit_11）；status_power_panel 1 项（coverage_all_actors）；zhenqi page.*：换回 58340027 重跑相同。
  - state_effects 155 行（「敌人＋缓存不脏」那批＋2792＋costume，同 newsrc3）；state_effects_tp 2 项（同 newsrc3）。
  - help_card 16 项：10 个角色专属技能「成长：」措辞（谷雨、云裳等）＋2 件随机词缀装备的特效排序（界面）；穿透内容已对上。
  - gear_search 3 项：专武词缀归类（见①d）。
- 之后又单跑：shield_ledger 232、xuan_auto 4559、guyu_battle 1638、alien_affix 2119、shield 565、alien_battle 335、xuan_battle 272 全过；passive 263/263。
- **没跑**：xiyou_rules 全段（被 source_identity 挡，等哪吒 CY；本机临时去掉更新日志指纹跑过 d1 第一段 61678/61678，那次是 c9aa2b95 之前的代码，没提交那个临时改动）、event_compare 等其余场景。`actor.gd` 影响面大，请合并后在云端跑 `xiyou_rules*`。
- `回退开关覆盖.py`：147 个开关，缺口 14 跟改前同（新 2 是 O-206、O-209）。

## 变更记录草稿

## 2026-11-06 【cc·rules·未经审查】新源补单三：穿透说明卡与战力去重、角色被动缓存按状态重建、O-待定·角色HP包装 并成一个开关（dev.待定）

见本交付单「做了什么」。核查：待审查。

## 交接板

- 下一步：source_identity 等哪吒 CY；gear_search 等专武词缀（悟空 DB ①）；help_card 特效排序归界面。
- 需要用户决定：O-待定·角色HP包装（现在一个开关 `XResourceContext.o_actor_hp_wrappers`，默认修正）。

## 可优化

- 建议（另开一单，总装已同意）：璇·余辉（installNativeXuanRuntime 308，回光溢出转护盾）和绑定（installNativeBindingChargeRuntime 232，敌方行动期间不可选中的不掉血）这两个 `Game_Battler.gainHp` 包装，原版对角色同样被 krz 的 Game_Actor.gainHp 遮住；Godot 现在对角色照包、没有回退支。先各量一个参照，再看要不要并进 O-待定·角色HP包装（规则，中）。
- 建议：xiyou_rules 第一项 source_identity 挂了整段就不比，一处工具改动就让 65 段全红、看不到真正的规则差；可以让它记一项失败后照常往下比（工具／哪吒，小）。

## 本分支提交

- c9aa2b95 角色被动缓存随状态重建
- 684a9759 战力穿透去重
- a612b321 说明卡穿透行
- 384889e3 O-待定·角色HP包装 并开关、v0.62 账本夹具
- 6cfc61a6 state_effects 复活实战照探针现场
- （本提交）交付单
