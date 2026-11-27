# 交付：luiluu/t570

- 车道／工作者：T570 天启篇状态削弱进结算（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-27 【cc·T570·未经审查】天启篇护体罡气、绯红之夜、不死之躯、吃瘪之力的削弱真正进结算；两条「30% 复活」改成真 30%；首领状态窗异常页签（dev.待定）

- 玩家可见：天启篇里真气护体（护体罡气）改为用魔法抵消 30% 伤害（原来实战 9.9%）；普通闪躲（绯红之夜）每场只救一次（原来三次）；不灭之躯（不死之躯）复活回 30% 生命（原来回满）；预感的庇护、拼命守护的「死后 30% 复活」实际几率从约 51% 降到 30%；吃瘪之力（贝吉特）受到伤害 −10%（原来实战 −50%，Kyo 11-27 事项 73 定「天启篇改成设计稿 −10%，西游档不动」）。状态说明、技能说明一并改成这些数。首领状态窗里，天启篇标成「异常」的 39 个状态都进「减益」页签（原来 22 个在「增益」）。西游档不变。
- 起因：T566 R2 发现 2562／2560／2554 的削弱只写进备注（`note_sub`），战斗跑的是转换器预编译好的 `effects`，备注改了不进结算；1099／1178 的复活条件是原版「hp≤0 掷一次、isDead 再掷一次」，30% 一次实为 1−0.7²≈51%。
- 设计值（私密设计仓 `重制设定/天启篇_全角色技能重构_v0.2.md`）：165 真气护体「30% 受伤由魔法值代替」；163 普通闪躲「免疫一次即死或致命伤」；159 不灭之躯「复活回 30%（每场一次）」；预感的庇护、拼命守护「死后 30% 复活（回 30%，每场一次）」。表里原来的 `note_sub` 也是这三个数（T 第六期写卡时的本意）。
- 改法（`core/tianqi_skills.gd` `rec_state`，只在天启篇卡开着时走）：
  - 改写表状态行新字段 `effect_nums: [[原值, 新值]…]`：把预编译效果（含 fix／fix2 各份程序）里等于原值的数字字面量换成新值；`effect_floor_hp_gain: true` 给回血数额包 `Math.floor`。2562 `[[0.01,0.3],[0.099,0.3]]`，2560 `[[3,1]]`，2554 `[[1,0.3]]`＋取整；2561 `[[0.1,0.9],[0.5,0.9],[0.7,0.9]]`（`XVegetaTune` 先把全局表的 0.1 改成甲档 0.5／乙档 0.7／关掉仍 0.1，天启篇记录是它的复制，三种都认，结果都是 ×0.9；该状态预编译程序只有这一个字面量）。四条的 `note_sub` 删掉（不生效，留着误导）。
  - 带 `revive.chance` 的 `down_each` 复活改成 `down`（每次倒下掷一次，< chance 复活）。全表只有 1099、1178 两条是 `down_each`。
  - 回退开关：`XTianqiSkills.REVIVE_SINGLE_ROLL`、`XTianqiSkills.EFFECT_NUMS`（false 回 T570 之前），专项设过回退值。
- 首领状态窗（`core/boss_status.gd`）：新 `panel_kind`，记录带 `tianqiKind == "异常"` 的进 Debuff，其余照 `kind_of`；只换状态窗 `entries` 的页签。`kind_of` 本身没改（驱散、异化、心魔等 8 处结算在读，见「要协调定」）。回退开关 `XBossStatus.PANEL_TIANQI_KIND`。西游档记录没有 `tianqiKind`，照旧。
- 说明同步：状态说明 2562／2560／2554／2561，技能说明 9927 真气护体、9936 普通闪躲、10052 不灭之躯第二行、9942 吃瘪之力，改成设计值（待小A 文字审）。1099／1178 说明本来就写 30%，不用改。
- 数据校验：`天启篇数据校验.py` 加 `effect_nums`（数字对列表）、`effect_floor_hp_gain`（布尔）的格式检查。

## 交接板

- 下一步：四条状态说明、四条技能说明的新字待小A 文字审；「要协调定」2、3 两项。
- 用户试玩说明：天启篇里李逍遥真气护体、拳一普通闪躲、五河琴里不灭之躯、两条 30% 复活被动、贝吉特吃瘪之力（−10%）按设计削弱；首领状态窗异常类状态归到减益页签。
- 需要用户决定：无（吃瘪之力 Kyo 11-27 已定）。

