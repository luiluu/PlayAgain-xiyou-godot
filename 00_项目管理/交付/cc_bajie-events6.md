# 交付：cc/bajie-events6

- 车道／工作者：A 内容·事件／八戒（cc，派单第一批 S）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·八戒·未经审查】渡鸦 61 级 MP 差异查清（战斗中升级按新上限回满，可回退）；原版语法错误脚本认作无操作；事件对照变体清跨存档变量（dev.待定）

- **渡鸦 61 级以上 mmp 1193／1208（events5c 遗留、审查 43 遗留）查清：不是封顶。** 探针量原版 167 渡鸦 rank 3／5、60～99 级：地图上 mmp 就是成长表（60 级 1193、61 级 1208、65 级 1271、70 级 1348），paramMax 99999999，无特性。差异只出在**战斗中升级**：`krz_state_re` 的 `Game_Actor.param` 在 `$gameParty.inBattle()` 时走 `_ParamCache2`，`levelUp` 不标 `need_refresh`，`Olivia_AntiPlayerStress.levelUpRecover` 读到的 mhp／mmp 还是升级前的值，于是 MP 只回到旧上限 1193（59→60 级同样回到 1177）。地图上升级（升级药、事件）原版就回到新上限。玩家可见：胜利结算升级后 HP／MP 差一级成长没回满。
  - 重制保持「按新上限回满」，登记 O-待定（`XActor.FIX_BATTLE_LEVELUP_MAX = false` 回到原版：战斗中升级回到升级前的上限）。`actor.gd` `_level_up` 只多一行取旧上限、`_level_up_recover(stale)` 按参数选。
  - `xiyou_raven_battle` residue.sync 拆成 `_residue_sync`：默认比「回满＝新上限」，回退支（字面量赋值 false）连 MP 也与参照逐项比（1193、571 都对上）；myth 一步加「回满」断言。反向验证：回退支不取旧上限时 `residue.sync.original.0/1.state` 两项红。
  - 遗留（不在本期）：重制角色在战斗中仍每次重算能力值（krz 缓存只对敌人做了，`battler.gd` 注释已写），战斗中换装、升级后同一场里读 mmp 的技能（如渡鸦 10122 mmp×39）原版用旧值、重制用新值；要不要整套给角色做缓存另派。
- 审查 43 P3-3：`_level_up_recover` 注释写明不调 `refresh_passive`（events5c 交付单「先 refresh_passive 再回满」与代码不符，已订正措辞，不改行为）。
- **原版语法错误的整段脚本认作无操作**（events6，`mv_script.gd` `_js_syntax_error`）：YEP_CoreEngine `command355` 把 eval 包在 try 里，出错只 displayError、整段不执行。覆盖 `$.toaster` 少收尾引号（大厅难度开关 Map004 EV062、萨麦尔格祝福 Map145 EV005、传承强化上限 Map195 EV023）、少 `}`（中级熟练度 CE859／860 的「通过努力自学」一族）、整段是备注 `<passivePBST0:1000>`（CE513）。普查已知清单 A 类 44 条全删（101 → 57）。
- **读 null 角色名的提示按原版中止整段**：`$.toaster({ message : ''+$gameActors.actor($gameVariables.value(N)).name()+…})` 角色不存在时原版抛错、不提示、同段后面的语句也不执行；重制原来不提示但记成「认不出」，现在 `_toaster_text` 标 `toaster_threw`，`_statements` 照原版停在这句。心法 CE1003～1018、鲲拳 CE1160～1185、学习莫等闲 CE623～648 等 95 例。
- 对照例：地图事件对照 6692 例 6691 一致（唯一不一致仍是登记的 m4e73p0），**102 例不再有跳过**（上面两族），跳过基线 148 例 424 条 → 48 例 322 条（`--update-baseline` 重写）。
- 事件对照变体段每个变体前都清跨存档变量存储（accept1 可优化）：参照 `event_state_probe` 只在第一例真开局、之后换回开局快照，前一例设的跨存档变量带不进下一例；之前 Godot 只在第一个变体前清。加回 `m158e1p1#a2`（开关 2483、变量 1475＝1），整批一致；反向验证：改回只清一次时 `m158e1p1#a2` 红（变量 1476 原版 1、Godot 空）。空绿基线 1127 → 1124（m158e1p1 与另两例 ce2487、m17e4p0 已补上）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 战斗中升级回满（`core/actor.gd` `_level_up`／`_level_up_recover`） | 战斗中（含胜利结算）升级，krz_state_re 能力值缓存还是升级前的值，Olivia 回满只回到旧上限，战后 HP／MP 差一级成长 | 按新上限回满 | 升级回满本意是回满；差值只是缓存时序副作用 | `XActor.FIX_BATTLE_LEVELUP_MAX = false` | cc（八戒） | 待用户决定 |

## 交接板

- 下一步：渡鸦 61 级 mmp 遗留可销；「角色战斗中能力值缓存」（krz `_ParamCache2` 对角色）未做，要不要整套做由总装定（影响面：战斗中升级、换装后同场读能力值）。
- 用户试玩说明：战斗胜利升级后 HP／MP 照新上限回满（原版差一点，O-待定 可回退）；玩家看不到别的变化（语法错误脚本原版本来就不执行）。
- 需要用户决定：O-待定（战斗中升级回满）保留还是照原版。

## 进度账

- 无（事件对照口径收紧，不改完成度）

## 可优化（流程／工具／效率）

- 建议：`xiyou_script_census` 的 F 类（27 条，静态找不到调用）可以做一个「从数据库全量反查调用方」的小工具（技能／物品效果 44、敌群页、插件参数里的公共事件号），确认真不可达后标成「不可达」单列，普查就只剩 B 类手机端／云存档；归 A 内容车道，预计半天。
- 建议：事件对照的跳过基线现在只认「跳过」，没有区分「原版也会报错」；本期把两族报错写法做成无操作，之后再有同类（原版 YEP SCRIPT CALL ERROR）可以在 `_js_syntax_error` 加一行。

## 验证

- 专项：`xiyou_raven_battle`、`xiyou_event_compare`、`xiyou_script_census` 本机通过；`语法检查.py`、`工具回归.py` 通过。
- 选测：`选测.py main --list` 231 个场景（actor.gd 归战斗核心），走 `云端选测.py`：提交 1ec3d4bcd1 231 个场景 7 片全部通过（运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41996415802）。没跑全量 `检查.sh`（车道规则）。

## 待交叉核查

- 核心文件 `actor.gd`：`_level_up` 取旧上限的时机（`_lv += 1` 之前、在战斗里才取，用 `XBinding.in_battle()` 判战斗）；默认支行为与 events5c 一致。
- `mv_script.gd`：`_js_syntax_error` 三条正则只认整段；`toaster_threw` 时 `break` 停整段（原版 eval 抛错）。
- 跳过基线、普查清单批量删条目是工具重写的，可抽查。

## 本分支提交

- 891e0507 渡鸦 61 级 mmp 查清；战斗中升级按新上限回满（O-待定）；订正注释（P3-3）
- a6753c06 事件对照变体每例前清跨存档变量存储；加回 m158e1p1#a2
- 46223e88 原版语法错误脚本、读 null 角色名提示认作无操作；跳过基线 102 例、普查 A 类 44 条
- 1ec3d4bc 合并 main（只有文档）
