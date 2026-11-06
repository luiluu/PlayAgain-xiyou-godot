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