## 要协调定（本单没改）

1. **2561 吃瘪之力（已定，续做已改）**：Kyo 11-27 事项 73「天启篇改成设计稿 −10%，西游档不动」，见下「续做」。原记：设计稿写「受伤 −90% → −10%」（表里 `note_sub` `value*0.1→0.9` 也是这个意思，同样没生效）；实测天启篇、西游档都是受伤 ×0.5，来自 `XVegetaTune`（11-13 贝吉特调整，两档共用）。照设计改要在天启篇绕开 `XVegetaTune` 这一项，属于改 Kyo 定过的数，没动。说明现在写的是实战「−50%」。
2. **结算用的 `XBossStatus.kind_of` 没跟着改**：天启篇标「异常」的 39 个里 22 个它判成 Buff（856、916、907、233、869、2023、1409、1134、1086、1752、1093、1139、1145、1819、1832、1824、1826、1827、1539、1158、1172、2776）。它被元素效果、瘟疫／战争异化、心魔特性、`tianqi_skills.gd:1557` 等读（驱散、减益计数一类）。本单只改首领状态窗显示；要不要让这些结算也认显式标记，是平衡改动，另定。
3. **2560 的「每场」（R1 已定：每次成功施放给一次，见下「返修 R1」）**：`set_variable(1597, 1)` 在 Battle 阶段写，若同场再放普通闪躲（冷却 6）会重置成 1 次；说明沿用 T566「每场最多 N 次」的写法。设计稿写「免疫一次即死」，是否要「每场总共一次」需另定（我倾向现状：每放一次给一次）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：改写表里还有别的 `note_sub` 去改脚本备注（`Custom * Effect` 块）的状态，可能都不进结算。可写个一次性扫描：状态行 `note_sub` 命中的是 `<Custom ... Effect>` 块且记录有预编译 `effects` 的列出来，逐条改成 `effect_nums`（该归一条 Sonnet 车道，先盘点再派）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiSkills.rec_state` | 调用方 2 处（`git grep -nE '(^\|[^[:alnum:]_])rec_state[[:space:]]*\(' -- 'modes/xiyou/core/*.gd'`） | `xdb.gd`（XDB.rec 包装）、`tianqi_skills.gd` 新状态：签名不变；只有表里带 `effect_nums`／`effect_floor_hp_gain`／`revive.chance`＋`down_each` 的 5 条记录内容变 |
| `XBossStatus.entries` 的页签 | `git grep -n "XBossStatus.entries\|entries(" -- 'modes/xiyou/battle/boss_status_panel.gd'` 状态窗 1 处 | 只多一层 `panel_kind`；西游档记录无 `tianqiKind`，与 `kind_of` 相同（专项 `xy.boss_kind_rule_unchanged`） |
| `XBossStatus.kind_of` | 没改（调用方 8 处结算＋界面，见「要协调定」2） | — |

## 数值报告：逐种子分布

单角色木桩（生命上限 100000、魔法 100000），直接跑运行时状态记录的效果阶段（`XStateEffects.run_one`），种子 1，复活抽 20000 次；来源 D271。没剔除。

| 状态 | 天启篇改前（实测） | 天启篇改后（实测） | 设计值 | 西游档（实测，不变） |
| --- | --- | --- | --- | --- |
| 2562 护体罡气，受 1000 | 受 901、扣蓝 99（9.9%） | 受 700、扣蓝 300（30%） | 30% | 受 901、扣蓝 99 |
| 2560 绯红之夜，连倒 5 次 | 救回 3 次 | 救回 1 次 | 一次 | 3 次 |
| 2554 不死之躯 | 回 100000（满），状态去掉 | 回 30000（30%），状态去掉 | 回 30%，一次 | 回满 |
| 1099 预感的庇护 | 51.17%，回 30% | 30.12%，回 30% | 30%，回 30% | 64.5%（1−0.6²），回满 |
| 1178 拼命守护 | 51.17%，回 30% | 30.12%，回 30% | 30%，回 30% | 58.0%（1−0.65²），回满 |
| 2561 吃瘪之力，受 1000 | 受 500 | 受 900（−10%） | −10% | 受 500（贝吉特调整甲档，不变） |

首领状态窗：天启篇标「异常」39 个，改前 `kind_of` 判 Buff 22 个，改后全部进 Debuff。

## 验收

1. ✓ 逐条实测现状并对照设计值（上表；专项 `xiyou_tianqi_t570` 的 `T570_MEASURE` 行）。
2. ✓ 运行时改成设计值：2562、2560、2554、1099、1178、2561 六条都已改（2561 为续做，Kyo 11-27 定）。
3. ✓ 说明同步：四条状态说明＋四条技能说明改成设计值（待小A 审）。
4. ✓ 西游档零改动：六条记录与原表逐字段相等，实测值同改前；首领窗页签规则同 `kind_of`。
5. ✓ 首领状态窗：天启篇按记录显式「异常」进 Debuff（39/39），西游档不变；只改显示（见「要协调定」2）。

## 测试

- 本机：`xiyou_tianqi_t570` 22/22（先红：改前 8 项红，量出现状）；`xiyou_tianqi_t566` 19/19（三条说明期望改成设计值）、`xiyou_tianqi_skills` 248/248（`fill_revive_once` 断言从两次掷骰改成一次）、`xiyou_tianqi_t528` 19/19、`xiyou_state_effects` 32816/32816、`xiyou_boss_status` 57/57、`xiyou_tianqi_abs_skill` 43/43、`xiyou_tianqi_elements` 60/60、`xiyou_tianqi_qishi_states` 24/24、`xiyou_party_status_panel` 19/19、`xiyou_side_status_order` 15/15、`xiyou_tianqi_plague` 98/98、`xiyou_tianqi_xinmo_traits` 212/212、`xiyou_tianqi_qiyin_effects` 71/71、`xiyou_determinism` 372/372、`xiyou_vegeta_tune` 41/41、`xiyou_ui_skin_hud` 112/112。
- 回退：专项把三个开关设 false，复现改前 9.9%／三次／回满／约 51%，首领页签回到 `kind_of`。
- `测试天启篇数据校验.py` 165/165；`天启篇数据校验.py` 退出码 0；`语法检查.py` 0 问题；`发行空壳.py check` 退出码 0。
- 没起带窗口的 Godot，没截图（本单无界面布局改动，首领窗只换页签归属，由专项断言）。
- 云端选测：通过，提交 ab6c4ff68c，基准 82fc265067，99 个场景、16 片，`gh run watch` 前台等到完成，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45962094738 。

## 本分支提交

- 5a30d960a WIP：2562/2560/2554 削弱进预编译效果、1099/1178 复活一次掷骰＋专项
- ab6c4ff68 首领状态窗天启篇显式异常进 Debuff、回退开关专项、数据校验
- 350a20817 （续做）天启篇 2561 吃瘪之力 −10%，西游档不动

## 续做：2561 吃瘪之力（Kyo 11-27 事项 73，第 74 任项目经理cc 派）

- 改动只在 `tianqi_data/skill_rework.json`（天启篇改写表，`XTianqiSkills.rec_state` 只在天启篇卡开着时读）两行：状态 2561 加 `effect_nums`、删不生效的 `note_sub`、`state_note`「−50%」→「−10%」；技能 9942 `desc` 同改。`vegeta_tune.gd`、`xdb.gd`、`States.json` 都没动。
- 回退：`XTianqiSkills.EFFECT_NUMS = false` 回到 ×0.5（专项 `rollback.old_values` 带上 2561＝500）。
- 测试（本机 `--headless --audio-driver Dummy`）：`xiyou_tianqi_t570` 26/26（新增 `tq.2561_minus10pct` 受 1000→900、`tq.2561_skill_desc`、`tq.2561_no_dead_note_sub`、`xy.2561_vegeta_half` 西游档受 1000→500；`xy.records_untouched` 本来就含 2561：西游档运行时记录与原表同一份）；`xiyou_tianqi_t566` 19/19（2561 说明期望改成 −10%）；`xiyou_vegeta_tune` 41/41（西游档贝吉特调整照旧）；`测试天启篇数据校验.py` 165/165；`天启篇数据校验.py` 全部通过。
- 西游档零改动证据：`git diff ab6c4ff68..HEAD --stat` 只有改写表、两个天启篇专项和本交付单；`xy.2561_vegeta_half`、`xy.records_untouched`、`xiyou_vegeta_tune` 41/41 全过。
- 云端选测：通过，提交 350a208171，基准 07cf27af41，10 个场景、1 片，`gh run watch` 前台等到完成，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45969267673 。

## 返修 R1（小o 甲档核退回，第 74 任项目经理cc 派；报告 `xiyou-design-docs/协作交接/核查报告/T570_核查报告.md`）

- **P1-1 普通闪躲首次施放没保护**：绯红之夜的次数存在变量里（新源 1597，原版脚本写 1683），只在 Battle 阶段（开战）初始化，普通闪躲施放走附加状态入口，只跑 Apply 阶段、已有状态只续回合，所以当场首次施放次数是 0、用完同场续施也补不回。改法：改写表 2560 加 `cast_grant: true`；`XBattler._add_state` 在行动里挂上（含已有时续上，`source != null`）时调 `XTianqiSkills.state_cast`，把该状态 Battle 阶段 `set_variable` 的变量至少置成它的值（1）。变量号从预编译效果里读，不写死。回退开关 `XTianqiSkills.CAST_GRANT`。开战带着状态照旧发一次。
- **P1-2 两段攻击同一次归零掷两次**：天启篇单掷骰复活（R0 把 `down_each` 改的 `down`）的条件加 `once_per_fall`＋`state`；`XStateEffects._revive_cond` 掷过就记进 `XBattler.revive_rolled[状态号]`，同一次归零（序列暂缓阵亡、生命一直 ≤0）后续命中不再掷；生命写成 >0（被救回、复活、回血）时 `hp` setter 清空，下次归零照规则再掷。不存档。西游档的 `down`／`down_each` 条件没有 `once_per_fall`，不走这段。回退照旧 `REVIVE_SINGLE_ROLL`。
- **P2-1 说明**：技能 9936「效果：施放后，下次倒下时回复 1 点生命」；状态 2560「下次倒下时回复 1 点生命，触发一次」（待小A 文字审）。`xiyou_tianqi_t566` 里 2560 说明期望同改。
- 数据校验：`天启篇数据校验.py` 加 `cast_grant` 布尔检查＋单测。

### R1 验收（专项 `xiyou_tianqi_t570`，实战 `XBattleLogic.execute`，天启篇炼狱档、只带拳一、敌群 788）

| 断言 | 结果 |
| --- | --- |
| `rt.crimson_first_cast_grants`：首次施放后挂上 2560、次数 1 | ✓ |
| `rt.crimson_first_cast_saves`：首次施放后致命普攻，留 1 血、次数归 0 | ✓ |
| `rt.crimson_used_up_dies`：用掉后再挨致命普攻阵亡 | ✓ |
| `rt.crimson_recast_grants`／`rt.crimson_recast_saves`：消费后同场续施再给一次、再救一次 | ✓ |
| `rollback.crimson_cast_no_grant`：`CAST_GRANT=false` 复现退回现象（施放后次数 0、阵亡） | ✓ |
| `rt.1099／1178_two_hit_one_roll`：694 两段打到 0，复活掷骰给 0.5、0.2，只掷 1 次、阵亡 | ✓（把闸去掉时掷 2 次、回 874 复活，同核查报告） |
| `rt.1099／1178_new_fall_rolls_again`：救起来再归零照规则再掷（0.2 中，复活） | ✓ |
| `rollback.revive_two_hit_rolls_more`：`REVIVE_SINGLE_ROLL=false` 同一序列掷多次 | ✓ |

- 测试（本机 `--headless --audio-driver Dummy`）：`xiyou_tianqi_t570` 39/39、`xiyou_tianqi_t566` 19/19、`xiyou_tianqi_skills` 248/248、`xiyou_state_effects` 32816/32816、`xiyou_boss_status` 46/46、`xiyou_vegeta_tune` 41/41、`xiyou_smart_ai_revive` 85/85；`测试天启篇数据校验.py` 全过、`天启篇数据校验.py` 退出 0、`语法检查.py` 0 问题、`发行空壳.py check` 退出 0。
- 西游档零改动：`battler.gd`／`state_effects.gd` 新分支只认天启篇改写表才有的 `once_per_fall`、`cast_grant`；`xy.records_untouched`、`xy.*` 实测照旧。
- 云端选测（R1）：通过，提交 4687f7726，基准 3b93fbb34，290 个场景、16 片，`gh run watch` 等到完成，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45986007374 。
