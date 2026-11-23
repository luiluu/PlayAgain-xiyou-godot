# 交付：luiluu/t411

- 车道／工作者：T411 徐凤年 152 放出＋天启篇技能卡 v0.3＋接线＋量数（前半 cc，后半小A Gemini 4 Neon＋high 接续）
- 状态：可合并

## 变更记录草稿

## 2026-11-23 【小A·未经审查】T411 解放徐凤年（152）＋天启篇技能卡 v0.3 接线与两轮量数过线（dev.待定）

- 玩家可见：
  - 西游版在看过漩涡三阶段过场（`rift3`）后，兑换大厅号角商店上架「徐凤年号角」（359），可招募超强者角色「徐凤年」（152），改版向导停用名单同步删去苍龙破晓与徐凤年；已有号角或已入队老档照常可用。
  - 天启篇候选池开放「徐凤年」（超强者）：剑一～剑八保持被动、攻击命中时按原版 2%～30%（合计 95%）追加伤害；大帝转世提供物品掉落率 +10%；主动两招为「剑气滚龙壁·封印」（单体五段爆发）与「剑九」（单体八段终式，目标生命低于 30% 时伤害翻倍，放完 1 回合不能动，每场一次）；清除了原版遗留乘区、专属装备溢出属性、九阶基因锁 −100% 经验与角色本体旧特性。
- 设计稿与口径：定稿 `03_再刷重制_Godot/00_设计/徐凤年天启篇技能卡草稿_v0.3.md`（回写 Kyo 11-23 事项 34 全部定案，修复 v0.1／v0.2 审稿全部 P1／P2／P3）。
- 引擎与数据接线：
  - `modes/xiyou/core/imported_balance.gd`：放出开关 `RELEASE_XUFENG`、号角 359 上架门槛 `XUFENG_HORN_GATE`（接 `rift3`）、改版向导文本清理、天启篇候选池开关 `XUFENG_TIANQI = true`（过线后打开）。
  - `modes/xiyou/core/tianqi_skills.gd`、`modes/xiyou/core/state_effects.gd`：新增天启篇数据驱动状态命中追加伤害 `hit_extra_pct`（`rec_state` 合成 `establish` op，`run_one` 按主段实伤 `r.hp` 整数 % 扣血并写入 `r.extra` 弹字与 `r.hit_extra` 统计，回退开关 `HIT_EXTRA_ON`），修复原版 `States.json[2530..2537]` 闭合标签笔误导致 `effects: []` 零效果的问题。
  - `modes/xiyou/core/actor.gd`、`modes/xiyou/core/tianqi_skills.gd`：新增天启篇角色本体特性清理 `actors.<id>.traits_remove`（`actor_trait_obj(self, data())`，首句返回 `base` 合规发行空壳规则 2，回退开关 `ACTOR_TRAITS_STRIP`），清理 `Actors.json[152].traits` 再动 +100%、攻次 +2 与物理承伤 −20%；西游原版档零变化。
  - `modes/xiyou/tianqi_data/skill_rework.json`：补齐 152 段（`actors.152`、`skills` 9985～9998 共 14 条、`states` 2530～2537 与 `10833 剑竭`、`new_states.10833`、`gear` 4 件专属装备 `armor:143`／`weapon:76`／`armor:129`／`weapon:94`）。
  - `03_转换工具/天启篇数据校验.py`：同步校验 `states.*.hit_extra_pct`（1～100 整数）与 `actors.*.traits_remove`（`[[code, dataId]…]` 整数对），校验退出码 0。
  - `tests/virtual_player/k_calibrate.gd`：`_scan` 与 `_collect_hits` 计入 `r.hit_extra`（与奈叶／空间空蚀的 `r.extra` 隔离），并新增 `_target_hp_rate()` 仅对 152 徐凤年剑九（9995）把木桩血量压至 `<30%`（29%），确保整招各段条件全中且不波及 14/27/95/124/155 与狂刀等已标定角色。
  - `modes/xiyou/core/tianqi_hall_text.gd`：改版向导 EV071 天启篇停用名单替换锚点由 `"花橙、落芸、苍龙破晓"` 改为稳定锚点 `"已停用，不能招募"`，修复 `XImportedBalance.patch_map` 删去 `苍龙破晓、`／`徐凤年、` 后天启篇漏出西游停用名单的问题；`tests/xiyou_tianqi_hall.gd` 补天启篇与西游档双向实机文字断言（去「等」字漏测），`modes/xiyou/core/item_marks.gd:250` 删过时「条件待定」注释。
