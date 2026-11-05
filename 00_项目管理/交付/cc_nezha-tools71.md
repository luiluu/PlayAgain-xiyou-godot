# 交付：cc/nezha-tools71

- 车道／工作者：工具／BK2（cc，哪吒）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·BK2·未经审查】云端选测基准不再退回老点；presets 单改自动重传产物；事件覆盖按变体记（dev.待定）

- **① 选测基准**：根因有两层。a) `检查.sh --cloud` 测的是快照提交，收尾提交 sha 没有云端结果，`cloud_passed_base` 找不到它；b) 收尾提交带「手补」代码时 `local_verified_base` 一律不认（当年手补没在云端测过）。改：`检查.sh` 做快照后把快照号写进 `.git/xiyou_cloud_snapshot`；`合并车道.py` 收尾提交后调 `云端选测.py adopt <快照> HEAD`，快照有通过的 affected／full 结果且收尾提交的树与快照一致（或只差版本号、登记、文档、.uid）时，把结果 ref 复制成收尾提交的 `refs/ci/results/<收尾>/<模式>`（失败只提示，不挡收尾）；有手补代码时尾注加 `手补已验: 快照 <号>`，`local_verified_base` 见到它不再按「手补」退回合并提交。另加 `云端选测.py trust <提交> --reason …` 写人工锚点（通过的结果，带 manual 标记），供基准链已断时总装确认后用。
- **注意（当前历史）**：main 上现有收尾提交都没有云端结果，且 f75a9250 带未验手补，链是断的。tools71 合进 main 之后的**第一次** `--finish --affected --cloud` 仍会从 a7baef3ab 起算（整轮）；它收尾后基准就接上了。想省这一次：确认 4616b58c 已验后，总装自己执行 `python3 03_再刷重制_Godot/07_开发环境/云端选测.py trust 4616b58c --reason "…"`（我没执行，是否放行由总装定）。
- **② presets 单改不重传**：`补跑事件状态探针.py` 实际重量出 `event_states.json` 后留标记 `.git/xiyou_cloud_upload_needed`；`检查.sh --cloud` 见标记就不沿用 `CHECK_CLOUD_NO_UPLOAD`、重传产物，云端通过后删标记。没改 `refresh` 判定（改了会触发整轮同步，太重）。
- **③ 事件覆盖按变体**：`xiyou_event_compare --coverage` 的 JSON 加 `byCase`（用例号含 `#变体` → 该例执行到的指令），`executed` 仍是并集，`事件写法覆盖.py` 照旧读 `executed`。`--only=m23e2p0 --coverage=…` 实测给出 `m23e2p0`、`m23e2p0#s1` 两份。
- **④ 总装补**：`检查.sh --cloud` 的快照提交改用 `git add -u`（不再 `-A`）：未跟踪文件不进快照，新文件要先 `git add -N`（`--also` 的新文件同理）。
- 测试：`测试云端准备.py` 新增 adopt（同树／文档差异过户、代码差异不过户、无通过结果不过户）、手补已验被认、trust 4 例；`测试选测.py` CheckerTests 新增未跟踪文件不进快照、标记强制重传 2 例；`测试合并工具.py` 新增过户＋尾注 1 例。

## 交接板

- 下一步：无。
- 用户试玩说明：无（工具改动）。
- 需要用户决定：无。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`事件写法覆盖.py` 可用 `byCase` 把「某变体才走到的写法」单独列出（小，归工具车道）。

## 待交叉核查

- `检查.sh`（快照 `add -u`、重传标记）、`云端选测.py`（adopt／trust／手补已验）、`合并车道.py`（过户）、`tests/xiyou_event_compare.gd`（byCase）。未改战斗核心文件。

## 验证

- `工具回归.py` 全过；`测试合并工具.py` 258 项、`测试选测.py` 132 项、`测试云端准备.py` 29 项全过；`语法检查.py` 通过；选测列出的 10 个场景（含 xiyou_event_compare、xiyou_cover_interp）本机全过。没有真实推云端跑过 adopt／快照，只在本地裸库和桩上验证。

## 本分支提交

- 见 git log
