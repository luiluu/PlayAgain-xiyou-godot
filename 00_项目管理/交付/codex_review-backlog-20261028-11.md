# 交付：codex/review-backlog-20261028-11

- 车道／工作者：核查／重制_沙僧_88（Codex）。
- 状态：WIP，勿合并。
- 正在做什么：固定 dc8057c1 核 Claude 难度继承 challenge4（a36d50a、9acfdf9、410bfb8、22772cd），不复核 Codex 历史、进度初值；第十期问题批保留待修。旧证据和现场保留。
- 范围：入队、读档、开战同步及强弱分类、超强者入队／出战；先检查参照夹具、对照原版、相关专项及收尾登记。

## 进行中

- 固定参照夹具 1080 例、三时机各 360、无 errors，runtimeInputs 与 generated manifest 相同；尚未确认夹具全部结果真实性。
- 两项长任务运行：`specialties88.log` 为难度继承及直接依赖专项；`native88.log` 从正式探针缩到 81 例独立重采，使用新脚本和新 sandbox 文件，不覆盖已有产物。先查状态并等待，结束后对比对应 cases 与 sourceIdentity。
- 原版 `syncActor`／`syncNativeTier`、强弱分类代码已定位，继续按调用时机、存档恢复、缓存与名单逐项核查；主角不存在的兜底及原单遗留须单列边界。
