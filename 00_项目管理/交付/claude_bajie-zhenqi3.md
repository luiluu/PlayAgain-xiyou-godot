# 交付：claude/bajie-zhenqi3

- 车道／工作者：B 界面／C 规则／八戒（Claude，重制_八戒_16 开工准备，交给重制_八戒_17）
- 状态：进行中——只做了开工准备：从 main（3725463）切出分支，代码尚未开始，没有未提交的改动。第二批合并为 dev.081，产物与第二批相同，不必重跑 `--补齐`；main 再改了切片、探针或转换器时再跑。

## 接手说明（给重制_八戒_17）

- 任务（唐僧_8 2026-10-18）：真气第三批。独占真气相关代码、探针、测试，以及 battle_logic 里道法的接线；切片要加事件时写进本单，由唐僧协调悟空。优化编号只用 O-048。
- 原版：冻结源 `js/codex/runtime/installNativeZhenqiRuntime.js`。
  1. **道法运行时效果**（严格级，先在 zhenqi_probe 补参照用例，再改 Godot）：
     - 第 92～98 行：连击（`attackTimesAdd`＋1）、分神（`actionPlusSet` 再加一个 [1]，必定再动）、金身（`shieldEffectBonus`＋daofaScale）。
     - 第 113～119 行：`executeHpDamage`。我方受伤时，护法乘 (1−0.3×scale)；元婴护体（学了 fixed:yuanying）每场一次，致命伤保留 1 点生命（`_codexZqGuard`，`BattleManager.setup` 时清掉）。
     - 第 328～337 行：命中 `xparam(0)` 下限 0.9（所有角色都适用，不只道法）；破甲·真气是状态 2705，施加者有破甲道法时，目标双防倍率＝1−0.5×scale，`states()` 里改写特性 21 的 3／5 号，`clearStates`／`eraseState` 时删掉。
     - 被动标签：灵台的 passivePRETP（战斗间保留 TP）、护法的 passiveSUBS（掩护）、破甲的 passiveATKST2705。先查 Godot 有没有，没有的要补。
     - Godot 接入点：`XBattler` 的普攻次数、行动次数、伤害执行、状态，以及 `XZhenqi.has_daofa`、`daofa_scale`（已有）。
  2. **神兵试炼**（第 266～278 行）：`weaponMasters`（敌人备注 `<CodexZhenqi: weapon N>`，取首个成员是它的敌群）；`startWeaponTrial` 对手强度＝修行进度层守层者 ×2，用 `_pendingScale`，打法同瓶颈之战，`troop_setup` 已支持 ref/scale，需加 scaled 分支；第 160～165 行 `unlockSpecs`：打败 master 才把 `sp.w[wtype]` 与 `weaponTrials` 记上，并提示「神兵试炼完成：…」。闭关首页的 `{"page": "weapon"}` 现在由 `XZhenqiRetreat` 显示占位提示，改成真正的菜单（列表、［试炼完成］／［已领悟·未完成试炼］标签、返回、离开）。
  3. **降服时含隐藏成员**：原版 `$gameTroop.members()` 包括没出场的隐藏成员；Godot 的 `on_victory` 只拿 `logic.enemies`。可以让 `XBattleLogic` 把隐藏成员也传进去，或者由 `unlock_specs` 自己读敌群数据，并补一个带隐藏 Boss 的敌群用例。
- 参照与测试沿用：探针仍是 `03_转换工具/mv_oracle/zhenqi_probe.cjs`，第二批的 `B(...)` 包装每例会清全局；Godot 测试是 `tests/xiyou_zhenqi_break.gd`，按前缀接新用例（可加新前缀，并同步改 `xiyou_zhenqi.gd` 的 SECOND）。注意：参照新局的难度是 2，Math.random 固定为 0.5，原版 makeRewards 只计已倒下的敌人。
- 跑探针约 4 分钟（并行负载高时更久），放后台跑；跑完把 `.sandbox/zhenqi.json` 复制到 `generated/oracle/` 再跑 Godot 专项测试。
- 交付前：`git merge main`，本工作树跑 `同步正式西游.py --accept-additions`（约 30 分钟），再跑 `检查.sh --oracle`，最后把本单状态改成「可合并」，并通知会话「重制_唐僧_8」（或当时的总装）。

## 本分支提交

- （尚无）
