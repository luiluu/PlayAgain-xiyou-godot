# 交付：codex/state-effects-2f

- 车道／工作者：框架／沙僧（Codex，重制_沙僧_49）
- 状态：进行中
- 位置：沿用 `.claude/worktrees/state-effects-2b`，保留所有未入 Git 的原版证据。

## 规模与边界（开工）

- 本期仅战斗路径的 607／609／857 Battle 与 1334／1336 Apply 五个纯 TP 整块：显式资源域包装及嵌套恢复、行动结果槽、角色／敌人分层刷新、开战 TP 顺序；逐项对照 dev.136 的 26 例参照。
- 顺带 F31 的 stages 按阶段分别计数，以及 additive_rate 按原版浮点求和顺序、图鉴收回 1e-9 容差；跑相关战斗对照。
- 文件限于用户交接的资源／状态／战斗核心、actor 的 add_state／刷新、相应转换器／探针／专项。地图与菜单根域及宠物／种族界面不动。
- 若需要交接范围外的文件，或现有 state_effects／troop_events／settlement／review135／rules 出现原版参照以外的变化，记录原因后停手；地图／菜单根域需要时先报告，不把战斗支持冒充全局闭环。
- 探针若未改，不跑正式同步；有改才跑一次 --accept-additions。仅相关专项，不跑全量检查。

## 开工记录

- 已读 AGENTS.md、只读交接板、2e／第三四期目标设计、dev.136～147 各条与车道规则。
- main 起点 `3ac5779d`；旧树分支 `codex/state-effects-2e` 的已提交现场干净，原版证据保留。
- 新分支从 main 创建；下一步补齐工作树并检查生产调用边界。

## 验证

- 两小项最终专项待跑。预检批次选到了不存在的 floor_run_d 且 rules 前缀扩大到 24 场景，随后开始 TP 草案会使测试版本漂移，已主动中止，不计通过。长任务状态曾标 orphaned；已核对进程表，包装器及其独占进程组 77660 均无进程，未终止其他车道。
- 草案转换边界测试 8/8、Godot 导入无脚本错误；均只代表草案可加载，不代表 TP 功能验收。
- 预览边界现场复现（原生测试场景、exit0、无脚本错误）：`plain_clone=true`、`scoped_clone=false`、`live_context_preserved=true`。证据：本树 `03_再刷重制_Godot/04_验证/本地结果/state-effects-2f/preview-boundary-scene.log` 及同目录 `_state_effects_boundary.gd/.tscn`。此前两次入口错误日志也原样保留，不算成功证据。

## 停手原因与所需交接

- 2e 要求 holder 绑定显式资源域，并保证生命周期内调用预览时不继承／操作真实资源域。`core/formula_context.gd:66` 的 `clone_battler` 遍历全部脚本变量，除 state_origins 外没有运行时域排除；新 `lifecycle_context` 含 XResourceContext、队员等对象，`XFormulaProgram._detached` 会拒绝，直接返回 null。不是数值差或随机容差问题。
- 需要补交 **`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/formula_context.gd`**：把新运行时域按明确规则从影子克隆中剥离，并补生命周期内预览回归；不能把引用复制给影子，也不应放宽通用 `_detached` 守卫。该文件未列入本轮交接，按用户指令停手，未修改。
- TP 草案已以 `WIP:` 提交保存，再单独提交撤回，最终分支不含其生产／转换器变更。尚未完成五块与 26 例 Godot 对照，未翻译仍 444。地图／菜单根域未接，期二至六未开；期五仍等八戒接口。
- 后续可从 WIP 提交恢复草案作参考（不是已验收实现）；先明确上述文件交接，再接续原 2f 验收，不跳到期三。

## 交接板／进度账

- 不自行增加完成度；由唐僧合并与 Claude 交叉核查后登记。
