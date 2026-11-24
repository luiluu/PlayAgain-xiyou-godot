# 交付：luiluu/t453

- 车道／工作者：cc（Claude Sonnet 5.5＋medium，P6），T453 火海披风纳入首领持续伤害 5% 上限
- 状态：可合并
- 云端选测：run 45378841735（`https://github.com/<本库>/actions/runs/45378841735`），结果见文末「云端选测」一节

## 变更记录草稿

## 2026-11-24 【cc·T453·未经审查】传承 2617 火海披风（State 243）纳入守层者／首领每回合 5% 持续伤害预算；T405 核 P3-1／P3-2 收口（dev.待定）

- 实测（传承 2617 开战给全体敌人挂 State 243「火海」，`StartAEPushState0243`；XExtDot 按 abs_rescale.json state_dot 243 = 生命上限 100%，浮动 ±20%）：3 个回合键下，22 层三眼娃（敌群 458）、29 层太白金星（465）、30 层（466）、副本首领（422）第一回合末都被整血级扣掉（约 92%～100% 最大生命，≥ 单回合直接死）。T405 的 5% 封顶只管 HP 再生那一路，XExtDot 在再生之前执行，所以没拦住它。
- 改法：`balance_table.combat_rules.boss_neg_hrg_cap_extdot_states: [243]`（表驱动，现只列火海）。`XExtDot._one` 算完值后调 `XTianqiCombat.cap_extdot`：守层者／首领（同一个 `is_neg_hrg_boss`）身上列表里的状态，扣血合计不超过 ⌊最大生命×boss_neg_hrg_cap_pct%⌋，已用预算记在敌人 meta `t453_dot_used`；`_regenerate` 算出 dh 后调 `cap_regen_after_dots`，把已用预算从再生负值里扣掉并清账。两路（XExtDot 火海＋再生灼伤／中毒）合计 ≤5%，先扣 XExtDot 再扣再生。不在表里的 XExtDot 状态（如 T402 守层者自带的毒／出血）不动。
- 开关：仍是 `XTianqiCombat.BOSS_NEG_HRG_CAP`（关＝火海整血级，回到封顶前）；西游档（`on()` 为假）零变化，专项里照原版 10000±20%。
- T405 核 P3-1：`battle_logic._regenerate` 导入角色分支，封顶关着（或小怪）时改回 T332 原式 `rr[0] − dot_neg`（逐值回退）；封顶开着时重套封顶，且逆祷（prayer）来源的导入负再生已在 `prayer_block` 里，不再重复扣（新加 `dot_prayer`）。
- T405 核 P3-2：D273 的再生那一路挂在 `XTianqiCombat.regen_unscaled()`（= `DOT_NO_WAREHOUSE and on()`）下，关 T332 会连带关掉再生封顶；T453 的 XExtDot 一路不依赖 T332，只看 `BOSS_NEG_HRG_CAP`。依赖已写进 `tianqi_combat.gd` 开关注释与 `balance_table.json` 的 `boss_neg_hrg_cap_note`。
- 校验：`天启篇数据校验.py` 加 `boss_neg_hrg_cap_extdot_states` 必须是正整数列表，配套单测。
- 新增专项 `xiyou_tianqi_extdot_cap`（13 项）。
- 玩家可见：无（战斗数值，卡面没有「按血量」字样）。

## 交接板

