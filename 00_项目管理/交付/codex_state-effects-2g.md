# 交付：codex/state-effects-2g

- 车道／工作者：框架／沙僧（Codex）
- 状态：进行中
- 起点：fetch 后从 main `2fba4b52`（dev.164）新建分支；沿用 state-effects-2b，旧原版证据不删。
- 范围：五块 TP 的资源刷新前置、运行时域从预览影子剥离、原版同点对照；每一可合并期单独提交。actor.gd 的 XTraining.param_bonus 保持原样。
- 边界：旧设计要求 Apply 在地图／菜单也有显式根域与操作结果出口；其入口在 mv_event_core／界面，未授权时保留 JS，不把战斗支持冒充全局闭环。先交能完成的 Battle 块与前置，若确需这些接口按用户停手条件交付。
- 原版 state_effects 26 例已有参照；不重跑有全局改写的旧 native22，只读既有证据。
- 收工只跑专项；不核查自己的提交、不自行增加完成度。

## 接续任务

- 期二：死亡图鉴与 ConsumeReduceAll|Zj|Mf|N 结算，相关 cat_probe／xiyou_cat 收紧；期三历史两项可砍，未开。
- 阶段审查职责已接收；未收到“阶段审查 N%”不启动，现账面49.6%。

## 验收现场（接手入口）

- 资源层前置与三块 Battle 已实现；转换器未翻译 444→441。1334／1336 Apply 只在专项里临时提供未来 op 验证刷新前置，生产仍 JS。
- 537 项 TP 专项初步通过（不放宽比较，不改参照）。合入 main `7fc0c310`（dev.165）后已重导入；无探针／切片改动，只有转换器状态块分支重生成。
- 即将以长任务运行相关专项：state_effects 两场、formula 前缀、troop_events 两场、settlement、review135、enemy_book、floor_run_c、combat。日志在 `03_再刷重制_Godot/04_验证/本地结果/state-effects-2g/final-related.log`；不运行全量检查。结束后将结果抄入本单，再删除本车道临时输出。
- 另有完整预览隔离边界待交接：`formula_execution.gd` 的预览复制结果槽调用 `resource_context.result(a/b)`，空槽会插入真实 slots；应由该文件改为只读读取（缺槽用 empty_result），本车道不越界修改。已存在槽的生命周期预览专项通过；不能声称所有预览入口已闭环。

- 验收选择修正：原37场排槽期间未启动任何场景，已主动终止；静态属性 rules24 段不受本次改动影响，最终仅跑13场直接相关专项（不把中止批次计作通过）。
- 预览空槽边界已在合main并重新导入后干净复现：available=true、journal=0、slots_before=0、slots_after=2，exit0、无脚本错误；临时场景和临时HOME已删除。
