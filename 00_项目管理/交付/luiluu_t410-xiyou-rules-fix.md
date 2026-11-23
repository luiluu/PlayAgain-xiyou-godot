# 交付：luiluu/t410-xiyou-rules-fix

- 车道／工作者：T410 西游档规则修／小o（sol＋high，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-23 【co·T410·未经审查】西游档至臻词条、乌鸦图纸、甚尔选招和陈塘关送礼（dev.待定）

- 依据 D261 与 T408 #1、#2、#8、#10、#14。开工基准 `fd0a48deb` 与当时的 `github/main` 一致，近期提交无同题重复。
- 冻结配置中有 10 款至臻武器的随机候选全被专武排除。西游档装备入包时统一为候选全被过滤的至臻底材补同库合法 Mod 特效，沿用原词条行和掷出机会。自然掉落、宝图及王者副本宝箱都经由该入口。协调答复选 A，深渊商人维持现有底材池与档位指定特效，商人底材池目前没有至臻。
- 兑换大厅两张图纸及学会提示按各自产物改为五眼乌鸦、七眼乌鸦。独立的究极九眼图纸沿用原文。
- 甚尔成功切换后在本场记住离开的咒具形态。智能选招只有在回切扣除行动成本后的估值高出当前最佳直接攻击 25% 时才放行回切。下一次成功切换更新记录，开战与复活回游云时清空记录。手动与挂机顺序表继续使用原切换条件。
- 陈塘关首领未败时，成功交付活力水后先执行原分支的扣道具、设变量、移除主席，再同图传送到李静南侧一格并面向李静。首领战仍由玩家和李静交互开始。
- 玩家可见：掉落、挖宝与王者副本宝箱得到的至臻装备可以带随机词条。乌鸦图纸与制作产物同名。智能挂机减少甚尔反复换咒具。陈塘关送活力水后直达李静面前。
- 初交验证：本机 18/18 个专项通过。首轮云端 751/754，三个原版对照差异修正后，增量云端 17/17 通过。
- r1 返修验证：本机 8/8 个专项、云端 773/773 个场景通过。

## 交接板

- 小A 已通过图纸文字审。下一步请总装按西游档路线收件，并安排 r1 返修复核。
- 用户试玩可检查兑换大厅两张乌鸦图纸、甚尔智能挂机和陈塘关送礼。建议在测试档验证。
- 需要用户决定：无。

## 进度账

