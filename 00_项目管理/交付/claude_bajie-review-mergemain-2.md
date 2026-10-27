# 交付：claude/bajie-review-mergemain-2

- 车道／工作者：核查／八戒（Claude）
- 状态：进行中

## 接续（八戒，2026-10-27，上下文接近 40%，只开了工）

刚开工就到了上下文线，下面的事一件都还没做。接手的人从头按派单做：

- **派单原文要点**：总装 2026-10-27 派的期二，核查集成分支 `codex/passive-content-merge-main`（23519cff）里 Boss 系列六张原交付单的实现：
  - `00_项目管理/交付/codex_passive-content-boss.md`
  - `codex_passive-content-boss-context.md`
  - `codex_passive-content-boss-output.md`
  - `codex_passive-content-boss-react.md`
  - `codex_passive-content-boss-sequence.md`
  - `codex_passive-content-boss-state-origin.md`
- **一并核**：期一只核了一部分的 f4dff07e、1f63aa68、c635a38d、39721928、5d909854，属于哪张单就并进哪张一起核。
- **原版探针确认**：期一报告的 P3-3「开战标签状态和上场结果槽残留」。状态 1337～1340 既是开战标签状态，又是 removeAtBattleEnd；要确认连打两场时，第二场开战还能不能把它们挂上，以及重制在地图上 onTurnEnd 时是否清结果槽。
- **重点**：
  - Boss 来源域的推入和恢复是否成对；
  - 低倍率遮蔽；
  - 护盾前后的次序；
  - settled／direct 两层防止二次缩放；
  - 与 battle_logic、resource_context 的边界。
  - 各单声明的「限制」（例如 JS 宿主未移植）不算缺陷，只核声明范围内的。
- **怎么找提交**：用 `git show codex/passive-content-merge-main:<单的路径>` 读，提交号在各单的「本分支提交」「最终交付」两节。boss 单在第 41 行有「本分支提交」，其余几张的「最终交付」分别在：
  - boss-context 第 9 行
  - boss-react 第 21 行
  - boss-sequence 第 8 行
  - boss-state-origin 第 33 行
- **验证**：
  - 照期一的做法：`git worktree add --detach <scratchpad>/mm 23519cff`，再 `长任务.py start` 跑 `新建工作树.sh --补齐`。godot import 可能要排 20 多分钟的共用槽。
  - 跑每张单列的新增专项和最相关的直接依赖，不跑全量，不跑 24 段规则。
  - 跑完删掉临时检出（`git worktree remove --force`）。
  - 注意：补齐时参照数据是从主工作区克隆的，条数可能和沙僧报的不一样，见期一报告第四节。
- **交付**：
  - 报告写到 `00_项目管理/核查报告_20261027_沙僧82_集成期二.md`，格式照期一报告。
  - 销账范围只写逐个核过的提交号，不写分支名。
  - 提交尾注：`执行者: Claude（八戒）`、`核查: 待Codex`。
- **停手条件**：
  - 发现 P0 或 P1，马上告诉总装（local_102f2c6b-6a6f-45de-a0c6-8d8732d0c04c）；
  - 5 小时额度到 80% 时收尾，WIP 提交；
  - 上下文到 40% 时写接续，WIP 提交。

## 变更记录草稿

（待写）
