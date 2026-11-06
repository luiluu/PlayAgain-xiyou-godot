# 交付：cc/wukong-newsrc8

- 车道／工作者：DB 装备与养成续（换源 v0.62.12；cc，悟空）
- 状态：可合并
- 基线：从 `cc/newsrc-switch` 58340027 切出；工作树 `.claude/worktrees/elated-davinci-bc9b43`。`generated/` 取集成分支工作树（recursing-shamir-4cd3d8）那份，再 `xiyou_export.py --app …/冻结正式源/v0.62.12/app.nw` 重出（没有文件变）。跑测试设 `XIYOU_APP=…/v0.62.12/app.nw`、`XIYOU_SKIP_GENERATED_CHECK=1`。
- 本分支的 `xiyou_export.py` 仍不认 `XIYOU_APP`（tools80 在 main 上），重出要显式传 `--app`。

## 变更记录草稿

## 2026-11-06 【cc·悟空·未经审查】换源集成：专武前缀旧武器读档还原、心钢按回合冷却、SvPngFd 先清再解析（dev.待定）

- ① 专武前缀旧武器读档还原（跟到 v0.62.12 `installIntegratedV029Runtime.js` `U.revertExclusiveAffixes`，v0.57，extractSaveContents 包装）：`XGear.revert_exclusive_affixes`，`XState.from_dict` 读完仓库后调用。v0.37 前掉落、抽到了专武词缀的武器（如「卍解-斩月练习剑」）转回普通装备：原版拿存档里的模板比，重制不存模板，按 `affixIds` 用现在的数据重拼模板 t（底装备＋各词缀＋备注参数）；特效、备注、说明换成底装备那段＋实例在 t 之后追加的，属性＝底＋实例−t（底值不为负的夹到 0），价格同理；名字去掉专武前缀（最长的专武名，找不到按底装备名切）。原版把整份模板换掉，同一件上别的词缀也一起没了、名字里的后缀字留着，照搬。备注解析出的 meta 取底装备的、留实例上不是备注来的键；yep、套装只换回被词缀改过的项。对不上的不动、记进 `last_affix_revert.skipped`。**只跑一次**：改前字段整份存进 `_affixRevert`（随存档），有它的不再处理。只管武器（原版只扫 `_independentWeapons`），背包、身上、仓库都扫。开关同 `XGear.EXCLUSIVE_V056`（**O-待定·专武不当词缀与读档还原**，false＝读档不还原）。
  - 属性浮动的口径：原版掉落掷两次浮动（makeItem 给模板一次、gainItem 登记实例再一次），还原丢掉模板那次、留实例那次；重制只掷一次，t 用不带浮动的模板，所以留下的是这一次（幅度同原版：专武词缀的 Random Variance），强化加的照留。
  - 参照：`equipment_probe.cjs` 加 `affixRevert` 三例（临时放开 isValidItem 造出旧装备，照掉落 gainItem 进背包、可选强化一次，调 revertExclusiveAffixes 量前后；重复执行不变）。为两边可比，前两个随机数取 0（抽中专武 67「卍解-斩月」）、其余 0.5（浮动为 0）。`xiyou_equipment` 照 v0.28 造出同一件，存档往返后比名字、属性、特效、价格、说明、品质，另比开关关着不动、备份字段、再读一次不变。
- ② 心之钢巨人吞噬按回合冷却（跟到 v0.62.12 `installNativeHeartsteelRuntime.js`，v0.35）：第 2 回合可用，施放后冷却 2 回合（`_ready_turn`＝施放回合＋2，剩余＝就绪回合−max(1, 回合数)，开战就绪回合 2），行动结束不再减蓄力。回合数从本场战斗取（`_logic_ref` 弱引用，不让静态变量留住战斗对象）。说明卡冷却行同步成「冷却：巨人吞噬第2回合可用；冷却2回合」。开关 `XHeartsteel.TURN_CD_V035`（**O-待定·心钢按回合冷却**；false＝v0.28 按行动）。
  - `heartsteel_probe.cjs` 两版都能量（有 `H.round` 就按回合设就绪回合、读 `H.remaining`，否则照旧读 `_codexHeartsteelWait`；v0.28 重跑与旧夹具逐字节相同）。夹具 `heartsteel_oracle.json` 换成 v0.62.12 量的，旧的改名 `heartsteel_oracle_v028.json`；`xiyou_heartsteel` 开关开着比新夹具全部例，关掉再比旧夹具的心钢几例（heart.*、suppress.*，标签前缀 v028.）。
- ③ SvPngFd 先清再解析（跟到 v0.62.12 dsPassiveSkill v0.51：refreshPassiveCache 先把 SvPngFd 复位成 1 再解析，状态／装备／技能变了置脏、下一次 refresh 重建，Sprite_Actor.updateFrame 每帧读缓存）：战斗图 `XBattlerSprite._process` 每帧比装备／状态／技能签名（`XSvPngFd.signature`），变了重算倍数、按比例改身体缩放。开关 `XSvPngFd.REFRESH_V051`（**O-待定·SvPngFd 先清再解析**；false＝回到 v0.28 开战算一次）。参照里 `stateMidBattle` 加状态后 refresh 变 2，跟上；`unequipMidBattle` 只 setObject 不 refresh 所以没变，重制换装总会刷新，不比这一条。dsPassiveSkill v0.51 同一处还复位了 harmRe 等别的字段，重制的被动缓存本来每次整份重建，没有累计问题，没动。
- ①补 gear_search 词条来源（总装归到本单）：原版 `getBaseItem` 对随机词缀装备返回 DreamX 生成时的模板（v0.62.12 实测：布腰带实例 baseItemId 指向模板、模板备注带词缀），所以词缀那几行算「固定」。重制原来拿底装备比，词缀行成了「随机 / 附加」。抽出 `XGear.affix_template`（还原和检索共用），`XGearQuery.record` 改用它。`xiyou_gear_search` 加 `affix_lines_fixed`、`added_line_random`（旧代码挂前一条）。
  - **剩的 3 项（sort_power、row_small_power、detail_rows）不是词缀归类**：夹具是 v0.28 手量的，测试把 v0.28「队员死霸装」的备注叠到 v0.62.12 防具 130 上，新源这件闪避、爆伤、passiveHarmRi 从 5 改成 50（导入平衡 revision 2），行对不上底装备、战力 1410 变 2400。要在新源重量 gear_search 夹具（手取、没无头驱动，归界面）。
