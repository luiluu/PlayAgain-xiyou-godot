# 交付：claude/bajie-f2f5f6

- 车道／工作者：修复／八戒（Claude，八戒_77）
- 状态：可合并（待 Codex 核查；battle_logic.gd 一处是总装批准的例外，actor.gd 只改了一行注释）
- 基线：552e39f8，已合 main ea742076
- 来源：沙僧积压核查第一期（`00_项目管理/核查范围/清积压_第一期_20261027.json`）的 F6、F5、F2，总装 2026-10-27 派单。

## 提交

| 提交 | 内容 |
| --- | --- |
| 254cff75 | F6 优化登记补缺，统一编号 |
| 8b36089b | F5 事件运行中行动序列 COMMON EVENT 照原版立即装子解释器，加原版探针和专项 |
| ea5b161c | F2 叠毒等 Regenerate 脚本致死时补倒下表现记录（battle_logic 单处例外），加专项 |

## F6／P3：优化登记补缺与撞号

先查了当前最大编号：登记表到 O-098（黄泉暴击）为止，O-097 只在交接板预留，后来作废。O-099～O-103 都没有被占用，所以不用顺延。

| 新编号 | 内容 | 出处 | 原来的写法 |
| --- | --- | --- | --- |
| O-099 | 法宝技能不重复进技能栏 | b94f1abc | 交付单里写「请总装分配 O 号」，代码里没有编号 |
| O-100 | CE463「更改形象80」改写给天虎令 104 号（`ACTOR_IMAGE_FIX`） | 049b002f | O-待定 |
| O-101 | 神秘生物刷新提示照弹（`SHOW_REFRESH_TEXT`） | 926f914f | O-098（与黄泉暴击撞号） |
| O-102 | 第 5 回合只让活着的可捕捉敌人逃跑（`FLEE_ALIVE_ONLY`） | 926f914f | O-098 |
| O-103 | 物品 372 改学 1672（`BOOK_FIX_372`） | 926f914f | O-098 |

改动范围：
- `03_再刷重制_Godot/00_设计/优化登记.md` 加了五行，状态都是「待用户决定」。
- 代码注释：
  - `mv_event_core.gd`：O-100。
  - `pet_capture.gd`：O-101、O-102。
  - `pets.gd`：O-103。
  - `actor.gd` 只在法宝技能那一行的注释里加了「O-099 去重」。actor.gd 是沙僧的独占文件，这里只动了注释，没动代码。
- 测试注释：`xiyou_pet_capture.gd` 改成 O-102、O-103；`xiyou_actor_change.gd` 改成 O-100。
- 顺带修了 `xiyou_alien_config.gd` 两处「O-待定」：说的是一键出售跳过异化装备，这一项早就登记为 O-081，就改成了 O-081。
- 已分卷的变更记录（`变更记录卷/变更记录_2026-10-16至2026-10-26.md`）只在两处原文后面加了括注：
  - 宠物 O-098 三项后注明「改为 O-101～O-103」；
  - CE463 后注明「登记为 O-100」。
- 交接板没改。上面 F6 那一条和「O-098 已被占用」的说明，请总装合并时更新。

O-099 没做成开关：去重写在 `XActor.skills()` 那一段的 `if not ids.has(id)` 里，恢复方法写在登记里了。v0.28 里不会触发。

## F5／P2：事件运行中行动序列 COMMON EVENT

**原版**（YEP_X_ActSeqPack1 `actionCommonEvent`）：
- 如果 `$gameTroop.isEventRunning()` 为真，就执行 `$gameTroop._interpreter.setupChild(list, 0)`。这是在顶层敌群解释器上装子解释器，并且会换掉已有的子解释器。
- 否则执行 `reserveCommonEvent`。

强制行动结束后，解释器先 `updateChild` 跑完子解释器，再从 339 的下一条接着往下。

**原版探针** `03_转换工具/mv_oracle/battle_common_event_child_probe.cjs`：
- 真实 BattleManager，全内存新局，只写 `.sandbox`。
- 合成公共事件只追加在内存里的 `$dataCommonEvents` 末尾：先强制角色 8 用 292 踏地（目标动作 `Common event: 375`），375 荒天弟剑诀再强制 83 用 5989。
- 变量 1600 当时间戳，父事件在 339 之后执行 `V=V*10+k`。
- 结果（errors 全空）：

