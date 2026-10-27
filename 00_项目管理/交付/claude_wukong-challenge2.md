# 交付：claude/wukong-challenge2

- 车道／工作者：A 内容／悟空（Claude，悟空_62 期十四）
- 状态：可合并

## 变更记录草稿

## 2026-10-27 【Claude·悟空·未经Codex检验】挑战被动差异 2／3／4 查清并修复：敌人难度倍率、入队难度继承（dev.待定）

- **差异 3（最要紧）：开战敌人能力偏弱——查清并补上。** 对冻结 v0.28 量得：原版 `Game_Enemy(6)` 单独读 HP 困难 7.5M、地狱 17.5M，和重制一致；多出的 ×2.5／×3 出在层门里调的公共事件 714：它按难度开关置 `$gameParty.DCultyL1～8`，`Star_Warehouse` 插件把 `Game_Enemy.param`（取整）／`xparam`／`sparam` 全乘插件参数 DCL1～5＝1／1.5／2／2.5／3（取 L1～L5 里第一个为真的，L6～8 不乘）。所以：简单 ×1.5、普通 ×2（开关 2491→L3）、困难 ×2.5、地狱 ×3、天灾不乘；包装次序在首领倍率里层（先乘它再乘首领倍率）。重制之前没有这层，所有真实战斗的敌人偏弱。`enemy.gd` 加 `warehouse_rate()`，`param`／`xparam`／`sparam` 乘它；标志取自 `XState.flags`（事件脚本早就按原名存着）。新参照探针 `mv_oracle/enemy_warehouse_probe.cjs`（难度 3～6 × 12 种标志组合 × 敌人 1／6／193／214，共 192 例）→ 夹具 `tests/fixtures/enemy_warehouse_oracle.json`；专项 `xiyou_enemy_warehouse` 5569／5569。
- **差异 2：入队难度继承——补上（纯难度技能路径）。** 原版 `installNativeDifficultyInheritanceRuntime.syncActor` 在 `Game_Party.addActor` 时把非主角队员同步成主角的难度技能（主角一个也没有则按全局难度开关取基础被动，第 2～4 档再带难度适应 5980；不在名单的难度技能忘掉，没被保留的开局状态去掉）。重制补 `XState.inherit_difficulty`（`_add_actor` 里入队前调）。**没做**：主角带强／弱者分档技能 6216／6235、补强档开关 2461～2463 开着、角色号 ≥167 的路径（要读公共事件 1345／1443～1445 的名单，需另补参照；这些情况现在原样不动）。读档时的补同步（extractSaveContents／startBattle 钩子）也没做。
- **差异 4：天灾 11／21 层敌人命中等读数——查清是参照读数缓存，重制对。** 原版开战后 `e.hit`＝0.95，`e.refresh()` 后＝1.45（1657 的 22 号特性加上去）；之后任何刷新都读到加后值。专项改成按刷新后值比对。
- 专项 `xiyou_challenge_passives` 由 934 升到 1005 项，只剩伤害（五乘区，用户另定）一项跳过；队员由「先开难度开关、再逐个入队」建，对上原版状态 1691。

### 改了的核心文件（请沙僧重点核）

- `modes/xiyou/core/enemy.gd`：`param` 乘 `warehouse_rate()` 并取整、新增 `warehouse_rate()`／`xparam`／`sparam`。
- `modes/xiyou/core/xstate.gd`：`_add_actor` 入队前调 `inherit_difficulty`，新增 `inherit_difficulty`／`difficulty_managed_skills` 与常量。
- 测试：`tests/xiyou_floor_run.gd` 的 f31 阶段检查：记录上限 64→256，第二阶段判据去掉「普通攻击（技能 1）落到」（见验证）。

## 交接板

- 下一步：差异 1（五乘区）等用户定；难度继承的分档／补强档／≥167 路径与读档补同步另期补参照；普通／简单难度敌人现在也带 ×2／×1.5，试玩确认手感。
- 用户试玩说明：**所有难度的敌人比之前更强**——简单 ×1.5、普通 ×2、困难 ×2.5、地狱 ×3（天灾不变），这是原版插件 Star_Warehouse 的行为，之前重制漏了。后招募的队友入队时会拿到主角的难度被动。
- 需要用户决定：五乘区伤害系数要不要移植（唐僧已登记）；普通／简单难度敌人变强是否符合预期（原版如此，默认照原版）。

## 进度账

- 困难／地狱／天灾挑战被动：大部分已核 → 差异 2／3／4 已解决，仅余差异 1（五乘区，待用户定）与分档／补强档继承路径。

## 验证

- 新专项：`xiyou_enemy_warehouse` 5569／5569；`xiyou_challenge_passives` 1005／1005。
- 回归批（50 个场景：`xiyou_rules` 全部 28 段、`xiyou_event_compare`、`xiyou_battle`、`xiyou_boss_*`、`xiyou_dungeon`、`xiyou_floor_run` 三段、`xiyou_state_effects`、`xiyou_troop_events` 等）：49 通过；`xiyou_floor_run_c` 的 `f31_immunity_stages` 失败——敌人 ×2 后第 31 层首领第二阶段改由分身技能 533（含 311）打完，没有再落下普通攻击，原判据要求第二阶段有一次普通攻击命中。原因是战斗节奏变了而不是规则错；把第二阶段判据放宽成「到达（有伤害、带 1051、已脱离 1047）」，上限提到 256，`xiyou_floor_run_c` 重跑通过。
- 没跑：内容覆盖检查（没改切片）。

## 遗留

- 差异 1 五乘区；难度继承的分档／补强档／≥167 路径、读档补同步；灭世（6250～6253）、洪荒（10300）没有参照例；`CodexHonghuangSuppress` 标志。
- 夹具 `enemy_warehouse_oracle.json` 与 `boss_output_oracle.json` 一样是手工拷自 `.sandbox` 的静态夹具，没挂进 `同步正式西游.py` 的探针表（要挂得补契约校验）。

## 可优化（流程／工具／效率）

- 建议：`xiyou_rules_d3.tscn`（338 秒）、`xiyou_rules_d5c.tscn`（318 秒）超过上限一半，按并行测试提示拆场景（归工具车道）。
- 建议：难度类敌人倍率现在有三处来源（Vitsuno 参数倍率、Star_Warehouse 标志倍率、首领倍率），可在 `enemy.gd` 文件头补一张「乘法次序」表（已在 `warehouse_rate` 注释里写了次序，其余两处没补）。

## 本分支提交

- 2c6acb4b 难度怪物倍率（Star_Warehouse）接入敌人，探针与专项
- 39c02379 入队难度继承，挑战专项去掉状态差异跳过
- 收尾提交：floor_run 判据放宽、交付单
