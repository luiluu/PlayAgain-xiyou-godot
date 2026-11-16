# 交付：cc/t036-worktree-setup

- 车道／工作者：T036 新建工作树补引擎与 generated／cc（Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·未经审查】T036 新建工作树 --快速：Orca 建树后自动补引擎软链与 generated 克隆（dev.待定）

- 起因：T022 回报 Orca 自己建的树（`orca worktree create`）不走 `新建工作树.sh`，缺 `当前Godot.app` 和 gitignore 的 `modes/xiyou/generated`（1.5G），XDB 读不到 manifest、`start_troop_2..6` 全挂，引擎要手动软链。
- `新建工作树.sh` 新增 `--快速 <路径>`：引擎软链＋generated／.godot 用 `cp -c`（APFS 克隆）带过去，不跑转换器和 import，约 4 秒；主工作区没有 generated 就跳过并提示（退出码 0）；已有的不覆盖，幂等。
- 软链（`当前Godot.app`、`引擎`）写进公共 `info/exclude`，不入库（`.gitignore` 的 `引擎/` 带斜杠挡不住软链）。悬空软链按「已有」处理，原先 `[[ -e ]]` 会让 `ln -s` 撞名后在 `set -e` 下整段退出。完整 `--补齐` 共用同一段 helper，主工作区缺 generated 时也不再因 `cp` 失败退出。
- 接线：仓库根新增 `orca.yaml`（`scripts.setup` 调 `--快速`，失败不挡建树）；规则/天启篇三方协作.md 第二节记一句。Orca 要 `--setup run`（或 app 里批准一次）才跑钩子。
- 测试：`测试快速补齐.py`（临时库：软链可解析、generated 克隆成真目录、git status 干净、幂等、不覆盖、悬空软链、缺 generated、主工作区拒绝、orca.yaml 接线），接进 `工具回归.py` 和 `检查.sh`。
- 只改工具，不改游戏，不递增开发编号。丙档。

## 交接板

- 下一步：派车道时 `orca worktree create` 加 `--setup run`；首次可能要在 Orca 里批准运行 orca.yaml 的 setup。
- 用户试玩说明：无
- 需要用户决定：无

## 进度账

- 无（工具改动）

## 可优化（流程／工具／效率）

- 已做：`--快速` 档（回退：删仓库根 orca.yaml 即不自动跑，脚本其余行为不变）。
- 建议：快速档不重跑转换器，分支落后 main 且改了切片时仍要车道开工 `--补齐`；若常有车道漏跑，可让总装派单模板把 `--setup run` 写死。

## 本分支提交

- 见 git log
