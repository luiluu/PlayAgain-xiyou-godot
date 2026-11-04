# 交付：cc/nezha-tools61

- 车道／工作者：D 工具／哪吒（cc，Sonnet／medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】推送 5xx 自动重试＋陈旧产物检查收窄（dev.待定）

- 新 `07_开发环境/推送重试.py`（共用 `retry_push`）：git push 输出含 5xx／Internal Server Error／commit_refs／RPC failed／HTTP 408 等服务端临时故障时，退避 10、30、60 秒最多重试 3 次，每次打一行；认证失败、non-fast-forward 等原样报错不重试。`云端选测.py` 的全部 push（产物快照、基准、沿用、ci 分支、云端结果）和 `合并车道.py` 收尾推 main 都走它。回退：`XIYOU_PUSH_RETRY=0`；`XIYOU_PUSH_RETRY_DELAYS=1,2,3` 改间隔。
- 审查 38 P3-9：`参照批次.py flux` 只在状态文件 30 分钟内动过才算「正在合并」；总装中断后停在 prepared 不再让车道的陈旧产物检查一直被跳过。跳过时的提示加上「这次测试可能用着过期产物，合并收尾后补跑」。回退：`XIYOU_MERGE_FLUX_MAX_AGE=0`（旧行为）或 `XIYOU_IGNORE_MERGE_FLUX=1`。
- 新测试 `测试推送重试.py`（7 项）接进 `检查.sh` 的 tools 段；`测试参照批次.py` 补一例；`测试云端准备.py` 的临时副本多拷 `推送重试.py`。

## 待交叉核查

- `推送重试.py` 的 TRANSIENT 正则（别把认证／non-fast-forward 误当临时故障）；`云端选测.py` 导入 `推送重试`（CI 里同目录，工作流不用改）；`合并车道.py push_github`。
- `参照批次.py` flux 的时间判断。

## 验证

- 没碰 .gd，不跑 Godot 选测。
- `测试推送重试.py` 7/7、`测试参照批次.py` 20/20、`测试云端准备.py` 24/24、`测试选测.py` 108/108（`STUB_CHECKS` 补了新测试名）、`测试合并工具.py` 251/251、`语法检查.py` 532 个 .gd 0 问题。
- 没有真的打到 GitHub 500：重试逻辑用伪造失败测。

## 给总装

- 下次合并若再遇 GitHub 5xx，会看到 `[推送重试]` 行；全部用完才失败，`push_github` 仍只警告。

## 可优化（流程／工具／效率）

- 已做：以上两项（回退见上）。
- 建议：`云端选测.py` 里 `git ls-remote`／`fetch` 也可能遇 5xx，这期没加（没见到失败）；出现再加同一函数。
