# 交付：claude/magical-cori-e77cba

- 车道／工作者：B 界面·工具（本批核查为主）／八戒（Claude，重制_八戒_48）
- 状态：可合并

## 变更记录草稿

## 2026-10-22 【Claude·八戒_48】核查 codex/state-effects-2（合并提交 09ebfb0，dev.124）

- 核查范围：codex/state-effects-2 的 12 个提交 0210701…2e31c9c。以 `09ebfb0^1..09ebfb0` 的代码差异为准（battler.gd、damage.gd、state_effects.gd、battle_logic.gd、state_effects_probe.cjs、xiyou_state_effects／xiyou_troop_events 测试），另看总装在 e5e283b 给 xiyou_settlement 补的行动前 param_refresh。
- **结论：通过，无 P0／P1／P2**。逐项对照冻结 krz_state_re.js、YEP_BuffsStatesCore.js、YEP_BattleEngineCore.js、_Fix_StackOverflow.js：
  - **KRZ 热缓存**：effect_snapshot 对应 `_statescache2`、effect_lists 对应 `typestates` 的 `_statelist`，只在 param_refresh 消费 dirty 时失效，与 KRZ:179～315、897～945 一致；gain 非零在调用结束后标 dirty（resource_context.gd），与 KRZ:70～95 一致。参照 `turn.start_end` 里 e0 的一回合到期状态 2721 在 regenerateAll 内先被移除、随后仍触发 regenerateState／turnEndState（旧列表），Godot 的 `_regenerate → _tick_states(2) → regenerate → turn_end` 顺序与之对应；有非零再生时 gain 先标 dirty、到期移除的 refresh 重建列表，原版同样不再触发，两边一致。
  - **加状态到出手前是否都经过 refresh**：真实战斗里有四个刷新点——回合开始全员 mark_dirty＋param_refresh（KRZ onTurnStart＋Unit.refresh）、execute() 付费后行动者 param_refresh（防御分支已前移到 initiate 前，行动序列分支同样先刷新）、每次行动收尾逐目标 param_refresh（execute 收尾与 action_sequence.gd:155 的 removeImmortal）、资源 gain 后的 XResourceContext.refresh。两次刷新之间加的状态（如敌群事件 313、行动中途给非目标加状态）在下一次刷新前不进 react／respond 列表，这与原版 KRZ 的惰性列表相同，不是遗漏。总装给 xiyou_settlement 补的两行 param_refresh 模拟的就是开战第一回合的刷新，是夹具修正，正确。
  - **FIX 全局锁**：`_adding_state` 静态锁跨战斗者拒绝嵌套 add_state，已有状态只续回合不重跑 apply，与 _Fix_StackOverflow.js 一致；_add_state 内提前 return 也会释放锁（锁在外层函数）。
  - **remove／leave**：remove_state_auto 才带 leave，来源在两段之后清除，嵌套驱散继承 `_leaving_state`，与 BSC:1449～1474 及参照 lifecycle 两例一致。
  - **mul 取整**改走 XPower.js_round（负半整数向正无穷），参照 `mul.round_boundaries` 覆盖。
- P3（已在后续批修好，不再登记）：本批 `_establish` 没把 respond 的返回值传给 establish（BSC:1901～1907 是链式传值）；当时 respond 只有 js、establish 只有 user_param_damage（不读 value），无可见差异；当前 main 的 battle_logic.gd:1303 已改为 `ctx.value = XStateEffects.run("respond", …)`。
- 验证：见本单「验证」。

## 2026-10-22 【Claude·八戒_48】核查 codex/formula-rest（合并提交 f96cc9b）

- 核查范围：be81f3b、9968e1d、816372f、d1db0b4，以 `f96cc9b^1..f96cc9b` 差异为准：新 formula_rest_probe.cjs（不进同步探针表，固化为 tests/fixtures/formula_rest_oracle.json）、xiyou_formula_rest 专项、测试公式程序.py 新增 31 块清单回归；be81f3b 的 dev.121 核查报告只核结论。
- **结论：通过，无 P0～P2**。31 块清单、135 例的组合（装备 4 种×攻击力三向分支）在 Python 回归里逐项断言；Godot 专项同时核实际执行、影子预览隔离、资源与结果槽、随机次数、只读程序与实际执行一致，并用 sourceIdentity 绑定冻结源。
- P3（已修，见下）：`.value` 一项用 `is_equal_approx` 比对原版值，相对容差约 1e-5，值在百万量级时可容下个位数误差，会掩盖取整差一；实测 135 例改成精确相等全部通过，已收紧。

## 2026-10-22 【Claude·八戒_48】核查 codex/converter-write-changed（合并提交 635734a）

