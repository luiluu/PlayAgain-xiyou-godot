# 交付：luiluu/t513

- 车道／工作者：T513 养成线二期 2A 套装同台上限（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-25 【cc·T513·未经审查】天启篇套装同台上限：一人最多生效两套，七印算在内（dev.待定）

- 依据：私密设计仓《天启篇_原版养成线重做方案_v0.3》第三节第 3 条（Kyo 11-14 上午「原版套装照方案」已定）：一人最多生效两套，七印套装也算在这两套里，件数多的优先；老存档「身上超过两套的，按件数多的两套算」。拆卡见私密仓 `协作交接/派单/T513_二三期拆卡.md`（第二、三期共 21 张卡，本卡是 2A）。
- 新增 `modes/xiyou/core/tianqi_suits.gd`（`XTianqiSuits`）：候选＝原版套装穿够最低一个多件档的、七印穿够 2 件的；按「生效件数」（穿的件数和这套最高一档取小：2 件套穿 3 件按 2、七印穿 6 件按 5）降序取前 `CAP`＝2 套。**件数相同：七印优先 → 原版套装号大的优先（后期、高层套）→ 七印按印序**（协调 11-25 定，小A 核 T513 P2-1；`XTianqiSuits.NEWER_FIRST = false` 回到号小优先）。
- 「单件套」（所有档都只要 1 件）不占名额、照旧生效，等 2E 拆成装备固有特效。**混合套**（有 1 件档又有多件档，表里实际能穿的只有 101 哥布林脚趾 1／3 件）：1 件档同单件套照旧生效、不占名额；多件档才进名额竞争，被挤掉时只退多件档（小A 核 P2-2）。不认识的印不进名额（P3-1）。
- 接线：`XEquipSuits._active_now` 先过 `XTianqiSuits.filter_suits`（原版套装的属性、特性、状态、技能、掉率、金钱都走 `active`，一处管全）；七印 `XTianqiQiyinEffects.gear_effects`、`param_rate` 改读新加的 `live_set_counts`（`set_counts` 原样留着给显示和测试）；`filter_suits`／`filter_seals` 直接用传进来的件数，不再重扫一遍（P3-2）。
- **说明牌提示接在真实装备页**（返修 P1-1：首版只改了正式游戏不调用的 `ui/gear_info.gd`，已撤回）：天启篇新皮肤装备页 `XSkinEquipPage._sync_card`（选栏位时）和全部属性页 `XSkinGearDetail`（装备详情页、非比较时）在身上这件所属的套装被挤掉时，第一行加独立提示「本套未生效（每人最多同时生效两套，件数多的优先）」（旧金色；文字照小A 文字审方案 A），原版套装件、七印套装件都认（`XTianqiSuits.note`）。选候选装备时不显示（候选还没穿上）。
- 装备页环纹小点（`XTianqiRingStyle.resolve`）只给生效中的七印画（P3-3）。
- 存档不改：只在算效果时筛。只对天启篇存档生效（`XTianqi.active`）；西游档、开关关时原样放行。
- 回退开关 `XTianqiSuits.ENABLED`（O-待定）：false＝天启篇也不限套数（回到本卡之前）；`XTianqiSuits.NEWER_FIRST`（同号）：false＝同件数原版套号小的优先。
- 发行空壳：`filter_suits` 原样放行、`note` 恒空、`crowded_out` 恒 false（`发行空壳.py show XTianqiSuits` 核过）。
- 专项 `tests/xiyou_tianqi_suit_cap`（41 项）：原版 3＋原版 2＋七印 2、七印 5＋3＋原版 3、原版三套＋七印三印（新套优先，开关关回号小）、溢出件数、不认识的印、混合套 1 件档不占名额与被挤只留 1 件档、掉率来源跟着退、殉印 2 件生命跟着退、说明提示（原版件、七印件）、详情页提示行（比较时不显示）、真实装备页（XEquipScene＋新皮肤）说明牌第一节、单件套、开关关、西游档。
- 截图工具 `tests/t513_suit_shots`（不是专项，要窗口）：真实装备页两张，图在 `00_项目管理/交付截图/luiluu_t513/`（同步一份在私密仓 `协作交接/审样/T513/`）。
- 玩家可见：天启篇里身上同时穿够三套以上（七印也算）时只有件数最多的两套生效；装备页选到没生效那套的部件，说明牌第一行写「本套未生效（每人最多同时生效两套，件数多的优先）」。

## 交接板

- 下一步：T013 二期 2B（原版套装模板引擎）可派，依赖本卡；其余见私密仓 `协作交接/派单/T513_二三期拆卡.md`。
- 用户试玩说明：天启篇同时穿三套以上套装，只有件数最多的两套生效（七印也算）。
- 需要用户决定：无（同件数排序协调 11-25 已定：七印优先 → 套装号大的优先，可回退）。

