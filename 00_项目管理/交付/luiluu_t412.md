# 交付：luiluu/t412

- 车道／工作者：漩涡三阶段 rift3（cc，Opus＋medium，P8）→ 小A 续做（Gemini 4 Neon＋high，P9）
- 状态：可合并

## 做到哪（cc 11-23 ＋ 小A 11-23 续做收尾）

1. **rift3 过场**（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/rift.gd`）：Map004 新事件 205「时空漩涡_字幕3」、206「时空漩涡_徐凤年3」、207「时空漩涡_异化怪3」，接着 rift2 的 201～204 往后排。
   条件 `RIFT3_CONDITION`：rift2 看过、rift3 没看过、且不是刚播完 rift2 的同一次进大厅（新虚拟键 `rift2@thisvisit`，不跟 `CHAIN_AFTER_RIFT1` 走）。先 `CodexWhisper.mark('rift3')` 再播，全存档只播一次。开关 `XRift.STAGE3`（默认开，关了不加 205～207、`stage()` 不到 3）。
2. **Kyo 11-23 过场设定与台词定稿**（隐世强者感受到了天地的变化，在追杀异化怪物的时候回归跟随玩家，留点四阶段小彩蛋）：
   - 演出：变暗 →「??????」一句 → 漩涡闪光 → 异化怪物（原版行走图 Monster 第 6 格，大厅异化层按备注 `<codex_rift_alien_mob>` 染幽紫，`lobby_corruption.gd` `_update_tint`）从漩涡正上方摔到 (14,22) → 白光，徐凤年（`7mobu7` 第 2 格＝角色 152）追下来落到 (14,21) → 原版斩击动画 23＋重震＋白闪，怪物淡掉 → 徐凤年三句 → 淡出往南 → 小字。不新画。
   - 台词 `XRift.RIFT3_LINES`（已过小A 文字审并落地 `e6e7d4b38`）：
     - `whisper`：`……又有东西，从那头漏过来了。`
     - `sense`：`山里躲了这些年清静，天地气机一乱，还是追着这东西出了山。`
     - `hint`（点到四阶「化形」彩蛋、不剧透）：`刚才那只，不过是染了层异色。再往后……怕是连模样都要换了。`
     - `follow`：`你身上沾着漩涡的气息，想来前头热闹还多。这一程，我跟你走。`
     - `after`：`兑换大厅里，好像又来了一个人。`
3. **whisper 键 `rift3`、`XRift.stage()==3`**：`rift3` 看过且 `STAGE2`、`STAGE3` 开着时 `stage()` 返回 3（给 T411 `xufeng_gate_met()` 读 `XConfig.whisper_seen("rift3")` 或 `XRift.stage() >= 3`）。`xconfig.gd` 的虚拟键判断改成 `XRift.is_visit_key`。
4. **三阶怪物异化不开**：`rift_alien.gd` 新开关 `XRiftAlien.STAGE3_ALIEN := false`，`XRift` 给 3 时怪物端按 2 算（西游档怪物与二阶逐值相同）；`STAGE_OVERRIDE` 不受影响。
5. **测试与兼容**：
   - 新专项 `tests/xiyou_rift3_xufeng.gd/.tscn`（53/53，台词审改后复跑通过）。
   - `tests/xiyou_rift2_canglong.gd` 的 keep 断言 205→208（单独复跑 85/85 通过）。
   - 20 个先记 `rift2` 防过场占大厅的测试（含 `xiyou_test_env.gd`、`xiyou_fest_lobby.gd`、`07_开发环境/造测试档/load_check.gd`）同步记 `rift3`。
   - 云端首轮选测（run `45143951023`）抓出 `tests/xiyou_hall_intro.gd` `_settle()` 未等新加的 EV205（rift3）放完，在 `_skip("key", 4)` 切场景时挂起过场协程导致退出报 `ERROR: 2 resources still in use at exit`；经协调批复修法 A 后在 `_settle()` 补等 `EV205` 开 A（非 `rift2@thisvisit` 时），提交 `1dedfb674`，本地实跑 67/67、0 泄漏。
6. **截图**：`00_项目管理/交付截图/luiluu_t412/rift3_fall.png`（怪物落地、徐凤年下落时白光）、`00_项目管理/交付截图/luiluu_t412/rift3_strike.png`（斩击瞬间）。
7. **云端选测**：提交 `1dedfb6749`（分支 `ci/luiluu/t412`，基准 `fd0a48deb6`），338 个场景、9 片，全部通过（最长一片 12.0 分钟）：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45148518536 。

## 还剩（小A 续做）

- [x] 台词文字审（`XRift.RIFT3_LINES`，5 句）：已审改落地 `e6e7d4b38`，消去重复字词并补齐隐世强者＋天地气机变化＋追杀异化怪＋四阶化形彩蛋＋徐凤年口吻，复跑 `xiyou_rift3_xufeng` 53/53 通过。
- [x] 单独复跑 `xiyou_rift2_canglong` 专项：85/85 通过（改断言 205→208 后实跑确认）；全套 338 场景由云端选测覆盖全部通过（run `45148518536`），本机未用并行测试。
- [x] `python3 03_再刷重制_Godot/07_开发环境/工具回归.py`（23/23 全部通过）、回退开关覆盖检查 `回退开关覆盖.py`（退出码 0，新开关 `XRift.STAGE3`、`XRiftAlien.STAGE3_ALIEN` 均已有专项回退支覆盖，无需进豁免清单）、`发行空壳.py check`（退出码 0，81 个脚本 781 个函数全齐）。
- [x] 写下面三节草稿、状态改「可合并」、提交后跑 `交付自检.py` 到 0、云端选测 `gh run watch` 前台等完并写 run 链接（https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45148518536 ）。

## 变更记录草稿

## 2026-11-23 【cc·小A·T412·未经审查】漩涡三阶段 rift3：徐凤年追杀异化怪从天而降、XRift.stage()==3、三阶怪物异化默认关（dev.待定）

- 依据：Kyo 11-23 事项 34→D262（「先做漩涡三阶段，再开放」）、事项 35（「看完二阶后下一次进大厅就播」「不再做甩出来，徐凤年从天而降」），以及 Kyo 11-23 回归设定（「隐世强者感受到了天地的变化，在追杀异化怪物的时候回归跟随玩家，可以留点关于四阶段的小彩蛋」）。
- rift3 过场（`modes/xiyou/core/rift.gd`）：Map004 新增事件 EV205「时空漩涡_字幕3」、EV206「时空漩涡_徐凤年3」、EV207「时空漩涡_异化怪3」；触发条件 `RIFT3_CONDITION` 要求 `rift2` 看过、`rift3` 未看过、且非刚播完 `rift2` 的同一次进大厅（新虚拟键 `rift2@thisvisit`，不跟 `CHAIN_AFTER_RIFT1` 走）；先 `CodexWhisper.mark('rift3')` 再播，全存档只播一次。
- 演出与台词（`XRift.RIFT3_LINES`，已过小A 文字审定稿）：变暗 → `??????` 低语 → 漩涡紫闪震屏 → 异化怪物（原版行走图 Monster 第 6 格，`XLobbyCorruption._update_tint` 按备注 `<codex_rift_alien_mob>` 染幽紫）自上方落至 (14,22) → 白光，徐凤年（`7mobu7` 第 2 格＝角色 152）追杀而下落至 (14,21) → 原版斩击动画 23＋重震＋白闪，怪物消散 → 徐凤年三句（隐世察觉天地气机变化追杀出山／点到四阶化形彩蛋不剧透／随玩家同行）→ 淡出往南 → 灰色小字。不新画美术；截图见 `00_项目管理/交付截图/luiluu_t412/rift3_fall.png`、`00_项目管理/交付截图/luiluu_t412/rift3_strike.png`。
- `XRift.stage()==3` 与虚拟键：`rift3` 看过且 `STAGE2`、`STAGE3` 开着时 `XRift.stage()` 返回 3（供 T411 徐凤年招募／号角门槛读 `XConfig.whisper_seen("rift3")` 或 `XRift.stage() >= 3`）；`XConfig.whisper_seen` 改经 `XRift.is_visit_key` 判虚拟键，`XRift.on_mark` 改为键→进图次数字典。
- 三阶怪物异化默认关（`modes/xiyou/core/rift_alien.gd`）：新增 `XRiftAlien.STAGE3_ALIEN := false`，`XRift.stage()` 返回 3 时怪物端按 2 算，西游档怪物行为与二阶逐值相同；`STAGE_OVERRIDE` 不受影响。
- 回退开关：`XRift.STAGE3 = false` 后 `clear_cache()` 不加 EV205～207、`stage()` 不到 3（二阶不变）；`XRiftAlien.STAGE3_ALIEN` 默认 `false`（设为 `true` 才开三阶蚀骨异化）。两项回退支均已由 `xiyou_rift3_xufeng` 覆盖。
- 测试与验证：新增专项 `xiyou_rift3_xufeng`（53/53）；`xiyou_rift2_canglong`（keep 断言 205→208，85/85）；20 个防过场占大厅的测试同步记 `rift3`；`xiyou_hall_intro` `_settle()` 补等 EV205 放完（67/67，0 泄漏）；`工具回归.py` 23/23、`发行空壳.py check` 退出码 0、`回退开关覆盖.py` 退出码 0；云端选测 run `45148518536` 338/338 全部通过。
- 玩家可见（小A 文字审定稿）：看过漩涡二阶段（苍龙破晓）过场后，下一次进入兑换大厅将触发漩涡三阶段过场——隐世强者徐凤年追杀异化怪物从天而降，一刀斩灭后决定随玩家同行。

## 交接板

- 下一步：T411 把 `xufeng_gate_met()` 接 `XConfig.whisper_seen("rift3")`；换家核查本单。
- 用户试玩说明：看过苍龙过场后下一次进大厅，播徐凤年从天而降斩异化怪的过场。
- 需要用户决定：三阶怪物异化（蚀骨）开不开（`XRiftAlien.STAGE3_ALIEN`，默认关）。

## 进度账

- 不涉及主表完成度变化（天启篇前置漩涡三阶段过场与接口）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/rift.gd` `XRift.STAGE3`（Map004 EV205～207、`stage()`） | 原版无漩涡三阶段 | 新增漩涡三阶段徐凤年过场与 `stage()==3` 接口，供 T411 门槛读取 | Kyo 11-23 事项 34→D262、事项 35 | `XRift.STAGE3 = false` 后 `XRift.clear_cache()`（回到二阶段） | cc／小A（T412） | 保留 |
| O-待定 | `modes/xiyou/core/rift_alien.gd` `XRiftAlien.STAGE3_ALIEN`（`stage()`） | 原版无漩涡三阶段怪物异化 | 独立控制三阶怪物异化（蚀骨）开合，默认 `false` 使西游档怪物维持二阶逐值一致 | Kyo 11-23 未拍板是否开放三阶蚀骨异化，按默认先关 | 默认 `false`；需开放三阶蚀骨异化时设 `XRiftAlien.STAGE3_ALIEN = true` | cc（T412） | 保留 |

