# 交付：claude/inspiring-sanderson-ce8806

- 车道／工作者：C 机制／工具，重制_八戒_25（Claude）
- 状态：**进行中**（原任务「同步备份留 3 份、探针并行」等 dev.099 合并后再做；本单先放沙僧交付的核查报告）

## 核查报告：沙僧 codex/formula-rng-implementation（含 codex/sync-incremental）

核查者 Claude（八戒_25），2026-10-19。对象是 main 上的合并提交 380ac8e，以及唐僧在 claude/merge-formula-rng 上的 1e57b81、f12f5b1。只读核查：没有改沙僧和唐僧的分支，也没有跑同步或 Godot 测试。对照的是沙僧两份交付单和交接板「沙僧协作清单」第 2、3、5 条。

### 结论

可以合并，没有阻断项。有 2 处要沙僧返工，2 处要用户拍板或确认，其余是建议。

### 需返工

1. **升级 Godot 后存档全部读不了**。`random_stream.gd:5` 把引擎串 `4.7.2.stable.official.ed1daf0bf` 写死了，`XRandomStream.valid_saved`（:104-105）和 `XState.valid_random_save`（xstate.gd:69-70）都要求它严格相等。`xsave.gd` 的 `valid_data` 和 `XState.from_dict` 校验不过就整档拒读，所以只要升级 Godot，凡是带 `random` 字段的存档都打不开。建议版本不符时丢掉流快照，按 master 重新派生；不应拒绝整个存档。
2. **不支持的公式在实战里静默打出 0 伤害**。`formula_execution.gd:11-20` 遇到 unsupported、effectful 加 mixed 或资源钩子时直接返回 `value 0`。诊断只写进 `r.formulaDiagnostic`（battle_logic.gd:1125），全仓库没有地方读它，也不打日志。旧路径至少会 `push_warning`。现在的切片里没有这类技能（manifest 的 reachablePending=0），所以当前不出错；但 addShield 5 条、角色模块约 81 条一旦进切片，就会无声打 0。建议加 `push_warning`，并在切片检查里拒收可达的 unsupported 公式。

### 需用户拍板或确认

3. **随机流随存档保存，读档重打结果完全相同**。master、serial、world、equipment 流都写进存档。MV 的 Math.random 不存档，原版读档可以重刷，现在不行。这是行为改变，应登记进优化登记，由 Kyo 定是否保留。
4. **三十三层首领测试（f33_boss_won）仍然失败**。到 f12f5b1 为止，鸿蒙老祖（敌群 469）不交礼时，第 2 页 1397 给全队加 1106（命中 −100%），普通攻击必定落空，胜负取决于自动战斗有没有选到必中技能。以前用全局 seed 碰巧能赢，换成本场随机流以后这个种子赢不了。claude/fix-f33-rng 上未合并的 028758c 把夹具设成 842=1 来跳过这条分支，这是放宽了测试。合并前要先确认 469 的不交礼分支在 troop_events 或参照里另有覆盖。

### 逐项核对（属实）

- **公式结构化**：交付单的五条声称都属实。
  - `eval_formula` 只读：纯公式走无对象上下文，写入报 write_capability_required。
  - 副作用只在命中、闪避、暴击判定之后执行一次（battle_logic.gd:1147-1157，`_damage_value` 只有这一个调用点）。
  - gainHp／Mp／Tp 按顺序即时刷新（resource_context.gd:70-94）。
  - 结果槽存负的请求量，同资源后写覆盖。
  - XCustomDamage 已删且无残留引用，原来的特例 857／858／4013 由结构化程序和 112 例资源链参照覆盖，没有技能退回。
  - 四个 formula 探针都在冻结原版里调真实的 evalDamageFormula、apply、反射和反击，期望值来自探针产物，不是 Godot 自己的结果。
  - 预览用克隆体，不传随机流，浮动取中值，不改真实资源，也不消耗随机。
