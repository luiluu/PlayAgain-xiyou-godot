# 交付：cc/rules-bugfix1

- 车道／工作者：规则（cc，项目线程「完成再刷西游Godot引擎重制」），总装派单 EE（Kyo 2026-11-07：原版 bug 一律修，不照搬）
- 状态：可合并
- 基于：main 02a1798c。工作位置：会话原工作树已清，按总装同意在临时目录 `git clone --shared` 本库做（交付后删）。
- 改了战斗核心：`battle/battle_logic.gd`（O-待定-2 一处换成函数调用＋新函数）、`core/actor.gd` trait_objects 一行、`core/confusion.gd`、`core/guyu.gd` recruit 一行。

## 结论表

| 条目 | 结论 | 依据 |
| --- | --- | --- |
| ① 魅惑／混乱己方随机含自己 | 现在修：O-待定-1 `XConfusion.FIX_SELF_TARGET`（默认 true） | 单体、落在己方时排除行动者；己方只剩自己时改打对方随机一个（同样 1 个随机数）。全体照旧含自己。专项 xiyou_confusion 406/406：参照 53 例在开关关时逐例比原版；新 `_self_fix` 断言开时不选自己、关时同一随机值选到自己。修复行注掉后专项挂。 |
| ② O-137 百谷生招募后倍率重复 | 现在修＋补开关：`XThreeGrowth.FIX_RECRUIT_DUP`（默认 true）；登记行改「默认修」 | 原来是重制不重现、无开关。现在关时能重现原版：招募时新生成的实例记下（人物等级, 法宝等级），两者都没变时多出生命 ×1.3、物防 ×1.2 两条，变了就去掉记号。three_growth 专项 100/100：参照 9 例开关关时全部逐项比（含 relic.lv1.r1 的重复），开时 relic.lv1.r1 断言生命、物防低于原版、其余六项相同；谷雨 78/78。 |
| ③ 猫哥「清理存档」回满 | 原版功能、早已实现（44f62a7f，审查 25 期核过） | zchuli.js 在 updateActorEquips 末尾给在队成员 gainHp(mhp)／gainMp(mmp)／refresh；v0.62.12 重写后注释写「保留原脚本的满血满蓝」，是有意保留的功能。重制 `mv_script.gd _cleanup_independent` 照做，xiyou_script_gaps `_cleanup` 对参照 cleanupHeal。只改了测试文件头一句过期说明（还写着「无操作」）。另：仓库武器防具丢失（O-147）在 v0.62.12 原作者也修了，跟重制默认一致。 |
| ④ 新源敌人热缓存不复活 | 本单不动代码，只给结论 | 是原版缓存 bug，重制一律复活就是修好的方向；要登记 O 号、加回退开关（关时重现热缓存不复活），测试改成开关两头测。代码在集成分支上，等换源失败清单出来后一起归到规则车道做。 |
| 顺手：敏捷减益不后移 | 现在修：O-待定-2 `XBattleLogic.FIX_AGI_DEBUFF_SHIFT`（默认 true） | Olivia_BattleSysOTB `otbBuffDebuffAgiConvert` 第二个 if 本该判减益（32），写成又判增益（31），敏捷减益从不让目标后移（v0.28 与 v0.62.12 相同）。影响 7 个技能（嘤嘤嘤 6 个、天坠翼击 10150）。修成后移 1 格，画面预览共用 `agi_convert_shift`。xiyou_otb 25/25；默认值改 false 时新测试挂。 |

## 其余照搬的原版缺陷（rg「照原版／照搬／原版也／写错／失效」后人工筛过，UI 还原和已登记 O 号的不算）

剩下 5 条，超过 3 条，按派单只列出、不修：

1. `map/hang_up_overlay.gd` 挂机提示：原版 drawWord 把「摆烂中.....」画进离屏画布，贴图仍是原图，文字从不显示。修法：把字画上去（界面）。
2. `battle/boss_hp_bar.gd`：敌人变身后血条不切到新编号；追加的 Boss 现身时不补建血条（原版也不会）。修法：变身／现身时重建血条（界面）。
3. `ui/map_transfer.gd`：传送页开着时，掉落窗口仍处理方向键（框在后面移动、详情不变）。修法：传送页开时掉落窗口不吃键（界面）。
4. `core/yunshang_orders.gd`：天衣订单把 `<Prefixes>` 补进备注，但 DreamX 的词缀表在读库时已经解析好，补的不生效，所以不掷词缀。要先问清作者本意，才能判断这是不是 bug（规则）。
5. `core/gear.gd`：同几率词缀排序用的序号，重掷后不归零。当前数据没有同几率的词缀，没有可见影响，建议不修（规则）。

