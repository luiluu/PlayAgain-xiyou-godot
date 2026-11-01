# 交付：cc/nezha-tools31

- 车道／工作者：C 工具／cc（哪吒，新会话接旧哪吒的 WIP）
- 状态：可合并

## 变更记录草稿

## 2026-11-01 【cc·哪吒·未经审查】tools31：smart_ai 共用布置、探针登记守卫、airship_view 名牌等待改按条件（dev.待定）

- **smart_ai 同敌群共用布置**（`tests/xiyou_smart_ai.gd`）：原来每条伤害行、每个选择用例都重新开局（setup 约 43 毫秒、两万多次）；现在同一敌群×场面连着的几条共用一次布置，布置次数降到每份约 650。复用前比一遍「战斗指纹」（双方 HP／MP／TP、状态与回合、增减益、冷却、护盾、各项能力、学会的技能、物品与开关、随机流快照、回合数），与刚布置完不同就丢掉重布置并记入 drift，`share_setup_isolated` 判失败并列出哪组哪些字段。回退：环境变量 `XIYOU_SMART_AI_SHARE=0`。16 份合计 83249/83249 通过（原 83233＋每份新增 1 条隔离断言）。旧哪吒 WIP 里留下的调试计时（tick／TIMES）已删，`alien_projection` 里被改坏的缩进已修。
- **探针登记守卫**：新增 `07_开发环境/探针登记检查.py`，接进 `检查.sh`（文档与登记之后）。`mv_oracle/*_probe.cjs` 须在 `同步正式西游.py` 的 PROBES 里，或有同名夹具 `tests/fixtures/<名>_oracle.json`（如 yunshang_probe），否则列入 `探针登记豁免.json` 并写明去处，不然判失败。现有 121 个探针，豁免两个：`otb_probe`（夹具叫 otb.json）、`state_effects_tp_context_probe`（补充证据，手动跑）。
- **xiyou_airship_view 的 plate_airship 偶发**：根因**没有复现出来**（空载 6 次、再加 14 个满载进程拖到约 3 倍慢 8 次，全过）。读代码的推测：名牌由地图 `_process`（画面帧）按物理帧里改的状态摆放，测试只固定等 3 个画面帧，负载高时物理帧会挤在少数画面帧里。已把 `plate_walk`、`plate_airship` 前的固定 3 帧等待改成按条件等（`_plates()`，最多 120 个画面帧，至少让出 3 帧）；断言本身不变。若之后还偶发，说明根因另有其处（先查 `_update_vehicle` 里 `airship.real` 与 `player.real` 的同步时机）。

## 交接板

- 下一步：无新增
- 用户试玩说明：无（只改测试与检查工具）
- 需要用户决定：无

## 进度账

- 无（工具车道）

## 可优化（流程／工具／效率）

- 已做：smart_ai 共用布置（`XIYOU_SMART_AI_SHARE=0` 回退）；探针登记守卫（删 `检查.sh` 里那一行即回退）。
- 建议：smart_ai 单份在满载下仍要约 17 分钟（并行 3、共用槽排队），共用布置后瓶颈多半转到 `XSmartAI.choose` 本身，值得测一遍再决定是否继续（工具车道）。

## 验证

- `语法检查.py` 通过；`xiyou_smart_ai*` 16 份 83249/83249；`探针登记检查.py` 通过；`xiyou_airship*` 3 个场景全过（条件等待改动后）。
- 没跑全量检查（车道规则）。

## 待交叉核查

- `tests/xiyou_smart_ai.gd`（指纹字段是否漏了能被伤害行改动的状态）、`探针登记检查.py`

## 本分支提交

- c956ec98 旧哪吒 WIP（共用布置初版）
- eb7a761c 整理 WIP＋探针守卫
- 本次：airship_view 条件等待＋交付单
