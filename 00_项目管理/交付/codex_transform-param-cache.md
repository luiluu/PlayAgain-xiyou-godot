# 交付：codex/transform-param-cache

- 车道／工作者：规则预检／沙僧（Codex，重制_沙僧_17）
- 状态：进行中
- 开工：2026-10-20，从 main bf42625 独立建立工作树；已读 AGENTS.md、主线交接板、交付规则并核对干净现场。转换器已在独立分支交付（3ec7a5b），本分支不复用它。
- 范围限制：当前悟空_25 与八戒_31 占满两条代码车道；本轮先做冻结源只读实测，只写本交付单和忽略的本地证据，不改受管代码、探针或参照基线。空出名额后才推进 Godot 实现。
- 运行：工作树补齐由独立长任务 `/tmp/transform-param-cache-prepare.log` 执行（runId `86f9ce2924404799bb8ae7f3169aa34f`，PID 73282）；接着等待同一任务，不重复启动。

## 变更记录草稿

## 2026-10-20 【Codex·沙僧·未经Claude检验】336 变身能力值缓存预检

- 原版行为须用 mv_oracle 实测：466→538 变身前暖过和没暖过的 ATK／DEF／MAT／MDF／AGI／LUK，以及普通 refresh、状态、buff、完全回复和回合边界的缓存失效。
- 现有实现只把 HP／MP 上限留在 stale_caps；敌人 param 每次重算。冻结源 G_StateParam 按参数惰性缓存非零值，krz_state_re 只有 need_refresh 时清 _baseParamCache；YEP_EnemyLevels.transform 仅清 _cacheBaseParam。源码信息仅用于设计实验，不能代替参照。
- 验证计划：守卫保持，只读冻结源、不加载真实存档，输出只落本工作树 mv_oracle/.sandbox；正式新增参照、只增接受、逐项 Godot 对照及全检留待代码车道可用后做。

## 交接板

- 下一步：先完成原版只读预检，登记逐项观测；代码车道空出后再改 battle_event_probe／Godot 变身缓存及测试。新增参照只增接受，交付前检查 --oracle 全过。
- 用户试玩说明：本阶段只做预检，游戏行为尚未修改。
- 需要用户决定：无。

## 进度账

- 预检不调整完成度；实现完成后仍由 Claude 独立核查。

## 本分支提交

- 从 main bf42625 开工，先登记范围与预检计划。
