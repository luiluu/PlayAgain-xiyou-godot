# 交付：cc/bajie-fix1b

- 车道／工作者：C 规则／八戒（cc，唐僧总装派 fix1b）
- 接：接自另一账号八戒的 cc/bajie-fix1（头 4930ef4b），代码和测试未改动，只收尾验证
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·八戒·未经审查】修原版笔误 12 条，可回退、默认开（dev.待定）

- 依据：rules3～rules6 探针测出的原版行为，加技能说明里写明的本意。原版测量不动，`同步正式西游.py` 报「测量不变」，**不需要测量接受单**。
- 做法：`xiyou_export.py` 的 `EFFECT_FIXES` 给对应块多生成一份 `fixed` 程序，原版程序照旧留着；`XStateEffects.fix_on` 按开关选。金剪追加、戮仙印记是 `battle_logic.gd` 的钩子，绯红之夜在 `_variable_writable`，余辉在 `xuan_battle.gd` `_yuhui`。
- O-154（手动璃壁下回合排最前）保留，没动。
- 测试：`xiyou_state_effects` 开头关掉全部修正比原版（回退支），`_fix_blocks` 开着比修正；`xiyou_xuan_battle` 加 `_yuhui_fixed`；`xiyou_xuan_auto`、`xiyou_state_js` 比原版的地方关开关；`测试状态js翻译.py` 加 `EffectFixTests`。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | 不灭之躯 2554（`core/state_effects.gd`） | `target.RemoveState` 写错，TypeError，状态不消耗，无限复活 | 复活后移除自身 | 说明写「死亡后会复活一次」，同名 1580 也是一次 | `XStateEffects.FIX_UNDYING_2554 = false` | cc（八戒） | 待用户决定 |
| O-待定-2 | 护体罡气 2562（`core/state_effects.gd`） | MP 归零时移除 1662（破魂），自己不消失 | 移除自身 | 明显抄错状态号 | `XStateEffects.FIX_QI_GUARD_2562 = false` | cc（八戒） | 待用户决定 |
| O-待定-3 | 永世乐土 1302（`core/state_effects.gd`） | 累进 `_zuizhongshanghai`，没人读，没有减伤 | 受伤减 4%×存活队友（不含自己），最高 13% | 说明原文 | `XStateEffects.FIX_ELYSIA_GUARD_1302 = false` | cc（八戒） | 待用户决定 |
| O-待定-4 | 剑道争锋 2575（`core/state_effects.gd`） | 累进 `_zuizhongshanghai`，没人读，没有增伤 | 伤害 +0.5%×层数；获得 1 层，回合结束加 1，最多 10 | 代码里的系数和层数 | `XStateEffects.FIX_SWORD_2575 = false` | cc（八戒） | 待用户决定 |
| O-待定-5 | 挨打反击 1072（`core/state_effects.gd`） | `this.isDamageAffected` 不存在，TypeError，不反击 | 受伤 50% 由持有者放双蛟逐月打攻击者 | 说明「受到攻击时，50%概率触发双蛟逐月」 | `XStateEffects.FIX_SCALE_COUNTER_1072 = false` | cc（八戒） | 待用户决定 |
| O-待定-6 | 金剪追加 1068（`battle/battle_logic.gd`） | crit 阶段冻结版不触发，不追加 | 持有者暴击时追加金蛟剪·断魂 | 块注释写明 | `XStateEffects.FIX_SCISSORS_CRIT_1068 = false` | cc（八戒） | 待用户决定 |
| O-待定-7 | 往世乐土 1301（`core/state_effects.gd`） | 排了强制行动，但解除 immortal 后已倒下，339 不行动，只消耗状态 | 留 1 血不倒，移除状态，事件阶段放万古青天一株莲 | 说明「不会死亡，而是移除状态并释放」 | `XStateEffects.FIX_ELYSIUM_1301 = false` | cc（八戒） | 待用户决定 |
| O-待定-8 | 秩序 1711、同谐 1716（`core/state_effects.gd`） | `else if` 从小到大，只有最低档生效 | 按活人数分档，大的优先 | 明显写反 | `XStateEffects.FIX_ORDER_TIERS = false` | cc（八戒） | 待用户决定 |
| O-待定-9 | 戮仙印记 1067 与 5576、5577（`battle/battle_logic.gd`） | 加成写在 Custom Damage Formula，实测不生效 | 目标有印记时伤害 ×4 | 备注写「放大 400%」 | `XStateEffects.FIX_MARK_5576 = false` | cc（八戒） | 待用户决定 |
| O-待定-10 | 鼬被动 1318（`core/state_effects.gd`） | `!v == 1`，只有 v 为 0 才预约 | v 不是 1 就预约 | 写法笔误 | `XStateEffects.FIX_ITACHI_1318 = false` | cc（八戒） | 待用户决定 |
| O-待定-11 | 绯红之夜 1683（`core/state_effects.gd` `_variable_writable`） | 变量号超范围，写不进，永远不触发 | 放开 1683 号，抗 10 次致死 | 说明「每场免疫 10 次致死」 | `XStateEffects.FIX_CRIMSON_1683 = false` | cc（八戒） | 待用户决定 |
| O-待定-12 | 星纹余辉（`core/xuan_battle.gd` `_yuhui`；installNativeXuanRuntime.js:308） | 钩子挂在 Game_Battler.gainHp，角色走不到，不给护盾 | 回光溢出按 20%／35%／50% 转护盾 | 星纹说明；开局默认配的星纹 | `XXuanBattle.YUHUI_SHIELD = false` | cc（八戒） | 待用户决定 |

