# 交付：luiluu/t546

- 车道／工作者：T546 技能表跨调用缓存（cc，Opus＋medium，P8）
- 状态：可合并（R1 返修：小A 甲档核查退回 P1×4＋P3×1，已全部修完，见下「R1 返修」）

## R1 返修（2026-11-26，核查报告 P1-1～P1-4、P3-1）

| 编号 | 漏了什么 | 怎么修 | 专项（拿掉修复就红，本机两线都跑过） |
| --- | --- | --- | --- |
| P1-1 | `XMagicWeapon.SCALE_99_TO_888`（西游档徐凤年 9998 系数 130000↔209000） | 加进 `_skills_switches` | `switch.scale_99_to_888.*` |
| P1-2 | `XTianqiElements.PHYSICAL_DUAL_KEEP_NEUTRAL`（自然物攻单／双属性，86 号 elementId 14↔0） | 加进 `_skills_switches` | `switch.physical_dual_keep_neutral.*` |
| P1-3 | `ReleaseEntry.is_release()`（天启篇各层 `on()` 认 `RELEASE_OPEN or not is_release`） | 加进 `_skills_switches` | `switch.release.*`（7238 号卷改写↔原版） |
| P1-4 | 底表 `XDB._tables["Skills"]` 整张换过（苍龙 `clear_cache`、贝吉特 `original_data`、文字修正 `clear_cache` 都是 erase 重载，不调作废） | 静态记一份建缓存时的表引用 `_skc_tbl`，`_skills_entry` 一进来 `is_same` 比当前底表（只比引用，O(1)），不同就整个 `_skc_store` 清掉（见下「偏离」） | `table.canglong.*`、`table.vegeta.*`、`table.erase_plain.*`、`table.old_entries_dropped` |
| P3-1 | 天启篇模块 `reload_table()` 不作废 | 主线 5 处（`XTianqiSkills`、`XTianqiElements`、`XTianqiGeneralBooks`、`XTianqiSecrets`、`XTianqiWeakAffix`）、补丁线 3 处（没有通用书、秘籍）开头调 `XActor.skills_touch()` | `reload.<模块>.rebuilt` |

**变异检查**：上面 5 项各拿掉一项，主线（108 条）和补丁线（96 条）各自那一组断言都失败（主线 104/108、104/108、104/108、100/108、103/108；补丁线 92/96、92/96、92/96、88/96、93/96），放回全过。

**偏离核查报告的修法（P1-4）**：报告建议每个缓存项各记 `tbl`。我先照这样做了（ff2b0450e），云端第 8 片连跑两次都在 `xiyou_tianqi_team_builder` 附近被机器关掉（exit 143）；本机量最大内存：该场景缓存关 2.16 GB、R0 2.15 GB、各项记 tbl **8.6 GB**。原因：这个场景反复切档，文字修正每次 erase 重载 Skills 表，最多 64 个缓存项各自攥着一份旧整表。改成全局只记一份、换表就清空整个缓存（bd5a8df08）后 2.24 GB，专项加 `table.old_entries_dropped`（换表后缓存里只剩按新表建的项）。补丁线同改，team_builder 2.22 GB。

### 全库扫法（不只补这 4 个）

写了个只读脚本（没入仓，scratchpad 里的 `scan.py`，逻辑如下，下回要复扫照做）：

