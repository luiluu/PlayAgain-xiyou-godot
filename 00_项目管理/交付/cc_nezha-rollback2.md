# 交付单：cc/nezha-rollback2（哪吒_12，回退支补测试 期二）

- 状态：可合并
- 执行者：cc（哪吒_12）；从 rollback1 末端 ac1e620b 切出，**须在 rollback1 之后合**。已合最新 main（3226cc85，无冲突）。
- 本期补了 9 个开关的回退支测试：O-016、O-017、O-020、O-021、O-022、O-023、O-024、O-031、O-078。`回退开关覆盖.py`：覆盖从 33 升到 42，缺口从 28 降到 19（新增缺口 0）。
- O-018 `RANGE_MAP_PREVIEW` 本期没做：它只决定挂机范围图底下画不画地图截图，headless 下测不到绘制结果。已写进豁免理由；要测，得先给它加个能查询的绘制记录，或者改用截图对照。

## 改了哪些文件

- const 改成 static var（默认值不变；rg 全工程连 tests 一起查过，全是读取）：
  - `core/hang_up.gd`：`SILENT_WHEN_IDLE`、`AUTO_SAVE_SETTING`
  - `core/hang_up_auto.gd`：`SAVE_ORDER`、`SAFE_RECOVERY`、`CONSISTENT_ORDER`（`LOOP_CAP` 仍是 const）
  - `map/hang_up_overlay.gd`：`CLEAR_SUMMARY`
  - `ui/options_scene.gd`：`KEEP_INDEX_AFTER_PAGE`
  - `ui/power_strip.gd`：`SHOW_GEAR_GAIN`
  - `ui/enemy_book.gd`：`BOOK_FIXED_NORMAL`
- 测试：`tests/xiyou_hangup.gd`、`xiyou_hangup_auto.gd`、`xiyou_notice_options.gd`、`xiyou_status_power.gd`、`xiyou_enemy_book.gd`。
- `07_开发环境/回退开关豁免.json`：删掉这 9 项，O-018 的理由改写成上面的说明。

## 各开关的回退断言

| 编号 | 开关 | 断言（依据：优化登记「原版行为」栏和原版代码） |
| --- | --- | --- |
| O-016 | `XHangUp.SILENT_WHEN_IDLE = false` | 没在挂机时，战斗结束有人阵亡，也会播一声取消音（system 2）；默认不播 |
| O-017 | `XHangUp.AUTO_SAVE_SETTING = false` | 「自动储存」关着，计时满了照样记待存；说明里的档位取插件参数 saveId（空为 1）。默认关着就不存，档位写开局存档位 |
| O-020 | `XHangUpAuto.SAVE_ORDER = false` | 排好的顺序 [1,3,2] 存档再读档、清空全局表（相当于重开游戏）后，再打开顺序页重排成 [1,2,3]，存档里 ActTemp 是空的。默认读档后还是 [1,3,2] |
| O-021 | `XHangUpAuto.SAFE_RECOVERY = false` | 阵亡角色也照吃回蓝药：10 瓶全吃光，法力不变。默认一瓶不动（已有 dead_no_mp_potions）。「不消耗的药无限循环」那半边，回退后会真的死循环，没法测 |
| O-022 | `XHangUpOverlay.CLEAR_SUMMARY = false` | 停止挂机后摘要清空了，但上一段摘要还留在叠画历史里（原版只清 (120,0,120,28)） |
| O-023 | `XHangUpAuto.CONSISTENT_ORDER = false` | 技能次数从 2 减到 1，回合表不重建，旧的「修003」还在（3 条）。默认会重建成 2 条 |
| O-024 | `XOptionsScene.KEEP_INDEX_AFTER_PAGE = false` | 从「消息提醒」子页返回后，光标回到第 0 项、列表滚回顶部（进去之前 top > 0） |
| O-031 | `XPowerStrip.SHOW_GEAR_GAIN = false` | 第三段文字是「自身 N  ·  装备战力 N」，战力条上实际画的也是这一段 |
| O-078 | `XEnemyBookPage.BOOK_FIXED_NORMAL = false` | 对同一只敌人（取参照神话例的第一只）连开 64 次，普通和神话都会出现；默认 16 次全是普通（神话的画法已有 oracle_elite 对参照） |

用循环、两种取值都测的地方，回退值写成字面量赋值（`= false`），这样 `回退开关覆盖.py` 能认出来。

## 留给车道（本期不碰）

- 同期一：battle_logic.gd 里的 O-026、O-048；map_scene.gd 里的 O-010、O-011、O-012、O-015、O-036、O-117。
- 剩下还没补、也不在别人独占文件里的：O-030（item_marks.gd）、O-042（save_scene.gd）、O-076 的四个（achievement.gd）、O-085（xstate.gd，核心存档类，派之前先确认没人在改）。O-027、O-100 在事件解释器和事件核心里，属于内容车道的范围。

## 验证

- 合最新 main 后跑了对 main 的选测，108 个场景（连 rollback1 的改动一起验），107 个一次通过。
- xiyou_hangup_auto 第一轮失败：我新写的 O-020、O-023 断言把顺序表当成 3 项，实际角色 8 还有别的技能、默认次数是 1，表有 5 项。改成按实际项数断言后单跑通过（232/232）。产品代码没动。
- 并行测试提示有几个场景用时超过上限的一半：xiyou_map186_b 373 秒，xiyou_smart_ai 四份 369～428 秒。当时本机满载，不是本期改的场景。
- `回退开关覆盖.py`：覆盖 42、缺口 19，新增缺口 0。

## 变更记录草稿

## 2026-10-31 【cc·哪吒·未经审查】回退支补测试期二：挂机、设置页、战力条、怪物图鉴 9 个开关（75% 审查 G3，dev.待定）

- 9 个优化开关补了回退支测试（见交付单表）：设成回退值，断言原版行为，再恢复默认值；依据是优化登记「原版行为」栏和原版代码。
- 挂机、设置页、战力条、怪物图鉴这 6 个文件里的 9 个开关从 const 改成 static var，默认值不变。
- `回退开关豁免.json`：覆盖 33→42，缺口 28→19；O-018 headless 测不了，豁免理由写清。
- 回退：测试是新加的段，删掉即可；static var 改回 const 不影响调用。

## 交接板

- 「下一步」：回退支补测试期三，做 O-030、O-042、O-076（四个）、O-085；map_scene.gd 那批等悟空的 O-117 合并后再派。

## 可优化

- 优化登记草稿：无。
- `xiyou_map186_b` 单场景用时 320～373 秒（rollback1、rollback2 两轮选测都提示了），超过上限 600 秒的一半，按场景拆分规则该拆。这一轮 xiyou_smart_ai 四份也到了 369～428 秒，不过当时本机满载，建议在空闲时再量一次。都不是本车道的文件，请总装另派。
- O-018 这类只影响绘制的开关，现在的测试框架在 headless 下看不到结果。以后登记这种开关时，可以顺手给它加一个能查询的绘制记录（比如 `_painted_map_shot` 布尔值），回退支才测得到。

## 本分支提交

- 见 `git log ac1e620b..cc/nezha-rollback2`
