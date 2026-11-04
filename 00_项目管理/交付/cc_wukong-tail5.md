# 交付：cc/wukong-tail5

- 车道／工作者：C 规则／机制·悟空（cc）
- 状态：进行中

## 变更记录草稿

## 2026-11-04 【cc·悟空·未经审查】跳过回合的收尾钩子逐个核对原版：全部一致，补镜骸反噬例（dev.待定）

派单：审查 38 P3-4——tail3 把行动收成 `ended` 门后，跳过回合的敌人／角色漏没漏回合结束效果，用原版实测定。**结论：没有新差异，游戏代码一行没改**，只补了探针和专项。

- 原版层级（读冻结正式源）：敌人被控时 YEP `processTurn` 没有当前行动，不 `startAction`，也不 `endAction`，所以挂在 `BattleManager.startAction／endAction` 上的包装（谷雨、屠苏、璇、心钢、狂妄、种族、小猫、异化、绑定、BuffsStatesCore 的 actionEndState 等）整串都不跑；角色走 OTB `startOTBInput→makeActions→startAction→endAction`，包装会跑，但没有行动，tail3 的 13 个专属角色实测全部读数不变。
- 新量：`stunned_turn_probe` 加 `gate.mirror`（镜骸反噬）：角色打充能的镜骸 → 反噬 93（5215→5122）；角色被控跳过、镜骸被控跳过两步生命都不变；重新充能后再打，反噬照常 93。原因是 `A.root` 在 `startAction` 建、`endAction` 收，跳过回合没有 root（角色 `startAction` 的行动为空 → root=null，敌人不进 startAction），也不会留旧 root 串账。重制 `act` 的跳过分支不调 `XAlienBattle.begin`，`finish` 见 root 空直接返回，一致。
- 专项：`xiyou_stunned_turn` 16→17 例，加 `_gate_mirror`（9 条断言，含充能位和敌人生命）。

### 已核、一致（跳过回合的收尾钩子逐个）

| 钩子（重制 `act` 里） | 原版挂点 | 跳过回合 | 依据 |
| --- | --- | --- | --- |
| 屠苏 `XTusu.end_action`、谷雨 `XGuyu.end_action`、小猫 `XCat.end_action`、心钢、狂妄 | endAction 包装 | 敌人不跑；角色无变化 | tail3 `gate.party`、`actor.*` |
| 璇 `XXuanBattle.end_action` | endAction 包装 | 敌人不跑；被控角色无变化 | `xuan_auto` 的 `skip_*` 例（tail3 已补）、`actor.xuan` |
| 异化 `XAlienBattle.finish` 的连命 `sync_relations` | endAction 包装 | 敌人不跑（tail3 已修） | `gate.lifelink` |
| 异化 `finish` 的镜骸反噬 | endAction 包装，读 `A.root` | 都不触发 | **本期** `gate.mirror` |
| 异化蚀术封印 `release_seals`／`idle_window` | endAction 包装 | 门外单独走，`idle_window` 要 `can_move`，被控不列 | O-116，读码一致 |
| 种族 `XRaceBattle.finish` | endAction 包装，读当前行动记录 | 跳过回合没有记录，直接返回 | 只读码，没开例（同 tail3） |
| 绑定 `XBinding.end_action` | endAction 包装 | 角色走（clear／validate）、敌人不走 | tail3 `gate.party.bound` |
| 黑闪 `break_chain` | processTurn／otbCheckIfBattlerIsUnable 包装 | 不能行动连闪归 0 | tail3 |
| BuffsStatesCore actionEndState | endAction 包装 | OTB 的 endAction 整个替换，不触发 | 重制 `NEVER_FIRED` 已登记 |
| 米拉／奈叶／谷雨 afterAction 等 `started` 段 | endAction 包装 | 角色被控照走，读数不变；敌人 `started=false` 不走 | `actor.mira／nanoha／guyu` |

## 交接板

- 下一步：无（审查 38 P3-4 销账）
- 用户试玩说明：无变化
- 需要用户决定：无

## 进度账

- 无变化（只补核对与专项）

## 可优化（流程／工具／效率）

- 建议：`选测.py` 把 oracle 探针（`mv_oracle/*.cjs`）一律归 converter 类，改一个探针脚本就选出 19 个规则场景（抽样后）。探针只写 `.sandbox/` 和拷出的夹具，若夹具改动已单独选中对应专项，探针本身可只选对应专项＋`探针登记检查`，预计每次探针小改省 10 分钟以上；归 tools 车道。

## 验证

- `语法检查.py`：532 个 .gd 0 个问题。
- `xiyou_stunned_turn`：59/59（改前 50/50，新增 9 条）。
- 选测 `选测.py main --list` 19 个场景（含抽样），`CHECK_JOBS=2` 本机跑：见下「选测结果」。
- `探针登记检查.py` 通过。
- 没做反向验证：`gate.mirror` 咬不住门写错（root 为空时 finish 本来就空转），它是对「跳过回合不反噬、不留旧 root」这个原版行为的记录；门本身由 `gate.lifelink`、`gate.party` 咬住（tail3 已反向验证）。

## 待交叉核查

- 无 `battle_logic.gd` 等核心文件改动。核查只需看 `stunned_turn_probe.cjs` 的 `gate.mirror` 序列是否真覆盖「角色跳过／敌人跳过」两条路径，以及上表「读码一致」几行（种族、BuffsStatesCore）是否同意不开例。

## 本分支提交

- 见 git log（分支 cc/wukong-tail5）
