# 交付：cc/rules-newsrc6

- 车道／工作者：C 规则／rules（cc）。从集成头 21cd90eb 切出，交回集成分支。
- 状态：可合并（只有本交付单，没有代码改动）

## 任务（总装定）

DN 伤害取整口径：流萤二期 firefly 例里敌人普攻打流萤，基础 72×防御 0.05＝3.6，重制扣 4、原版参照扣 5。查原版在哪一步取整。

## 结论

**不是取整问题，是 `liuying2_probe.cjs`（cc/wukong-newsrc9 9ad2cb1d，未进集成）漏了 `superReference(w)`。**

- 在 v0.62.12 上用那个探针的同一场战斗量（临时脚本 `mv_oracle/.sandbox/dn_trace.cjs`，不入库）：这一击 `installDamageElementRuntime` 的伤害明细（`action._codexDamageBreakdown`）是 defense 0.05、incoming **1.5**，origins 「路线压制·承伤 ×1.5」。流萤是超强者（探针开了 2494），超强者路线压制让她承伤 ×1.5：72×0.05×1.5＝5.4，Math.round 得 5。
- 路线压制按 O-050 不移植，别的探针都用 `shared/host.cjs` 的 `superReference(w)` 去掉（binding、guyu、heartsteel、tusu 等）。同一脚本加上 `superReference(w)` 后，这一击是 4（3.6→4），暴击 5（5.4→5），与重制一致。
- 取整口径本身对得上：原版最后一步 `Math.round`（YEP DamageCore／installDamageElementRuntime 的最终值），最低 1；基础值扫 1～10000（×0.05：1→1、20→1、40→2、72→4、73→4、75→4、80→4、90→5，暴击另一列）都和 `js_round` 一致。重制 `core/damage.gd` 结算用 `XPower.js_round`（负数 .5 照 JS 往大取），固定减伤那处 `roundf` 只作用于非负值，等价。Math.random 0.5 时方差为 0，这次没另量方差。

## 建议（交总装派）

- `liuying2_probe.cjs` 照别的探针加 `superReference(w)`（`newGame` 之后要开 2494 的话用它返回的 `enableSuperSwitch()`），重出 `liuying2_oracle.json`；`xiyou_liuying2.gd` firefly 例去掉「生命按参照」那段覆盖，改回逐步比生命。属悟空 newsrc9 的分支，我没动。
- 第一期 `liuying_probe.cjs` 也没调 `superReference`，它只取我方天火伤害比值，应不受承伤影响，但顺手一起加更稳。

## 验证

- 没有 Godot 改动，没跑 Godot 测试。探针结论见上（v0.62.12，`XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`）。

---

# 第二单：DU 两个旧战斗 P2（总装加派，同分支）

## 结论：两项都早已修好，新源上原版行为没变，本单不改代码

- **① 武器解放误触发（清积压第七期 W1／P2）**：dev.225（八戒_90）修掉：不能行动时不掷解放；断言在 `xiyou_weapon_unleash`。
- **② 空行动收尾消耗行动结束状态（清积压第十期 P2，`bada3339`）**：dev.225 修掉：行动无效时不减行动结束状态；断言在 `xiyou_attack_query`。
- 进度核定 dev.239 已写「交接板里两条已知战斗 P2（W1、空行动收尾）都已修」，变更记录 1743 行（沙僧 P2 核对单）也复核过。
- **新源复核**：本树 generated 换成集成树 recursing-shamir（21cd90eb）的克隆，其中 `oracle/weapon_unleash.json`、`oracle/attack_query.json` 的 sourceIdentity 都是 v0.62.12。`并行测试.py … xiyou_weapon_unleash xiyou_attack_query`：2 个场景全部通过（321 秒，排槽）。即新源原版这两处行为与旧源一致，重制照旧对得上。
- **要改的只有文字**：`重制步骤清单.md`「战斗规则与战斗画面」一行的「旧依据」末尾仍写「武器解放误触发（第七期 W1／P2）、空行动收尾消耗行动结束状态（第十期 P2）仍待修」，已过时。进度账归审查线程，我没改，请总装转审查线程改成「已修（dev.225）」。

## ③ 近 10 期核查报告（40～50 期）里提到的战斗相关项（只列，没逐条核是否已销账）

下表按报告原文摘出；「状态」只写报告里自己说的，后续报告没提到的标「未见销账」，需要总装或审查线程再对一下。

| 出处 | 项 | 状态 |
|---|---|---|
| 审查 42 P2-1 | events4 `_actors_add_state` 给已死亡的角色也加状态，原版不加 | 未见销账 |
| 审查 42 P3-1～3 | raven1：`xiyou_raven_reflect` 只比比例盖住设置差；反射分支只补渡鸦的 `applied`；10124 神话形态被反射时黑暗侵蚀增伤晚一击，原因没查清 | 未见销账 |
| 审查 43 P3-1、P3-2 | `act()` 开头清所有角色 `stale_state_ids` 可能偏早；`apply` 开头无条件置 `rv_tp_refreshed=false`，嵌套 apply 会冲掉外层 | 未见销账（45 的 P3-2 与 43 P3-1 相关） |
| 审查 45 P3-1、P3-2 | raven4：setHp「值变了」判早了；跨行动清除点比原版少 | 审查 47 称已由 raven5 修掉 |
| 审查 45 P3-3 | events6 回退支：同一次得经验连升多级没量 | 未见销账 |
| 审查 41 P3-4 | `XSvPngFd.scale` 读 `skill_ids`，原版读 `skills()` | 未见销账 |
| 审查 40（12 条 P3） | dot 恒真断言（`xiyou_dot.gd` 142、339）、rules8 732 跳过变体、dot2 `or true` 恒真等 | 未见销账，没逐条看 |

非战斗的（界面、工具、事件）没列。没有找到别的「仍待修」战斗 P1／P2。