## 玩家能感觉到的变化

| 内容 | 以前 | 现在 | 手感 |
| --- | --- | --- | --- |
| 不灭之躯（10052） | 每次倒下都满血复活 | 只复活一次 | **明显变弱**，之前等于不死 |
| 护体罡气 | 蓝空后一直挂着 | 蓝空后状态消失 | 蓝空后没了图标，数值几乎不变 |
| 永世乐土（小爱莉） | 没有减伤 | 每个存活队友减伤 4%，最高 13% | 小爱莉变肉 |
| 剑道争锋 | 没有增伤 | 随回合从 0.5% 涨到 5% | 长线略强 |
| 逆鳞之怒（琼霄） | 不反击 | 受伤 50% 放双蛟逐月 | **明显变强**，受击常常连出招 |
| 金剪追加（琼霄） | 不追加 | 暴击追加金蛟剪·断魂 | **明显变强** |
| 戮仙印记（琼霄） | 没用 | 带印记的目标吃 4 倍金蛟剪、双蛟逐月 | **非常强**，这条最该试玩确认 |
| 往世乐土（小爱莉） | 倒下就只是倒下 | 第一次归零不死，留 1 血放一株莲回满全队 | **明显变强** |
| 秩序、同谐（护符） | 只有最低档 | 人越多档越高 | 满队更强 |
| 鼬被动 | 变量为 0 才触发 | 变量不是 1 就触发 | 触发更频繁 |
| 绯红之夜 1683（神明灵） | 从不抗死 | 每场抗 10 次致死 | **明显变强** |
| 星纹余辉（璇） | 溢出不给盾 | 溢出转护盾 | 璇开局就有的星纹开始有用 |

## 交接板

- 下一步：等 Kyo 试玩确认这 12 条。
- 用户试玩说明：见上表，琼霄三条（挨打反击、金剪追加、戮仙印记）叠起来可能超模，优先试。
- 需要用户决定（没有擅自改，都写进表里说明）：
  1. 护体罡气说明写 9.9% 由蓝代替，代码是 1%，这次只修了移除状态，比例没动。
  2. 天剑极意说明写「用剑时伤害 +3.5%」，代码按层数到 5%，也不限用剑；按代码做的。
  3. 一株莲说明写「回复所有队友（包括死亡）」，技能范围只打活的，已倒下的队友不会被拉起来；说明里「对敌方全体造成伤害」那段也没做，只跑技能数据里的范围。
  4. 戮仙印记 ×4 按备注来，备注那段公式的其它部分（`a.atk - target.def`）没用，它比技能现有伤害低得多。

## 进度账

- 无（原版笔误修正，不改完成度）。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 云端选测：提交 4930ef4b（ci/cc/bajie-fix1），138 个场景、4 片，全部通过（基准 951e3c60）。运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41798649475
- 合并 main（f27dc0aa，dev.309）：无冲突；main 新增的只有文档、版本号、开发编号，没碰本分支的代码／测试／转换器文件，按车道须知不重跑选测。

- 专项（本机）：`xiyou_state_effects` 25062、`xiyou_state_effects_tp` 538、`xiyou_state_js` 1733、`xiyou_xuan_battle` 272、`xiyou_xuan_auto` 4556、`xiyou_battle_log` 64、`xiyou_determinism` 372，全过。
- 工具：`测试状态js翻译.py`、`测试公式程序.py` 过；`语法检查.py` 0 问题；`回退开关覆盖.py` 无新缺口；`内容覆盖检查.py` hard 0、new 0。
- 同步：干净基线，退出码 0，「测量不变」，没有接受单。
- 没测：一株莲的完整流程只测到排队和 `_force_action` 能跑出记录；实际手感、数值平衡都没试玩。

## 本分支提交

f0215845（代码＋测试）、6397789d（state_js 参照、余辉测试类型）、4930ef4b（交付单草稿）、fix1b 改名与合并 main。

## 待交叉核查（核心文件）

- `state_effects.gd`（`fix` 分派）、`battle_logic.gd`（金剪追加、戮仙印记钩子）、`xuan_battle.gd`（`_yuhui`）。