## 进度账

- 部件 9（数值总账与养成）：70% → 71%，T013 二期 2A（拆卡稿估 +0.10 点，按部件内 +1% 记）。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 恢复方法 | 执行 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_suits.gd` `XTianqiSuits.ENABLED`、`XTianqiSuits.NEWER_FIRST` | （天启篇新增）原版套装、七印套装各自全部生效，不限套数 | 天启篇一人最多生效两套（七印算在内，件数多的优先，同件数七印优先、再套装号大的优先），单件套和混合套的 1 件档不占名额；装备页提示没生效的套；西游档零改动 | 养成线重做方案 v0.3 第三节第 3 条（Kyo 11-14）；排序协调 11-25 | `XTianqiSuits.ENABLED = false`；`XTianqiSuits.NEWER_FIRST = false` | cc（T513） | 保留 |

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XEquipSuits._active_now`（经 `active`） | `active` 被调 3 处（`git grep -n 'active(a)' -- '*equip_suits.gd' '*tianqi_drop.gd'`：tianqi_drop.gd:146 掉率来源、equip_suits.gd:38 value、:45 ids；value／ids 再被 actor.gd 属性、特性、状态、技能和 tianqi_money、battle_logic 战果读） | 调用方 3 处逐处结论：西游档 `filter_suits` 原样返回同一字典，结果逐字节同；天启篇只少了被挤掉那套的档，掉率、金钱、属性、状态、技能一起退，符合稿「按件数多的两套算」 |
| `XTianqiQiyinEffects.gear_effects`、`param_rate` | `gear_effects` 5 处（`git grep -n 'gear_effects(' -- '*.gd'` 七印的：tianqi_qiyin_effects.gd:244、:246、:1124、:1136，skin_battle.gd:166） | 调用方 5 处逐处结论：只换成读 `live_set_counts`；没超两套时与 `set_counts` 相同；武器印记、真印、独有、刻印不受影响（不走件数） |
| `XSkinEquipPage._sync_card`、`XSkinGearDetail._build` | `_sync_card` 15 处（`git grep -n '_sync_card(' -- '*.gd'`，都是装备页刷新）、`_build` 2 处（`git grep -n '_build()' -- '*skin_gear_detail.gd'`：set_data、choose） | 调用方 17 处逐处结论：函数签名、返回不变，只在天启篇、身上这件所属套装被挤掉时往说明牌最前面插一节／一行；西游档 `note` 恒空，牌面不变（xiyou_ui_skin_1c、xiyou_gear_detail 过） |
| `XTianqiRingStyle.resolve` 小点 | 装备页环纹 1 处 | 调用方 1 处逐处结论：不超两套时 `live_set_counts`＝`set_counts`，小点照旧；xiyou_tianqi_ring_style 过 |

## 验证

- 专项：`xiyou_tianqi_suit_cap` 41/41（本机，返修后）；关联本机选测 7 个全过：xiyou_ui_skin_1c、xiyou_tianqi_ring_style、xiyou_gear_detail、xiyou_tianqi_qiyin_effects、xiyou_equipment、xiyou_gear_ui、xiyou_tianqi_qiyin_equip。
- 语法检查 0 问题；`发行空壳.py check` 退出 0；`天启篇数据校验.py` 全部通过（本卡没改数据表）。
- 云端选测：整轮 815 个场景 16 片全部通过（提交 3831d4ec4，基准 547e9b7a1；之后只加了交付单），运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45662370851 。
- 云端选测（返修，提交 98378e611，基准 91b267df7）：15 个场景 1 片全部通过，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45670733993 （之后只改交付单、加截图）。
- 截图（返修，真实装备页、新皮肤 1280×720）：`00_项目管理/交付截图/luiluu_t513/t513_equip_orig.png`（冰冷 3＋黑印 3＋云压 2，选云压戒指）、`t513_equip_seal.png`（白印 3＋统帅 3＋黑印 2，选黑印件；夹具把黑印 2 件放在项链、戒指格）。

## 本分支提交

- 3831d4ec4 WIP: T513 2A 套装同台上限（一人两套含七印）＋专项
- c7ce38ecf T513 交付单（云端选测待填）
- 91b267df7 交付单填云端结果、标可合并
- 886e292b6 补两个 .gd.uid
- 98378e611 返修：提示接真实装备页（原版＋七印）、同件数新套优先、混合套与溢出件数、环纹小点认生效套
- e37c2373c 返修交付单更正＋截图入仓
- 本提交：填返修云端结果