| 例 | 83 行动时的 V | 父事件跑完后的 V | 375 是否预约 | 说明 |
| --- | --- | --- | --- | --- |
| top_level：父事件顶层 339 | 1 | 12 | 否 | 子事件先跑完，父事件才继续 |
| inside_call：339 在 117 叫起的公共事件里 | 1 | 19 | 否 | 顶层子解释器被换掉（`replaced: true`），被叫公共事件里 339 之后的 `+5` 不再执行 |
| no_event：不在事件里 | 0 | — | 是 | 照常预约，行动后才跑 |

夹具是 `tests/fixtures/battle_common_event_child_oracle.json`。ActSeqPack1 的 sha256 与 manifest 一致。

**重制改法**：
- `MVEventCore.setup_child(list, ce_id)`：换掉本层子游标，被换掉的那个的 skipped 并进本层。
  - 本层原来没有子游标时，游标已经在下一条指令上（339 返回前已前进），子游标跑完后不再前进。用 `_child_resumes_here` 标记。
  - 换掉的是 117 子游标时，117 还没前进，跑完照常前进。
  - 连续两次从外面装子游标时，沿用第一次的标记。
- `XBattleCommonEvent.run_or_reserve`：`logic._runner` 不为空（事件在跑）时装到顶层 runner，否则照旧预约。
- `action_sequence.gd` 的 `COMMON EVENT` 改调 `run_or_reserve`。`ACTION COMMON EVENT` 原版本来就只预约，没改。

**影响面**：
- 12 个技能里，8 个是 `Common event: 375`（292、466、479、843、848、3992、4154、4157）；另外 4 个（10055～10058）指向的 1709、1712 是空公共事件。
- v0.28 里没有 339 直接强制这些技能，所以实际只在事件中的强制行动碰巧用到它们时才会触发。
- 没做开关：这是照原版改，不算优化。

**专项** `tests/xiyou_battle_common_event_child.gd`，13/13：
- 三例逐条比较强制行动的行动者、技能和当时的 V，以及父事件跑完后的 V、是否预约。
- 另加一项解释器单元：连续两次从外面装子游标。
- 反向验证：退回成只预约，有 3 项失败。83 行动时的 V 变成 12 或 159，inside_call 的最终 V 是 159，原版是 19。

## F2／P2：叠毒致死缺倒下表现记录

**原版**：
- YEP_BuffsStatesCore `regenerateStateEffects` 先记下 `lifeState = isAlive()`，跑 Regenerate 脚本。脚本跑完如果倒下，就 `performCollapse`。
- 叠毒脚本自己在弹字之后也会 `if (target.isDead()) target.performCollapse()`。
- 所以 `oracle/state_js.json` poison.tick 的每条致死行都是：弹伤害字 → 倒下 ×2 → 弹一次空结果。参照里 17 个状态的 64 条致死行都是这样。

**重制原来的问题**：`_poison_tick` 的译文没有接这两次倒下，回合结束时毒死的敌人只有 regen 记录，画面上不演倒下。死亡、奖励和掉落本来就是对的。

**改法（总装批准的 battle_logic.gd 单处例外）**：
- 位置是 `turn_end_battler` 里 Regenerate 的 emit。派单里写的是 `resolve_collapses`，但那个函数在全部单位结算完后才统一处理掉落，没有记录参数。原版的倒下是紧跟着那次弹字、逐个单位发生的，所以改在 emit 这一处。
- 进去时活着、弹字后倒下的，紧跟着加一条 `{"type": "collapse"}`。同一次倒下只记一条，原版的两次 performCollapse 都只是启动倒下效果。
- Regenerate 跑完再补查一次，覆盖不弹字就倒下的情况。
- 死亡结算、`resolve_collapses`、掉落、经验都没动。
- `battle_scene._play` 与 `sequence_player` 本来就会播放 collapse 记录。

**专项** `tests/xiyou_poison_collapse.gd`，191/191：
- 逐条对照 poison.tick 的致死行（状态 × 持有者 × 来源；重制翻成 `poison_tick` 的 15 个状态，共 60 例）：持有者倒下，并且 regen 后紧跟一条 collapse。
  - 来源用真实能力值，角色 1 敏捷加 100，因为 488、505 按来源敏捷算伤害。
  - 持有者设 1 血，因为 894 用真实来源只扣 2.8。