1. 把工程里每个带 `class_name` 的 `.gd`（不含 `tests/`）拆成「静态函数 → 函数体」和「静态变量名」两张表。
2. 从 `XActor._skill_records` 出发沿调用走（`类名.函数` 跨类、同类裸函数名，深 4 层；这样覆盖 `XDB.rec`、`XDB.table` 首次载入时的各 `patch_skills`、`XTextFix.load_table`、三层视图、`is_sealed`）。
3. 列出走到的函数里读到的全部**静态变量**（大写开关和小写状态都列，如 `ReleaseEntry.simulate_release`）。
4. 逐项归类：①已在缓存键／开关位图；②只在载入 Skills 表时用（苍龙、五条悟、五条悟试炼、贝吉特、文字修正、真气突破奖励）→ 切了要 erase 底表才生效，由 P1-4 的表引用比对兜住；③天启篇模块自己的数据缓存（`TUNE_D189～D287`、`GUARD` 只在 `XTianqiSkills.data` 里读）→ 要 `reload_table` 才生效，由 P3-1 兜住；④只影响别的表（Enemies／Troops／States／Items／CommonEvents／Armors：`STRIP`、`XINMO`、`CROW_BLUEPRINT_NAMES`、`FIX_HALFSTEP_1666`、`SukunaFx.FX`、`TURN_CD_V035`、`ELEMENT_FABAOS`、`YEP_RECOMPUTE`……）→ 与技能记录无关；⑤纯性能缓存开关（`XZhenqi.DAOFA_TAG_CACHE`）与按输入键好的记忆表（`_views`、`_recs` 等，键里带了基底记录引用或开关）→ 结果不变；⑥测试注入 `XTianqiWeakAffix.test_entries` → 已在 `view_sig` 里。
5. 扫出来落在 ①～⑥ 之外的只有核查报告那 4 个开关（P1-1～P1-3 三个＋P1-4 底表），没有第五个。补丁线（接 306d3ad5a）同样扫过一遍，结果是主线的子集（少通用书、秘籍两模块），同样只有这 4 个。

说实话：脚本只走静态调用，`self.xxx()` 实例方法链和动态 `call()` 走不到；`_skill_records` 这一段本身都是静态调用（`XDB.rec`、各模块 `skill_view`、`is_sealed`），所以这一段是全的，但以后新加一层用实例方法读开关的视图会漏，兜底照旧是 `XIYOU_READ_VERIFY=1` 跑专项。

## 结论

角色的技能表现在跨调用记住：id 表每次照算（便宜），逐条建记录这一步（贵）只在输入变了时重做。400 个被动时，只读窗口外读一次最大 MP 8.2 → 2.4 ms、`param_base` 14.8 → 1.3 ms、`skills()` 7.1 → 0.6 ms；战斗里每次行动平均 205 → 123 ms；技能页（已带 T545 窗口）移动一格 54 → 31 ms。整场战斗日志开关两态逐字相同，全程比对（`XIYOU_READ_VERIFY=1`，不一致当场崩）46 个战斗／技能场景全过。**安卓实机没测。**

## 做法（为什么不是「挂脏标记」）

派单设想的是「学／忘技能、换装、升级、加减状态、天启篇养成变化时作废」。我查下来，技能表的输入远不止这些：云裳借技能读别的角色会不会、吸取专武读整个背包和全队装备、异化读战斗中与否和异化记录、屠苏／璇读本体等级……逐个写入点挂作废，漏一处就是读到旧技能表，而且没法证明挂全了。所以拆成两段：

1. **id 表**（`_skill_ids_now`，各 skills 包装都在这里）：每次照算，400 个被动约 0.8 ms。上面那些牵涉别的角色、背包、战斗的输入全在这一段，不需要挂作废。
2. **建记录**（`_skill_records`：`XDB.rec` 的二十来层改写、秘籍封印、真气／天启篇装备／弱者词条三层视图）：400 个被动约 7 ms。这一段的输入我逐个对过代码，全部放进缓存键（`XActor._skills_key`），键和 id 表都跟上次逐项相同才用上次的结果。

另有一个全局代数 `_skills_epoch`（版本号），已有的全部写入点都会让它加一（宁可多建）。按标签取的被动值（`passive_values`）跟着同一份记录一起记住。

### 会改技能表的输入清单（验收 2）

