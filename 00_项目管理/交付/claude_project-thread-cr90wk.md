# 交付：claude/project-thread-cr90wk

- 车道／工作者：云端线程「云端并行跑选测」（Claude，云端）
- 状态：可合并

## 变更记录草稿

## 2026-10-30 【Claude·云端选测·未经Codex检验】Godot 选测移到 GitHub Actions 分片并行（dev.待定）

- 用户 2026-10-30 同意把选测移出 Mac：Mac 上多条车道抢共用槽，一批 20/189 个场景要 35 分钟。新增工作流 `.github/workflows/godot-tests.yml`（「云端选测」）与 [云端选测.py](../../03_再刷重制_Godot/07_开发环境/云端选测.py)：选场景照旧用 `选测.py`，跑与判定照旧用 `并行测试.py`（云端单场景超时 1200 秒），按耗时分片到多台 2 核机器并行。
- 只在推 `ci/<分支>`（选测）、`ci-full/<分支>`（整轮）和手动触发时跑；推 main 和普通分支不触发，同一提交测过并通过就跳过（私有仓库每月 2000 免费分钟）。
- 转换产物不入 Git：Mac 上 `云端选测.py upload` 把 generated 做成快照推到 `refs/ci/generated/<分支>`（不在 refs/heads 下，clone 和普通 fetch 不会拉；大文件切成 45 MB 段）。结果推到 `refs/ci/results/<提交>/<模式>`，`云端选测.py wait` 用 git 读，不需要令牌。
- 首次实测：整轮 258 个场景 17 分钟跑完、约用 155 分钟额度；指定 2 个场景 2 分钟、4 分钟额度。云端机器补装中文字体（回退字体在 Linux 上缺字）。`estimate` 子命令先估额度。
- 选测对照加一条 `.github/*` → docs（工作流改动不触发整轮）。用法、分钟数与回退见 [云端测试](../../03_再刷重制_Godot/07_开发环境/云端测试.md)「GitHub Actions 分片并行」。

## 交接板

- 下一步：总装合并后第一次在 Mac main 上跑 `云端选测.py run`（会推约 400 MB 产物快照），之后合并时大的选测改用 `run`＋`wait`。
- 下一步：GitHub 上留了一个试推的空分支 `claude/project-thread-cr90wk-probe`（云端删不掉），Mac 上 `git push github --delete claude/project-thread-cr90wk-probe` 删掉。
- 用户 2026-10-30 定：云端选测只放大批（Mac 要排队的选测）；小的留在 Mac 跑。每月 2000 免费分钟，用完自动停、不扣费。

## 进度账

- 无（工具，不计完成度）

## 可优化（流程／工具／效率）

- 建议：`合并车道.py --affected` 接上 `云端选测.py run`＋`wait`，代替本机 `并行测试.py`（八戒，工具车道）。
- 建议：非 Godot 检查（tools、content 等）也可以挪到云端，再省一点 Mac CPU；目前留在 Mac。

## 本分支提交

- 6b1879f 云端选测：工作流、云端选测.py、耗时种子
- 0c02b6c 云端机器装中文字体、手动触发可只跑指定场景
- （其后）撤掉试跑设置、estimate、说明与交付单
- 367a1e7、d60f3d1 是试跑设置（本分支触发、临时快照），已在最后一个提交撤掉
