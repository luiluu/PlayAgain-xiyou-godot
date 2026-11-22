# 交付：luiluu/t389

- 车道／工作者：T389 教派包辛：真材料首杀与升华（K10）／cc 车道（Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-22 【cc·天启篇·未经审查】教派包辛：真材料首杀与升华（T389，dev.待定）

- 依据私密仓 `重制设定/天启篇_教派连带内容重做方案_v0.2.md`「辛：真材料首杀与升华」。只认天启篇存档，西游档不变；回退开关 `XTianqiSect.XIN`（O 号待总装编）。
- 31／32／33 层守层者（女娲、伏羲、鸿蒙老祖，敌群 467／468／469）第一次打赢各掉一件：原初火种·源（1975）、永恒玄冰（1976）、极渊重岩（1977）。挂在 `XTianqiSect.after_map_battle`（XMapScene.start_battle 末尾现成的挂点），记进新存档分区 `flags.tianqi.sect_xin.kills`，再打、再挑战不再掉；打完弹一句「获得了…！带去 N 层，交给守层者某某。」
- 天启篇里三件材料去掉「真*」：1975 和普通「原初火种」1953 重名，叫「原初火种·源」；说明末尾加去处（经 `XTianqiSect.has_item／item_rec` 的 XDB.rec 挂点）。
- 19 层炎龙队长（Map047 EV013）、25 层嫦娥（Map147 EV001）、27 层多宝道人（Map182 EV001）打赢后的普通商店页（独立开关 A）：身上有对应材料、这层还没升华过时由 `XTianqiSect.intercepts／run_event` 接管：有人学过旧被动→收材料，照原公共事件 1388／1389／1390 的做法所有学过的角色忘掉永恒之火 6133／天宫之寒 6138／镇渊之岩 6238、学「·极尽升华」6236／6237／6239，守层者说一句、弹「你的被动：…极尽升华！」，记 `sect_xin.sublimed`；没人学过→守层者提示、不收材料。之后照原来的普通页继续（商店、索要礼物，含见面礼模块改过的那页）。升华每层只一次。
- 这三层的随机页、轮回页和魔塔外围送真材料页本来就被包甲拦住，不动（专项锁住）。
- `XTianqiSave.SECTIONS`／`WIRED` 登记 `sect_xin`。
- 玩家可见：天启篇 31～33 层守层者首杀掉三件材料，带回 19／25／27 层守层者处可让三本被动极尽升华。

## 验收逐条

1. 方案 v0.2 包辛一节验收：首杀 31／32／33 层各拿一件、再打不再掉 ✓（专项 first_kill_three／second_kill_none，实机 live_32_first_kill）；带材料回 19／25／27 层能升华对应被动 ✓（sublimate_ok／sublimate_25_27，实机 live_19_sublimate）；没学过有提示且不收材料 ✓（none_hint_keep_item）；升华只一次 ✓（sublimate_once、live_19_after_plain）。
2. 31～33 层首杀掉三件材料 ✓（同上；输了不掉 loss_no_drop；别的守层者不掉 other_troop_none）。
3. 19／25／27 层守层者普通商店页加升华 ✓（data_ce_and_pages 核了三页是独立开关 A 页、A 开时天启篇选中第 1 页；实机先升华台词再开原商店 live_19_line_then_shop）。
4. 回退开关 `XTianqiSect.XIN` ✓（switch_off：不接管、不掉、名字回原版）。
5. 西游档零变化 ✓（original_untouched：不接管、不掉、名字原样、不建 sect_xin 分区）。
6. 发行空壳特例：本包没有新增被西游代码直接调用的函数（入口都走现有的 has_item／item_rec／intercepts／run_event／after_map_battle，特例表已有或按 void 空壳），`发行空壳.py check` 通过（81 个脚本，775 个函数都有），无需补特例。
7. 交付单＋自检、云端选测：见回执。

## 验证

- 专项 `xiyou_tianqi_sect_xin` 27/27（含实机：真进 32 层打伏羲、真进 19 层跟炎龙队长说话）。
- 相关专项本机：`xiyou_tianqi_sect_a`、`xiyou_tianqi_sect_b`、`xiyou_tianqi_sect_bing`、`xiyou_tianqi_sect_geng`、`xiyou_tianqi_sect_ren`、`xiyou_tianqi_guardian_gift`、`xiyou_tianqi_save` 全过。
- `选测.py main --list` 选中的 17 个场景交云端选测（结果见回执）。
- `语法检查.py` 0 问题；`工具回归.py` 全过；`天启篇存档登记.py` 通过；`发行空壳.py check` 通过。
- 截图：`00_项目管理/归档/交付截图/luiluu_t389/xin_kill32.png`（32 层首杀提示）、`xin_sublimate19.png`（19 层炎龙队长升华台词）；截图工具 `tests/t389_xin_shot.tscn`（无头时跳过）。

## 没做／偏离

- 独占文件之外动了：`tianqi_save.gd` 登记一行 `sect_xin` 分区（存档登记检查要求）；`tianqi_sect.gd` 里包丙的 `has_item／item_rec` 各加一个分支、包乙的 `after_map_battle` 末尾加一行调辛段（这两个是 XDB.rec／地图战斗的共用挂点）。没碰 `tianqi_drop.gd`、`guardian_rework.gd`、`balance_table.json`。
- 首杀掉落没走掉落表，用地图战斗打完的挂点直接给（避免碰 tianqi_drop.gd，且「首杀」按敌群认更直接）。
- 升华时没跑原公共事件 1388～1390 本身，按它的写法在 GDScript 里做（遍历全体角色 hasSkill→forget/learn），多了「没人学过只提示」。
- 守层者台词、获得提示、材料说明是草稿，待小A 文字审。

## 交接板

- 下一步：无新增。
- 用户试玩说明：天启篇打赢 31～33 层守层者拿到三件材料，学过永恒之火／天宫之寒／镇渊之岩后带去 19／25／27 层守层者处升华。
- 需要用户决定：无。

## 进度账

- 无（教派连带内容包辛落地，按启封缺口拆卡 K10 销）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_sect.gd`、`modes/xiyou/core/tianqi_save.gd`、`tests/xiyou_tianqi_sect_xin.gd` | 三件真材料只在随机／轮回模式下 31 层后由魔塔外围老板直接送，19／25／27 层守层者只在随机／轮回页升华 | 天启篇改为 31～33 层守层者首杀各掉一件（去掉「真*」，1975 叫原初火种·源），19／25／27 层守层者普通商店页有材料时先升华（没人学过只提示、每层一次） | Kyo 2026-11-14 教派连带内容重做方案 v0.2（包辛）；Kyo 11-11 优化直接接受 | `XTianqiSect.XIN = false`（不掉材料、不接管守层者、材料名原样） | cc | 保留 |

## 可优化（流程／工具／效率）

- 无。

## 本分支提交

- 见 git log（本交付提交）。
