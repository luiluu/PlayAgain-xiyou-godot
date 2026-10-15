# 交付：claude/bajie-actor-power

- 车道／工作者：B 规则·界面／八戒（Claude，重制_八戒_4，沿用）
- 位置：worktree `.claude/worktrees/bajie-flow-test-3b9e3c`，分支 `claude/bajie-actor-power`
- 状态：进行中
- 任务（唐僧 2026-10-15 派）：角色战力 XPower.actor 对上正式版（①30 级学技能差异 ②单次伤害偏大 ③passive_cache 缺 againUse／atkk），把 xiyou_power 角色比对计入结果，再接装备页／技能页「战力 N」与主菜单（cached_actor）。
- 预分配编号：O-031～O-033

## 停在哪里（重制_八戒_4，上下文到 50% 停下；下一会话 重制_八戒_5 接）

- ① 30 级学技能差异：**不是规则问题**。正式版新开局的等级上限是 10，探针里 changeLevel(30) 实际只到 10 级（MV 只学到 10 级的 160，Godot 测试升到 30 学了 311、502）。power_probe 改为记录实际等级 `level`（另记 `asked`），xiyou_power 按实际等级 change_level_mv。已重跑探针（本提交）。
- ② 单次伤害偏大：**已定位**。node 里对裸装 1 号角色、防御 1 万的中性敌人做 makeDamageValue 预演：元素增幅 bonus 2.4 两边相同（技能 2746 妖兽化形 passiveELUP 33%＋技能 41 天遁仙法 passiveELUP01 107%）；差别是
  - **growth 0.6437651755973418**：正式版 CodexDamage 的 growthMultiplier（五乘区预算软上限，installNativePowerZonesRuntime 的 CodexDamageHooks），Godot XDamage 首期精简把 growth 固定为 1；
  - **暴击倍率 1.7**（Godot 按 1.5＋criticalMultiplierBonus），来源待查（可能同一钩子或别的 criticalAdd）。
  - 结果：正式版普通 9、暴击 16（Godot 14、约 22）；命中 1、闪避 0、暴击率 0.19 两边一致。
  - 这两项是**伤害规则层**的缺口（实战伤害也走 XDamage），不只是战力。xiyou_rules 现在全过，说明战斗对照的用例里没覆盖到这个钩子或它为 1——建议唐僧判断：由 C 规则车道移植 PowerZones（growthMultiplier）与暴击加成，战力随后自然对上；或战力先单独加。
- ③ againUse／atkk：未动（XPower 里 AgainUse 自己扫备注，atkk 未计）。
- 下一步：读 `js/codex/runtime/installNativePowerZonesRuntime.js` 的 build 钩子（growthMultiplier、criticalAdd），移植进 XDamage（要对 xiyou_rules 重测），再看 xiyou_power 角色比对；对上后把 ACTOR_PENDING 改回 check，再接装备页／技能页「战力 N」与主菜单 cached_actor。
- 用户 2026-10-15 指示「按建议继续」：由本车道移植伤害结算的成长乘区与暴击加成（XDamage），再对战力。已查到的写入点：
  - growthMultiplier：`installNativePowerZonesRuntime.js`（`growthMultiplier*=c`，约 2 万字，五乘区预算软上限）与 `installNativeZhenqiRuntime.js`（`growthMultiplier*=r`，真气）。
  - criticalAdd：`installDamageElementRuntime` 自身（passiveCrHarmRi、黑闪）、ImportedBalance（+12，引入角色）、NativeRace（q/2）、MiraRaven／YomiJingliu（专属角色）；另有 criticalMultiplier 在非 reference 时乘 `$gameSystem.criticalMultiplier()`。1 号角色裸装 1.7 的来源先查 passiveCrHarmRi（Godot 的正则不允许冒号后有空格）与 $gameSystem.criticalMultiplier。
  - 改 XDamage 后必须重跑 xiyou_rules（严格级），并核对悟空 dev.045 新加的元素吸收／G_StateParam 不受影响。
- 复现脚本：mv_oracle/.sandbox/try_dmg.cjs（不入 Git，内容：setupNewGame、Math.random=0.5、actor(1).clearEquipments、中性敌人、Game_Action 普攻 _codexPowerPreview、打印 _codexDamageBreakdown.rows[0]）。

## 本分支提交

- 53e097a 开工交付单
- （本提交）探针记实际等级；交付单写明差异定位