- 验证：
  - `03_转换工具/天启篇数据校验.py`：全部通过（退出码 0）。
  - `03_开发环境/发行空壳.py check`：81 个脚本 782 个函数全过（退出码 0）。
  - 本机专项：`tests/xiyou_tianqi_xufeng.tscn` 33/33（含天启篇扣血、回退开关与西游档零变化证明）、`tests/xiyou_xufeng_release.tscn` 27/27、`tests/xiyou_tianqi_skills.tscn` 245/245、`tests/xiyou_tianqi_join_gifts.tscn` 208/208、`tests/xiyou_tianqi_hall.tscn` 74/74。
  - 云端选测：Run `45152905079`（16 片 683 场景全绿），链接 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45152905079 。

## 交接板

- 下一步：
  - 总装合并 `luiluu/t411`（cc 换家核过无 P1，已按审核意见完成 P2-1／P3-1／P3-4 小修）；
  - 后续单：①`six_dim.json` 的 152 行目前全为 `C`，按 v0.3 新卡与实测强度重算（本单未动 `six_dim.json`）；②P3-2 弹字合并：剑一～剑八当前每段由 8 个状态各自往 `r.extra` 弹 1 次（滚龙壁五段合计 40 个追加弹字、剑九八段合计 64 个），后续若实机观感偏密可合并为每段 1 个汇总弹字。
- 用户试玩说明：
  - 西游档：看过漩涡三阶过场后，在兑换大厅号角商店购买「徐凤年号角」即可招募徐凤年；
  - 天启篇：开局随机阵容或通关抽角色可抽到超强者「徐凤年」，剑一～剑八被动命中后自动追加伤害，50 级终式「剑九」在敌人 30% 血以下触发斩杀翻倍。
- 需要用户决定：无（Kyo 11-23 事项 34 已全部拍板）。

## 进度账