- 核查范围：18 个提交 b1035ed…3ec7a5b，代码差异只有 xiyou_export.py、检查.sh 一行与新回归 测试转换器写入.py，其余是交付单。
- **结论：通过，无 P0／P1**。JSON 表改为最终版本才落盘（pending_json），逐文件按字节比较后才写；临时文件与目标同目录、os.replace 原子替换；父目录做符号链接与越界检查（self.out 已 resolve，不会误报）；remove_stale 只清五个自有子树中本次未产出的文件，保留仍产出文件的 .import，清根目录残留临时文件；manifest 最后写。后来 0a5ec4c 加的 JPEG／WebP 转 PNG 也走 write_changed 并登记 outputs，不会被 remove_stale 误删。
- 已知、不属本批：sips 转码 PNG 的 ICC 头带当前时间，使这 3 张图每次转换都被重写（沙僧 review-dev122-123 已登记 P2，待工具车道修）。

## 2026-10-22 【Claude·八戒_48】核查 codex/review-backlog-20261021（合并提交 b4aaad2）

- 核查范围：34 个提交 eb6ae21…7e1e888；代码只有 9d9e4bf 两处测试小修，其余是核查报告与交付单（只核结论与编号）。
- **结论：通过**。9d9e4bf：xiyou_achievement 只在测试进程把成就提示音的 XSound 缓存填 null（XSound.play 按名字取缓存、null 即不播），保留 Popup Sound 参数断言，游戏代码未改；测试合并工具.py 的全局槽位用例剔除外层 CHECK_FULL／CHECK_JOBS／CHECK_LOG_DIR，避免假场景写坏外层 test_timings.json。报告结论（54＋3 批与 152 批文档）抽查与交接板、变更记录一致。

## 2026-10-22 【Claude·八戒_48】核查文档批（只核结论与编号）

- 核查文档登记：c61e494、ce77a69、ccb0b66、2d71840（codex/review-35-lanes）；0949ba9、48828be、e3141fe、7f6033a、e13942a、ea51385（codex/transform-param-cache，合并 4d690c3）；234fdeb、750d14c、905ea99、9742e90（codex/review-state-effects，合并 bcdeb50）；0dc1d00、65d22ac、71af5ce（codex/review-dev114-120，合并 5efdd50）；65943a4、6b40ec5、157e08e、56e57fc（codex/review-dev122-123 的核查报告与交付单）。
- **结论：通过**。实测抽核：
  - 状态效果提案核查：导出层 638 块与 13 个畸形结束标签漏导的状态（1743、2530～2538、2550～2552）用冻结 States.json 与 generated 重算，完全吻合。
  - 变身缓存预检：冻结 Troops.json 敌群 466 成员为敌人 534、指令 336 参数 [0, 538]，Enemies[466] 为空记录，与「敌群 466、敌人 534→538」的编号更正一致；27＋13＝40 项口径一致。
  - 晚间批核查（dev.116～120）：两条新 P2 结论成立且均已修——导入 DOT 漏乘 REC（当前 battle_logic.gd:1473、1496 已乘 rec，与冻结 installImportedBalanceRuntime.js:496、506 一致）；待核查.py 误销同号批（292fb24 改为只认销账范围行）。
  - dev.122／123 核查：结论与已列 P2（sips ICC 时间）与上条 converter 核查一致。

## 2026-10-22 【Claude·八戒_48】修复 9968e1d 核查问题：formula_rest 原版值改精确比较

- xiyou_formula_rest 的 `.value` 断言由 `is_equal_approx` 改为精确相等（JSON 数值与 GDScript float 都是双精度），135 例全过；只改测试，游戏代码不变。

## 交接板

- 下一步：无新增。sips 转码 PNG 的 ICC 时间 P2（review-dev122-123 登记）仍待工具车道。
- 用户试玩说明：本批只有核查与一处测试收紧，玩家看不到变化。
- 需要用户决定：无。

## 进度账

- 不调整完成度。

## 验证

- 基点 main fe726f6，未合新 main（一期只读核查＋一处测试收紧）。车道不跑全量。
- Godot 专项（并行测试.py，并行 2、共用上限 4，无偶发）：xiyou_state_effects 19944/19944、xiyou_settlement 11/11、xiyou_troop_events 3839/3839＋xiyou_troop_events_b 3862/3862、xiyou_achievement 50/50、xiyou_achievement_badge 34/34；改精确比较后的 xiyou_formula_rest 1352/1352。
- Python 回归：测试转换器写入.py 20/20、测试公式程序.py 12/12、测试合并工具.py 120/120。
- 只读核对：冻结 States.json／generated States.json（638 块、13 个漏导状态）、冻结 Troops.json 敌群 466、参照 generated/oracle/state_effects.json 的 turn.start_end 日志。

## 本分支提交

- 045d92c 修复 9968e1d 核查问题：formula_rest 原版值改精确比较
- 本提交：一期核查结论与交付单
