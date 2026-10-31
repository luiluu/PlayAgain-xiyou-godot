# 交付单：cc/nezha-tools26（哪吒_12，工具车道）

- 状态：可合并
- 执行者：cc（哪吒_12）；自 tools25 末端 7abd91f9 切，**须在 tools23、tools24、tools25 之后合**。没合 main（main 还在合 bailong-garou2）。只改 `07_开发环境/`：新增 `回退开关覆盖.py`、`回退开关豁免.json`、`测试回退开关覆盖.py`；改 `检查.sh`（接线两行）、`测试选测.py`（检查替身补新脚本、只改文档时的调用名单加一项）。没碰 Godot 工程，没跑 Godot。
- 验证：`测试回退开关覆盖.py` 10/10；`测试选测.py` 58/58；`zsh -n 检查.sh` 通过；真实工程扫一遍 0.4 秒。

## 变更记录草稿

## 2026-10-31 【cc·哪吒·未经审查】回退开关覆盖检查：优化开关的回退支没人测时提示（75% 审查 G3，dev.待定）

- **起因**（75% 审查 G3）：O-101/102/103/107/117 五个优化开关的回退支没有任何测试碰过。总装把补测试派给对应车道，这里做的是防止以后再漏的守卫。
- **做法**：`07_开发环境/回退开关覆盖.py` 读优化登记里状态是「保留／待用户决定／待用户确认／已做」的行，从「恢复方法」列解析开关名和回退值。认得三种写法：`X.NAME = 值`／`NAME := 值`、`` `X.NAME` 设 值 ``、`` `X.A`、`B` 分别设 值 ``。按 class_name 找到声明在哪个文件、是 const 还是 static var，再在 `tests/*.gd` 里找把它赋成回退值的语句（`NAME = 值`，或 `.set("NAME", 值)`；比较和注释不算，赋成别的值也不算）。结果分四类：覆盖、缺口（const 的另注「测试改不了，要先改成 static var」）、人工确认（只见到 `NAME = flag` 这种非字面量赋值）、解析不了（提到了全大写或 `o_` 开头的名字，但认不出回退值，或者找不到声明、有多处声明；这类不猜）。
- **接线**：`检查.sh` 在「文档与登记」段后面跑它，`|| true`，只警告不挡。单元测试放在 `want tools` 段。
- **豁免**：`回退开关豁免.json` 收了现在已知的 47 项（37 个缺口、8 个人工确认、2 行解析不了），检查只报清单外新出现的项。豁免项补上测试后，检查会提示「可从豁免删掉」。新缺口在任何地方都只警告，不挡（单元测试里读真实工程那条只核能跑通、认得出 G3 五项）。
- **回退**：`回退开关豁免.json` 的 `enabled` 改成 false，或设环境变量 `XIYOU_ROLLBACK_CHECK=0`；要彻底撤，就删 `检查.sh` 里那两行。
- 当前盘点：一共 69 个开关，测试覆盖回退值 24 个，缺口 37 个（其中 31 个是 const），人工确认 8 个，解析不了 2 行。

## 当前缺口清单（给总装派活）

**G3 那五个**：O-101、O-102、O-103 是 static var，可以直接在测试里设回退值；**O-107 `POISON_HELP_NEAR`、O-117 `SAFE_AIRSHIP_MENU` 是 const**，补测试的车道得先把它们改成 `static var`，否则测试改不了。

static var、可以直接补测试的：

| 编号 | 开关 | 回退值 | 文件 |
| --- | --- | --- | --- |
| O-101 | XPetCapture.SHOW_REFRESH_TEXT | false | core/pet_capture.gd |
| O-102 | XPetCapture.FLEE_ALIVE_ONLY | false | core/pet_capture.gd |
| O-103 | XPets.BOOK_FIX_372 | false | core/pets.gd |
| O-122 | MVTilemap.open_cells_fix | {} | map/mv_tilemap.gd（**其实已间接覆盖**：xiyou_floor_reach079 把 `map.lower.open_cells` 清空，验证了原版牢房走不通；豁免理由里写了） |

const、要先改成 static var 才能测的（31 个；路径前缀都是 `modes/xiyou/`）：

