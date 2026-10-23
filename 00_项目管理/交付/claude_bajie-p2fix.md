# 交付：claude/bajie-p2fix

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_59）
- 状态：可合并

## 规模与分期

沙僧三期核查（`核查报告_20261023_沙僧50_*`）留下的 5 项 P2，一期做完：

1. 怪物图鉴击败数应在死亡时计（系统批 P2-1）：死亡转移在 `battle_logic.gd`／`battler.gd`（沙僧独占），本单只备接口与原版参照，挂钩交沙僧（见「交沙僧」）。
2. 军团 676 e3 强制 3813 缺主体比较（内容批 P2-C2 前半）。
3. 739 等的 extra 空集假通过（P2-C2 后半）。
4. 状态 44「再次行动」豁免漏检（P2-C1）。
5. 178 哈基米剑段重复数与招募练习剑（早期批 P2-1、P2-2）。

## 变更记录草稿

## 2026-10-23 【Claude·八戒_59·未经Codex检验】沙僧50 核查五项 P2 修复（dev.待定）

- **哈基米剑段重复（早期批 P2-1）**：`core/cat.gd` 开招时按原版 `nativeRepeats` 捕获每段重复次数 `max(1, floor(…))`＝技能 repeats（普攻加追加次数）＋被动 `atkk`＋AgainUse（全局／战技／魔法／指定技能几率合计，规则随机 ×100 小于几率时 +1），被动来源同 dsPassiveSkill（装备＋技能＋状态的备注元数据）。每一剑段按次数重复，不重复整个连携。`cat_probe` 补两例：剑 92「天外天·轩辕剑」（AgainUseAll 100%，敌人生命加到 1e16 免得第一段就打倒）与技能 1817「海军王」（atkk +1），两例各段、伤害、剑痕都与原版一致。
- **哈基米招募练习剑（早期批 P2-2）**：招募时练习剑总是新生成一把装上（gainIndependentItem），背包里原有的同款保留；法宝仍复用背包里的。`cat_probe` 补「背包已有练习剑 2」一例（原版招募后背包仍有那把）。`xiyou_cat` 的连携例照参照把 `keep_unequippable` 打开（参照 releaseUnequippableItems 空操作；剑 92 只限李逍遥）。
- **敌群事件测试补严（内容批 P2-C1、P2-C2）**，`tests/xiyou_troop_events.gd`：
  - 第 1 回合事件强制行动逐条比 `[行动者, 技能]`（含军团 676 第 1 回合 e3 强制 3813），不再只数首敌。
  - 随机技能敌群（军团 676～693、嘤族之光 739）的附加伤害：每一次实际命中都要带精确的 `[攻击, 魔攻]`（参照有命中时取参照值，没有时取守层者自己的），空集合不再算通过；全套另要求 739 至少一例确有命中且与参照相符。
  - 状态 44：去掉「44 一律放过」。`troop_event_probe` 新记下一回合开始时（回合末事件已跑完）各敌人的状态与剩余回合（`turnStarts`），与 Godot 跑完一回合同一时点；第 1 回合末非首敌 44 的有无要对上，Godot 也走到回合末时剩余回合要对上（参照 2→1）；末态只在 Godot 走完第 2 回合末时允许 44 到期。排查中先在「回合末之后、回合末事件之前」取参照，Godot 不同是因为 Godot 在第 1 回合内分出胜负时不跑 `end_turn`，按观察时点对齐后全部相符，不是规则差异。
- **怪物击败数（系统批 P2-1）**：`core/enemy_book.gd` 加 `on_enemy_death(s, 敌人)`：每次死亡立刻按当时编号计一次；结算 `on_battle_end` 对本场已在死亡时计过的敌人不再补记，没经死亡钩子的照旧按「倒着」补记一次（过渡，钩子接上后不再走到）。新探针 `mv_oracle/enemy_book_defeat_probe.cjs`（死亡→复活→再死亡记 2、死亡→复活→逃跑记 1、死亡后变身原编号与新编号各记 1、死亡后立刻读数为 1），`xiyou_enemy_book` 按这四例核接口。**死亡转移处的调用要沙僧接**（见「交沙僧」）。
- **新发现（交沙僧）**：技能 1817 的 `<ConsumeReduceZj: 50%>`（被动减技能消耗）Godot 没有接，哈基米带 1817 时 TP 消耗比原版多一倍；`cat_probe` 该例标 `tpGap`，`xiyou_cat` 只在该例不比 TP。

## 交接板

- 下一步：沙僧在敌人死亡转移处调 `XEnemyBook.on_enemy_death`；沙僧接 dsPassiveSkill 的 ConsumeReduce（技能消耗打折）；八戒接修炼界面（Map082 魔塔教师、Map180 小萝莉）。
- 用户试玩说明：哈基米装备带「再动／再释放」或学了「海军王」时，每一剑段会照原版多打一次；招募哈基米不会再拿走背包里已有的练习剑。

## 交沙僧

- **怪物击败数的死亡钩子**：原版 AB_EnemyBook 包装 `Game_Enemy.die`，每次死亡即时 `incrementDefeatNumber(enemyId)`。Godot 的死亡转移在 `battle_logic.gd`（`_die`／`resolve_collapse` 一带）与 `battler.gd`，是沙僧独占，八戒不改。请在敌人每次进入死亡时调 `XEnemyBook.on_enemy_death(XState.current, 敌人)`（复活后再死要再调；被事件变身后若再走死亡也调，原版新编号也会记 1）。接上后 `on_battle_end` 自动不再重复计。参照与断言：`enemy_book_defeat_probe` → `xiyou_enemy_book` 的 `defeat.*`。
- **ConsumeReduce 未接**：dsPassiveSkill 的 `<ConsumeReduceAll|Zj|Mf|N: x%>` 让技能 MP／TP 消耗打折（`status_page.gd` 只显示，没进结算）。消耗结算在 `battler.gd`／`battle_logic.gd`。接上后去掉 `cat_probe` atkk1817 例的 `tpGap` 和 `xiyou_cat` 的对应跳过。

## 进度账

- 无新增完成度（核查修复与测试补严）。

## 验证

- `并行测试.py` 专项：`xiyou_cat` 992/992、`xiyou_troop_events` 6574/6574、`xiyou_troop_events_b` 6450/6450、`xiyou_enemy_book` 51/51、`xiyou_battle_ui` 70/70。
- `同步正式西游.py --accept-additions` 在本 worktree 跑过（改了 cat、troop_event 探针，新增 enemy_book_defeat 探针；合并 main 带来的 Map083～085 新增用例一并接受）。
- 已清理：本次同步备份（`04_验证/本地结果/自动同步/` 下本次的一份）、长任务日志与调试脚本（会话临时目录）、排查用的临时测试场景（`tests/_tmp_44.*`，没提交）。

## 本分支提交

- 4c10b71b 交付单规模与分期
- 81df3175 哈基米剑段按原生重复次数、招募练习剑新生成，参照补三例
- 76ebbd60 敌群事件测试补严
- 09af9407 怪物图鉴击败数死亡即时计数接口与原版参照
- 12dabb64 合并 main