- 下一步：无
- 用户试玩说明：天启篇带传承 2617 火海披风，守层者／首领每回合最多被它（连同灼伤等）扣 5% 最大生命，不再一回合蒸发；普通小怪照旧被整血级扣掉。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：量数脚本 `endTurnDmg` 只记 `end_turn()` 前后总血差，看不出各来源（XExtDot、再生、别的回合末效果）；给 VP 加一列按来源拆的账，之后 P3-4 这类「超 5% 来源」一次跑完就能定位（预计收益：省一轮重跑；归 VP 车道）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XExtDot._one`（加一行 `cap_extdot`）、`XExtDot.tick`（开头清账） | `tick` 调用方 9 处（`git grep -nE 'XExtDot\.tick' -- '*.gd'`） | 调用方 9 处逐处结论：战斗里 1 处、测试 8 处。`cap_extdot` 对西游档、非首领、不在表里的状态、正值（回血）原样返回，不碰 meta；`reset_dot_budget` 只在有 meta 时清 |
| `BattleLogic._regenerate`（导入分支改动＋`cap_regen_after_dots`） | 战斗里回合末 1 处调用 | 导入分支：封顶关着时逐值回到 T332 原式；`cap_regen_after_dots` 无 meta 直接返回 dh（西游档、没挂火海的首领零变化）；`xiyou_imported_balance` 233/233、`xiyou_tianqi_boss_neg_hrg_cap` 11/11、`xiyou_guardian_burn_regen` 48/48 过 |
| 新增 `XTianqiCombat.cap_extdot／cap_regen_after_dots／reset_dot_budget／boss_dot_budget／extdot_capped_states` | 3 处调用（`git grep -nE 'XTianqiCombat\.(cap_extdot|cap_regen_after_dots|reset_dot_budget|boss_dot_budget|extdot_capped_states)' -- '*.gd'`） | 3 处即 ext_dot.gd 2 处、battle_logic.gd 1 处 |
| `XEnemy.cap_neg_hrg`（未改签名，调用处新增 1 处判断） | 5 处（`git grep -nE '[^[:alnum:]_]cap_neg_hrg[[:space:]]*\(' -- '*.gd'`） | 签名不变，行为不变 |

## 实测数字与 CE334 核对（验收 7）

### 实测（封顶前，3 个回合键，单只敌人，难度「剑仙」）

| 敌群 | 最大生命 | 第 1 回合 XExtDot 扣血占比 |
| --- | --- | --- |
| 458（22 层） | 11,120,000 | 约 98% |
| 465（29 层） | 25,680,000 | 约 99% |
| 466（30 层） | 1,560,000 | 约 93% |
| 422（副本首领） | 500,000 | 100%（血量不够，直接倒） |

结论：火海一回合就杀掉首领，不是「按血量 100%」的字面扣 100% 一刀，而是 100%±20% 的浮动；封顶后每回合恰为 ⌊最大生命×5%⌋（专项逐项断言：22 层 556,000、29 层 1,284,000、30 层 78,000、副本首领 25,000）。

### 「13～33 层被 CE334 清掉」核对

没有证据。公共事件 334 是「真气珠」（掉真气珠／加属性），不是清状态；全库公共事件和敌群事件里也没有一条去掉状态 243 的命令（313 改状态）。实测 22／29／30 层和副本首领开战后都带着 243。这一说法不成立，不改。（13～33 层其余层没逐层起战斗测，只靠公共事件／敌群事件全表扫描，不是逐层实打；如要逐层实打得另开专项。）

## 数值报告：逐种子分布

没有跑 VP 量数（见「没做」）。专项里的「种子」是 3 个回合键（11／22／33）的 XExtDot 浮动随机：

| 回合键 | 22 层掉血 | 29 层掉血 | 30 层掉血 | 副本首领掉血 | 剔除 |
| --- | --- | --- | --- | --- | --- |
| 11／22／33 | 均 = ⌊mhp×5%⌋ | 均 = ⌊mhp×5%⌋ | 均 = ⌊mhp×5%⌋ | 均 = ⌊mhp×5%⌋ | 全部计入 |

（专项断言 worst ≤ 预算且 best ≥ 预算，所以每个回合键都恰好打满预算。）

## 没做／没查清

- **验收 6（P3-4 量数表注明、查清最大 5.47%）：只做了一半**。口径可以写明：`endTurnDmg` ＝ VP 里 `end_turn()` 前后敌人总血差（含 XExtDot、再生、回合末别的掉血），平均到每回合，再除以开战初始总血（`enemyHp`）；T405 统计里最大 5.47% 出现在 29 层寻常「随机2」14 回合，22 层艰险最大 5.43%。**超出 5% 的 0.4～0.47 个百分点的来源没查清**：专项确认守层者单只 XExtDot＋再生合计 ≤⌊mhp×5%⌋；那几场里火海披风没穿（量数队没带），所以不是 243；T402 的毒／出血挂在我方身上，也不是。剩下候选是 `end_turn()` 里别的回合末掉血，或 duel 模式下敌人血量与 `enemyHp` 口径差。要查清得在 VP 里按来源拆账重跑，量数两轮封顶、此单不开第 3 轮，建议另开一单（见「可优化」）。已写进此处，没改 T405 的归档统计文件。
- **量数（D271 五档标尺强队、22／29 层回合数与胜率变化）没跑**：基准队没带 2617，跑出来的回合数与封顶前后对比不变；真正要比的是「带披风」队，需要给 VP 加装备选项，超出本单（P6、小改动）范围，且要动 `tests/virtual_player/`，是共用文件。要不要做请项目经理cc 定。
- P3-1 的导入分支（有导入角色挂的状态＋逆祷）没有新写专项：现有 `xiyou_imported_balance` 233/233 通过，但没有覆盖「天启敌人＋导入状态＋异化逆祷」这一组合；我按代码推理改的，没实测这个组合。

## 本分支提交

- 10b78deaf T453（D273）：火海披风 State 243 的 XExtDot 持续伤害并进守层者／首领每回合 5% 预算

## 云端选测

（待跑完补）
