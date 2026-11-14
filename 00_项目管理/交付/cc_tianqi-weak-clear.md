# 交付：cc/tianqi-weak-clear

- 车道／工作者：C 规则·机制／cc（天启篇全弱者通关资格）
- 状态：可合并

依据：私密仓库 xiyou-design-docs `重制设定/天启篇_设计总览_v0.2.md` 第二节 3「全弱者通关资格跟本档走，奖励另行标定」（Kyo 11-08）；`天启篇_对重制内容影响审查_v0.6.md` 第 245、268 行（原版弱者挑战在天启篇作废，新判定「全弱者通关 36 层」没做）。只对天启篇存档生效，原版档不变；合进本地，不推玩家。

## 变更记录草稿

## 2026-11-14 【cc·全弱者通关·未经审查】天启篇全弱者通关资格：36 层决战全弱者打赢记本档资格（dev.待定）

- 新模块 `core/tianqi_weak_clear.gd`（`XTianqiWeakClear`，O-待定-1），只认天启篇存档。
- 判定：36 层决战（`XTianqiLine.run_final`，四线共用）打赢时，这一场出现过的我方角色全是弱者档才记。「出现过」＝出战栏 5 格（上场＋助力位）里出现过的角色和行动者。出战栏写入收拢在 `XState`：单格写入 `set_battle_slot`、整列赋值走 `battle_slots` 的 setter，写入那一刻就记；开战前、每回合开头、每次行动开头、天启篇换人、结束时再扫一次出战栏兜底。中途加入又撤下（同一事件里也算）、换上来没行动就倒下的都算。成长型名单读不到或为空时一律不授予。档位读 `XTianqiSkills.battle_tier`（五条悟照天启篇表），每次见到时按当时档位记，见到一次不是弱者就一直不算。成长型角色一律不算弱者（Kyo 11-14 定）：名单以 `skill_rework.json` 的 `tiers.growth` 为准（`XTianqiWeakClear.is_growth`），现在是三笠 95（锻炼变量 1490 满 10 次变强者、四次进阶变超强者）、饿狼 173（进阶 2 次强者、4 次超强者）；不管练没练、在出战栏、助力位还是只行动过，队里有就不记。只改全弱者判定，别处档位加成、弱者光环不动。跟踪绑定存档，战斗中断没收尾时换了存档不记，下一场 36 层决战开战重置。
- 记录：存档 `flags.tianqi.weak_clear = {本档难度 key: {line, members}}`，跟本档走；读档后还在；同档再打赢不重复记。
- 原版弱者挑战（`XWeakChallenge`，Map157＋敌群 469＋混沌难度 9）在天启篇走不到：天启篇借的原版难度号最高 6（统一后都是 3），牢妲改难度菜单已删（O-405）。新资格达成时点亮原版成就 142（开关 `ACHIEVEMENT`，成就自带物品照发）；不写全局 `codexWeakFiveClearV2`（那是西游档新局学 10357 的奖励）。
- 奖励不做：留 `XTianqiWeakClear.reward(s, diff)` 空接口，另行标定后填。
- 只算 36 层首通路线（`run_final`）；大厅再挑战 36 层（`XTianqiSummit.rechallenge`，不记通关）不算。
- 接线：`core/tianqi_line.gd` `run_final` 开战前一行 `begin`、返回前一行 `finish`；`battle/battle_logic.gd` 三处（行动开头 `note_actor`、`run_turn` 回合开头 `note_slots`、`tianqi_swap` 换人 `note_actor`，换人的两次写格子改走 `set_battle_slot`），`core/xstate.gd`（`battle_slots` setter、新函数 `set_battle_slot`，`add_actor`／`remove_actor` 写格子改走它，`init_battle_slots` 改成整列赋值），`core/imported_balance.gd`、`core/actor_warehouse.gd` 各一处、`core/item_marks.gd` `enforce_party` 两处写格子改走 `set_battle_slot`（不在跟踪时都直接返回，西游档行为不变）；`ui/save_scene.gd` 天启之路一行末尾接 `save_mark`。
- 专项 `xiyou_tianqi_weak_clear` 46 项。
- 玩家可见（只在本地）：天启篇 36 层决战用全弱者打赢，结算多一行「全弱者通关（本档）　某难度，出战的全是弱者。」，读档界面天启之路一行末尾标「全弱者」，成就「弱者挑战」点亮。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/tianqi_weak_clear.gd` `XTianqiWeakClear.ENABLED`、`ACHIEVEMENT`；`core/tianqi_line.gd`（run_final 两行）、`battle/battle_logic.gd`（三行）、`core/xstate.gd`（add_actor 一行）、`ui/save_scene.gd`（天启之路一行）；`tests/xiyou_tianqi_weak_clear.gd` | 弱者挑战＝混沌难度最终战五名弱者，入口靠牢妲改难度号，天启篇走不到 | 天启篇存档：36 层决战全弱者（出战栏和行动者，中途进出的也算）打赢记本档资格，点亮成就 142；奖励留接口 | 天启篇设计总览 v0.2 第二节 3（Kyo 11-08「全弱者通关资格跟本档走，奖励另行标定」）；影响审查 v0.6 | `ENABLED = false`（不判不记、读档界面不标）；`ACHIEVEMENT = false` 只记资格不点亮 142 | cc | 保留 |

## 交接板

- 下一步：全弱者通关奖励标定后填 `XTianqiWeakClear.reward`；36 层正式地图做好后入口照旧走 `run_final`，不用再接。
- 用户试玩说明：天启篇 36 层决战全用弱者（含助力位，战斗中也别换上强者）打赢，结算多一行「全弱者通关（本档）」，读档界面天启之路一行末尾标「全弱者」。只在本地。
- 需要用户决定：无（Kyo 11-14 已定，四条都写进上面的变更记录草稿）：
  1. 判定口径：最终战上场 4 人＋助力位＋行动过的角色（含中途进出），按默认。
  2. 档位：成长型角色（三笠 95、饿狼 173，名单按 `tiers.growth`）一律不算弱者；其余按战斗档。
  3. 大厅再挑战 36 层：不算。
  4. 成就 142 自带物品：照发。

## 进度账

- 无（天启篇新机制）。

## 可优化（流程／工具／效率）

- 无

## 待交叉核查

- 改了核心文件 `battle/battle_logic.gd`（行动开头、`run_turn` 回合开头、`tianqi_swap` 各一行）、`core/xstate.gd`（`add_actor` 末尾一行），不在 36 层决战跟踪时直接返回；`note_slots` 直接读 `battle_slots`，不调 `battle_members`（那个会清超强者，有副作用）。
- 别车道独占文件一个没碰（damage、battler、tianqi_horsemen、tianqi_affix_battle、tianqi_qiyin_*、balance_table、难度被动）。

## 验证

- 专项 `xiyou_tianqi_weak_clear` 46/46（首交 29 项，返修加 6 项，Kyo 定口径后换 2 加 6，二次复核返修加 6，三次复核返修加 1，见「核查返修」）：
  - 全弱者通关：`win`、`record_members`、`result_line`、`achievement_142`、`only_this_difficulty`（别的四档没有）、`after_load`（to_dict→JSON→from_dict 后还在）、`save_mark`、`second_win_keeps`、`no_global_weak_flag`、`lineup_weak`；输了 `lost_no_record`、`lost_no_line`。
  - 强者上场不记：`fighter_strong`、`helper_strong`、`join_helper_mid_battle`（战斗中入队进助力位）。
  - 战斗中换进强者不记：`swap_in_strong`、`swap_seen_by_action`、`swap_back_all_weak`（真 `XBattleLogic` 换上强者、行动一回合、再换回去，结束时又是全弱者，靠行动记录判出）。
  - 再挑战不算 `rechallenge_not_counted`；另一档 `xunchang_win`、`xunchang_line`。
  - 西游档照旧：`plain_not_tracked`、`plain_finish`、`plain_save_mark`；原版入口走不到 `legacy_unreachable`；开关 `switch_off`、`switch_off_save_mark`、`achievement_off`；`pool`。
- 反向验证（`反向验证.py`，4 项全咬住）：去掉 battle_logic 行动记录、判定不看档位、结束时不并当前阵容、不按难度分。
- 选测（`选测.py main`，battle_logic 改动波及 278 个场景）：走云端 `云端选测.py run`：提交 e524b0a1a0，278 个场景、16 片全部通过（Actions run 43558694922）。
- 返修后云端整轮（合 main 后 `选测.py` 结论是整轮）：提交 471d093589，583 个场景、15 片全部通过（Actions run 43578391942）。
- 语法检查通过；工具回归全部通过。
- 不跑 `--oracle`（天启篇新机制，没碰移植的原版逻辑）。

## 核查返修（gpt 甲档「修完再合」）

- P2 漏记中途进出的强者（`tianqi_weak_clear.gd` 只采开战、结束和行动者；助力位不行动也给光环和掉落）：
  - 修法：出战栏 5 格在开战前、每回合开头（`battle_logic.run_turn`）、每次行动开头（`note_actor` 顺带记出战栏）、天启篇换人（`tianqi_swap`，换上来的那一刻）、战斗中入队（`XState.add_actor`）、结束时都记一次；直接读 `battle_slots`，不调有副作用的 `battle_members`。
  - 断言：`join_then_leave_no_action`（战斗中强者入队进助力位、过一回合没行动、结束前撤下）、`swap_in_dead_no_action`（强者换上场、没行动就倒下、再换回去撤下）。
- 顺手核 ① 战斗异常中断后静态 `_tracking` 带到下一场：有这个问题，但没有实际后果——`finish` 只在 `run_final` 里、紧跟同一函数的 `begin` 调，`begin` 每次重置；残留只会让别的战斗往 `_seen` 里白记。修法：跟踪绑定存档（`_state`，`is_same` 判），换了存档不记、不能收。断言 `stale_other_save`（旧存档开了跟踪没收尾，新存档记不进、`finish` 返回 false、不出结算行）、`stale_reset_by_begin`（残留跟踪后照常打一场全弱者能记上，收完 `_tracking`、`_seen` 清空）。
- 顺手核 ② 档位结束时按 ID 重读、不存历史档位：有这个问题。成长型角色（三笠 95 按锻炼变量 1490、饿狼 173 按进阶）打到一半变成强者、结束前再改回去，原来就会漏。修法：每次见到时按当时档位记，见到一次不是弱者就一直不算，结束时再按当前档位核一次。断言 `tier_change_mid_battle`（三笠开战弱者→中途锻炼满变强者、过一回合→改回，不记）、`tier_steady_records`（同阵容不变档就记，对照）。
- 反向验证：换人不记、不按当时档位记、不绑存档、`note_slots` 整个失效（只剩行动者）、行动开头不记（连带换人），各项都咬住。回合开头 `note_slots` 和行动开头记出战栏两层是互相兜底的，单去一层测试仍过，两层一起去就咬住。`add_actor` 那一行也是兜底层：测试是入队后才直接写出战栏，这一行单独没断言。
- 提交：4d6669131（返修）、471d09358（合 main；先前 1917fad44 合进了后来被 main 退回的 claude/project-thread-n6hozb，带来的 xiyou_tianqi_e2e 在云端挂，已撤掉重合）。

## Kyo 定口径后的改动（11-14，单独提交，供 gpt 复核：本提交＋4d6669131）

- 判定：`XTianqiWeakClear.is_weak` 前加 `is_growth`（`skill_rework.json` `tiers.growth` 有这个号就不算弱者）。结算行「出战的全是弱者」、成就 142 文案没写弱者定义，不用改。
- 测试：删掉拿三笠当弱者的 `tier_change_mid_battle`、`tier_steady_records`，换成 `growth_list`（95、173 在名单里，测试的固定弱者池里没有成长型）、`growth_untrained_not_counted`（三笠没练，战斗档是弱者也不记）、`growth_trained_not_counted`（练满也不记）、`growth_wolf_not_counted`（饿狼没进阶放在上场位也不记）、`growth_mid_battle_not_counted`（真战斗里三笠换上来行动一回合再换回去，也不记）、`fixed_weak_records`（纯固定弱者照记）。39/39。
- 反向验证（3 项都咬住）：成长型照档位算、成长型名单只认三笠、判定恒假。
- 云端选测（基准 b1b69bccc，只改模块和专项）：801bef583，5 个场景全部通过（Actions run 43580010877）。
- 上次返修的「见到时按当时档位记」现在只防以后新加的会变档、又不在成长型名单里的角色；眼下能变档的只有成长型，已经一律不算，所以这一层暂时没有能单独咬住的用例。

## gpt 二次复核返修（4d6669131、801bef583 之后，两项 P2；本次单独提交，供 gpt 只复核这一个）

- P2-1 出战栏是边界采样，没盖住写入本身（同一事件里 add_actor 强者→设助力槽→恢复，中间不过回合／行动／换人就漏）：
  - 修法：不再加采样点，把写入收拢到 `XState` 一个咽喉点：单格写入 `set_battle_slot(i, id)`（写完记写进来的在队角色），整列赋值走 `battle_slots` 的 setter（赋值后扫一遍）。不在 36 层决战跟踪时 `XTianqiWeakClear` 直接返回，西游档零影响。改走咽喉点的写入：`xstate.gd` 的 `add_actor`、`remove_actor`、`init_battle_slots`（改成先拼好再整列赋值）；`battle_logic.gd` `tianqi_swap` 两处；`imported_balance.gd` `migrate_party` 补第一格；`actor_warehouse.gd` `_first_slot_fix`。`add_actor` 末尾那行 `note_slots` 删掉（被 `set_battle_slot` 取代，原来它在写格子之前触发）。
  - 没改走咽喉点、36 层决战里够不着或只写 0 的（逐条依据）：
    - `ui/party_scene.gd` 6 处：整队页，战斗场景里没有菜单入口，36 层决战期间打不开。
    - `core/imported_balance.gd` 第 70 行：只写 0（停用的导入角色移出），移出不会带进新人；`migrate_party` 只在读档迁移时跑。
    - ~~`core/item_marks.gd` `enforce_party`：经别名只写 0~~ 依据写错了（gpt 三次复核指出）：它清掉超出上限的超强者后会把替补的正角色号补进空格，三次复核返修已改走 `set_battle_slot`，见下一节。
    - `core/actor_warehouse.gd` `battle_slots.erase(id)`：移出；角色仓库是大厅页面，战斗里打不开。
    - `core/cat.gd`、`XState.from_dict`：整列赋值，本来就经 setter。
    - 事件改队伍（指令 129）走 `add_actor`／`remove_actor`；本场战斗成员 `XBattleLogic.actors` 从 `battle_members()`（读出战栏）取，换人走 `tianqi_swap`。召唤／替身没有写出战栏的代码（`rg` 过 `battle_slots` 全部写入，见专项 `slot_write_choke`）。
  - 防回归：专项 `slot_write_choke` 扫 `modes/xiyou` 全部 `.gd`，直接写 `battle_slots[…] =` 的只许 `xstate.gd` 1 处（`set_battle_slot` 本身）、`party_scene.gd` 6 处、`imported_balance.gd` 1 处（写 0）；以后谁新加一处直接写就挂。
  - 冗余采样层（开战前、回合开头、行动开头、换人、结束扫一遍）留着：成本一次字典写，兜住测试和以后可能出现的绕过咽喉点的写法；原来的 `join_then_leave_no_action`、`join_helper_mid_battle` 等仍用直接写格子，专门测这层兜底。
  - 断言：`same_event_slot_write`（同一事件里 add_actor→`set_battle_slot` 设助力槽→恢复原弱者，不过任何回合边界，不记；中途就已记上）、`same_event_slots_assign`（整列赋值换成带强者的一列再换回，不记）、`slot_write_choke`。
- P2-2 `is_growth` 名单缺失或为空时失效（三笠、饿狼会按战斗档被放行）：
  - 修法：失败即关闭。`growth_ok()`：`tiers.growth` 读不到或为空就不授予资格（不记、不点亮成就、不出结算行），`push_error` 报一次（专项里先压掉这一行，因为并行测试把 `ERROR:` 行判失败）。
  - 断言：`growth_missing_closed`（删掉 growth）、`growth_empty_closed`（设为空）、`growth_restored_records`（放回后照记）。
  - 数据校验：`03_转换工具/天启篇数据校验.py` 的 skill_rework 规则加一条「tiers.growth 非空」；`测试天启篇数据校验.py` 加 `SkillReworkGrowth` 三例（真表过、缺失报、为空报），51 例全过。
- 反向验证（4 项都咬住）：单格写入不记、整列赋值不记、名单读不到照放行、`tianqi_swap` 改回直接写格子（`slot_write_choke` 抓到）。
- 专项 45/45；云端选测（基准 ffddb04ca）：ea295a562，546 个场景通过，`xiyou_fabao_rework` 偶发一次（并行时失败、单跑通过，不碰本车道文件）（Actions run 43581272231）；工具回归通过。

## gpt 三次复核返修（ea295a562 之后，一项 P2；本次单独提交，供 gpt 只复核这一个）

- P2 `core/item_marks.gd` `enforce_party` 经别名 `slots := s.battle_slots` 把替补的正角色号写进空格（`slots[i] = reserves.pop_front()`），绕过 `set_battle_slot`，也绕过只搜 `battle_slots[…] =` 的源码守卫；上一节把它写成「只写 0」是错的。
  - 修法：去掉别名，清空格和补替补两处都改走 `s.set_battle_slot`；行为不变（同一个数组，顺序一样），只是写入时多一次记录。
  - 断言：`enforce_party_fill_noted`（寻常档超强者上限 +1 名摆进上场格、替补只剩一名强者，跟踪中跑 `enforce_party`：超出的超强者清出、强者补进那一格，且写入当时就记成「不是弱者」）。
- 守卫 `slot_write_choke` 扩成三类，逐文件计数和白名单比：`index`（`battle_slots[…] =`）、`mutate`（`battle_slots.append／insert／erase／remove_at／clear／fill／assign／resize／push_*／pop_*／reverse／sort*／shuffle(`）、`alias`（把 `battle_slots` 本身交给变量、函数参数或字典值——之后经别名原地写就绕过前两条）。
- 全库 rg 结果（`modes/xiyou` 全部 `.gd`，`var x := *.battle_slots` 不带 duplicate、函数参数、字典值、原地修改方法、下标赋值；tests 不算游戏代码）：
  - 别名：原来只有 `item_marks.gd` 552 行一处（已去掉）；另一处是 `xstate.gd` `to_dict` 把 `battle_slots` 放进存档字典（只用来写盘，不经它改格子），白名单 `alias: 1`。
  - 原地修改：只有 `actor_warehouse.gd` `battle_slots.erase(id)`（角色仓库，大厅页面，战斗里打不开；移出不会带进新人），白名单 `mutate: 1`。
  - 下标赋值：`xstate.gd` 1 处（`set_battle_slot` 本身）、`ui/party_scene.gd` 6 处（整队页，战斗里打不开）、`imported_balance.gd` 1 处（写 0，读档迁移）。
  - 其余读取 `battle_slots` 的都是读（`find`、`has`、下标读、`duplicate()`、`filter`），守卫不算。
- 反向验证（3 项都咬住）：补替补改回经别名直接写（断言和守卫都挂）、只加一个别名不写（守卫挂）、加一处原地修改 `push_back`（守卫挂）。
- 专项 46/46；云端选测（合 main 后 e866647ec，基准 07fdbfa77）557 个场景全部通过（Actions run 43583278931）。

## 本分支提交

- 8c41caaf6 模块、接线、专项
- e524b0a1a 专项补「战斗中入队进助力位」用例
- afe6191fa 交付单
- 4d6669131 返修 gpt 甲档 P2＋中断残留、战斗中变档
- 471d09358 合并 main
- b1b69bccc 交付单（核查返修）
- 801bef583 Kyo 定口径，成长型角色不算弱者（模块＋专项＋交付单）
- ffddb04ca 交付单记云端结果
- ea295a562 gpt 二次复核返修（出战栏写入咽喉点、成长型名单失败即关闭）
- 07fdbfa77 交付单记云端结果
- c0b223710 gpt 三次复核返修（enforce_party 改走 set_battle_slot、守卫扩到原地修改和别名）
- e866647ec 合并 main
- 本提交：交付单记云端结果