| # | 输入 | 怎么作废 | 专项（`tests/xiyou_skills_xcall.gd`） |
| --- | --- | --- | --- |
| 1 | 学会技能 `learn_skill` | id 表变了；另有 `read_touch` 换代 | `learn_skill.*` |
| 2 | 遗忘技能 `forget_skill` | 同上 | `forget_skill.*` |
| 3 | 直接改 `skill_ids`（不经 learn） | id 表比对 | `skill_ids_direct.*` |
| 4 | 换装备（带「增加技能」特性、心钢、法宝……） | id 表比对；`XEquipment.change` 另有 `read_touch` | `equip_direct.*`、`unequip_direct.*` |
| 5 | 加状态（带特性加技能） | id 表比对；`state_touch` 换代 | `add_state.*` |
| 6 | 去状态 | 同上 | `remove_state.*` |
| 7 | 直接改 `state_ids` | id 表比对 | `state_ids_direct.*` |
| 8 | 等级（屠苏／璇／谷雨按等级解锁） | id 表比对（直接改 `_lv` 也认） | `level_direct.*`、`change_level.*` |
| 9 | 真气境界（道法说明按境界缩放） | 键：`XZhenqi.daofa_scale` | `zhenqi_realm.*` |
| 10 | 当前存档换了 | 键：`XState.current` 实例号 | `state_current.*` |
| 11 | 天启篇档（rules） | 键：`XTianqi.active` | `tianqi_mode.*` |
| 12 | 各层改写的回退开关（19 个，R1 后 22 个，`_skills_switches`） | 键：开关位图 | `switch_toggle.*` |
| 13 | 秘籍封印（原始封印表） | 键：`XTianqiSecrets.sealed_raw`（新加） | `seal_raw.*`、`unseal_raw.*` |
| 14 | 弱者专属词条投影 | 键：`XTianqiWeakAffix.view_sig`（新加） | `weak_affix_on.*`、`weak_affix_off.*` |
| 15 | `_cat_bare`（猫的裸装读法） | 键 | （跟窗口缓存同一个键，`xiyou_cat` 覆盖） |
| 16 | 已有写入点：`read_touch`、`state_touch`、`passive_touch`、`read_reset`、`batch_begin` | 换代 | `epoch.*` |
| 17 | 测试重载数据表后 | `XActor.skills_touch()` 换代 | `epoch.skills_touch.*` |
| 18 | 徐凤年 9998 系数开关 `XMagicWeapon.SCALE_99_TO_888`（R1） | 键：开关位图 | `switch.scale_99_to_888.*` |
| 19 | 自然物攻单／双属性 `XTianqiElements.PHYSICAL_DUAL_KEEP_NEUTRAL`（R1） | 键：开关位图 | `switch.physical_dual_keep_neutral.*` |
| 20 | 发行 `ReleaseEntry.is_release()`（R1） | 键：开关位图 | `switch.release.*` |
| 21 | 底表 Skills 整张重载（苍龙、贝吉特、文字修正切开关后 erase）（R1） | 命中时 `is_same` 比表引用 | `table.canglong.*`、`table.vegeta.*`、`table.erase_plain.*` |
| 22 | 天启篇模块数据表重载 `reload_table`（R1） | 里面调 `skills_touch` 换代 | `reload.*` |

每条都查三件事：确实重建了、结果与关掉缓存现算的逐项相同、结果确实变了（换代那几条不要求变）。另外：没改什么时连读不重建；影子克隆（装备预览）各算各的、本体缓存不受影响；测试里改写了 `skills()` 的子类，`passive_values` 照旧读改写版；回退两态在 120 个被动下读能力值逐项相同；全程比对零不一致。共 81 条全过。

**变异检查**：把缓存键里的封印表、词条投影、道法缩放、开关位图、天启篇档分别拿掉一项，各自那一组断言都会失败（本机跑过，五项都抓到了）。

### 剩下的风险（说实话）

- 天启篇以后新加一层 `XDB.rec` 改写或技能视图：只靠回退开关和存档模式的照样自动作废；要是读了存档里的新进度，就得把它加进 `_skills_key`（代码注释和 `sealed_raw`、`view_sig` 旁边都写了）。漏了的话，带 `XIYOU_READ_VERIFY=1` 跑专项会当场崩。
- 切了只在载入 Skills 表时生效的开关（苍龙、五条悟、贝吉特、文字修正……）却没 erase 底表：原来就不生效（现算也读旧表），缓存跟着一致，不算新问题。
- 加减状态都会换代（不分类别），所以开战和收场挂、卸状态的时候缓存基本用不上：开战（setup）和收场的时间几乎没变（见下表）。要再快得按状态类别细分，这一单没做。

## 复量（验收 4；Mac Apple Silicon，无头 Godot，毫秒）

修复前＝同一份代码关掉开关（`--xcall=0`）。

### 战斗（`t546_battle_probe.gd`：全队 99 级、每人学 N 个被动，打敌群 2，自动 3 回合）

