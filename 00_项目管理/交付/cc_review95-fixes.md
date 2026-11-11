# 交付：cc/review95-fixes

- 车道／工作者：工具＋测试／哪吒（cc，审查 95 返修）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·哪吒·未经审查】审查 95 返修：探针审计不再被缓存命中绕过、影响面声明拒重复与环、天启篇标题贯通测试、逃跑时地图曲提前换回（dev.待定）

- **P2-2 缓存整份命中会绕过到期审计**：`03_转换工具/同步正式西游.py` 新增 `audit_due_before_hit`，`run_probes` 在用外层缓存（`CACHE_HIT`）和暂存产物（`STASH_HIT`）之前，先按键账 `auditedAt` 看 troop 与事件状态两个探针的每日审计有没有到期；到期就记 `AUDIT_DUE <探针>`、缺失原因加 `{"kind":"audit-due"}`，照常进执行器整份重跑并审计（执行器里原有的到期判断不变）。`PROBE_PLAN` 和返回值多一项 `auditDue`。账上认不出已发布结果的不强跑（跑了也没有可比的）；`XIYOU_TROOP_INCREMENTAL=0`、`XIYOU_COVER=1`、`XIYOU_*_AUDIT_HOURS=0` 时同以前。回退：`XIYOU_AUDIT_BEFORE_HIT=0`（O-待定·审计先于命中）。说明写进 `07_开发环境/长任务与增量同步.md`。
- **P2-3 同一目标 SHA 的重复声明**：`mv_oracle/event_state_probe.cjs` 读 `probe_change_scope.json` 时拒同一个 `to` 写两条、拒 from／to 连成环（都在用例执行前报错）；`incremental_sync.py` 读 `helper_change_scope.json` 原来已拒重复 `(file,to)`，这次也拒环（原来只靠追链的 `seen` 防死循环）。探针本身改了，按影响面声明登记一条 `presetKeys: []`（只加校验，变体执行路径不变）；本树同步两次都是「测量不变」、事件状态 6165 例全部取回。
- **P3-2 默认开局缺标题贯通测试**：新增 `tests/xiyou_tianqi_title_flow`（38 项）：只发真实按键／触屏事件，走 entry.gd 的标题与三页。键盘：回车「新的游戏」→ 右移到已有存档的 2 号位 →「换一格」取消覆盖（旧档逐字不变）→ 再选「覆盖它」→ 难度下移一档 → 重抽（名单换了）→ 确认 → 大厅（道号、存档位、难度、阵容与确认页一致、存档里的天启篇标记）→ 回标题「旧的回忆」回车三次读回。触屏：同一条路点 5 号空位、第一档、重抽、确认、点读档页三处读回。开关回退：`XTianqi.ENABLED = false` 时回车「新的游戏」建原版 Map001 局（Map001 之后由 xiyou_flow 实走）。挂进 `选测对照.json` 的 entry 组。反向验证三项都咬住（「换一格」改成进难度、重抽不换名单、开关关掉仍走天启篇）。
- **P3-5 普通逃跑后地图曲晚一个消息窗（O-254，Kyo 11-11「按你设计优化一下」）**：照原版对齐。`XBattleScene._escape_success` 在逃跑消息出来前发新信号 `escape_audio`，`XMapScene.start_battle` 接到就停战斗曲、接过没放完的 ME、地图曲 0.5 秒淡入；收场时原有的几步再调一次，已换过的不动。回退：`XBattleScene.ESCAPE_MAP_AUDIO_EARLY = false`。`tests/xiyou_battle_me` 加真开一场可逃战斗的两段（开／关开关，消息窗停着时看地图曲和战斗曲，翻页后回地图），52 项过，反向验证两项咬住。
  - 玩家可见：逃跑成功时「开始逃跑了」一出来，地图音乐就淡入，不再等消息窗关掉。
