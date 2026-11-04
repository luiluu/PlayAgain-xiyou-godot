# 交付：cc/review-40

- 车道／工作者：审查（核查轨，不写游戏代码）；从 main `d4b149ee`（含 passive1）切出
- 状态：可合并（只含文档：核查报告、进度核定、本交付单；没有代码改动）

## 变更记录草稿

## 2026-11-04 【cc·审查】核查 rules8、dot1b、steal1b、dot2、gauge1、gaps6、tools62、rules9b、passive1、tail5、tools61／63／64，及进度核定 86.2%

- 核查覆盖：cc/bajie-rules8（4f3b08ab）；cc/wukong-dot1b（47452c03）；cc/nezha-steal1b（d48e2a03）；cc/wukong-dot2（9d9f65f9）；cc/nezha-gauge1（35d73053）；cc/wukong-gaps6（e389b170）；cc/nezha-tools62（df7c7e04）；cc/bajie-rules9b（c3dbd74e）；cc/wukong-passive1（d4b149ee）；cc/wukong-tail5（8e2769ab）；cc/nezha-tools61（77d1ad3d）；cc/nezha-tools63（1d714256）；cc/nezha-tools64（02a62ee3）
- 结论：P1 无，P2 无，P3 十二条，全部通过。要点：①`xiyou_dot.gd` 142、339 行两处恒真断言（`or true`）；②732 等「靠换行补分号才合法」的块，转换器整段 token 比对对换行不敏感，改成单行也会被译成有效果的程序（数据里碰不到，放行妥，建议加原文哈希守卫）；③passive1 把防御读法收拢到 `is_guard()`，但基础实现缺原版 `&& canMove()`；④gauge1 的「实现与备注一致」测试用同一个正则自证；⑤`tusu_xuan.gd` 头注释过时。详见[报告](核查报告_20261104_审查第40期.md)。
- 进度：核定 **86.2%**（原始 86.23%，区间 83.7～86.8），[报告](进度核定_dev323_20261104.md)。
- 验证：读 diff 对冻结 v0.28 插件源码；node 复现 JS 语法错误；`测试选测.py` 119/119、`测试状态js翻译.py` 21/21、`测试ext_dot.py` 6 项；没跑 Godot。

## 交接板

- 清掉「待交叉核查」里上述 13 批对应的行（销账靠上面变更记录条目里的提交号与分支名，`待核查.py` 自动识别）。
- 下一步建议（交总装派车道，审查只记不修）：
  1. 清 `xiyou_dot.gd` 两处恒真断言（改成真比较：原版 `o.after.states` 对重制状态集）。
  2. 转换器给 ASI 依赖块加原文哈希或换行 token；然后可删 `测试状态js翻译.py` 的 732 跳过。
  3. `XBattler.is_guard()` 补 `&& can_move`（passiveGUARD 支保持不看）。需先量一例原版：防御后被挂不能行动再受伤。
  4. 改 `tusu_xuan.gd` 头注释。
  5. 抽奖动画移不移出养成分母：请 Kyo 定。
- 需要用户决定：抽奖动画 Star_LotteryAnimation（930 行）是否移出养成分母（移出后核定 86.8%）。默认：不移出，按低算。

## 进度账

- 九行按[进度核定_dev323_20261104](进度核定_dev323_20261104.md)「结论」表改；`进度账.py --write --as-of dev.323`；`当前状态.json` percent 86.2、asOf dev.323。

## 可优化（流程／工具／效率）

- 无

## 待交叉核查（改了核心文件）

- 无（本分支只有文档，提交尾注写「核查: 无」）。

## 验证

- 见核查报告「本期没有覆盖」与核定报告「本次验证」。

## 本分支提交

- 见 `git log main..cc/review-40`
