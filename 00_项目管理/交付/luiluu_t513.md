# 交付：luiluu/t513

- 车道／工作者：T513 养成线二期 2A 套装同台上限（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-25 【cc·T513·未经审查】天启篇套装同台上限：一人最多生效两套，七印算在内（dev.待定）

- 依据：私密设计仓《天启篇_原版养成线重做方案_v0.3》第三节第 3 条（Kyo 11-14 上午「原版套装照方案」已定）：一人最多生效两套，七印套装也算在这两套里，件数多的优先；老存档「身上超过两套的，按件数多的两套算」。拆卡见私密仓 `协作交接/派单/T513_二三期拆卡.md`（第二、三期共 21 张卡，本卡是 2A）。
- 新增 `modes/xiyou/core/tianqi_suits.gd`（`XTianqiSuits`）：候选＝原版套装穿够最低一档的、七印穿够 2 件的；按件数降序取前 `CAP`＝2 套。**件数相同时七印优先，再按原版套装号小、七印印序靠前**（稿没写，见「需要用户决定」）。「单件就生效」的套装（最高一档只要 1 件，约 49 套，稿里说「其实不是套装」）不占名额、照旧生效，等 2E 拆成装备固有特效。
- 接线：`XEquipSuits._active_now` 先过 `XTianqiSuits.filter_suits`（原版套装的属性、特性、状态、技能、掉率、金钱都走 `active`，一处管全）；七印 `XTianqiQiyinEffects.gear_effects`、`param_rate` 改读新加的 `live_set_counts`（`set_counts` 原样留着给显示和测试）。
- 说明卡（`ui/gear_info.gd`）：穿够了却被挤掉的原版套装，名字后加「（同时最多生效两套，本套未生效）」，各档改灰。七印的说明卡没加这一句（没做，见下）。
- 存档不改：只在算效果时筛。只对天启篇存档生效（`XTianqi.active`）；西游档、开关关时 `live` 返回空、原样放行。
- 回退开关 `XTianqiSuits.ENABLED`（O-待定）：false＝天启篇也不限套数（回到本卡之前）。
- 发行空壳：`filter_suits` 照第一句 `return pieces` 原样放行、`crowded_out` 恒 false（`发行空壳.py show XTianqiSuits` 核过）。
- 专项 `tests/xiyou_tianqi_suit_cap`（24 项）：原版 3＋原版 2＋七印 2、七印 5＋3＋原版 3、原版三套＋七印三印、单件套不占名额、开关关、西游档。
- 玩家可见：天启篇里身上同时穿够三套以上时只有件数最多的两套生效，说明卡标出没生效的那套。

## 交接板

- 下一步：T013 二期 2B（原版套装模板引擎）可派，依赖本卡；其余见私密仓 `协作交接/派单/T513_二三期拆卡.md`。
- 用户试玩说明：天启篇同时穿三套以上套装，只有件数最多的两套生效（七印也算）。
- 需要用户决定：件数一样多时谁优先——本卡先按「七印优先，再按套装号」做，可回退；协调也可以直接定。

## 进度账

- 部件 9（数值总账与养成）：70% → 71%，T013 二期 2A（拆卡稿估 +0.10 点，按部件内 +1% 记）。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 恢复方法 | 执行 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_suits.gd` `XTianqiSuits.ENABLED` | （天启篇新增）原版套装、七印套装各自全部生效，不限套数 | 天启篇一人最多生效两套（七印算在内，件数多的优先，同件数七印优先），单件套不占名额；西游档零改动 | 养成线重做方案 v0.3 第三节第 3 条（Kyo 11-14） | `XTianqiSuits.ENABLED = false` | cc（T513） | 保留 |

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XEquipSuits._active_now`（经 `active`） | `active` 被调 3 处（`git grep -n 'active(a)' -- '*equip_suits.gd' '*tianqi_drop.gd'`：tianqi_drop.gd:146 掉率来源、equip_suits.gd:38 value、:45 ids；value／ids 再被 actor.gd 属性、特性、状态、技能和 tianqi_money、battle_logic 战果读） | 调用方 3 处逐处结论：西游档 `filter_suits` 原样返回同一字典，结果逐字节同；天启篇只少了被挤掉那套的档，掉率、金钱、属性、状态、技能一起退，符合稿「按件数多的两套算」 |
| `XTianqiQiyinEffects.gear_effects`、`param_rate` | `gear_effects` 5 处（`git grep -n 'gear_effects(' -- '*.gd'` 七印的：tianqi_qiyin_effects.gd:244、:246、:1124、:1136，skin_battle.gd:166） | 调用方 5 处逐处结论：只换成读 `live_set_counts`；没超两套时与 `set_counts` 相同；武器印记、真印、独有、刻印不受影响（不走件数） |

## 验证

- 专项：`xiyou_tianqi_suit_cap` 24/24（本机）。
- 语法检查 0 问题；`发行空壳.py check` 退出 0；`天启篇数据校验.py` 全部通过（本卡没改数据表）。
- 云端选测：整轮 815 个场景 16 片全部通过（提交 3831d4ec4，基准 547e9b7a1；之后只加了交付单），运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45662370851 。
- 截图：没拍（说明卡只加一句后缀，原有界面布局不变）。

## 本分支提交

- 3831d4ec4 WIP: T513 2A 套装同台上限（一人两套含七印）＋专项
- c7ce38ecf T513 交付单（云端选测待填）
- 本提交：交付单填云端结果、标可合并