另外，`combo_counter.gd` 的「总伤害」层是作者在西游版里注释掉的坐标，不算 bug；`achievement.gd`「全局已有、本局不补记」是设计。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | 混乱类目标（`modes/xiyou/core/confusion.gd` `targets`） | 魅惑（3 级）和混乱 2 级落在己方时，单体随机能选到行动者自己 | 己方单体随机排除行动者；己方只剩自己时改打对方随机一个；全体照旧含自己 | 原版缺陷（Kyo 2026-11-07「原版的 bug 要修」） | `XConfusion.FIX_SELF_TARGET = false`（参照 confusion_probe 在关时逐例比） | cc（规则 bugfix1） | 默认修 |
| O-待定-2 | OTB 敏捷增减益换位（`modes/xiyou/battle/battle_logic.gd` `agi_convert_shift`，`battle_scene.gd` 预览） | otbBuffDebuffAgiConvert 第二个 if 写成判增益，敏捷减益（嘤嘤嘤等 7 个技能）从不让目标后移 | 敏捷减益：目标下个回合后移 1 格 | 原版缺陷（判断写错） | `XBattleLogic.FIX_AGI_DEBUFF_SHIFT = false` | cc（规则 bugfix1） | 默认修 |

## 变更记录草稿

## 2026-11-07 【cc·规则·未经审查】原版 bug 改成修：混乱自选、百谷生倍率重复、敏捷减益换位（dev.待定）

- **混乱自选**（O-待定-1，`core/confusion.gd`）：魅惑和混乱落在己方时，单体随机不再选到行动者自己；己方只剩自己时打对方。开关关时跟原版逐例比。
- **O-137 补开关**（`core/three_growth.gd`、`guyu.gd`、`actor.gd` 各一行）：默认不重复；`FIX_RECRUIT_DUP = false` 重现原版招募后、改等级前生命 ×1.6、物防 ×1.4。登记改为「默认修」。
- **敏捷减益换位**（O-待定-2，`battle/battle_logic.gd`、`battle_scene.gd`）：原版判断写错，减益从不后移；改为后移 1 格。
- 猫哥清理存档：回满是原版功能，早已实现；只改测试的过期说明。热缓存不复活：结论见交付单，代码等集成分支。

## 交接板

- 下一步：④热缓存不复活随换源失败清单派规则车道（登记 O 号、加开关、测试两头测）；上面 5 条照搬清单待总装定派不派（1～3 是界面）。
- 交接板「待 Kyo」里 O-137 那条可以删：按 Kyo 11-07 规矩默认修、有开关了。
- 用户试玩说明：魅惑／混乱的队友打己方时不会打自己；嘤嘤嘤等敏捷减益会让目标下回合往后排一格。
- 需要用户决定：无。

## 待交叉核查

- cc/rules-bugfix1：混乱自选 O-待定-1、O-137 开关、敏捷减益 O-待定-2（甲档：战斗核心 battle_logic／actor trait_objects）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 会话原工作树被清后，车道没有地方改代码，只能请总装决定。这次用了 `git clone --shared` 加 `新建工作树.sh --补齐 <clone>`，可以用，`.git` 只有几百 K。`云端选测.py run --no-upload` 也能直接从 clone 推。可以写进车道须知，作为「工作树被清、又不能自建」时的备用做法。

## 验证

- 语法检查：601 个 .gd，0 个问题。
- 专项（本地）：xiyou_confusion 406/406、xiyou_three_growth 100/100、xiyou_guyu 78/78、xiyou_otb 25/25。①②的新测试在旧代码上挂（①注掉修复行；O-待定-2 默认值改 false），已核。
- `事件空绿扫描.py --check` 通过（空绿 55 例，均在基线内）。
- 云端选测通过：基准 02a1798c，324 个场景、14 片，提交 0cbe5905（https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42317398718）。

## 本分支提交

- b3190bfe 混乱自选 O-待定-1
- 63a0717b O-137 开关
- 猫哥说明、敏捷减益 O-待定-2（0cbe5905）
- 交付单 cc_rules-bugfix1（本提交）
