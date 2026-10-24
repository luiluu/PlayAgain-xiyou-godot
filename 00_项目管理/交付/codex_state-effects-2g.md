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
