# 交付：cc/nezha-newsrc3

- 车道／工作者：工具／哪吒（cc）。从 `cc/newsrc-switch` 34d486ad 切出，交回集成分支，不进 main。
- 状态：进行中（核心两件已做完，custom_params 探针改挑防具留给下一位，见「接续」）

## 结论

1. 新源 v0.62.12 改写的 19 个状态 Custom Effect 全部翻成结构化效果，新源上 `parse_state_effects` 不再落 `op: js`。
   - 原样可译、只差数值的：整段 token 收进白名单。`MEASURED_VALUE_BLOCKS` 加 1451、1726、2558、2561、2583；`MEASURED_EFFECT_BLOCKS` 加 1061、1431、1731、2559；2574 新源只剩注释，进 `NO_EFFECT_BLOCKS`。
   - IR 表达不了原文写法的，照 rules5 的做法整段比对后换成等价写法（`MEASURED_EFFECT_SOURCES`）：1450（for 条件「i < cishu && 目标活着」→ 固定 10 轮、每轮先判）、1711／1716（forEach 回调＋三元链 → if 链，`aliveMembers().length` → `aliveFriends()`）、1714、2544／2545（0.01→0.1）。
   - 2575 Confirm 0.005→0.05：仍写没人读的 `_zuizhongshanghai`，原版无效果，进 `UNREAD_FIELD_BLOCKS`；fix1 `FIX_SWORD_2575` 按新系数 5%／层，fix2 沿用旧签名那份（按说明 +3.5%）。
   - 1725 复活：新源 `gainTp(target.maxTp())`，`REVIVE_GAIN` 认 `maxTp ( )`，运行时 `state_effects.gd` `_revive_amount` 读 `max_tp()`。
   - 1768：新源走 `CodexNanohaAdapt(user, 1)`（适应成长软上限）。转换器出 `param_add` `scale: nanoha_adapt`；运行时新 `XNanoha.adapt(a, share)`：前 2000 次每次 +10 生命／+30 魔法，之后乘 2000/次数，次数存 `flags.codexNanohaAdapt{角色ID}`，第一次按已得魔法加值÷30 估算（照原版）。
2. 规则车道转来的大数：`formulaGd` 里超过 int64 的整数字面量写成浮点（`_gd_big_ints`，10037／10060 → `1e+23`／`1e+41`，与 JS double 相同）。formulas 的两条 ERROR 没了。
3. 新源新增、本来就没翻译的 15 个状态（不在本单）：2720、2721、2723、2724、2747、2748、2750、2751、2771、2772、2773、2774、2775、2776、2777。已报协调。

## 验证（本机，新源 = `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`，产物用转换器 `--app` 新源重出）

| 场景 | 改前（34d486ad＋新源产物） | 改后 | 剩下的 |
|---|---|---|---|
| xiyou_state_effects | 1097 失败 | 175 失败（29958/30133） | revive.apply 173（见下）、action.counter 1（2792）、rest.costume 1 |
| xiyou_param_states | 52 失败（1768 一批＋shadow／enemy） | 1 失败（`source` 夹具身份） | `source`：夹具重出，归 rules ④ |
| xiyou_nanoha | 1 失败（kill.nanoha.self） | 286/286 全过 | — |
| xiyou_guyu_battle | 2 失败 | 2 失败（未变） | `script.sub.6.revive.party`／`7.turn.party`，不是 1725，见下 |
| xiyou_state_effects_tp | 2 失败 | 2 失败（未变） | `inventory.costume_0`（2771～2774 超赛换装块，属那 15 个新状态）、`untranslated_46` 计数 |
| xiyou_formulas | 2 失败＋2 条 ERROR | 2 失败、0 ERROR | 两例 10020 三元在 rules 分支已改测试，集成分支还没合 |

