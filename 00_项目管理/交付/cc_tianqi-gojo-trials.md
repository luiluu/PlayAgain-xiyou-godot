# 交付：cc/tianqi-gojo-trials

- 车道／工作者：天启篇五条悟进阶两次＋两场专属试炼战／cc（Opus＋high）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【cc·天启篇·未经审查】五条悟进阶改两次，进阶条件是打赢专属试炼战「怀玉」「新宿」（O-待定，dev.待定）

- 依据：Kyo 2026-11-14 细案（只能进阶两次；一阶 25 级、二阶 55 级；条件＝打赢专属试炼，一阶对伏黑甚尔的影子、二阶对两面宿傩的影子）；设计稿私密仓 `重制设定/天启篇_五条悟_角色设计_v0.3.md`（v0.2 保留）。
- 进阶表（`XGojo.patch_plugins` 写 Star_ActorAdvanced「Advanced 501／502」）：一阶 25 级、10 万，学超越极限 I、II，进阶·自动反转、进阶·茈贯穿；二阶 55 级、50 万，学 III、IV，进阶·领域强化、进阶·茈收束。不要材料（原表的 186、180 号去掉）。增伤预算不变（四个超越极限合计 +20%）。金钱照细案 10 万／50 万，不走金钱重构的四阶价（`XAdvance.row` 对五条悟跳过 `XTianqiMoney.advance_gold`）。
- 学技能：虚式「茈」50→25 级、无量空处 60→55 级（试炼要用；职业习得表，`XTianqiGojoTrial.learn_level`）。
- 入口：兑换大厅奉神老妪「进阶」（方桌大厅走一步）。选五条悟、等级金钱够、只差试炼时，确认窗写「挑战试炼「怀玉」」；选「是」关掉进阶页，`mv_script` 接着 `XTianqiGojoTrial.run_request` 开战。进阶需求下多一行「试炼:怀玉（未通过／已通过）」；缺等级或金钱照常提示，多列一项「试炼：怀玉」。云裳天衣铺里打开的进阶页不开试炼。
- 单挑：开战前存检查点，记下队伍、出战栏和五条悟的生命／魔法／TP／状态（存档 `flags._gojoTrial`），只留五条悟一人（助力位也空）。输了或逃跑：不算全灭、不回标题、不扣钱，回原地图，队伍和五条悟战前状态还原，可马上重打。赢了：同样还原，记 `flags.tianqi.gojo_trials`，扣钱进阶。存档里留着进行中的试炼的，读档时还原（`XSave._load_data`）。
- 影子：借甚尔、宿傩现成的战斗图（`<Sideview Battler>`），压一层暗紫色调（`battler_sprite` 一行）；不进怪物图鉴，没有经验、金钱、掉落、法宝经验、真气等任何战斗奖励。强度按五条悟开战时的等级 L 算（不看装备）：生命＝hp_units × U，U＝职业 L 级本体魔攻 × 等级缩放 × 天启出伤倍率 × 我方结算乘区（×6）；出招＝职业 L 级本体生命 × 比例 ÷ 承伤倍率；五档难度打起来一样。出手按回合表，不掷随机数，招都不判命中闪避。
- 怀玉（伏黑甚尔的影子，16 U，速度 ×1.5，每回合 2 次）：单数回合天逆鉾（10%，无下限挡不住，命中打掉 1 个苍印或赫印）、双数游云（8%）；第二次 3 的倍数回合释魂刀（18%）、否则游云。五条悟生命第一次掉到 30% 以下（会被打死就留 1 点）领悟反转术式：回满、苍印赫印补满 3／3，台词「天上天下，唯我独尊」。只有虚式「茈」能打倒影子，别的伤害最多压到 1 点。
- 新宿（两面宿傩的影子，60 U，魔防＝本体魔攻 ×0.5，每回合 1 次）：第 2 回合起每 5 回合展开伏魔御厨子 3 回合，开着的每个回合结束对五条悟必中斩击（50%，无下限挡不住）；领域到期的下一回合神灶：开（25%）；其余回合 3 的倍数捌（16%）、否则解（9%）。两边领域都开着＝领域对拼：御厨子斩击不落，无量空处的术式必中和信息过载失效（给印照常）；双方挂「领域对拼」。信息过载对影子按首领 15%。
- 新技能 10651～10658、状态 2801～2802（接在五条悟号段后，`XGojo.patch_skills／patch_states` 末尾补，被正式源占用时报错不覆盖）。数值表 `tianqi_data/gojo_trials.json`。
- 旧存档：按旧四阶表进阶过的五条悟，读档迁移一次（`flags.tianqi.gojo_adv_v＝3`）：新阶数＝旧阶数 ÷ 2，包含的试炼记通过，已学技能不收回、缺的补学；已到 25／55 级的补学茈／无量空处。
- 战斗核心改动（核查重点）：`battle_logic.gd` 只加 6 处挂钩——setup 换影子、decide 影子出招、`_make_action_times` 固定次数（和骑士取大）、hp 账本 `_execute_hp_damage_ledger`（怀玉留 1 点、只有茈能打倒）、`rewards()`／`grant()` 试炼无奖励。其余走 `gojo.gd` 现成挂点（begin、finish、end_round、infinity_block、overload、sure、after_apply、after_hit、formula）。没改函数签名；没碰 tianqi_horsemen.gd 和派单列的别车道文件。
- 玩家可见：天启篇五条悟最多进阶两次，25 级、55 级时在进阶界面挑战专属试炼，打赢才进阶；茈 25 级、无量空处 55 级就能学到。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_gojo_trial.gd`（挂点：`battle_logic.gd` 6 处、`gojo.gd`、`advance.gd`、`ui/actor_advanced.gd`、`ui/yunshang_shop.gd`、`map/mv_script.gd`、`core/xsave.gd`、`battle/battler_sprite.gd`）；`tianqi_data/gojo_trials.json`；`tests/xiyou_gojo_trials.gd` | 重制新角色，无原版；v0.2 照狗逍遥四次进阶（50／60／70／80 级、材料） | 进阶两次（25／55 级、10 万／50 万、无材料），条件是打赢专属试炼战怀玉、新宿；茈 25 级、无量空处 55 级学；旧四阶存档迁移 | Kyo 2026-11-14 细案；设计稿 v0.3；Kyo 11-11 优化直接接受 | `XTianqiGojoTrial.ENABLED = false`（回 v0.2 四阶表、50／60 级、没有试炼）；分项 `LEARN_SHIFT`、`OWN_GOLD`、`RESTORE_ON_WIN`、`SHADOW_TINT` | cc | 保留 |

## 交接板

- 下一步：gpt 甲档交叉核查本分支（battle_logic 6 处挂钩、tianqi_gojo_trial.gd 全部、gojo.gd 挂点）。数值线做金钱重构校准时一起看五条悟两阶的 10 万／50 万。
- 用户试玩说明（最快走到两场试炼）：
  1. 本机天启篇开新档（任意难度；五条悟要先解锁「最强之名」，测试时可在全局配置把 `codexTianqiGojo` 设 true），抽阵容时重抽到五条悟（超强者，九死以上才抽得到）。
  2. 大厅调试 NPC（方桌大厅 EV069，测试模式）一键 99 级会直接越过 25 级；想看 25 级那场，用测试模式改等级到 25，或正常打到 25 级。金钱至少 10 万（测试模式可加）。
  3. 方桌大厅走到兑换大厅，找奉神老妪「进阶」→ 选五条悟 → 底部「进阶」→ 确认窗「挑战试炼「怀玉」」选是。打法：交替苍、赫攒印，被打到 30% 以下会领悟反转术式补满印，甚尔被压到 1 点后放茈收尾。输了回原地、什么都没少，可重打。
  4. 打赢后五条悟一阶；练到 55 级、凑 50 万，再进阶界面挑战「新宿」。打法：宿傩第 2 回合展开伏魔御厨子，当回合就开无量空处对拼；之后每 5 回合他再开，领域冷却好了就接上，接不上的那几刀靠反转术式顶。
- 需要用户决定（都已按默认实装，可改）：
  1. 茈 50→25 级、无量空处 60→55 级学（不提前的话一阶试炼没有茈、二阶没有领域）。
  2. 进阶金钱照细案 10 万／50 万，不走金钱重构给全体角色的 10 万／30 万（OWN_GOLD 关掉即改走金钱重构）。
  3. 试炼入口放在兑换大厅的进阶界面（不另加大厅 NPC）。
  4. 打赢也把五条悟的生命等恢复到战前（细案只说输了恢复）；试炼可逃跑，逃跑＝放弃。
  5. 新宿数值：影子 60 U、御厨子斩击 50%。斩击 30% 时反转术式（天启篇治疗 ×5）基本回满，不开领域也偶尔能拖到最后，所以加重；对拼时整刀抵消，只罚不开领域的打法。

## 进度账

- 无。

## 验证

- 语法检查（841 个 .gd，0 问题）；发行空壳 `check`（50 个脚本、395 个函数都有）、`测试发行空壳.py`、`测试导出过滤.py` 通过；工具快速回归全部通过（86 秒）。
- 专项 `xiyou_gojo_trials` 115/115、`xiyou_gojo` 74/74（本机）：
  - 一、表：`rows_two`、`row1`、`row2`、`learn_shift`、`trial_skills`、`trial_states`、`trial_skill_module`、`data_nice`。
  - 二、条件：`missing_only_trial`、`challengeable`、`missing_gold_too`、`missing_level_too`、`own_gold_rank0/1`、`own_gold_off`、`full_no_trial`、`other_actor_untouched`、`xiyou_untouched`。
  - 三、换队恢复与存档：`begin*`、`lose_*`、`escape_same_as_lose`、`win_*`、`save_roundtrip`、`mid_saved`、`load_restores`、`restore_on_win_off`；迁移 `migrate_*`。
  - 四、怀玉：`h_shadow`、`h_tint(_off)`、`h_actions`、`h_rewards`、`h_grant_none`、`h_fast`、`h_schedule`、`h_spear_*`、`h_lock*`、`h_purple_kills`、`h_one_left`、`h_awaken*`、`h_can_die_after`、`h_end_clears`。
  - 五、新宿：`x_shadow`、`x_r1`、`x_r2_shrine`、`x_shrine_on`、`x_slash*`、`x_domain_tick`、`x_clash*`、`x_shrine_ends`、`x_fuga`、`x_cleave`、`x_shrine_again`、`x_overload_boss_rate`。
  - 六、脚本化整场（夹具按真实开局学三个难度被动；五个存档种子各一遍）：怀玉会用机制全赢 7～14 回合、不放茈全输（甚尔一直剩 1 点）；新宿会用机制全赢 14～15 回合、不开无量空处全输（第 4 回合）。`huaiyu_*_0～4`、`xinsu_*_0～4`、`huaiyu_awakening_usual`。
  - 七、界面到开战：`page_confirm_trial`、`page_request`、`run_lose`、`run_win`、`run_stale_request`、`page_no_trial_in_shop`；开关 `off_*`、`learn_shift_off`。
- 反向验证（`04_验证/反向验证清单/tianqi_gojo_trials.json`）：15 处改坏全部咬住（天逆鉾破无下限／拆印、只有茈能打倒、领悟回血、对拼抵消斩击／废必中、到期神灶、输了恢复、条件要试炼、rewards／grant 无奖励、甚尔两次、自己的金钱、提前学、迁移折半）。
- 选测（云端，`选测.py main` 选中 444 个场景，含 xiyou_rules 全部段、xiyou_determinism、事件对照；提交 c5b62c615，运行 43581720835）：444 个场景全部通过，16 片、最长一片 11.9 分钟。之后的 93bde989d（专项加断言、反向验证清单）、aaa7b4cdd（读档还原整个恢复五条悟、没进阶时的提示语）只动了 `tianqi_gojo_trial.gd` 两个函数和专项，本机重跑 `xiyou_gojo_trials` 115/115、`xiyou_gojo` 74/74、语法检查、发行空壳 check 通过，没再上云端。
- 没跑 `--oracle`：没改原版移植的底层逻辑；battle_logic 的挂钩只在试炼战（`active(logic)`）生效，西游档和别的天启篇战斗原样返回。

## 可优化（流程／工具／效率）

- 建议：`选测.py` 认手写数据 json 的引用只找 `"文件名"` 带引号的写法（`loaders`），天启篇模块都写完整路径 `res://…/tianqi_data/x.json`，所以新数据表一律判「找不到用它的测试，整轮」；本车道是在专项头注释写上文件名绕过的。可以让 loaders 也认路径结尾是 `/文件名"` 的写法（预计每条新加天启篇数据表的车道省一次误判整轮，归工具车道）。

## 本分支提交

- 7bb5a34d6 天启篇五条悟：进阶改两阶（25／55 级）＋专属试炼战怀玉、新宿
- a4b67b50b 专项 xiyou_gojo_trials；xiyou_gojo 进阶行改两行
- 77311fec5 发行防泄漏：类改名 XTianqiGojoTrial、空壳特例
- c5b62c615 专项头注释写明数值表（选测认引用）
- 93bde989d 专项补无奖励断言；反向验证清单
- aaa7b4cdd 读档还原整个恢复五条悟；没进阶时的提示语
