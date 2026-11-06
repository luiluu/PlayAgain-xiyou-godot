# 交付：cc/rules-newsrc2

- 车道／工作者：C 规则／rules（cc）
- 状态：进行中（第一段已交，见下；总装追加的敌人复活、weapon_unleash 在做）
- 基于 `cc/rules-newsrc1` 的 dce20d67（已在集成分支里），交付合回集成分支 `cc/newsrc-switch`，**不合 main**。工作树就是 rules-newsrc1 那棵，产物是集成分支的新源产物；探针一律 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`。

## 做了什么

| 项 | 结论 | 改了什么 |
|---|---|---|
| life_steal `source` | 夹具重出（`life_steal_probe.cjs`，v0.62.12）。2570 的 `<DBHPLSteal:80%>` 等 4 项随夹具一起对上 | 夹具 |
| param_states `source` | 夹具重出（`param_states_probe.cjs`）。`source` 过了；剩下的全是 1768「杀敌加属性」：新源 conclude 改成 `target.hp<=0‖isDead()` 并调 `CodexNanohaAdapt`（v0.62.03 适应成长软上限），转换器落成 `op: js`，归哪吒 newsrc3 的状态白名单（同交付单 newsrc1 的 ①）。shadow.*、enemy.diagnostic 也是因为 1768 没翻译（诊断变成 js 那条） | 夹具 |
| wtype `native_cache_source` | 原夹具出自没入库的 `.sandbox/merge82_admission_probe_v5.cjs`。新写 `mv_oracle/wtype_cache_probe.cjs`（148 号 10 级 5600，stale 后照原版 `refreshPassiveCache` 再量）：**旧源重跑跟原夹具逐项相同**（mp730、stale 750／不可用、warmed 600、Zj/Mf 20）；新源 stale 就已经是 600／可用（新源自己刷新了缓存），测试里的 stale 比对照样成立 | 探针（新）、夹具 |
| qiyu `state2626.a164／a162` | 新源 `installIntegratedV029Runtime` 的 `addState` 包装：actorId 141～166 加 2626 直接返回（原来只挡 163，`installQiyuDimensionRuntime`） | `core/qiyu.gd` `blocks_state` 扩到 141～166 |
| skill_mastery `table.count`／`table.rows` | 夹具还是 v0.28。重出：表 6804→6984（Godot 6983＋运行时 7940），新技能 10169、10457、10463～10471、10491 上限 0，Godot 本来就是 0 | 夹具 |

改的原沙僧核心文件：无。`qiyu.gd` 是琦玉模块。

## 验证（本机，新源产物，`--skip-generated-check`）

- `语法检查.py` 通过。
- `选测.py 34d486ad --list`（round 3＋本单相对第三轮基线）17 个场景：通过 11 个（action_sequence、actor_advanced、battle_common_events、boss_sequence、element_ternary、life_steal、qiyu、rules10、skill_mastery、state_overlay、wtype）。
- 失败 6 个，**改前改后逐条相同**（把 `action_sequence.gd`、`qiyu.gd` 换回 34d486ad 重跑同 17 个：改前多挂 action_sequence、qiyu，其余 6 个 FAIL 行排序后完全一样）：
  - actor_p0 1 项：流萤号角 3063（A 内容）。
  - custom_params 1 项：`covers_aliases`（探针 PICKS，归哪吒）。
  - formulas：断言 7/7 全过，日志两条大数 ERROR（10037／10060 formulaGd 整数字面量，归转换器）。
  - param_states：1768（见上）。
  - event_compare 9/11：`no_new_skipped`／`no_regressions`（Codex 向导、低语等新事件脚本，A 事件）。
  - sve_visual 25/31：`census.*`、`weapon.rows` 计数（新角色，B 界面）。
- `事件空绿扫描.py --check`：rc=1、4747 条 ✗，全是 event_states 产物与预设对不上（产物克隆自集成分支）；本单没碰事件。
- `工具回归.py`：2 项挂，跟本单无关：插件备注覆盖（新源 7 个备注标签 codexaura、codexliuying* 等没读，转换器）、探针登记检查（`death_admission_probe.cjs` 没关五乘区，本单没碰这个探针）。

## 接续（总装追加，还没做完）

- 敌人复活：revive.apply 173 项全是敌人行，参照里敌人复活与否跟着 dirtyWarm 变（见 cc_nezha-newsrc3.md）；guyu_battle 两项复活可能同源。
- weapon_unleash：w93 解放 5636 用不了。

## 变更记录草稿

## 2026-11-06 【cc·rules·未经审查】新源补单：导入角色都挡 2626、三份来源夹具与熟练度表在 v0.62.12 重出（dev.待定）

见本交付单「做了什么」。核查：待 Codex。

## 可优化

- 建议：探针产物被拷成夹具时，`probe` 字段指向 `.sandbox/` 里的临时脚本就等于没法重出（wtype_cache 这次就得重写）；探针登记检查可以加一条：夹具的 `probe` 必须是已跟踪文件（工具／哪吒，小）。

## 本分支提交

- cc943917 三份夹具重出＋wtype_cache_probe.cjs
- （下一条）2626 扩到 141～166、熟练度夹具