- 优化登记加三行 O-待定（上面三个开关；专武那行把 newsrc7 的「专武不当词缀」一并写进去，两项同一个开关）。

## 结果（本机，新源）

| 场景 | 前 | 后 |
|---|---|---|
| equipment | （没单量） | 1249/1250（新增 affix_revert 各条全过；只挂 data_identity，见下） |
| heartsteel | 新夹具下按行动的口径对不上 | 676/676（新夹具全部例＋v028 心钢例） |
| growth_forge | 挂 forge.0 心钢 6 项（界面 CV 转来） | 544/544 |
| growth_help | 挂 | 仍挂 9 条：说明卡第 13～15 行排法（「mod特效」行的位置），心钢、狂妄都有，是说明卡 v0.43 版式，归界面（LAYOUT_V043）；本单改的冷却行已对上 |
| svpngfd | 挂（stateMidBattle 新源是 2） | 33/33 |
| stunned_turn | 59/59 | 59/59 |

- `equipment.data_identity`：参照 `sourceIdentity.inputs` 里没有 `data/PlayerChangelog/v0.37.json` 等 26 个，产物清单里有；集成分支工作树那份参照同样少这 26 个，本分支没碰，不是新挂的。

## 验证

- 语法检查 0 问题；工具回归只挂「探针登记检查」（death_admission 没关五乘区，集成分支原样就有，newsrc7 交付时同样）；回退开关覆盖：本单三个开关测试里两头都有字面量赋值，不在缺口里。
- `事件空绿扫描.py --check` 通过（空绿 96 例均在基线内）。
- 云端选测（提交 00dbbef9，基准 b5449f06，418 个场景，[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42219366793)）：103 个挂。本单动过的 heartsteel 676、growth_forge 544、svpngfd、stunned_turn 全过；equipment 1249/1250（data_identity）、growth_help 23/32（v0.43 版式）、gear_search 55/58（夹具版本，见上）同本机。xiyou_rules 整段 70 个是 source_identity（等哪吒 CY）；其余在集成分支失败表里的同数或更好（actor_book、enemy_book、power、zhenqi、hangup_auto、param_states、state_effects、state_effects_tp、raven_reflect、help_card、interp_review、item_marks、event_compare、map132_shop、script_census 30/31、status_power_panel）。
  - 表外的（这次选测范围比 newsrc7 大，都是没进上回选测的）：party、save_events、transfer、item_bag、casino_batch、skill_menu_events、empress_draw 的「MVInterpreter._host_command get_tree on freed」、floor_run 系列、hangup、pets、screen_fx、floor_reach041 等。抽了 party、save_events、transfer、hangup、pets 五个本机对比：本分支和 58340027 原代码结果、SCRIPT ERROR 数逐个相同，不是本单引入的；地图解释器那批归地图事件。
  - 云端那次在 gear_search 补丁之前；补丁后本机跑了 gear_search 57/60、equipment 1249/1250。

## 交接板

- 下一步：gear_search 夹具在新源重量（界面）；说明卡 v0.43 版式（growth_help 剩的 9 条）归界面；心钢技能说明卡（原版 `H.skillHelpView`：已就绪／冷却还需 n 回合、第 2 回合起可用）重制本来没有，没做。
- 需要用户决定：三个 O-待定开关的默认值（都按「跟原版新行为」开着）。
- 用户试玩说明：无（集成分支）。

## 进度账

- 无变化。

## 可回退

- `XGear.EXCLUSIVE_V056`、`XHeartsteel.TURN_CD_V035`、`XSvPngFd.REFRESH_V051`：static var，测试里两头都有字面量赋值。

## 可优化（流程／工具／效率）

- 建议：参照 `equipment.json` 的 `sourceIdentity` 少 PlayerChangelog 子目录 26 个文件，`xiyou_equipment.data_identity` 因此一直挂；该归工具车道看 source_identity.cjs 与 xiyou_export 的清单口径哪边该改。

## 合并须知

- 本单改了 `equipment_probe.cjs`（加 affixRevert）和 `heartsteel_probe.cjs`。`generated/oracle/equipment.json` 是本树按 v0.62.12 单跑探针后手拷进去的，总装合并后同步要重跑 equipment_probe（新参照才有 affixRevert，否则 `affix_revert_reference_present` 挂）。心钢夹具在 tests/fixtures，随提交。

## 待交叉核查

- `gear.gd`（revert_exclusive_affixes／_revert_one／_affix_prefix／affix_template）、`gear_query.gd`（record 的底）、`xstate.gd`（from_dict 一行）、`heartsteel.gd`（战斗核心类，请甲档细核）、`growth_help.gd`、`sv_png_fd.gd`、`battler_sprite.gd`（refresh_fd）；测试 `xiyou_equipment`、`xiyou_gear_search`、`xiyou_heartsteel`、`xiyou_svpngfd`；探针 `equipment_probe.cjs`、`heartsteel_probe.cjs`；夹具 `heartsteel_oracle.json`／`heartsteel_oracle_v028.json`。

## 本分支提交

- `git log 58340027..cc/wukong-newsrc8`
