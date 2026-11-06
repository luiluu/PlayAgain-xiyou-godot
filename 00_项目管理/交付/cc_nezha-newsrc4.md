# 交付：cc/nezha-newsrc4

- 车道／工作者：工具／哪吒（cc）。从 cc/nezha-newsrc3 64692cf2 切出，已合集成分支 cc/newsrc-switch 451012b6（一处冲突，见下），交回集成分支，不进 main。
- 状态：可合并
- 接的是 newsrc3「接续」里的两件；revive.apply 敌人复活不在本单。没碰 `xiyou_export.py` 的 `DEFAULT_APP`。

## 结论

1. **custom_params 探针**（`mv_oracle/custom_params_probe.cjs`）：`mhp_mmp_eight` 原挑的 1925／2019～2021（千古啸等专武）在 v0.28 写 mhp／mmp，v0.62.12 改成只 `atk／mat += 等级×10`，这一例量不到 mhp／mmp 了。改挑防具 129 春雷、4472 白马、4473 嘶风逐日驹、4476 团子（两版都带标签）。
   - 四件都有等级或专属需求（129 req_actors 152，其余 req_level 45／75），挑的时候有别的角色能装，换成新建角色后就装不上，原来会抛「没装上」。现在 `forceChangeEquip` 没装上就改成直接写槽位（`direct`，同既有 direct 例的做法，Godot 侧 `keep_unequippable` 已经对应）。别的 9 例两版的产物逐项不变（新源上和原来的 custom_params.json 比过）。
   - 新源选中 4472（角色 2，direct）；旧源 v0.28 也跑通，同样选中 4472（旧源产物这一例会从 1925 变成 4472，下次旧源同步时会看到）。
   - `tests/xiyou_custom_params.gd` `converter_all_parsed`：件数按参照的 `releaseVersion` 取（v0.28 224、v0.62.12 274）。集成分支在这行写死成 274，合并冲突时保留了本单的按来源写法。
2. **XNanoha.finish**（`core/nanoha.gd`）：新源 `installNanohaSharedKillRuntime` 的 endAction 包装改成 `window.CodexNanohaAdapt(nanoha, 0.5)`。重制的队友击杀改调 `XNanoha.adapt(n, 0.5)`：软上限前每只 +5／+15，累计次数每只 +0.5，和 1768 Conclude 用同一个计数。这是跟进新源的改动，不是修原版错误，所以没加回退开关。
   - 先在新源重出了 nanoha_kill 夹具，再改代码。新源和旧夹具的差别只有队友击杀那 4 例（plus 减半），其余 9 例逐项相同。
   - 探针加了一例 `kill.mate.aoe.softcap`（累计次数从 3000 起，AOE 杀两只：+6.666…／+19.998…），snap 里加了 `count`（原版 `_codexNanohaAdapt`，旧源恒为 null），这样软上限和 0.5 计数都有对照。夹具从 13 例变成 14 例。
   - 测试 `tests/xiyou_nanoha.gd`：plus 改成按浮点比（软上限以后是小数，原来按 int 比会把 2.5 和 2 当成一样）；count 有就比；`adapt` 设置写 `flags.codexNanohaAdapt`。

## 验证（本机，`XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`；产物由转换器 `--app` 新源重出，generated/oracle 克隆自 newsrc3 树，再用集成树的 alien_battle.json 补齐；工作树的 `冻结正式源/app.nw` 链接已改指 v0.62.12，这个链接不入 Git）

| 场景 | 改前（64692cf2） | 改后（合 451012b6 之后） | 说明 |
|---|---|---|---|
| xiyou_custom_params | 158/160（covers_aliases 缺 mhp／mmp，converter_all_parsed 274≠224） | 160/160 | — |
| xiyou_nanoha | 夹具重出后、改代码前 6 项失败（4 例队友击杀 after、softcap before／after、twice） | 289/289 | — |
| xiyou_state_effects | 175 失败（29958/30133） | 175 失败（未变） | revive.apply 173、action.counter.sequence 1（2792）、rest.costume.undefined_note 1，都是 newsrc3 留下的，不在本单 |
| xiyou_param_states | 1 失败（`source`） | 1 失败（未变） | `source` 夹具身份，归规则 ④ |

- 选测（`选测.py 64692cf2 --list`）另外选中 xiyou_event_compare：9/11，失败的是 `no_new_skipped`（m4e71p0 CodexGuide、m4e76p0 CodexWhisper、ce1370 等新源事件脚本没翻）和 `no_regressions`（m4e69p1、ce117～ce188 …）。这些是新源事件内容的问题，和奈叶击杀无关。我没在基线上单独复跑这个场景（一次要十分钟以上）。
- `事件空绿扫描.py --check`：rc=1，4747 条 ✗，几乎全是「在 event_states.json 里但预设已删（产物过期）」，另有「预设里有但没量」（m187e3p1#t75 等）、m213e2p1／p2#a3 一条效果都没走到。本树的 event_states.json 和集成树逐字节相同，本单没碰事件，归八戒补跑事件状态探针。
- `工具回归.py`：插件备注覆盖（test_known_unread）、探针登记检查（death_admission_probe 没关五乘区）这 2 项失败，和 newsrc3 时一样，是集成分支原有的，与本单的两个探针无关。
- `语法检查.py` 通过（591 个 .gd，0 个问题）。

## 改了哪些文件

- `03_转换工具/mv_oracle/custom_params_probe.cjs`（PICKS、装不上改直写槽位）
- `03_转换工具/mv_oracle/nanoha_kill_probe.cjs`（adapt 选项、snap count、softcap 例、注释）
- `01_Godot工程/modes/xiyou/core/nanoha.gd`（`finish` 走 `adapt(n, 0.5)`）
- `01_Godot工程/tests/xiyou_custom_params.gd`、`tests/xiyou_nanoha.gd`、`tests/fixtures/nanoha_kill_oracle.json`
- 产物 `generated/oracle/custom_params.json` 不入 Git：合并后在集成树用新源重出（`XIYOU_APP=…/v0.62.12/app.nw node custom_params_probe.cjs`，然后拷进 generated/oracle，或者跑同步）。

## 变更记录草稿

## 2026-11-06 【cc·哪吒·未经审查】新源 custom_params 探针改挑防具；奈叶队友击杀走适应软上限（dev.待定）

custom_params 的 mhp_mmp_eight 改挑春雷／白马等防具（新源专武不再写 mhp／mmp），装不上就直接写槽位；件数按来源比。XNanoha.finish 跟进新源 `CodexNanohaAdapt(nanoha, 0.5)`，nanoha_kill 夹具用新源重出，加了软上限例和累计次数。custom_params 160/160、nanoha 289/289；state_effects、param_states 与改前相同。核查：待审查（改了 nanoha.gd）。

## 交接板

- 下一步：集成树重出 custom_params.json；敌人复活随能力缓存脏不脏而变（规则车道）；event_states 产物过期（八戒）。
- 用户试玩说明：无
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 同 newsrc3：`新建工作树.sh --补齐` 还不认 `XIYOU_APP`，这次补齐又按 v0.28 跑了转换器、`app.nw` 也链回旧源，我是手动改的链接、重跑的转换器，generated/oracle 也是手动从别的树克隆的。另外 `并行测试.py` 的 generated 新旧检查拿主工作区（旧源）来比，新源树每次都得加 `--skip-generated-check`。建议这两个脚本在设了 `XIYOU_APP` 时以它为准（工具，小）。
