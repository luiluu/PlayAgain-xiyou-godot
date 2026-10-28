# 交付：codex/review-backlog-20261028-11

- 车道／工作者：核查／重制_沙僧_88（Codex）。
- 状态：WIP，勿合并。
- 正在做什么：固定 dc8057c1 核 Claude 难度继承 challenge4（a36d50a、9acfdf9、410bfb8、22772cd），不复核 Codex 历史、进度初值；第十期问题批保留待修。旧证据和现场保留。
- 范围：入队、读档、开战同步及强弱分类、超强者入队／出战；先检查参照夹具、对照原版、相关专项及收尾登记。

## 进行中

- 固定参照夹具 1080 例、三时机各 360、无 errors，runtimeInputs 与 generated manifest 相同；尚未确认夹具全部结果真实性。
- 两项长任务运行：`specialties88.log` 为难度继承及直接依赖专项；`native88.log` 从正式探针缩到 81 例独立重采，使用新脚本和新 sandbox 文件，不覆盖已有产物。先查状态并等待，结束后对比对应 cases 与 sourceIdentity。
- 原版 `syncActor`／`syncNativeTier`、强弱分类代码已定位，继续按调用时机、存档恢复、缓存与名单逐项核查；主角不存在的兜底及原单遗留须单列边界。

## 核查发现（待收口）

- **P3：重复入队指令漏做难度同步，实际触发范围待确认。** `xstate.gd` 的 `_add_actor` 仅在 `not party.has(id)` 内调用 `inherit_difficulty`；原版 addActor 包装每次都会先 `syncActor`。双端内存复现：队员 8 已在队、主角持有难度技能 5547、队员没有；再次调用 addActor／add_actor(8) 后，原版队员获得该技能，重制仍没有。复现脚本 `readd-native88.cjs`／`readd-godot88.gd` 存本期本地结果；正式数据存在该角色的入队事件，但其常规路径有已拥有判断，尚不能据此宣称正常游玩必现。`inherit_difficulty` 的调用点由 Claude 的 39c023798 引入；本期改写了同步机制但现有夹具只测初次入队。建议 Claude 检查事件可达性、补重复入队参照并修正调用时机；核查轨不修实现。

- 原版抽样 `native88.log` 已 done／0，81 例唯一、无错误；对比正式夹具 sourceIdentity、track 与各例完整内容均一致。诊断脚本和副本留本期本地结果，新的 sandbox 产物保留。专项仍 running，起初等待其他工作占用测试资源，不要重启。
- 排队期间为下一期预读 reach062／011／041 三批原交付，8 张图的冻结源字段与 generated 一致（仅 generated 增 `meta`），证据在 `review-backlog-20261028-12/map-comparison88.json`；只是预核数据，尚未跑专项或形成批次结论。
- 下一期预核续：上述八图直接遇敌表与事件战斗指令引用的 23 个敌群、30 个敌人、43 个行动技能无缺项；敌人 54 的原始生命值差异由 `<hp: 6000000>` 读库备注覆盖解释，技能原始 damage 字段一致、附加转换字段；未验证间接／脚本引用或战斗机制。三场地图专项以强制结束战斗推动流程，不能当作敌人技能实战覆盖。