- **独立随机数**：
  - 战斗规则用到的随机全部走本场 rule 流：精英和等级、初始 TP、选目标、出招、OTB 速度、行动次数、命中、闪避、暴击、反射、反击、状态、逃跑、浮动、122 号变量。掉落走 reward 流，按 stable_id 记；装备走 equipment 流；演出用独立的 RNG。
  - 概率判定是 `next_float < rate`。`next_int_inclusive` 用拒绝采样，在区间内均匀，等价于 `Math.randomInt`。单值范围也消费一次，与 `Math.randomInt(1)` 一致，没有差一错误。
  - 浮动和状态时长的公式与 MV 一致。
  - 读旧档时不初始化流、不推进流，预掷池、游标和装备实例都原样保留。
- **被改的既有测试**：
  - 多数是把全局 seed 换成显式的本场 seed，或者补夹具，断言不变。battle_events 的 336 重选和 troop 165 断言反而更严，determinism 整份重写，也更严。
  - 改了期望值的有三处，都有原版依据：
    - review_regressions:66，`killed.added` 从 `[]` 改为 `[1]`：MV 的 gainHp 会触发 refresh 并 addState(死亡)。
    - troop_events:216-231，第一回合行动次数放宽到含 ACTION_PLUS：MV 第一回合也生效。
    - battle_ui:94-98：只改了开战 TP 前提，没改断言。
  - f12f5b1 只把 794 的 122 号变量固定为 0.5，与参照一致，可以接受。
- **增量同步的指纹**：覆盖完整，而且偏保守。
  - 键里有：整个冻结源目录、转换器全部 .py、mv_oracle 全部非探针 .cjs／.js／.json、按 require 递归找到的依赖、node_modules、node 和 python 版本、环境变量、.sandbox 种子存档、读切片的探针加切片 SHA、读转换产物的探针加 maps／db／manifest／slice 的 SHA。命中还要求 generated/oracle 里的产物 SHA 没变。
  - 我核对了全部探针的 fs 读取：读切片的都写了字面量 `xiyou_slice.json`，读转换产物的三个探针都引用 `XIYOU_GENERATED`，没有漏掉的输入。
  - 失败时不会回退到旧缓存；同步结束时如果输入或产物有变，就不发布缓存。另有同步锁、看门狗和 `--full`。

### 建议（不阻断）

- **增量同步对日常车道提速有限**。转换器每次都全量重跑；只要切片改了，读切片的 8 个探针就全部重跑，其中包括最慢的 smart_ai 和 event。沙僧自己实测：改 maxLevel 后增量同步 693 秒，全量 686 秒，没有提速，只有无改动时降到 36 秒。车道加楼层几乎都会改切片，所以 Kyo 要的「同步提速」主要还得靠把切片依赖拆细（按探针实际读的切片字段算指纹）。探针本来就按 `SYNC_JOBS=4` 并行，所以我原任务里的「探针并行」已经有了，接下来要做的应该是拆细切片指纹。
- 战后奖励（dungeon.gd:221／278／319／321、zhenqi.gd:403）和地图侧（遇敌步数、敌群选择、随机走动、挂机）仍用全局随机，建议接 reward／world 流。
- 随机流出错（耗尽或越界）后，`error` 会一直置位，之后所有抽样都返回 0.0，结果是命中和暴击必定成立。战斗主循环不报这个错，建议断言或打日志。
- battle_event_runner.gd:69 战斗中调 `refresh_resources()` 没传 rule，阵亡时长会去抽 world 流。
- 初始 TP 和开战随机目标用 `uint % n`，其余地方用 floor(r·n)，写法不统一，但偏差可以忽略。
- 测试里的 `_half_events` 直接拷 XRandomStream 的私有字段，比较脆弱，建议加正式的覆盖钩子。
- 盾和 SC 解除开关的拒收守卫没有触发源，是死代码。smart_ai.gd:148、power.gd:491 的 formulaGd randf 替换也已无用。formula_execution.gd:51 的测试钩子留在了生产代码里。
- `fixtures/formula_equipment_enemy_oracle.json`（24 例）找不到生成脚本，无法重跑，建议补进 formula_equipment_probe。formula_equipment_probe 按转换器产物挑技能，转换器漏标的技能就进不了参照集。