## 可优化（流程／工具／效率）

- 建议：rift2 的三页结构可改用新的 `_whisper_pages()`（本单没动 rift2，免得改坏；归清理车道，小）。
- 建议：`tests/xiyou_star_warehouse.gd` 的 `_setup_ui()` 建议像原版夹具一样固定 `XGear.force_roll = 0.5`。防具 2「学徒斗篷」自带 6 组各 1% 无名高品质前缀（quality 8/11/13→金色 `ffd65a`），未固定随机池导致该测试有约 5.85% 的既有随机抖动（本单首轮云端 run `45143951023` 碰巧首跑与 rerun1 均撞上，本地 99/99、次轮云端 run `45148518536` 通过；归测试稳定性车道，小）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XRift.stage` | 精确 18 处（`git grep -n 'XRift\.stage(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`；同名 `stage(` 粗数 134 处） | 调用方 18 处逐处结论：`rift_alien.gd` 默认被 `STAGE3_ALIEN=false` 夹到 2；`lobby_corruption.gd` 只判 `>=2` 与 `maxStage` 记录（不影响二阶视觉）；其余均为测试断言，不会改坏 |
| `XRiftAlien.stage` | 精确 4 处（`git grep -n 'XRiftAlien\.stage(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`；类内 `stage(` 调用 2 处） | 调用方 4 处逐处结论：`STAGE_OVERRIDE > 0` 逻辑不变，默认 `STAGE3_ALIEN=false` 时对 `XRift.stage()==3` 夹回 2，所有战斗／画面／掉落调用方与二阶逐值相同 |
| `XRift.this_visit_seen`／`XRift.on_mark` | 各 1 处（`git grep -nE 'XRift\.(this_visit_seen|on_mark)\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 2 处逐处结论：仅 `xconfig.gd` 的 `whisper_seen`/`whisper_mark` 调用；改为键→进图次数字典后，`rift1@thisvisit` 与 `CHAIN_AFTER_RIFT1` 行为不变（`xiyou_rift2_canglong` 85/85 通过） |
| `XRift.keep_event` | 精确 5 处（`git grep -n 'XRift\.keep_event(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`；同名粗数 9 处） | 调用方 5 处逐处结论：仅 `map_scene.gd:467` 与专项测试调用；`STAGE3=true` 仅在 Map004 放行 EV205～207，`STAGE3=false` 或其它地图行为不变 |
| `XRift.patch_map` | 精确 1 处（`git grep -n 'XRift\.patch_map(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`；同名粗数 9 处） | 调用方 1 处逐处结论：仅 `xdb.gd:214` 调用；Map004 仅在 `STAGE3=true` 时追加 EV205～207，EV75～77、201～204 不变，`fest_lobby.gd` 只看 78～81 格不受影响 |
| `XConfig.whisper_seen` | 精确 20 处（`git grep -n 'XConfig\.whisper_seen(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`） | 调用方 20 处逐处结论：仅把虚拟键判断由硬编码 `THIS_VISIT_KEY` 改为 `XRift.is_visit_key(key)`（多认 `rift2@thisvisit`），其余已存键照旧读 `_values.codexWhisperSeen`，既有调用方（`mv_script.gd`、`imported_balance.gd`、`lobby_corruption.gd` 及测试）不受影响 |
| `XLobbyCorruption._update_tint` | 仅本类每帧 1 处调用 | 调用方 1 处逐处结论：多染备注为 `<codex_rift_alien_mob>` 的过场事件，其它事件与非异化大厅不受影响 |
| `XRift.STAGE3`／`XRiftAlien.STAGE3_ALIEN`（新） | 本单新增开关 | 默认 `true`／`false`，均已由 `xiyou_rift3_xufeng` 覆盖开关正反两态并还原 |

## 本分支提交

- `d4f688be2` WIP: T412 漩涡三阶段 rift3：徐凤年追杀异化怪从天而降（Map004 EV205～207）、stage()==3、三阶怪物异化默认关；交付单写明接续（交小A）
- `e6e7d4b38` T412 审改漩涡三阶段徐凤年过场台词 XRift.RIFT3_LINES
- `1dedfb674` T412 修 xiyou_hall_intro._settle 等 EV205（rift3）放完再切场景，消除退出协程泄露
- `39f29b452` T412 交付单收尾：变更记录草稿、优化登记草稿、调用方结论、云端选测通过 45148518536
- 本提交：交付单变更记录草稿截图路径改为仓内相对路径（交付自检 0）
