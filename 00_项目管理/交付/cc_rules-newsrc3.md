# 交付：cc/rules-newsrc3

- 车道／工作者：C 规则／rules（cc）
- 状态：可合并
- 接 `cc/rules-newsrc2` 的 35f00e07（「接续」三项），交付合回集成分支 `cc/newsrc-switch`，**不合 main**。产物、`.sandbox`、导入缓存从 rules-newsrc1 工作树 APFS 克隆（同一提交），探针一律 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`。
- 「敌人＋缓存不脏」那 28 行 revive.apply 照派单没动（等总装定归谁）。

## 做了什么

| 项 | 原因 | 改了什么 |
|---|---|---|
| revive.apply 252（七星续命 500 固定减伤） | 新源 dsPassiveSkill v0.51 起 addState／removeState／eraseState／clearStates 置脏、按签名（状态列表＋技能＋装备＋敌人号）重建被动缓存，敌人没有角色那道 okadd 门；Godot 敌人只在开战建一次，战斗中挂的状态 passiveHarmRe 不进缓存。另外测试的 ReviveLogic 固定 7 点不走 finish 的固定减伤 | `core/enemy.gd`：`passive_cache()` 读时比签名（敌人号＋state_ids），变了就 `refresh_passive()`。测试 ReviveLogic 的 7 点照真实链带上固定减伤候选（没有 harmRe 的状态 flat 为 0，跟原来一样）。252 的 20 行全过；**换回旧 enemy.gd 挂 20 行**（175→155） |
| weapon_unleash w93（解放 5636） | 不是规则差：参照用例带 `enabledDisabledActor: 166`，临时把 166 从 `CodexImportedBalance.disabledActorIds` 拿掉再量专武；Godot 测试没照做，`is_disabled_actor` 让 canUse 全否 | `core/imported_balance.gd` 加测试用 `static var probe_enabled`（默认空，游戏不受影响）；测试按用例设、量完清。963/963（改前挂 8 项） |
| guyu_battle `script.sub.6.revive.party`／`7.turn.party` | 原版代码错误：新源流萤（main.js 第 144 行）在 `Game_Actor.prototype` 上自定义 setHp，捕获的是谷雨（152）包装前的 `Game_BattlerBase.setHp`，角色 setHp 不看替倒，替倒中的谷雨被直接设满血（死亡状态仍去不掉、仍算替倒）。谷雨自己的 `entrances` 注释写明要封住角色上的重写入口，setHp 漏了；同 O-212（账本） | 回退开关 `XGuyu.ROOTED_ACTOR_SET_HP`（默认 true＝照谷雨本意抬不起；false 照原版），`core/resource_context.gd` 的谷雨 setHp 那行加条件。测试参照比原版支（`= false`）；另重放 sub 例断言修正支 revive 后生命还是 0。1638/1638；登记见优化登记末行 `O-待定·谷雨替倒 setHp` |

改的原沙僧核心文件：无（`enemy.gd`、`resource_context.gd` 不在那份名单里；请审查重点看 `enemy.gd` 的签名重建，它影响所有战斗里敌人身上带 passiveHarmRe 的状态）。

## 验证（本机，新源产物，`--skip-generated-check`）

- `语法检查.py` 通过（592 个 .gd）。
- 选测：`选测.py 35f00e07 --list` 因 `enemy.gd` 归战斗核心选了 263 个（xiyou_rules 全段）。本机跑了相关的 40 个（谷雨三份、state_effects／_tp、weapon_unleash、imported_balance、actor_p0、shield／shield_ledger、xuan_battle、alien_battle／affix、boss_output／_context／react／lifecycle、determinism、settlement、passive、difficulty_enemy、multi_element、element_ternary、rules10、rules、action_sequence、dot、item_use、poison_collapse、toji／mira／sukuna_battle、life_steal、module_hooks、qiyu、cat_trial、combat、race_battle、transform_params、three_growth）：通过 36 个。
- 失败 4 个，都是改前就有、跟本单无关：
  - state_effects 155 行：剩 revive.apply「敌人＋不脏」28 行（派单说先不做）＋action.counter.sequence（2792）＋rest.costume 1，跟 newsrc2 交接时相同，少了 252 的 20 行。
  - actor_p0 1 项：流萤号角 3063（A 内容，同 newsrc2）。
  - alien_affix 4 项 `battle.insulation／sacrifice.sethp`：**换回 35f00e07 的代码重跑一模一样**。看着也是流萤 setHp 绕过（异化 146／148 的 setHp 包装对角色失效），本单没查，见「可优化」。
  - state_effects_tp 2 项 `inventory.costume_0`／`untranslated_46`：同样改前改后相同（状态清单计数，A 翻译）。
- **没跑**：xiyou_rules 其余 64 段、event_compare 等其余 223 个场景（本机太慢；这个分支的 `云端选测.py` 还没有 `--scenes`）。`enemy.gd` 影响面大，请总装合并时云端跑 `xiyou_rules*`。
- `事件空绿扫描.py --check`：rc=1、4747 条 ✗，跟 newsrc2 交接时同数，全是 event_states 产物与预设对不上；本单没碰事件。
- `工具回归.py`：2 项挂，同 newsrc2（插件备注覆盖、探针登记检查），本单无关。
- `回退开关覆盖.py`：新开关 `XGuyu.ROOTED_ACTOR_SET_HP` 有回退值测试，不在缺口里。

## 变更记录草稿

## 2026-11-06 【cc·rules·未经审查】新源补单二：敌人被动缓存按状态重建、谷雨替倒 setHp 开关、w93 解放测试（dev.待定）

见本交付单「做了什么」。核查：待审查。

## 交接板

- 下一步：revive.apply「敌人＋缓存不脏」28 行待总装定归谁（newsrc2 判断是探针前面用例的现场）；异化 setHp 对角色失效（alien_affix 4 项）待派。
- 需要用户决定：`O-待定·谷雨替倒 setHp`（默认保留谷雨限制），同 O-212 一起确认。

## 可优化

- 建议：新源流萤的 `Game_Actor.prototype.setHp` 让之后装的所有 `Game_BattlerBase.setHp` 包装对角色失效（已知：账本 O-212、谷雨本单、异化 146／148 待查）。可以一次盘点 main.js 第 144 行之后所有 setHp 包装，统一一个「角色 setHp 照原版绕过」的回退口径，免得一个个撞（规则，中）。
- 建议：角色侧被动缓存在新源战斗中（okadd 之后）同样随状态增删重建，Godot 角色还没跟；本单只做了敌人。要查哪些状态带 passiveHarmRe／passiveXXX 并会在战斗中挂上（规则，中）。

## 本分支提交

- b270a9f4 敌人被动缓存按状态签名重建（252）
- 0ed869ab weapon_unleash 临时启用停用角色 166
- ffa78bc2 谷雨替倒 setHp 回退开关
- （本提交）优化登记、交付单