- **Kyo 11-11 对审查 95 其余 P3 的决定**（登记已改）：P3-1 演出中状态格「不能」打开，保留现状（O-256 改「保留现状」）；P3-3 发行构建不露出「新版」卡片（O-199 状态注明）；P3-4 渡鸦暴击夹值「按你设计优化」，保留重制在压制后的值上先夹 0、不让负暴击率碰上超过 100% 的暴击回避负负得正（新登记 O-待定·渡鸦暴击夹值；没有开关，要回原版先补参照）。
- 验证：`测试增量同步.py` 95 项（新增假时钟到期／未到期／回退开关／审计关／暂存五种情形与 helper 声明环）、`测试事件探针分段.StateScopeTests`（新增重复 to 两种顺序与环三个负向夹具，真跑探针，占槽）、工具回归、语法检查；Godot 专项 xiyou_tianqi_title_flow、xiyou_tianqi_opening、xiyou_entry_release、xiyou_global_vars、xiyou_event_compare 四段全过。

## 交接板

- 下一步：工程行按 Codex 审查 95 可回到 100%（P2-2、P2-3 已修，待交叉核查）。
- 需要用户决定：审查 95 的 P3-1、P3-3、P3-4、P3-5 Kyo 已于 11-11 在本线程定了（见变更记录草稿），不用再挂。
- 用户试玩说明：逃跑成功时地图音乐在「开始逃跑了」出来时就淡入。
- 给总装（P3-6，共用文件只由总装改，下面是审查指出、本车道核对过仍未改的几处）：
  - `交接板.md` 第 121 行把 O-210 写成「未采用，只是提案」，`优化登记.md` 第 189 行已是采用、`project.godot` 里两项也在：改成已采用。
  - `交接板.md` 第 10 行仍是 11-10 的 93.3% 现场，和已合入的余项：按当前 97.2%（审查核定 97.5%）收掉。
  - `重制步骤清单.md` 第 21、34、36 行仍写 64.042%、「下次审查 75%，之后 95%」：改成 95% 阶段审查已做（Codex，截点 dev.444），并换掉 64.042% 的旧口径说明。
  - O-129、O-234、O-246、O-250 的状态说明和 O-247、O-248 状态栏（正文已写 Kyo 决定、状态栏仍「待确认」）与正式口径对齐。

## 进度账

- 工程（工具）：99 → 100（Codex 审查 95 因 P2-2 暂记 99%，P2-2、P2-3 本批已修）；待交叉核查后总装再定。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·审计先于命中 | `03_转换工具/同步正式西游.py` `audit_due_before_hit`／`run_probes`（工具，不影响游戏） | 工具，无原版对应；原来外层缓存整份命中与暂存命中在执行器之前，troop 与事件状态探针的每日审计在输入不变时永远轮不到 | 用缓存和暂存前先判审计到期，到期照常进执行器整份重跑并审计，日志记 `AUDIT_DUE`、返回 `auditDue` | Codex 审查 95 P2-2：漏依赖的旧产物会一直被放过 | 环境变量 `XIYOU_AUDIT_BEFORE_HIT=0` | cc（哪吒） | 已做 |
| O-待定·渡鸦暴击夹值 | `modes/xiyou/core/battle_logic.gd` `item_cri`（渡鸦非归属动作的暴击：`maxf(rate, 0.0)` 用压制魂海后的值） | v0.62.12 installCritFloor 外层按带魂海加成的完整面板判「攻击方暴击率 ≤0」，内层用压制后的值；负内层暴击率碰上超过 100% 的目标暴击回避时负负得正、照样能暴 | 在实际用的（压制后的）暴击率上先夹 0，负暴击率不会因为目标暴击回避过高反而暴击 | 审查 95 P3-4；极端组合，夹值本意就是防负负得正；Kyo 2026-11-11「按你设计优化」 | 暂无开关；要回原版先补这组参照（八戒），再加开关让外层改按完整面板判 | cc（八戒）；登记 cc（哪吒） | 已做（Kyo 2026-11-11 定） |

