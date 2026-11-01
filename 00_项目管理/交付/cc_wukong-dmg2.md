# 交付：cc/wukong-dmg2

- 车道／工作者：悟空（cc），事件对照探针缺口与审查第 18 期甚尔两条
- 基线：总装十派单，从 11573884（dmg1 末端）切出。第六批推送后再按总装通知合一次 main（合了以后 xiyou_guyu 也会好）。
- 状态：可合并

## ① 事件对照探针

| 用例 | 原因 | 改法 | 现在 |
| --- | --- | --- | --- |
| ce1344 随机伙伴、m221e3p0 引路人（赢了以后调 ce1344） | 参照把 Math.random 固定成 0.5；随机伙伴抽 2701～2819 的伙伴号角，和已抽到的相同就跳回标签重抽，每次都抽到同一个，死循环到帧数上限（参照出错） | `event_probe.cjs` 加 `RANDOM_SEQUENCES`：这两例的事件指令 122（随机数）改按固定序列循环取（只包 command122，战斗等别处照旧 0.5）；Godot `MVEventCore.random_sequence` 同表，`xiyou_event_compare` 照用例设 | 两例都跑完、和重制一致；`KNOWN_ORACLE_ERRORS` 清空 |
| m4e1p2／p3 更换称号 | 选择称号公共事件只在标题画面 `Scene_Title.initialize` 里接到 `$dataCommonEvents` 末尾，参照不进标题画面，`ChooseTitle` 预约落空 | 参照启动时照 designation_probe 调一次 `Scene_Title.initialize`（父类换成空函数）；预约到称号公共事件时在子解释器里当场跑完（实机是本事件结束后跑，它不读本事件之后改的开关，结果一样）；选项里原版带 ESC 控制符（\x1b），比较前统一成反斜杠 | 两例一致，从登记里消掉 |

登记 `event_compare_baseline.json` 用 `--update-baseline` 重写：5808 例、一致 5807，只剩 m4e73p0（五乘区预算，O-050 不移植），说明也改了。同步用接受单 `04_验证/测量接受/cc_wukong-dmg2.json` 显式接受这 4 例的参照改变。

## ② 审查 18 P2：O-131 一号两用

- `XToji.CLEAR_DEBUFFS`（学暴君／repair 时清弱化）改标 O-138：`toji.gd` 第 44、81 行，`xiyou_toji_battle.gd` 的 `_tyrant` 注释与 `tyrant.original_threw` 那行，变更记录 toji2 段第 5 条。O-131 只留智能 AI 估伤。
- 优化登记.md 补 O-138 一行（8 列，状态「待用户确认」）。
- 顺带发现：`回退开关覆盖.py` 报 O-131～O-134 四行「解析不了」（列数 3／6，不是 8），是登记表里这几行少列，没动，建议总装补齐。

## ③ 审查 18 P3②：黄泉／镜流必中 × 甚尔影速闪避

- 新探针 `toji_eva_probe.cjs`：黄泉 10172、镜流 10187 打会天与咒缚的甚尔，原版 itemEva 是 0.3（影速上限）或 0.2757，不是 0；普攻 1 与打 1 号都是 0。
- 改：`XBattleLogic.item_eva` 里镜流黄泉的必中只把内层闪避压成 0，再照样加甚尔的影速（原版装入次序镜流黄泉在甚尔里面）；云裳、宿傩、甚尔五感照旧直接 0。这是照原版，不是优化，没加开关。新专项 `xiyou_toji_eva`；改之前 4 例失败（0 对 0.3），改后通过。

## 优化登记草稿

- 无（O-138 已直接登记）。

## 变更记录草稿

## 2026-11-01 【cc·悟空·未经审查】事件对照四例的参照缺口、甚尔暴君清弱化改标 O-138、黄泉／镜流必中照样吃甚尔影速（dev.待定）

- `mv_oracle/event_probe.cjs`：随机伙伴两例的事件随机数按固定序列取；启动时补上称号公共事件，预约到它时当场跑完。`core/mv_event_core.gd` 加 `random_sequence`；`tests/xiyou_event_compare.gd` 照用例设序列、选项 ESC 统一成反斜杠、参照出错名单清空；登记重写，只剩 m4e73p0。
- `core/toji.gd`、`tests/xiyou_toji_battle.gd`、变更记录 toji2 段：暴君清弱化改标 O-138；优化登记补 O-138。
- `battle/battle_logic.gd` `item_eva`：镜流黄泉必中后照样加甚尔影速。新探针 `mv_oracle/toji_eva_probe.cjs`（登记 PROBES）与专项 `tests/xiyou_toji_eva`。

## 验证

- 探针：`toji_eva_probe.cjs` 6 例无错；`event_probe.cjs` 改后单跑 m221e3／m4e1p／ce1344 全部跑完。同步先 `--accept-additions` 报这 4 例参照改变（退出码 2，只有这 4 例），再加接受单 `--accept-changes` 跑完「显式接受 4 条既有用例改变」，留了指纹。
- 选测 43 场景（CHECK_JOBS=3，宽前缀展开）全过、无偶发：`xiyou_event_compare`（5808／5807，无退步、无参照出错）、`xiyou_toji`、`xiyou_toji_battle`、`xiyou_toji_eva`（新）、`xiyou_jingliu`、`xiyou_jingliu2`、`xiyou_yomi_battle`、`xiyou_battle_common_events`、`xiyou_designation`、`xiyou_sukuna_battle`、`xiyou_yunshang`、`xiyou_common_scripts`、`xiyou_troop_events`／`_b`～`_half`、`xiyou_battle*`、`xiyou_smart_ai*`（日志 `04_验证/本地结果/并行测试/20261101_093421_sb5dr27v/`）。
- 反向：③ 改之前 `xiyou_toji_eva` 4 例失败（0 对 0.3／0.2757），改后通过；① 改之前 ce1344／m221e3p0 在参照出错名单、m4e1p2／p3 不一致，改后一致。
- `语法检查.py` 通过；`回退开关覆盖.py` 新缺口 0。

## 交接板

- 下一步：O-131～O-134 四行补成 8 列；O-138 等用户确认。
- 用户试玩说明：无可见变化（甚尔影速那条只在混乱打队友时出现）。
- 需要用户决定：O-138（甚尔学暴君时把弱化也清掉，原版写错函数名、清不掉；正常游戏碰不到），默认照说明清掉。

## 进度账

- 事件对照：登记只剩 1 例（定了不移植），参照出错 0。

## 可优化（流程／工具／效率）

- 已做：事件对照的随机数可以按用例给序列（`RANDOM_SEQUENCES`），以后遇到「重抽到不重复」的事件照加就行（回退：删表项）。

## 本分支提交

- 51a675c5 审查 18 P2：O-138
- 6cba8d94 审查 18 P3②：甚尔影速
- WIP：事件对照四例
- 交付单（本提交）