- 扩展账（天启篇角色卡与原版停用角色解放）：完成徐凤年（152）西游放出与天启篇技能卡接线、两轮 3 种子标定过线（1.21× 狂刀），`XUFENG_TIANQI` 已开放进天启篇超强者候选池。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/imported_balance.gd` `RELEASE_XUFENG`／`XUFENG_HORN_GATE`／`XUFENG_TIANQI`；`modes/xiyou/core/tianqi_skills.gd` `HIT_EXTRA_ON`／`ACTOR_TRAITS_STRIP` | v0.62.12 停用并隐藏徐凤年（152）与号角 359；原版 2530～2537 状态闭合标签笔误导致 `effects: []` 不生效；`Actors.json[152].traits` 暗带再动 +100%、攻次 +2、物伤 −20% | 放出徐凤年（漩涡三阶 `rift3` 后上架号角 359，改版向导同步去名），天启篇接线技能卡 v0.3 并用 `hit_extra_pct` 实现剑一～剑八命中追加、`traits_remove` 清本体旧特性，过线后开放天启篇候选池；西游原版档零变化 | Kyo 11-23 事项 34（D262、T411） | `RELEASE_XUFENG = false` 回原版停用；`XUFENG_HORN_GATE = false` 回解放即上架；`XUFENG_TIANQI = false` 移出天启篇候选池；`HIT_EXTRA_ON = false` 关命中追加；`ACTOR_TRAITS_STRIP = false` 保留本体旧 traits | cc＋小A（T411） | 保留 |

## 可优化（流程／工具／效率）

- 已做：`XTianqiSkills.actor_trait_obj(a, base)` 首句写 `if …: return base`，天然命中 `发行空壳.py` 规则 2，无需改 `发行空壳特例.json` 即可在西游发行包里原样保留 `data()`（回退：`ACTOR_TRAITS_STRIP = false`）。
- 已做（P3-4）：`tests/xiyou_tianqi_join_gifts.gd` 中 141～166 放行超强者计数已由硬编码改为按 `26 - DISABLED_ACTORS(141..166).filter(not released_actor)` 动态计算，后续再解放导入角色无需手改该专项。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XActor.trait_objects` | 29 处（`git grep -nE '[^[:alnum:]_]trait_objects[[:space:]]*\(' -- '*.gd'`） | 调用方 29 处逐处结论：仅将首元素 `data()` 改为 `XTianqiSkills.actor_trait_obj(self, data())`；西游档、总开关关或不在 `actors.<id>.traits_remove` 名单的角色原样返回 `data()`，29 处调用零变化，仅天启篇 152 清掉 `[61,0]/[34,0]/[11,1]` |
| `XTianqiSkills.reload_table` | 149 处（`git grep -nE '[^[:alnum:]_]reload_table[[:space:]]*\(' -- '*.gd'`） | 调用方 149 处逐处结论：只多清一条 `_actor_trait_cache = {}`，保证热重载表时不残留旧缓存，所有调用方更安全、无副作用 |
| `XTianqiSkills.rec_state` | 3 处（`git grep -nE '[^[:alnum:]_]rec_state[[:space:]]*\(' -- '*.gd'`） | 调用方 3 处逐处结论：仅 `XDB.rec("States")` 与 `new_state_rec` 调用；只在天启篇 `cards_on()` 且状态规格带 `hit_extra_pct`（目前仅 2530～2537）时追加 `establish` op，其余状态和西游档零影响 |
| `XTianqiSkills.actor_trait_obj`（新） | 2 处（`git grep -nE '[^[:alnum:]_]actor_trait_obj[[:space:]]*\(' -- '*.gd'`） | 调用方 2 处逐处结论：仅 `actor.gd:949` 调，首句 `return base` 经 `发行空壳.py check` 验证发行包空壳原样返回 `base` |
| `XStateEffects.run_one` | 94 处（`git grep -nE '[^[:alnum:]_]run_one[[:space:]]*\(' -- '*.gd'`） | 调用方 94 处逐处结论：仅新增 `elif op == "hit_extra_pct"` 分支（只对天启篇合成的 2530～2537 生效），原有全部 op 分支一行未动，西游档与其他角色零影响 |
| `XImportedBalance.XUFENG_TIANQI` | 3 处（`git grep -n XUFENG_TIANQI -- '*.gd'`：`imported_balance.gd`、`tianqi.gd`、`xiyou_xufeng_release.gd`） | 调用方 3 处逐处结论：仅控制 `XTianqi._disabled(152)` 是否放进天启篇候选池，西游档不读；过线后翻 `true`，同步更新了 `xiyou_xufeng_release.gd` 与 `xiyou_tianqi_join_gifts.gd` |
| `XImportedBalance.released_actor`／`is_hidden_actor`／`horn_id_disabled`／`patch_map` | 5／12／8／17 处（cc 前序提交 `80a53a172`、`0c20e6afa`） | 调用方 42 处逐处结论：仅在 `RELEASE_XUFENG` 开着时放行 152 与号角 359 并清改版向导停用名单，`RELEASE_XUFENG = false` 及 `XCanglong.original_data()` 一并回原版，隐藏角色与苍龙专项全过 |
| `XItemMarks.shop_goods` | 53 处（`git grep -nE '[^[:alnum:]_]shop_goods[[:space:]]*\(' -- '*.gd'`） | 调用方 53 处逐处结论：仅新增 `xufeng_horn_on_sale()` 过滤号角 359（及清理过时注释），`XUFENG_HORN_GATE = false` 回退，其余商品与商店不受影响 |
| `XTianqiHallText.rewrite_message` | 18 处（`git grep -nE '[^[:alnum:]_]rewrite_message[[:space:]]*\(' -- '*.gd'`） | 调用方 18 处逐处结论：仅将 EV071 停用名单匹配锚点由 `"花橙、落芸、苍龙破晓"` 改为 `"已停用，不能招募"`，西游档不走 `XTianqiHallText`，天启篇 EV071 实机文字与 `xiyou_tianqi_hall.tscn` 74/74 全过 |
| `XTianqiSkills.HIT_EXTRA_ON`／`ACTOR_TRAITS_STRIP`（新） | 各 2 处（本体＋专项 `xiyou_tianqi_xufeng.gd`） | 默认 `true`，专项已测开／关两支与西游档零变化 |

## 数值报告：逐种子分布

- 口径：D209（81 级甲档，烙印 100%，`exact` 确定值口径，黑印真印满配＋二号血海＋3 秘籍格＋极四阶贪心词条＋满熟练度）。`k_calibrate.gd` 对 `152` 计入 `r.hit_extra` 并仅对 152 剑九（9995）压木桩血量至 29%（不波及 14/27/95/124/155 与狂刀等已标定角色）；狂刀 `6026` 基线值 `2,308,294` 逐字节不变。
- 目标：徐凤年 152 ／ 狂刀 122 ＝ **1.2**（允许 **1.1～1.3**）。

### 第 1 轮（剑九 7 段×1，斩杀翻倍 14，滚龙壁 5 段×2＝10）

