# 交付：claude/bajie-zhenqi2

- 车道／工作者：B 界面／C 规则／八戒（Claude，重制_八戒_14 开头，上下文到 49% 交给下一个八戒会话）
- 状态：进行中——只做了开工准备：从 main（dc4d29a）切出分支、`新建工作树.sh --补齐` 已刷新产物与导入。代码尚未开始，无未提交改动。

## 接手说明（给下一个八戒会话）

- 任务（唐僧 2026-10-17）：真气第二批——突破与瓶颈之战（心魔 901／天劫 823，`HEART_TROOP` 演员 1→770；方桌大厅闭关 NPC 入口，事件备注 `<CodexZhenqi: retreat>`）、突破奖励与道法选择（`DAOFA` 九项、`choice.split`／`choice.all`、固定奖励技能 `fixed:*`）、主菜单「真气」（`openFromMenu` → 地图解释器执行 `CodexZhenqi.retreat`）；神兵试炼／本命兵牵连太多可留第三批。
- 源：冻结源 `js/codex/runtime/installNativeZhenqiRuntime.js` 第 89～90 行 breakthrough、199～278 行闭关流程、291～334 行门槛／奖励／道法缩放（daofaScale、skillView、破甲 2705）。第一批已做的部分见框架维护约定「真气与修行页」：`core/zhenqi.gd`（XZhenqi）、`core/guide.gd`（XGuide）、`mv_oracle/zhenqi_probe.cjs`、`tests/xiyou_zhenqi`。
- 规则：严格级，探针补用例（同一个 zhenqi_probe 或新探针；新探针要加进 同步正式西游.py PROBES 与 oracle_additions KEYS）；记账只在规则层；加成照旧只显示、不乘进伤害。闭关 NPC 若在大厅事件里（悟空的切片），只在 `xiyou_slice.json` 的 keepEvents 加该事件这一处并在本单写明，别动其它切片内容（悟空在做十三层以后副本）。主菜单「真气」现在灰显（`ui/menu.gd` 第 29 行）。
- 编号：优化只用 O-048（不够向唐僧要）。文档写「本批」，不写编号占位。
- 交付前：`git merge main`、本工作树跑 `同步正式西游.py --accept-additions` 留指纹、`检查.sh --oracle`，本单改「可合并」。

## 本分支提交

- （尚无）