- 不致死时不记倒下；已经倒下的持有者不再记。
- 真实 QuietBattle 回合结束：三只敌人叠毒倒下，各自 regen 后紧跟一条 collapse，判定胜利，画面上敌人倒下（`appeared` 为假）。经验、金钱与直接置 0 血倒下的同一敌群相同。
- 反向验证：去掉补的那条记录，专项失败。

## 验证

本工作树单独 import，exit 0，没有 SCRIPT、Parse 错误。21 场，并行 2，`--full`，用时 526 秒；20 场通过，1 场是环境问题。

- **新专项**：xiyou_battle_common_event_child 13/13、xiyou_poison_collapse 191/191，两场都做过反向验证。
- **F5 相关**：xiyou_battle_common_events 22、xiyou_troop_events 6574、xiyou_battle_start_event 50、xiyou_boss_lifecycle 5080。
- **xiyou_event_compare**：4/5。唯一失败的是 `oracle_cases_complete`（4632 对 4645），这项只比 manifest 和地图算出的例数与 `generated/oracle/events.json` 的例数，不走代码。
  - 原因是本工作树的 `generated/` 是旧的、彼此也不一致：地图 190 份，主工作区 197 份；manifest 也不同。
  - 把 F5 的三个代码文件临时换回 ea742076 的版本重跑，同样是 4632 对 4645。所以与本批无关。
  - 其余 4 项（逐事件对照等）都通过。合并后在 main 上会随 `检查.sh` 重跑。
- **F6 注释涉及的专项**：xiyou_pet_capture 43、xiyou_actor_change 48、xiyou_alien_config 95、xiyou_magic_weapon_level 51。
- **F2 相关**：xiyou_state_js 1733、xiyou_regen_popup 26、xiyou_race_battle 436、xiyou_alien_battle 330、xiyou_battle_ui 70、xiyou_shield 565。
- **xiyou_rules 难度 1 四段**：xiyou_rules 115637、xiyou_rules_d1b 115733、xiyou_rules_d1c 115746、xiyou_rules_d1d 115725。
- **必跑项**：MV 文件守卫 16/16，`git diff --check` 通过，新夹具 JSON 可解析。
- **没跑**：全量和 xiyou_rules 其余 20 段。
- 日志在 `03_再刷重制_Godot/04_验证/本地结果/20261027_八戒_F2F5F6/选测.log`（不入 Git）。

## 待交叉核查

- 254cff75、8b36089b、ea5b161c（执行者: Claude（八戒），核查: 待Codex）。
- 请沙僧重点看两处：
  - battle_logic.gd 单处例外（`turn_end_battler` 的 emit，第 637～650 行附近）；
  - `MVEventCore.setup_child` 换掉子游标后游标前进的规则。

## 可优化

- 原版每次 Regenerate 致死调两次 performCollapse，重制只演一次，表现等价（敌人倒下效果和音效从头再播一次）。没登记为优化；如果要逐帧对上，可以在 emit 里记两条。
- `新建工作树.sh --补齐` 之后，本工作树的 `generated/oracle/events.json` 与地图、manifest 不一致，xiyou_event_compare 的完整性检查因此失败。上一批已经提过补齐只补缺、按文件比对的事，这次还看到 oracle 与 manifest 不同批。建议补齐时把 `generated/` 整份对齐主工作区，或者给它记一个批次号再检查。
- 本工作树做反向验证时用 `git checkout -- 文件` 还原，把未提交的修复也一起退掉了，靠事先的备份才恢复。建议车道做反向验证时先提交检查点，或者用 `git stash push -m` 加 `apply <sha>`，不要直接 checkout 未提交的文件。

## 变更记录草稿

## 2026-10-27 【Claude·八戒·未经Codex检验】F6 优化登记补缺；F5 事件运行中行动序列公共事件照原版立即执行；F2 叠毒致死补倒下表现（dev.待定）

- F6：补登记 O-099 法宝技能去重和 O-100 CE463 改写给天虎令；宠物三项与黄泉暴击撞号的 O-098 改为 O-101～O-103。代码注释和分卷变更记录的编号已统一。
- F5：事件里的强制行动用到带 `Common event` 的技能（踏地等 8 个技能的 375）时，照原版 setupChild 立即执行，执行完再接着父事件；不在事件里时照常预约。新原版探针三例，新专项逐条一致。
- F2：叠毒等 Regenerate 脚本致死时，紧跟弹字记一条倒下，画面演倒下。死亡、掉落、经验不变。battle_logic 一处是总装批准的例外。