- 「测试先在旧代码上失败」：上表「改前」列就是同一测试在未改转换器时的失败，改后对应项转过。
- 旧源不退化：把旧源产物换回来，用改后的转换器 `--app` 旧源 v0.28 重出：`written 0, unchanged 3549`（产物逐字节不变）；同五个场景在旧源上 state_effects／param_states／nanoha／guyu_battle 全过，state_effects_tp 2 失败（`custom.cap`、`custom.-160.0.609.0.direct`，产物没变、改的运行时只走新 op，判断为集成分支原有，未在基线上单独复跑）。
- 测试改动（`tests/xiyou_state_effects.gd`）：`hook.2574` 原来写死「c108＋等级」的旧行为，改成按参照量到的值比（新源空块、原值不动；顺手修了 c 为空时的 SCRIPT ERROR）；`fix.2575` 按 2575 备注里的系数算（0.005 或 0.05）。
- 剩下的 revive.apply 173 项不是 19 个状态的问题：全是**敌人**行，15 个复活状态（114、252、1099、1164…2712）都有。参照里敌人行复活与否取决于 `dirtyWarm`（能力缓存脏不脏）：脏时新源复活（draws 1，hp 回满 75000007500），不脏时不复活也不抽随机；Godot 两种都一样。像是新源对敌人能力缓存／isDead 的改动，归规则车道看；guyu 的两项复活大概同源。
- `事件空绿扫描.py --check`：报 m45e1p1#o4 等 4 条「在 event_states.json 里但预设已删（产物过期）」——本树 event_states 是集成树克隆来的、本单没碰事件，归八戒补跑事件状态探针。
- `工具回归.py`：插件备注覆盖（新源 codexaura 等 7 个备注标签未读）、探针登记检查（module_equipment_view／recover_permanent 未登记、death_admission 未关五乘区）2 项失败，都是集成分支原有、与本单无关。
- `语法检查.py` 通过。没碰 `DEFAULT_APP`。

## 改了哪些文件（沙僧原核心文件逐个列）

- `03_转换工具/xiyou_export.py`（白名单／等价写法／2575 fix／1768／1725 maxTp／`_gd_big_ints`）
- `01_Godot工程/modes/xiyou/core/state_effects.gd`（原沙僧核心：`_revive_amount` 认 max_tp、`_add_params` 认 nanoha_adapt）
- `01_Godot工程/modes/xiyou/core/nanoha.gd`（`XNanoha.adapt`）
- `01_Godot工程/tests/xiyou_state_effects.gd`（hook.2574、fix.2575）

## 接续（下一位）

- custom_params 探针（规则车道转来）：`03_转换工具/mv_oracle/custom_params_probe.cjs` 的 `mhp_mmp_eight` PICKS 从 1925／2019／2020／2021 改挑防具 129、4472、4473、4476 等（新源还有 mhp／mmp 的 20 件），`XIYOU_APP=…/v0.62.12/app.nw node custom_params_probe.cjs` 重出 `generated/oracle/custom_params.json`，再跑 xiyou_custom_params。还没动。
- 共享击杀 `XNanoha.finish` 新源也改成 `CodexNanohaAdapt(nanoha, 0.5)`（队友击杀给一半、走同一软上限计数），现在还是旧的 +10／+30。`adapt` 已经能用，改一行即可，但 nanoha_kill 夹具要先在新源重出看值，本单没做。
- 重出产物后规则车道重跑 state_effects、param_states、nanoha、guyu_battle（派单原意）。

## 变更记录草稿

## 2026-11-06 【cc·哪吒·未经审查】新源 19 个状态的新写法翻成结构化效果；formulaGd 大数写成浮点（dev.待定）

见本交付单「结论」。旧源产物逐字节不变；新源 state_effects 1097→175 失败（剩敌人复活 173 另查）、param_states 52→1、nanoha 全过。核查：待 Codex（改了 state_effects.gd）。

## 交接板

- 下一步：custom_params 探针改挑防具重出；`XNanoha.finish` 改走 adapt(0.5)；敌人复活随能力缓存脏不脏而变（规则车道）。
- 用户试玩说明：无（集成分支追平）
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- `新建工作树.sh --补齐` 在 `--from cc/newsrc-switch` 时仍按默认旧源重跑转换器，`冻结正式源/app.nw` 也链回旧源；新源车道每次要手动改链接、克隆集成树的 generated。建议 `--补齐` 认 `XIYOU_APP`（设了就用它跑转换器并把 app.nw 链过去）。DEFAULT_APP 归 tools80，这里只提补齐脚本那头（工具，小）。
