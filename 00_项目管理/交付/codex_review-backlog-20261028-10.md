# 交付：codex/review-backlog-20261028-10

- 车道／工作者：核查／重制_沙僧_87（Codex）。
- 状态：WIP，勿合并。
- 正在做什么：固定 dc8057c1，先核 Claude attack-query3 的敌人无行动／不能用、角色执行、禁用号角及测试边界；前九期按各自交付单登记，不复核自身工作。
- 前九期交付单均为祖先，总装按实际合并顺序处理，避免重复导入；继续沿用工作树，旧证据全部保留，不改共享文件。

## 核查检查点

- 目标批：607dd6b、cf39218、2473344、44abfba、5c850de、12ecc0f（均须再核尾注）；`attack-original.md`、`attack-diff.patch`、`attack-registration.patch` 已存本地结果。
- 冻结原版 `processTurn` 对敌人检查 `isValid`；OTB 角色输入后直接 `startAction`，与本批处理方向吻合。正式 `xiyou_attack_query` 的 skip 组需注意它明确忽略原版 `valid`、`forcedValid`、`phase` 等字段，限定于实际逐项比较。
- 单独重采 `attack_query_probe`，done／0，43 例无错误，sourceIdentity 与全部 cases 和工程 generated 相同；原件与诊断源保留。收尾登记与原单仅开发编号替换和额外注明重复函数修正；该修正删掉 challenge4 添加的重名函数并保留已有实现，challenge4 整批尚待另核。
- 正式相关专项 `attack-specialties.log` 正在运行（名称前缀会展开多场），不得提前声称通过；查 status 后用等待任务脚本接续。仍需继续核实无行动的收尾路径、专项与测试边界、尾注及登记模拟，再做文档选测和交付。