| 被动数 | 读最大 MP | `param_base` | `skills()` | 开一次窗口读四项 | 开战 setup | 每次行动 | 收场 | 日志摘要两态相同 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20 | 0.72 → 0.36 | 1.22 → 0.25 | 0.57 → 0.12 | 0.90 → 0.88 | 112 → 108 | 23 → 22 | 21 → 18 | 是 |
| 120 | 2.80 → 0.93 | 4.87 → 0.54 | 2.37 → 0.25 | 3.30 → 2.22 | 299 → 267 | 50 → 38 | 173 → 181 | 是 |
| 400 | 8.20 → 2.42 | 14.76 → 1.32 | 7.13 → 0.61 | 10.1 → 5.9 | 1772 → 1683 | 205 → 123 | 1187 → 1261 | 是 |

（收场 120、400 两档「变慢」在单次测量的误差内：收场全是卸状态，每卸一个都换代，缓存用不上，两态做的事一样。）

### 技能页（`t546_skill_lag_probe.gd`＝T545 探针加 `--xcall=0`；移动一格＝刷新＋下一帧，空帧约 5 ms）

| 被动数 | 旧界面（带 T545 窗口） | 天启篇皮肤（带 T545 窗口） | 旧界面、关掉 T545 窗口（只看本单） |
| --- | --- | --- | --- |
| 20 | 51 → 47 | 9 → 8 | 122 → 69 |
| 120 | 30 → 23 | 19 → 16 | 328 → 70 |
| 240 | 41 → 26 | 34 → 28 | — |
| 400 | 54 → 31 | 54 → 42 | 974 → 146 |

最右一列说明：单靠本单，不靠 T545 的窗口，400 个被动的技能页也从约 1 秒降到 0.15 秒。所以本单治的是根子，T545 的窗口在它上面再省一截。

原始数据和探针：[04_验证/T546_技能表跨调用缓存/](../../03_再刷重制_Godot/04_验证/T546_技能表跨调用缓存/)（`战斗_修复前／后.log`、`旧界面_*`、`天启篇皮肤_*`、`旧界面_无窗口_*`）。

## 验证

**R1（ff2b0450e＋bd5a8df08，补丁线见下）**

- 本机主线：`xiyou_skills_xcall` 109/109（bd5a8df08；ff2b0450e 时 108/108）；`xiyou_tianqi_team_builder` 118/118、最大内存 2.24 GB；`XIYOU_READ_VERIFY=1` 下 `xiyou_skills_xcall` 108/108、`xiyou_battle_speed` 34/34、`xiyou_xufeng_rework` 96/96；`语法检查.py` 1244 个 0 问题；`发行空壳.py check` 86 脚本 848 函数，退出 0。
- 云端选测第一次（ff2b0450e）：16 片里 14 片过；第 5 片机器断了（重跑后过）；第 8 片两次都被机器关掉（exit 143），原因是上面说的内存，已修。https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45877636506
- 云端选测第二次（bd5a8df08，基准 47a3572c2）：487 个场景、16 片全部通过；`xiyou_fabao_rework` 并行时失败、单跑通过，按偶发算（跟本单无关的法宝场景，我没深查）。https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45889314645

**R0（原交付）**

- 本机：`xiyou_skills_xcall` 81/81；`xiyou_battle_speed` 34/34（开关默认和 `XIYOU_READ_VERIFY=1` 两种都过）。
- 本机 `XIYOU_READ_VERIFY=1`（不一致当场崩）跑 46 个战斗／技能场景，全部通过（并行 4，539 秒）：xiyou_skills_xcall、skill_page、skill_mastery、tusu_ui、tianqi_secrets、ui_skin_1b、list_pager、combat、passive、passive_content、battle_state_batch、battle_enter_exit_lag、param_cache、act_stat_memo、smart_ai、smart_ai_b、heartsteel、yunshang、yunshang_wraps、alien_battle、alien_affix、tianqi_weak_affix、tianqi_weak_b1、zhenqi、zhenqi_daofa、guyu_battle、tusu_battle、xuan_battle、magic_weapon、equipment、panels、wtype、module_hooks、tianqi_skills、tianqi_phase4、otb、party_skills、power_books、raven_battle、mira_battle、formula_effects、determinism、skill_progression、rules、tianqi_elements、affix_absorb（场景名都带 `xiyou_` 前缀）。
- 探针开 `XIYOU_READ_VERIFY=1` 跑技能页四组：比对零不一致（ROW 里 `read_mismatches` 都是 0）。
- 战斗日志摘要：开关两态在 20／120／400 三档逐字相同（上表）；另在 20、120 两档连跑 5 次（关 2 次、开 3 次）摘要全部相同。
- `语法检查.py` 1244 个脚本 0 问题；`工具回归.py` 全部通过；`发行空壳.py check` 退出 0。
- 云端选测第一轮（f8bdf569b）：469 个场景失败 1 个，`xiyou_battle_speed` 的 `window_stores`。原因是这条断言查的是实现细节：读能力值时窗口里要记下 `sk0`，现在 `passive_values` 直接用跨调用缓存，窗口里就不再另记 `sk0`，读到的值不变。已把断言改成认两种存法，本机过了。https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45849769952
- 云端选测第二轮（746ad29e6，含上面改好的断言）：469 个场景、16 片全部通过：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45854321950

