# 交付：cc/nezha-raven5

- 车道／工作者：C 规则／哪吒（cc，Opus）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·哪吒·未经审查】陈旧状态清除点补齐（审查 45 P3-1、P3-2），渡鸦头注释订正（dev.待定）

- **先量原版**：`mv_oracle/raven_reflect_probe.cjs` 加 13 例（夹具 `tests/fixtures/raven_reflect_oracle.json` 59→72 例）。
  - `refmid.tcr2.*`（行动 N 同 `refseq.reflect`：8 号魔法单体被反射回自己、侵蚀陈旧）中间夹一步，再由 e1 打两段：
    - 队友 1 号对 8 号出一次不伤害的技能（none／加 buff／回 HP／回 MP／加没特性的状态）：原版**都清**——连「什么效果都没有」也清，因为 8 号是这次行动的目标，收尾 removeImmortal 就 refresh 了；重制本来就一样（不是差异）。
    - 不经行动直接改（`ev*`：313 加／解状态、addBuff、gainHp、gainMp、gainTp）：原版**都清**（addState／removeState／addBuff 自带 refresh，gain 走 setHp／setMp／setTp 的 refresh）；**重制原来都不清**，e1 第一击仍读旧缓存（×0.9），原版 ×1.4——这是审查 45 P3-2 的真实差异。
  - `refzero.tcr2`（P3-1）：8 号 TP 99、e0 三段致死并加侵蚀；原版第二段请求的 hp 是负数、与 0 不同照样 refresh，第三段读新状态。重制本来就对得上（不是差异）。蛮骨（种族 6）限额用完那条没量（要搭整套种族现场），按原版代码顺序（先比请求值、再 limitHp）改。
- **改法**（新开关 `XBattleLogic.STALE_REFRESH_POINTS`，O-待定，见下表）：`XResourceContext.refresh`（setHp／setMp／setTp 与状态增减的 refresh）和 `XBattleLogic._refresh_battler`（313 改状态、加减 buff 等）开头清陈旧；`_execute_hp_damage` 的判据改成请求的扣血量 `value != 0`（原版 setHp 先比请求值、再 CodexRaces.limitHp），不再看扣完后的 hp。仍只在 `STALE_TIMING` 开着时生效（`stale_refreshed` 里判）。`false` 回到 raven4。
- `tests/xiyou_raven_reflect` 加 `refmid`／`refzero` 两类，548 项全过；回退支 `rollback.refmid.evbuff`（关掉开关时直接加 buff 后第一击仍读旧缓存，比值 1.4/0.9）。
- `raven.gd` 头注释（审查 44／45 P3）：「重制反射支不记帧」已过时——反射支照原版记帧（`reflect.*` 的狩猎、回响追加伤害落在渡鸦自己身上，专项全过），改成已移植并指向参照与测试；顺手去掉一处重复的 `## `。

## 优化登记草稿

| 编号 | 位置 | 原版 | 现在 | 理由 | 回退 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 清陈旧刷新点（`battle/battle_logic.gd` `STALE_REFRESH_POINTS`、`_refresh_battler`、`_execute_hp_damage`；`core/resource_context.gd` `refresh`） | 战斗里直接加减状态、加减 buff、回 HP／MP／TP、受伤 setHp 请求值不同，都 refresh、陈旧状态从此生效 | 照原版补上这些清除点（原来只在付费、removeImmortal、受伤 hp 变了、回合末清） | 对齐原版时序（审查 45 P3-1／P3-2） | `XBattleLogic.STALE_REFRESH_POINTS = false` | cc（哪吒） | 待用户决定 |

## 交接板

- 下一步：审查 45 P3-1、P3-2 可销账；蛮骨限额用完那一支没探针（只按原版代码顺序改），审查可抽看。
- 用户试玩说明：基本看不出——只影响「身上刚被加、还没进缓存的状态」在战斗事件改状态／加 buff／回血之后的下一击。
- 需要用户决定：上表 O-待定（默认开，照原版）。

## 进度账

- 战斗：无变化（P3 尾项）。

## 验证

- 合过 main（198dac5b），`新建工作树.sh --补齐`；没跑同步（本车道只改夹具式探针 `raven_reflect_probe`，不在 PROBES）。
- 专项：`xiyou_raven_reflect` 548／548（含新 `refmid`、`refzero` 与回退支）。
- 云端选测（`选测.py` 选中 209 个，云端按基准 d40c513b 选 404 个、13 片，提交 4e11b119，运行页 actions/runs/42015348511）：403 过，1 失败 `xiyou_weak_challenge`——原因是刚合进来的 weak1b 探针产物 `oracle/weak_challenge.json` 在本工作树还没生成（--补齐 时总装正在合并、没刷参照），与本车道无关；本机跑 `weak_challenge_probe.cjs` 补出产物后单跑 85／85 过。
- `语法检查.py` 通过；`工具回归.py` 全过（68 秒）；`回退开关覆盖.py` 无新缺口。

## 待交叉核查

- 改了 `battle_logic.gd`（`_refresh_battler`、`_execute_hp_damage`、新开关）、`resource_context.gd`（`refresh` 开头一行）：`refresh` 调用面很广，清陈旧只在角色有陈旧状态时才动（`stale_refreshed` 先判 `STALE_TIMING`、`XActor`、列表非空），请重点看有没有原版不 refresh、重制却走 `refresh` 的路径把陈旧状态清早了（现有 refseq／refnest／refstate 例都还过）。
- 探针 `ev*` 是直接调 addState／addBuff／gainHp 等，重制侧对应 `_change_actor_state`（313）、`sequence_buff`、`gain_hp`、`_operation_resources().gain`，口径是否对等。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 `git log main..cc/nezha-raven5`