| 编号 | 开关 | 回退值 | 文件 |
| --- | --- | --- | --- |
| O-007 | XHelpCard.MIN_FONT | 0 | ui/help_card.gd |
| O-008 | XHelpCard.PLACE_NEAR | false | ui/help_card.gd |
| O-010 | XMapScene.NATIVE_PROMPT | true | map/map_scene.gd |
| O-011 | XMapScene.SAFE_HUD_ACTIONS | false | map/map_scene.gd |
| O-012 | XMapScene.SAFE_TRANSFER_BUTTON | false | map/map_scene.gd |
| O-013 | XMapTransfer.PREVIEW_FIXED_NORMAL | false | core/map_transfer.gd |
| O-014 | XMapTransfer.REQUIRE_UNLOCK | false | core/map_transfer.gd |
| O-015 | XMapScene.SAFE_HANG_UP | false | map/map_scene.gd |
| O-016 | XHangUp.SILENT_WHEN_IDLE | false | core/hang_up.gd |
| O-017 | XHangUp.AUTO_SAVE_SETTING | false | core/hang_up.gd |
| O-018 | XHangUpOptionsScene.RANGE_MAP_PREVIEW | false | ui/hang_up_options.gd |
| O-020 | XHangUpAuto.SAVE_ORDER | false | core/hang_up_auto.gd |
| O-021 | XHangUpAuto.SAFE_RECOVERY | false | core/hang_up_auto.gd |
| O-022 | XHangUpOverlay.CLEAR_SUMMARY | false | map/hang_up_overlay.gd |
| O-023 | XHangUpAuto.CONSISTENT_ORDER | false | core/hang_up_auto.gd |
| O-024 | XOptionsScene.KEEP_INDEX_AFTER_PAGE | false | ui/options_scene.gd |
| O-026 | XBattleLogic.ESTABLISH_TRUE_POPUP | false | battle/battle_logic.gd |
| O-027 | MVInterpreter.TRANSFER_FIX | {} | map/mv_interpreter.gd |
| O-030 | XItemMarks.LIST_ONLY_NAMES | false | core/item_marks.gd |
| O-031 | XPowerStrip.SHOW_GEAR_GAIN | false | ui/power_strip.gd |
| O-036 | XMapScene.RERUN_AFTER_PAGE | {} | map/map_scene.gd |
| O-042 | XSaveScene.REAL_FILE_SIZE | false | ui/save_scene.gd |
| O-048 | XBattleLogic.SUBSTITUTE_NEEDS_MOVE | false | battle/battle_logic.gd |
| O-076 | XAchievement.GAIN_ONLY／BEFORE_REDIRECT／SAVE_NOW／FLOOR12_FIX | false | core/achievement.gd |
| O-078 | XEnemyBookPage.BOOK_FIXED_NORMAL | false | ui/enemy_book.gd |
| O-080 | XPets.SYNTH_CLAMP_SKILLS | false | core/pets.gd |
| O-085 | XState.GOLD_FLOOR_ZERO | false | core/xstate.gd |
| O-100 | XMVEventCore.ACTOR_IMAGE_FIX | {} | core/mv_event_core.gd |
| O-107 | XBattleScene.POISON_HELP_NEAR | false | battle/battle_scene.gd |
| O-117 | XMapScene.SAFE_AIRSHIP_MENU | false | map/map_scene.gd |

人工确认的 8 个我逐个看过，都确实测了回退值，已写进豁免：O-095 `XPartySkills.EXACT`（`_scenario(c, false)`）、O-105 `SINGLE_DEFEAT_COUNT`（`_defeat_count(false)`）、O-112 `SELECT_ALL_HIGHLIGHT`、O-121 `o_projection`（都是 `for on in [true, false]`）、O-123 `DEBUFF_FIX`（`_act(c, false)`）、O-124／O-126 `o_save_now`／`o_alien_reset`（`_probe(probe, false)`）、O-128 `o_reserved_no_dup`（`for orig in [false, true]`）。

解析不了的 2 行：O-062（恢复方法是「`TRANSFER_FIX` 删一条」，不是开关回退值）、O-085（还提到了下限常量 `GOLD_MIN_ORIGINAL`；开关 `GOLD_FLOOR_ZERO` 本身认出来了）。登记表其余行写的是「改函数／无开关」，本来就没有开关可测，不算在内。

## 交接板

- 「需要用户决定」不用加。「下一步」可加一条：31 个 const 开关改成 static var 再补回退支测试（可以按文件分批派，map_scene.gd 一个文件就占 6 个）。

## 可优化

- 优化登记草稿：无。
- 建议：以后登记新开关时，「恢复方法」统一写成 `` `X.NAME = 值` ``，再顺手在测试里设一次回退值。本检查会把没写测试的新开关报出来。等现有缺口补得差不多了，可以考虑改成挡（`--strict`）。

## 本分支提交

- 842bb7ea 工具：回退开关覆盖检查，接进检查.sh 只警告，已知缺口进豁免清单