## 能否进西游修复补丁（patch/v0.04）

不能原样摘过去，已另做补丁线版本，分支 **`luiluu/t546-patch`**（接在 306d3ad5a 上，3 个提交）。

- 原因：补丁线上还没有 T443 的 `XTianqiSecrets`（秘籍封印），也没有 T444 的 `XTianqiGeneralBooks`，T451 的 passiveELUP 补充也没有。主线这份 diff 对 306d3ad5a 跑 `git apply --check`，在 `actor.gd` 上失败，而且 `tianqi_secrets.gd` 在那边根本不存在。
- 补丁线版：去掉缓存键里的封印表，开关位图里去掉通用书、秘籍那 3 个开关，专项里去掉封印两条。补丁线的 `XDB.rec` 改写链我对过，是主线的子集，缺的只有这几层。
- 在 scratchpad 的 clone 里验证过（generated、.godot 是从本工作树补齐的，不是按 306d3ad5a 重跑的转换产物）：语法检查 0 问题，`发行空壳.py check` 0，`xiyou_skills_xcall` 73/73，`xiyou_skill_page`、`xiyou_wtype`、`xiyou_passive`、`xiyou_tianqi_weak_affix`、`xiyou_zhenqi_daofa`、`xiyou_battle_speed` 全过。**补丁线版没跑云端。**
- 只改脚本：没有新资源，不删文件，不动存档结构和数值。推给玩家要 Kyo 点头。
- **R1 同步**（补丁线提交见「本分支提交」）：同样补了 P1-1～P1-4，`reload_table` 作废只有补丁线有的 3 个模块（天启篇技能、元素、弱者词条）；专项去掉通用书、秘籍两条重载。scratchpad clone 里（generated、.godot 照旧从本工作树补齐）：`xiyou_skills_xcall` 96/96（内存修复后 97/97），变异检查五项都红；`xiyou_tianqi_team_builder` 118/118（2.22 GB）；`XIYOU_READ_VERIFY=1` 下 `xiyou_battle_speed` 34/34、`xiyou_xufeng_rework` 71/71；语法检查通过、`发行空壳.py check` 80 脚本 775 函数，退出 0。**补丁线版照旧没跑云端**：云端选测的基准是 GitHub main 的分叉点，补丁线从 patch/v0.04 切出、跟 main 分叉很早，会选出几乎整轮、而且用的是 main 的转换产物，结果不代表补丁线；要跑得等出补丁的人按补丁线的办法跑。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/actor.gd` `XActor.SKILLS_XCALL`（`_skills_entry`、`_skills_key`） | 原版每次取技能表都整张现建（MV 引擎快，不成问题）；重制照做，每读一次能力值要重建两三遍，技能越多越卡 | 技能表跨调用记住：id 表照算，建记录这一步只在输入（键）变了或写入换代时重做；按标签取的被动值跟着记 | Kyo 11-26（T544 长线建议）；400 被动时 `param_base` 14.8 → 1.3 ms、战斗每次行动 205 → 123 ms | `XActor.SKILLS_XCALL = false` | cc（T546） | 保留 |

## 变更记录草稿

## 2026-11-26 【cc·T546·未经审查】技能表跨调用缓存（dev.待定）

- 玩家可见：学的技能多时，战斗出手、技能页翻动、各菜单读属性更快。
- `XActor` 的技能表跨调用记住：id 表照算，建记录这一步只在缓存键（存档、天启篇档、道法缩放、秘籍封印、弱者词条投影、回退开关）或写入代数变了时重做；回退开关 `XActor.SKILLS_XCALL = false`。
- 400 被动 Mac 实测：`param_base` 14.8 → 1.3 ms，战斗每次行动 205 → 123 ms，技能页移动一格 54 → 31 ms；战斗日志开关两态逐字相同；安卓实机没测。
- R1（甲档核查退回后）：缓存键补徐凤年系数、自然物攻单／双属性、发行三个开关，命中时比底表引用；天启篇模块重载数据表时作废。
- 补丁线版另在 `luiluu/t546-patch`（接 306d3ad5a，去掉补丁线没有的秘籍封印、通用书两项）。

## 交接板

- 下一步：T546 甲档换家核查（核 `_skills_key` 的输入清单是否列全）；补丁线版 `luiluu/t546-patch` 要不要进 0.04 补丁由出补丁的人定
- 用户试玩说明：技能多的存档，战斗和技能页更跟手
- 需要用户决定：无（推玩家补丁照旧等 Kyo 点头）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：云端选测不带 `XIYOU_READ_VERIFY`。动只读窗口、跨调用缓存这类代码时，最有用的就是全程比对，现在只能在本机挑场景跑。可以给 `云端选测.py run` 加一个 `--env XIYOU_READ_VERIFY=1`（工具车道）。
- 建议：开战、收场时挂卸状态，每一个都换代，缓存用不上（400 被动时开战约 1.7 秒、收场约 1.2 秒）。要再快，得按状态类别只在会改技能表的状态上换代（照 O-398 `STATE_BATCH` 的分类），归战斗性能车道，要甲档核。

## 动了的共用函数和开关

| 函数／开关 | 调用方（`git grep -nE '<式>' -- '*.gd' ':!tests'`） | 逐处结论 |
| --- | --- | --- |
| `XActor._skills_now`（改成先查缓存） | 5 处（`_skills_now`），都在 `actor.gd` 的 `skills()` 里（窗口记忆、整批跨步、窗口外三条路） | 调用方 5 处逐处结论：返回值和原来一样（浅复制、记录对象同一批），窗口记忆与整批跨步照旧包在外面 |
| `XActor.skills()` | 68 处（`[^_a-z]skills\(\)`，含敌人、战斗者各自的 `skills()`） | 调用方 68 处逐处结论：签名、返回形状不变，每次返回新数组（原来也是）；全程比对 46 个场景零不一致 |
| `XActor._passive_values_now`（改走缓存项） | 经 `passive_values(` 25 处 | 调用方 25 处逐处结论：值不变（同一批 meta 值、新数组），passiveELUP 天启篇补充照旧每次现算；子类改写了 `skills()` 的照旧走 `skills()` |
| `read_touch`、`state_touch`、`passive_touch`、`read_reset`、`batch_begin`（各加一行换代） | 35／5／2／2／5 处 | 只多一个计数器加一，原有行为不变 |
| `XTianqiSecrets.sealed_raw`、`XTianqiWeakAffix.view_sig`（新加） | 各 1 处（`_skills_key`） | 只读，不写存档 |
| `tests/xiyou_battle_speed.gd` `window_stores` 断言 | — | 见「验证」 |
| `XTianqiSkills／XTianqiElements／XTianqiGeneralBooks／XTianqiSecrets／XTianqiWeakAffix.reload_table`（R1 各加一行 `XActor.skills_touch()`） | 非测试代码 0 处（`git grep -n 'reload_table(' -- '*.gd' ':!tests'` 只有注释和 `XTianqiLine.reload_table`，不是这几个） | 只多一个计数器加一；测试里调的照旧，缓存多重建一次 |

## 截图

无（没有界面变化）。

## 本分支提交

- 见 `git log main..luiluu/t546`；补丁线版 `git log 306d3ad5a..luiluu/t546-patch`
- R1：主线 ff2b0450e、bd5a8df08；补丁线 adb5bd607、7bb0abf9d
