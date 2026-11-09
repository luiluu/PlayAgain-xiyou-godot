# 交付单 cc/rules-gaps9（八戒，战斗内公共事件覆盖）

状态：**未完成，接续中**（额度到线前 WIP 停手）

## 做了什么

- 盘点：内容覆盖报的 battleOnlyCommonEvents 232 个里，210 个只由角色技能／物品（效果 44）触发、22 个由敌人技能触发；troop 例玩家只普攻，基本跑不到它们。
- 原版试跑（scratchpad 探索脚本，不入库）：每个 CE 让会起点技能的角色出手一次，213 个事件跑起来、115 个带强制行动；
  没出手的 16 个全是高号角色（96、104、106、107、122、123、127、142、147、148），addActor 被拦，探针里改成 addActor 后直接写 `_actors`；
  28／104／1316 的起点技能有两个效果 44，实际跑的是另一个 CE（1157／1158／388），探针优先挑只有一个效果 44 的起点。1516 原版跑视频报错（Graphics._playVideo，无场景引擎）。
- `troop_event_probe.cjs`：尾部新增 SKILL_CE 用例（按原版数据算战斗专用 CE，237 个 ⊇ 切片的 232；每 CE 按「111 角色会技能」分 met／unmet，没有就 plain）。
  用例带 party，键 (troop, paid, variant)，variant＝`ce<号>.<met|unmet|plain>`。旧 1051 例序号不变。
- `tests/xiyou_troop_events.gd`：`_skill_ce_case` 对照预约的 CE、强制行动［行动者, 技能］、CE 里 313／333 提到的状态、跳过指令。规则流全 0.5。语法检查通过，**还没跑过**。

## 接续要点

1. 尾部新例已在 clone 里跑：`XIYOU_PROBE_FROM=1051 XIYOU_PROBE_SHARD=i/2 XIYOU_TROOP_OUT=.sandbox/sce_i.json`（占槽.py 包着），产物在 `mv_oracle/.sandbox/sce_0.json`、`sce_1.json`；按序号交错拼回（i%2）接到 generated/oracle/troop_events.json 的 1051 例后面，本地跑 xiyou_troop_events*。
2. 看失败项分真缺（Godot 规则没接上）和比法问题，真缺补实现。
3. 交付前：合 main、`同步正式西游.py --accept-additions`、选测带 `xiyou_troop_events*` 全分段、`工具回归.py`。

## 验证

（未跑）

## 待交叉核查

- troop_event_probe.cjs（甲：mv_oracle 探针）、tests/xiyou_troop_events.gd

## 可优化

- 无
