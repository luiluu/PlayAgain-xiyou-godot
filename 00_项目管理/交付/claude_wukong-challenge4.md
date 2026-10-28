# 交付：claude/wukong-challenge4

- 车道／工作者：A 内容／悟空（Claude，悟空_62 期十六）
- 状态：可合并

## 变更记录草稿

## 2026-10-28 【Claude·悟空·未经Codex检验】入队／读档／开战难度继承四条路径补齐，顺带补两处原版机制（dev.待定）

- **原版行为（冻结 v0.28 `installNativeDifficultyInheritanceRuntime`＋公共事件 1345／1443～1445）**：①主角带强／弱者分档（6216／6235）：队员入队时按「1345 名单或新增超强者 167～173／175」学强者 6216，否则弱者 6235；②补强档开关 2461～2463（或主角带 5968～5973 任一对）：每档按 1443～1445 的 `skillNNNNIds` 名单学强者（5969／5971／5973）或弱者（5968／5970／5972）；③角色号 ≥167 不跳过，照同一档位算；④读档：≥167 走完整同步，<167 只补补强档（洪荒档再补洪荒压制被动）；开战：队伍里 ≥167 的队员重新同步。
- **重制补上**：`XState.inherit_difficulty` 改成与原版 `syncActor` 同形（`_difficulty_profile`／`difficulty_native_ids`／`_difficulty_strong`），新增 `sync_native_tier`、`sync_difficulty_after_load`（`from_dict` 末尾）、`sync_difficulty_on_battle`（`XBattleLogic.setup` 开头）。
- **探针一路查出的两处原版机制，一并补**：（a）`installStrongActorClassificationRuntime`：167～174、`<GuyuActor>`、`<CodexSuperStrong>` 角色学弱者分档技能（5968／5970／5972／6235）时改学强者那档，且不挂弱者状态，读档修复；于是弱者档里的 174／176 同步后因「先学 5969 再被当成非 desired 忘掉」而什么也没有——重制 `XActor.learn_skill`／`add_state` 加同样替换，结果与原版一致。（b）`installNativeBindingChargeRuntime` 把备注带 `<CodexSuperStrong>` 的角色（174 云裳、176 屠苏、177 玄）并入超强者名单；重制原来漏了，现在 `XItemMarks.is_super_strong` 认它们，所以低于地狱难度它们入队被拦、出战栏被清（与其它超强者一致）。（c）超强者入队被拦时原版先建出角色对象（读档才会同步到它），重制 `_add_actor` 拦截前先 `actor(id)`。
- **参照**：新探针 `mv_oracle/difficulty_inherit_probe.cjs`：主角技能 12 种 × 难度开关 6 种 × 补强档 5 种 × 入队／读档／开战 三时机，16 名队员（<167 七名、≥167 九名），共 1080 例（单跑约 20 分钟）→ 夹具 `tests/fixtures/difficulty_inherit_oracle.json`（手工拷自 `.sandbox`，同 enemy_warehouse，没挂进同步脚本）。专项 `xiyou_difficulty_inherit`（入队）／`_load`／`_battle`，各 6120 项全过。
- 没做：主角对象不存在（`$gameActors._data[1]` 缺）时的兜底来源（已写在 `_difficulty_profile`，没有参照例）；`startBattle` 钩子挂在 `XBattleLogic.setup`（开战建场时），不是真正的 `BattleManager.startBattle` 入口，行为等价但时点是建场。

### 改了的核心文件（请沙僧重点核）

- `modes/xiyou/core/xstate.gd`：`inherit_difficulty` 重写，新增 `sync_native_tier`／`sync_difficulty_after_load`／`sync_difficulty_on_battle` 与常量；`_add_actor` 拦截前建对象；`from_dict` 末尾调读档同步。
- `modes/xiyou/core/actor.gd`：`learn_skill` 对强者分档角色替换、`add_state` 拦弱者状态、`is_strong_classified`／`repair_strong_classified`。
- `modes/xiyou/core/item_marks.gd`：新增 `is_super_strong`（并入 `<CodexSuperStrong>`），`can_acquire_actor`／出战栏清理改用它；`enemy.gd`、`power_books.gd` 同改一处调用。
- `modes/xiyou/battle/battle_logic.gd`：`setup` 开头调 `sync_difficulty_on_battle`。

## 交接板

- 下一步：难度继承四条路径已补齐；剩差异 1（五乘区，待用户定）。`<CodexSuperStrong>` 的 174／176／177 现在算超强者，低于地狱难度拿不到、出战栏会清——原版如此，试玩确认。
- 用户试玩说明：低于地狱难度，云裳／屠苏／玄无法入队或出战（与其它超强者一致）；补强档开着时新入队的队员按强弱名单拿补强技能。
- 需要用户决定：无。

## 进度账

- 挑战被动：难度继承分档／补强档／≥167／读档补同步 → 已核，仅余差异 1（五乘区）。

## 验证

- 新专项：`xiyou_difficulty_inherit`／`_load`／`_battle` 各 6120／6120。
- 必跑与回归：`xiyou_challenge_passives` 1005／1005、`xiyou_enemy_warehouse` 5569／5569、`xiyou_rules`／`d1b`／`d1c`／`d1d` 全过（约 11.5 万项每段）、`xiyou_event_compare` 5／5、`xiyou_super_acquire` 27／27、`xiyou_super_deploy` 43／43、`xiyou_actor_p0` 3322／3322、`xiyou_party`、`xiyou_party_skills`、`xiyou_power_books*`、`xiyou_state_effects*`、`xiyou_save_page` 全过。
- 没跑：全量 `检查.sh`（车道不跑）；没改切片，不跑内容覆盖检查。

## 遗留

- 夹具未挂进 `同步正式西游.py`（需补契约校验）。探针单跑约 20 分钟（每例新局），可按时机拆三个探针并行。

## 可优化（流程／工具／效率）

- 建议：探针 `difficulty_inherit_probe.cjs` 里每例都 `newGame()`，占时最多；可用 `restore` 快照复用新局。
- 建议：`并行测试.py` 排槽期间机器负载高时，专项会排队十几分钟，车道自测可考虑单独占一个名额。

## 本分支提交

- a36d50aa 难度继承四条路径、强者分档学技能替换、<CodexSuperStrong> 并入超强者；参照探针与夹具
- 收尾提交：交付单