| 种子 | 狂刀 122 峰值（6026 雨龙泣） | 徐凤年 152 峰值（9995 剑九） | 152 / 122 | 剔除没有、为什么 |
| --- | --- | --- | --- | --- |
| seed=0 | 2,308,294 | 2,452,793 | 1.0626 | 没剔除 |
| seed=1 | 2,308,294 | 2,452,793 | 1.0626 | 没剔除 |
| seed=2 | 2,308,294 | 2,452,793 | 1.0626 | 没剔除 |

统计量（n=3，全部计入）：均值 `1.0626`、中位数 `1.0626`、最小～最大 `1.0626～1.0626`、标准差 `0`（偏低于 1.1 下线，进入第 2 轮将剑九由 7 段调至 8 段）。

### 第 2 轮（定稿：剑九 8 段×1，斩杀翻倍 16，滚龙壁 5 段×2＝10）

| 种子 | 狂刀 122 峰值（6026 雨龙泣） | 徐凤年 152 峰值（9995 剑九） | 152 / 122 | 剔除没有、为什么 |
| --- | --- | --- | --- | --- |
| seed=0 | 2,308,294 | 2,803,192 | 1.2144 | 没剔除 |
| seed=1 | 2,308,294 | 2,803,192 | 1.2144 | 没剔除 |
| seed=2 | 2,308,294 | 2,803,192 | 1.2144 | 没剔除 |

统计量（n=3，全部计入）：均值 `1.2144`、中位数 `1.2144`、最小～最大 `1.2144～1.2144`、标准差 `0`（**落入 1.1～1.3 区间，紧贴 1.2 目标，过线**；同测 9998 剑气滚龙壁·封印峰值 `1,751,995`，为狂刀的 `0.759×`）。

## 云端选测与独占范围

- 云端选测（提交 `e435cc3ba`，基准 `fd0a48deb`）：**通过**（16 片共 683 场景全绿），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45152905079
  - （前一次 Run `45147546647` 在 683 场景中检出 `xiyou_tianqi_join_gifts.tscn` 硬编码超强者放行计数 `17` 失败，已同步更新为 `18` 后重跑全绿。）
- 独占文件（含协调批准扩改项）：
  - `03_再刷重制_Godot/00_设计/徐凤年天启篇技能卡草稿_v0.3.md`
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/skill_rework.json`（152 段）
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_skills.gd`
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/state_effects.gd`
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/actor.gd`
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/imported_balance.gd`（仅打开 `XUFENG_TIANQI`）
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_hall_text.gd`、`modes/xiyou/core/item_marks.gd`
  - `03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`
  - `03_再刷重制_Godot/01_Godot工程/tests/virtual_player/k_calibrate.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_xufeng.gd`／`.tscn`／`.gd.uid`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_xufeng_release.gd`、`tests/xiyou_tianqi_join_gifts.gd`、`tests/xiyou_tianqi_hall.gd`
  - `00_项目管理/交付/luiluu_t411.md`
- 后续项：
  - P2-1：`xufeng_gate_met` 改走 `XRift.stage() >= 3`，等 T412 合进 `main` 后 rebase 一起改；
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/six_dim.json` 的 152 行留后续统一重算，本单未改动；
  - P3-2 弹字合并：剑一～剑八当前每段由 8 个状态各自往 `r.extra` 弹 1 次，后续如实机观感偏密再合并为每段 1 个汇总弹字。

## 本分支提交

- `80a53a172` WIP: T411 放出徐凤年 152 开关（RELEASE_XUFENG、号角 359 上架门槛接口、天启篇候选池暂不放、改版向导删苍龙徐凤年）
- `0c20e6afa` T411 号角 359 门槛接 T412 的 rift3；专项 xiyou_xufeng_release，隐藏角色与苍龙专项按原版比时一并关徐凤年解放
- `34a24f4b3` T411 专项 uid
- `83dcdc7c8` T411 徐凤年天启篇技能卡草稿 v0.1（只写文档、不接线，待小A 审）
- `f6784b7d9` T411 徐凤年天启篇技能卡草稿 v0.2（Kyo 事项34：剑一～剑八保持被动按原版比例追加、大帝转世掉落率+10%）
- `d1af1379a` T411 徐凤年天启篇技能卡 v0.3＋接线＋两轮 3 种子量数过线（1.21×狂刀）＋打开 XUFENG_TIANQI
- `e435cc3ba` T411 同步 xiyou_tianqi_join_gifts 超强者放行计数（17→18，含 152 徐凤年）
