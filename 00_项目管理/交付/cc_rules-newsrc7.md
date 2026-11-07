# 交付：cc/rules-newsrc7（集成整轮 6f07c74e 失败表：反击时机带出的 3 个场景）

- 车道／工作者：规则（cc，项目线程「完成再刷西游Godot引擎重制」），总装失败表（run 42353726551）。
- 状态：**可合并**。合回集成分支 `cc/newsrc-switch`，**不进 main**。
- 基于：集成 6f07c74e。产物从集成工作树 nostalgic-raman（6f07c74e）`cp -c` 克隆。

## 场景 → 用例 → 根因 → 修法

### 1. xiyou_combat：counter_logged、counter_negates_hit、enemy_mrf_1、reflect_logged、reflect_hits_user

- 场景：角色用物理技能 401（三段）打反击率 1 的敌人，然后另一个角色用普攻打魔法反射率 1 的敌人 2。
- 根因：
  - 反击两项：断言写的是旧源「反击代替挨打」。新源（COUNTER_AFTER_HIT，默认）敌人先挨打再反击，属预期变化。
  - **魔法反射没坏**。enemy_mrf_1 报 `[0,0,[1]]`：测反射用的敌人 2 在前面就死了。401 的三段在新源下先打中再反击，这只敌人也被打到 0，反射用例拿到的是一只死敌人，反射自然不发生。`_invoke` 的反射分支和随机数顺序都没动（拆分只动了反击之后那段）。
- 修法（只改测试）：反击用例两头测。回退支（`XBattleLogic.COUNTER_AFTER_HIT = false`，字面量）保留旧断言；默认支新加 `counter_after_hit_logged`（hit 在 counter 前，反击打到行动者）和 `counter_after_hit_damages`（敌人掉血）。测反射前，敌人 2 已经倒下的话先拉回满血。

### 2. xiyou_qiyu：invoke.a164／a162.s9934.cnt.countered

- 场景：奇遇角色 164、162 用普通一拳 9934 打反击敌人。
- 根因：参照（v0.62.12 qiyu.json）是走整段行动序列量的，序列开头 `IMMORTAL: targets, true`，敌人挨完打还活着，所以反击了（log 里有 e1→a164）。测试直调 `logic._invoke`，没有序列的不死，敌人被一拳打到 0 当场倒下，新源规则下死了就不反击。
- 修法（只改测试）：调 `_invoke` 前给目标 `immortal = true`，跟参照的序列一致。重制规则本身对得上。

### 3. xiyou_sequence_visual：counter_death_cmds、counter_death_jump

- 场景：s104 反击致死（行动者 1 HP、全体敌人反击率 1）。
- 根因：参照 `s104_counter_death` 是旧源 v0.28 量的。我用无头 Chrome 照原来的方法（`__seqRef.suite` 加 prep）在 v0.62.12 上重量了这一段；同一脚本在 v0.28 上量出的指令帧与原参照完全相同（SHOW BATTLE HUD 64、共 80 帧），说明方法对得上。新源 SHOW BATTLE HUD 在 69 帧、共 85 帧：多出来的 5 帧是先挨打那一下的日志（pushBaseLine、popupDamage×2、waitForNewLine、popBaseLine）。重制多了 7 帧，差 2 帧。
- 2 帧的来由：YEP `invokeAction` 一次只套一对外层 pushBaseLine／popBaseLine，挨打结果和反击结果都在这一对里面。重制 `sequence_player._push_results` 每段结果都自带外层一对，挨打、反击各带一对，就多了 2 条。
- 修法：
  - `battle_logic._invoke` 新源反击支给 counter 条目加 `after_hit = true`（只是标记）。
  - `sequence_player._play_results`：counter 带 `after_hit` 时，前面那段挨打的结果不收外层，后面反击的结果不开外层。旧源路径、多目标、反射都不受影响（只认这个标记）。
  - 夹具 `action_sequence_hp_oracle.json`：`s104_counter_death` 换成新源读数，旧的改名 `s104_counter_death_v028`。测试默认比新源，回退支（`COUNTER_AFTER_HIT = false`）比旧源。
  - 小注：重量的 v0.28 读数和原夹具相比，cmds、sprites 都一样，只有 frames（镜头层）有出入，可能是原来先跑过别的招。这个测试不比 frames，所以不影响。
- 重量脚本是临时的，在 `ui_reference/battle_pace_ref.cjs` 基础上改的，没入库。要重跑的话：serve.py 起 v0.62.12，战斗夹具 4 人；等到 a10 的指令窗，再跑 `__seqRef.suite([['s104_counter_death',{skill:104,target:1,prep}]])`，prep 里行动者 setHp(1)，敌人 xparam(6) 返回 1。

## 优化登记草稿

无新 O 号（反击时机已由总装补登 O-待定·敌人反击时机；本单是它带出的测试与画面）。

## 变更记录草稿

## 2026-11-07 【cc·规则·未经审查】新源反击时机：反击致死画面逐帧、测试两头测（dev.待定）

- 新源敌人先挨打再反击时，日志外层只一对 pushBaseLine／popBaseLine（YEP invokeAction）。s104 反击致死在 v0.62.12 重量，逐帧对上（SHOW BATTLE HUD 69 帧）。
- xiyou_combat、xiyou_qiyu、xiyou_sequence_visual 的反击用例改成两头测（默认新源，回退支旧源）。魔法反射没坏，是反射用的敌人被新源先挨打的三段打死了。

## 交接板

- 用户试玩说明：敌人反击把角色打死时，先能看到敌人挨打的伤害数字，再看到反击。
- 需要用户决定：无。

## 待交叉核查

- cc/rules-newsrc7：`sequence_player._play_results` 外层日志一对（甲档：战斗画面）；`battle_logic._invoke` after_hit 标记。

## 可优化（流程／工具／效率）

- 反击致死的读数没有入库脚本，这次是临时改的 battle_pace_ref.cjs。值得做成 `ui_reference/seq_counter_ref.cjs`（参数：app、技能、prep），以后换源可以直接重量。

## 验证

- 本地专项：xiyou_combat 36/36、xiyou_qiyu 231/231、xiyou_sequence_visual 73/73。
- 云端选测（基准 6f07c74e）209 个场景全部通过：提交 c676145696，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42355533781
