# 交付：cc/rules-gaps10

- 车道／工作者：C 规则／机制／cc（八戒，scratchpad 克隆里做的，已推回本库；主工作区没碰）
- 状态：可合并
- 分支基点：`cc/rules-gaps9` 头 f0e7901b（rules-gaps9 还没合进 main，所以本分支包含它的提交；合并时先合 gaps9，本分支只多一个提交）

## 变更记录草稿

## 2026-11-09 【cc·八戒·未经审查】三咒凝魄（CE1365）只额外放一次（dev.待定，O-待定）

- 原版缺陷：心法「三咒凝魄」6927 写的是「三魔术*火会额外释放一次」，但 CE1365 强制出来的 6930 自己的效果 44 又是 1365，会心法时原版一直强制下去（参照 2 万帧里放了 714 次还没完）。
- 重制：`XBattleCommonEvent.EXTRA_ONCE`（默认 true）——公共事件正在跑时，它强制出来的行动再带「同一个」公共事件的效果 44，不再预约，所以 6930 放出后额外再放一次就停。判断见 `in_common_event`（`reserve_action` 里）；别的公共事件、别的技能不受影响。`CHAIN_LIMIT` 64 保留作兜底，开关设 false 就回到原版的连放（被 64 截停）。
- 测试：`tests/xiyou_troop_events.gd` 的 CE1365 用例（`troop2.ce1365.met`／`unmet`）开、关两支各比一遍：默认值断言为 true；开支只比参照的第 1 个强制行动并断言实际只放了 1 次；关支比前 64 个。
- 玩家可见：会「三咒凝魄」心法的角色放「三魔术*火」，现在是额外放一次就结束，不再无限连放。

## 优化登记（行草稿，O 号由总装分配，表格行格式同 `优化登记.md`）

| O-待定 | `modes/xiyou/core/battle_common_event.gd` `XBattleCommonEvent.EXTRA_ONCE`（`reserve_action`／`in_common_event`） | 会心法 6927 时，CE1365 强制 6930「三魔术*火」，6930 的效果 44 又是 1365，原版一直强制下去（参照 2 万帧放了 714 次没完） | 默认只额外放一次（Kyo 2026-11-09 定，心法文字「会额外释放一次」）；`CHAIN_LIMIT` 64 仍作兜底 | 原版无限连放，战斗不会结束、实际打不了；与心法描述不符 | `XBattleCommonEvent.EXTRA_ONCE = false` | cc rules-gaps10 | 待 Kyo 确认 |

## 交接板

- 需要用户决定：无（Kyo 已拍板按建议做）。

## 进度账

- 无（原版缺陷修复，不改完成度）。

## 可优化（流程／工具／效率）

- 无。附：只量 CE1365 的参照用例不必跑整段 381 例——在 mv_oracle 里拷一份探针把 `SKILL_CE.map` 改成 `.filter(x => x.ce === N).map`，`XIYOU_PROBE_FROM=1051`、`XIYOU_TROOP_OUT=` 写 `.sandbox/` 下（别的路径被文件系统守卫挡），经占槽.py，约 1 分钟；结果拼到 clone 的 generated/oracle/troop_events.json 末尾，测试用 `XIYOU_CE_ONLY=1365`。临时探针副本已删，没入库。

## 验证

- 本机 `xiyou_troop_events_sce*`（`XIYOU_CE_ONLY=1365`）全过；反向验证：把默认改 false → `extra_once_default` 失败；把判断短路 → `once_len [64,714]` 失败（均已还原）。
- 本机选测 16 个场景全过（17 分钟）：xiyou_battle_common_events、_common_event_child、xiyou_battle_events、xiyou_battle_start_event、xiyou_cond111、xiyou_determinism、xiyou_random_streams、xiyou_script_census、xiyou_script_gaps、xiyou_troop_events 全部 7 段。`工具回归.py` 全过（70 秒），`语法检查.py` 过。
- 注意：clone 的 generated 参照里只拼了 CE1365 的 2 个 skillCE 例（不是 gaps9 的 381 例），`_sce*` 场景只比了这两例；其余 379 例没变（本改动只在「公共事件强制出的行动再带同一公共事件」时生效，只有 1365 命中）。总装合并同步后全量再比。
- 没跑同步（克隆不是工作树，无产物指纹）；探针没改，不会触发整份重测。

## 待交叉核查

- 甲：`modes/xiyou/core/battle_common_event.gd`（战斗公共事件预约）
- 乙：`tests/xiyou_troop_events.gd`
