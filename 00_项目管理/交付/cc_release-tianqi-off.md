# 交付：cc/release-tianqi-off

- 车道／工作者：总装／cc（总装）
- 状态：进行中

## 变更记录草稿

## 2026-11-11 【cc·总装·未经审查】发行整包先不开天启篇内容，只带天启篇标题与启动画面（dev.待定）

- Kyo 11-11：「新整包只有天启篇的标题和载入界面，游戏和目前的改版内容基本一致，完整的天启篇内容我们后面完成了之后单独更新」。
- 天启篇的游戏规则（五档难度、随机阵容、助力位与换人、通关抽角色、装备栏、数值表、去羁绊、去一线生机等）都只认存档里的天启篇标记（`XTianqi.active`），标记只在「新的游戏」走天启篇开局时写。新加 `XTianqi.RELEASE_OPEN`（默认 false）和 `XTianqi.new_game_enabled()`：发行构建里新游戏走原版开局（Map001 → 选英雄 → 教派 → 大厅），整局照改版；开发版、测试照 `XTianqi.ENABLED`。
- 天启篇标题（`XTianqiTitle.available`）和启动动画（`XIntroAnim.available`）不再要求 `XTianqi.ENABLED`，跟天启篇内容解绑。
- 回退：`XTianqi.RELEASE_OPEN = true` 发行构建也走天启篇开局（天启篇做完发补丁开放就是改这一行）。
- 专项：`xiyou_tianqi_opening` 加发行模拟三项；`xiyou_tianqi_title`、`xiyou_splash_autosave` 的「天启篇关掉时不出新标题／不放动画」改成照样出。
- 玩家可见：新版启动后是天启篇的启动动画和新标题，「新的游戏」进的仍是现在改版的开局和内容。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi.gd` `XTianqi.RELEASE_OPEN`、`new_game_enabled()`；`entry.gd` `_on_new_game` | 开发版新游戏走天启篇开局（O-260） | 发行构建在天启篇做完前新游戏走原版开局，天启篇标题与启动动画照放 | Kyo 11-11 整包只带天启篇标题与载入画面，完整内容以后单独更新 | `XTianqi.RELEASE_OPEN = true` | cc（总装） | 保留 |

## 交接板

- 下一步：天启篇内容做完后发补丁把 `XTianqi.RELEASE_OPEN` 改 true。大厅的洞二阶段等 Kyo 给设计（v0.62.12 只有一阶段 rift1，重制已照移植）。
- 用户试玩说明：发行包启动动画、天启篇标题；新游戏是原版开局。
- 需要用户决定：无

## 进度账

- 无变化（发行配置）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log
