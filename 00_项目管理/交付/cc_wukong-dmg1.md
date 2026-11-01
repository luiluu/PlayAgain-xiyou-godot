# 交付：cc/wukong-dmg1

- 车道／工作者：悟空（cc），1 号主角伤害差与效果型公共事件余项
- 基线：总装十派单，从 970e24c3（drops1 末端）切出。第六批进 main 后再按总装通知合一次 main。
- 状态：可合并

## ① 1 号主角伤害「高约 0.9%」

**结论：重制没有错，不用改。** 原因是 `yunshang_probe.cjs` 没有关五乘区（installNativePowerZonesRuntime 的成长修正，按数值平衡不移植，见数值平衡.md、O-044／O-050；别的伤害探针如 race_battle、attack_element 都先 `CodexZones.ENABLED=false`）。

- 新探针 `actor1_damage_probe.cjs`（关五乘区）把云裳专项的条件拆开：云裳在不在队（在就排第一）× 全员生命 +1e12 × 敌人物防 +5000 × 1 号 1／30 级，共 10 例。1 号与敌人的 param／xparam／sparam、普攻伤害、暴击，重制逐例完全一致（新专项 `xiyou_actor1_damage`）。不关五乘区时原版 1 号 1 级普攻是 207，关了是 308，重制 308。
- 把 `cc/bailong-yunshang4` 的 yunshang_probe 临时拷一份，分别开、关五乘区跑（没改那个文件）：1 号普攻开着 1731、关掉 1747，差 0.924%；山河击 10286 是 38372675 对 38715648，也差 0.9%。云裳自己的伤害不受影响，所以按「本例第一段」比比值时只有 1 号偏出约 0.9%。
- 建议（云裳车道）：yunshang_probe 开头加 `w.eval('CodexZones.ENABLED=false;')`，重跑参照后按比值比的那几项可以改回比绝对值。已告诉总装。

## ② 效果型公共事件 113 个不一致

盘点（交接板那条写着 dev.195 已清，这次逐项核了现状）：

| 来源 | 现在还剩 | 处理 |
| --- | --- | --- |
| 事件对照登记 `event_compare_baseline.json` | 3 例：m4e73p0（商店向导「战力短板」，五乘区预算，O-050 不移植）、m4e1p2／p3（更换称号，参照探针不经过标题画面，探针缺口） | 都不是重制的错，不用做 |
| 事件对照参照出错 `KNOWN_ORACLE_ERRORS` | m221e3p0、ce1344（参照探针跑这两页时报错，没有参照） | 留着：要先修探针才能比，归事件探针车道 |
| 内容覆盖基线 `content_coverage_baseline.json` | 2 项「未翻译」：CE46 一掷千金（战斗场合）的 250 播放音效、CE1401 敌人恢复所有血量（地图上也能用）的 331 更改敌人 HP | **本期做了**：战斗事件 250 记一条音效交画面层放；地图上 331 空操作（MV 战斗外只剩上一场的敌人，改了也看不到）。基线用 `--update-baseline` 清空，内容覆盖 hard 0 |

所以不用再分批：113 个里能做的已经全清，剩下的是探针缺口和定了不移植的。交接板那条可以归档。

## 变更记录草稿

## 2026-11-01 【cc·悟空·未经审查】1 号伤害差查明（五乘区，不改）、战斗事件播放音效、地图上更改敌人 HP（dev.待定）

- 新探针 `mv_oracle/actor1_damage_probe.cjs`（登记进 PROBES，产物 actor1_damage.json）与专项 `tests/xiyou_actor1_damage`：关五乘区后 1 号普攻在云裳专项的各条件下与原版逐例一致；云裳专项里 1 号偏 0.9% 是 yunshang_probe 没关五乘区。
- `battle/battle_event_runner.gd`：指令 250 播放音效记成 `se`，`battle/battle_scene.gd` `play_se` 放（CE46 一掷千金）。
- `map/mv_interpreter.gd`：指令 331 更改敌人 HP 在地图上空操作（CE1401）。
- `tests/content_coverage_baseline.json` 重写（未翻译清零）；`tests/xiyou_battle_common_events` 加 se_in_battle。

## 验证

- 探针 `actor1_damage_probe.cjs` 10 例无错；`同步正式西游.py --accept-additions` 跑完「测量不变」（产物先手工放进 generated/oracle，同步核过一致），留了指纹。`内容覆盖检查.py`：hard 0，`--update-baseline` 清掉 2 项。
- 选测 55 场景（CHECK_JOBS=3）：`xiyou_actor1_damage`（新）、`xiyou_battle*`（含 battle_common_events 新加的 se_in_battle、battle_drop、battle_gaps、battle_ui 等）、`xiyou_rules`／`_d2`～`_d6`（前缀展开成全部 24 份，比派单多）、`xiyou_custom_damage`、`xiyou_formula_effects`／`_equipment`／`_program`／`_rest`、`xiyou_formulas`、`xiyou_cat`、`xiyou_garou_battle`、`xiyou_jingliu`、`xiyou_jingliu2`、`xiyou_mira_battle`、`xiyou_raven_battle`、`xiyou_sukuna_battle`、`xiyou_toji_battle`、`xiyou_yomi_battle`、`xiyou_yunshang`、`xiyou_event_compare`：54 过、1 失败——`xiyou_guyu`（读不到 generated/oracle/guyu.json）。这个和本期改动无关：本分支的底子里 PROBES 还没登记 guyu_probe（main 909f5638 才登记），所以同步不产出它；合 main 后会好。日志 `04_验证/本地结果/并行测试/20261101_072540_qdtti62h/`。无偶发。
- 反向：把战斗事件的 250 分支改掉，`xiyou_battle_common_events` 的 se_in_battle 失败（250 进了 skipped），恢复后通过。① 没有改代码，不用反向；专项本身就是「关五乘区后逐例一致」的回归。
- `语法检查.py` 通过。

## 交接板

- 下一步：云裳车道给 yunshang_probe 关五乘区，再把按比值比的几项改回绝对值；事件对照参照出错的 m221e3p0、ce1344 修探针。「效果型公共事件 113 个」那条归档。
- 用户试玩说明：战斗里用「一掷千金」钱不够时会响音效（原来没声音）。
- 需要用户决定：无。

## 进度账

- 伤害链：1 号主角差异查明不是重制问题。内容覆盖：未翻译 0。

## 可优化（流程／工具／效率）

- 建议：伤害类新探针统一用 shared/host 里一个开关（比如 `start({zones:false})`）关五乘区，免得新探针忘了关又误报差异；归哪条车道：哪吒（工具）。

## 本分支提交

- WIP：1 号普攻伤害参照
- WIP：战斗事件 250、地图 331
- 交付单（本提交）