## 可优化（流程／工具／效率）

- 已做：P2-2 同时把「本轮应审计」写进同步日志（`AUDIT_DUE`）和 `PROBE_PLAN.auditDue`，审查报告「可优化」第一条要的「应审计／确已审计／取回复用」三项里，确已审计与取回数原本就在探针的一行注记里（「本轮整份重跑并审计」「取回 N 个」）。回退同上。
- 建议：审查报告「可优化」第二条（阶段证据记提交号、完整或选测、运行链接、源指纹，交接板只引用最新一条）归总装做，能一次消掉 P3-6 这类陈旧摘要。

## 验证

- 选测：`选测.py main --list` 列出 72 个场景，其中 70 个是 converter 组带出的 xiyou_rules* 与事件对照。本批跑了 xiyou_tianqi_title_flow、xiyou_tianqi_opening、xiyou_entry_release、xiyou_global_vars、xiyou_event_compare／_b／_c／_d，全过（日志 `04_验证/本地结果/并行测试/20261111_092342_1t_kplm9`）。xiyou_rules* 与 xiyou_status_power_panel 没跑：本批没改游戏代码，探针改动只加声明校验，合 main 后在本树跑的同步 97 个探针全部命中、结果「测量不变」，参照产物逐字没变，这些场景读到的东西和 main 相同；总装按影响面选测时可沿用。
- 工具：`测试增量同步.py`（95 项）、`测试事件探针分段.StateScopeTests`（占槽，2 项）、`工具回归.py`、`语法检查.py`（689 个 .gd，0 问题）全过。
- O-254 那批另跑了 xiyou_battle_me、xiyou_battle_bgm、xiyou_battle_end_ce、xiyou_battle_transition、xiyou_battle_options、xiyou_determinism、xiyou_battle_events、xiyou_dungeon、xiyou_floor_fortress029，全过（`04_验证/本地结果/并行测试/20261111_094223_acxusm_w`）；选测列出的其余两百多个场景（battle_scene／map_scene 被很多测试引用）没在本机跑，留给总装按影响面选测或云端。
- 反向验证：xiyou_tianqi_title_flow 三项都咬住；xiyou_battle_me 的逃跑音轨两项都咬住（去掉信号、开关关了也发）；测试增量同步的新用例在关掉修复（`XIYOU_AUDIT_BEFORE_HIT=0`）的子用例里断言回到整份命中，同一用例覆盖了改前行为。
- 同步：本树合 main 后跑 `同步正式西游.py --accept-additions`，测量不变，指纹已留。

## 待交叉核查

- 甲：`01_Godot工程/modes/xiyou/battle/battle_scene.gd`（`_escape_success`、`escape_audio`、`ESCAPE_MAP_AUDIO_EARLY`）、`01_Godot工程/modes/xiyou/map/map_scene.gd`（`start_battle` 接信号）、`tests/xiyou_battle_me.gd` 新两段；`00_设计/优化登记.md` O-199／O-254／O-256 三行改写。
- 甲：`03_转换工具/同步正式西游.py`（`audit_due_before_hit`、`run_probes` 三处）、`03_转换工具/mv_oracle/event_state_probe.cjs`（SCOPE_ROWS 重复／环校验）与 `probe_change_scope.json` 新增的一条声明（`presetKeys: []`，声明要甲档核）、`03_转换工具/incremental_sync.py`（helper 声明拒环）。
- 乙：`01_Godot工程/tests/xiyou_tianqi_title_flow.gd`、`07_开发环境/选测对照.json`（entry 组加一个场景）。

## 本分支提交

- b6be84e95 P2-2 缓存整份命中前先判到期审计＋假时钟回归
- 24cef22f0 P2-3 影响面声明拒重复 to 与环＋负向夹具，本次探针改动登记 presetKeys 空
- f073762de P3-2 天启篇标题→大厅贯通测试，挂进 entry 选测组
- c1d031f7d P2-2 回退开关写进长任务说明