- 西游档现有流程修正。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/gear.gd:98` `XGear.PRESTIGE_DROP_AFFIX` | 部分至臻武器的候选全是已排除的专武 | 西游档装备入包用同库合法 Mod 特效补至臻空候选，沿用原词条行概率 | D261 允许至臻装备获得随机词条 | `XGear.PRESTIGE_DROP_AFFIX = false` | co（T410） | 保留 |
| O-待定-2 | `modes/xiyou/core/xdb.gd:9` `XDB.CROW_BLUEPRINT_NAMES` | 两张图纸与提示分别写六眼、九眼 | 西游档按产物同步改为五眼、七眼 | D261 让图纸名和产物一致 | `XDB.CROW_BLUEPRINT_NAMES = false` | co（T410） | 保留 |
| O-待定-3 | `modes/xiyou/battle/smart_ai.gd:109` `XSmartAI.TOJI_SWITCH_HYSTERESIS` | 每次智能选招重新估值，允许直接切回 | 西游档回切须达到更高的估值门槛 | D261 改进甚尔智能挂机 | `XSmartAI.TOJI_SWITCH_HYSTERESIS = false` | co（T410） | 保留 |
| O-待定-4 | `modes/xiyou/map/mv_interpreter.gd:5` `MVInterpreter.CHENTANG_GIFT_TRANSFER` | 成功送礼后从主席处步行到首领 | 西游档送礼完成后传到李静南侧 | T408 #10、D261 简化交互 | `MVInterpreter.CHENTANG_GIFT_TRANSFER = false` | co（T410） | 保留 |

## 可优化（流程／工具／效率）

- 无。

## 动了的共用函数和开关

| 函数／开关 | 自检调用处粗数（含同名函数） | 调用处结论 |
| --- | --- | --- |
| `XState.gain_gear` | 166 处调用（`git grep -n 'gain_gear(' -- '*.gd'` 共 167 行，含定义） | 西游档新增装备统一由 `create_prestige_drop` 生成。由入包入口按档案分流，事件指令 127/128、战斗和挖宝无需单独传补候选标记。天启篇仍按来源键生成，装备登记、入包和提示沿用原出口。 |
| `XGear.create` | 173 处（`git grep -n 'XGear.create(' -- '*.gd'`） | 直接创建按原底材的词条行掷骰。补候选由西游档入包调用的专用工厂负责。 |
| `XGear.create_prestige_drop` | 1 处生产调用、1 处测试调用 | 工厂自己校验回退开关。至臻原候选全部被过滤时才补合法候选。普通底材与关闭开关时按原词条行掷骰。 |
| `XGear.roll_item` | 6 处（`git grep -n 'roll_item(' -- '*.gd'`） | `create_prestige_drop` 在补候选时传替换行，其余使用实例模板的原行。深渊商人、云裳订单、心钢测试和普通创建继续使用原参数。 |
| `XBattleLogic.gain_drops` | 12 处（`git grep -n 'gain_drops(' -- '*.gd'`） | 生产调用来自倒下即发和战后结算，两条沿用同一装备入口。天启篇通用奖励仍走天启篇装备生成。物品、掉落快照、来源键、测试加速照原流程。 |
| `XTreasureMap._dig` | 2 处（`git grep -n '_dig(' -- '*/core/treasure_map.gd'`） | 两个挖宝入口的武器、防具发奖均走 `gain_gear`，扣图、宝点记录、物品和事件奖照原流程。 |
| `XDB.rec` | 2534 处（`git grep -nE '[^[:alnum:]_]rec[[:space:]]*\(' -- '*.gd'`） | 商店与背包读取两张图纸，地图事件读取对应公共事件。补丁只返回这四条西游记录的副本，原缓存与其它记录仍照原路径取值。 |
| `XToji.start_battle`、`XToji.finish` | 63、284 处。生产调用各 1 处（`git grep -nE 'XToji\.(start_battle\|finish)\(' -- '*.gd'`） | 战斗开场清本场记录，行动结束确认切换成功才取离开的形态。原切换仍由 `set_shape` 完成。 |
| `XToji.end_battle` | 1 处实际调用（`XBattleLogic.end_battle`） | 战斗结束清形态与本场战斗的弱引用。 |
| `XToji.revived` | 1 处生产调用（`XActor.remove_state`） | 实际复活并成功回游云时，经本场战斗的弱引用定位当前甚尔，在西游档清除旧形态。 |
| `XSmartAI._choose` | 14 处（`git grep -nE '[^[:alnum:]_]_choose[[:space:]]*\(' -- '*.gd'`） | 开关只约束西游档甚尔返回刚离开的形态。自动行动仍优先跑可用的挂机顺序。其他技能、角色和天启篇沿用原估值。 |
| `MVInterpreter._host_command` | 2（`git grep -n '_host_command(' -- '*.gd'`） | 事件循环调用解释器。只在陈塘关主席送活力水分支的消除指令完成后发起同图传送，同图流程保留已移除事件。 |
| 四个回退开关 | 见优化登记草稿 | 每个开关各管相应行为，均默认开启。 |

## 验证

- 语法检查通过，1183 个脚本，0 个问题。工具快速回归 23/23 通过，发行空壳检查退出码 0。
- 本机 Godot 专项 18/18 个不同场景通过，均用 Dummy 音频驱动。
- `xiyou_treasure_map` 29/29、`xiyou_battle_drop` 19/19、`xiyou_treasure_batch` 41/41、`xiyou_affix_rate` 371/371、`xiyou_merchant29` 102/102、`xiyou_tianqi_affix_roll` 30/30。固定装备骰覆盖战斗发奖、挖宝实际入包、合法随机词条、可落空和开关回退。
- `xiyou_common_scripts` 472/472、`xiyou_map132_shop` 102/102、`xiyou_event_compare` 14/14、`xiyou_transfer` 53/53。覆盖两张图纸学会提示、原配方解锁、陈塘关送礼后的落点和朝向，以及缺水、只查看、首领已败、天启篇和回退开关分支。送礼流程用实际事件数据和记录宿主执行。同图移动另由场景验证。
- `xiyou_toji_battle` 1337/1337、`xiyou_smart_ai` 5355/5355、`xiyou_determinism` 372/372。甚尔在实战逻辑中成功切换后，固定估值验证连续选招、强收益回切、手动回切、天启篇和新战斗清记录。
- 补跑原版对照时，`xiyou_event_compare_c/d` 各有一条差异，均是预期改写的乌鸦提示。原版对照已显式关闭图纸文字开关，保持原参照。修正后本机 `xiyou_event_compare` 14/14，`xiyou_event_compare_b/c/d` 各 6/6，`xiyou_common_scripts` 472/472。另跑 `xiyou_text_fix` 61/61。
- 副本原版对照的送礼用例要求停在原位。该对照两轮都使用送礼传送的回退开关，保留对原版位置、文字、道具和变量的断言。本机 `xiyou_dungeon` 6954/6954，新位置和相关分支由 `xiyou_common_scripts` 472/472 覆盖。
- 首轮云端选测针对 `b041fe81a`，751/754 场景通过。失败场景只有乌鸦提示与送礼落点的三个原版对照。`b041fe81a` 到最终代码提交只改变两份原版对照的开关设置。[首轮云端选测](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45138784893)
- 图纸原版对照修正后，以首轮代码提交为基准对 `d8731038d` 增量选测，15/16 场景通过。失败项是还沿用原位置的副本送礼对照。[第一次增量云端选测](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45141083534)
- 两组原版对照均修正后，以首轮代码提交为基准对 `964ea198a` 增量选测，17/17 场景通过。三个首轮失败的场景都在此轮复跑。已通过 `gh run watch` 等到运行结束。[最终增量云端选测](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45142378663)
- r1 返修前，新增断言复现了宝箱开关开启仍无词条、工厂关闭开关仍补词条、甚尔复活残留回切记录。
- r1 返修后，`xiyou_treasure_map` 35/35、`xiyou_toji_battle` 1339/1339、`xiyou_determinism` 372/372、`xiyou_battle_drop` 19/19、`xiyou_treasure_batch` 41/41、`xiyou_affix_rate` 371/371、`xiyou_merchant29` 102/102、`xiyou_tianqi_affix_roll` 30/30。宝箱用例读取原事件的至臻发奖指令，由 `MVEventCore` 执行，覆盖启用、回退和天启篇档案隔离。甚尔用例走实战切换、阵亡和复活。
- r1 语法检查 1189 个脚本、0 个问题，工具快速回归 23/23，发行空壳检查退出码 0（81 个脚本、782 个函数）。
- r1 云端选测检验同步主线后的车道提交 `0e20b2f29`，基准为初交最终代码 `964ea198a`。已用 `gh run watch 45215889005 --exit-status` 等到退出码 0，并核对汇总为 773/773 场景、16/16 分片通过。`xiyou_floor_reach080` 并行时偶发失败，单跑通过。[r1 云端选测](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45215889005)
- 截图：本单为规则与文字修正，验证采用场景断言，交付无截图。

## 本分支提交

- `4211a6d21` 至臻词条候选修复。
- `b877042b1` 图纸改名和陈塘关传送。
- `169a84b97` 甚尔回切抑制。
- `b041fe81a` 回归用例和优化登记挂钩。
- `d8731038d` 原版事件对照使用旧图纸提示。
- `964ea198a` 副本原版对照使用旧送礼路径。
- `f40eff609` r1 返修，补王者宝箱至臻词条、工厂回退开关和甚尔复活回切记录，新增回归断言。
