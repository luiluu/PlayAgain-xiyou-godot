# 交付：cc/sync-reuse-pending

- 车道／工作者：工具（cc，线程「让 main 复用车道同步结果」，总装三十一方案 1，Kyo 回「开」）
- 状态：可合并

## 做了什么

- 起因：11-07 换源合并时 `合并车道.py` 调 `同步正式西游.py --from-worktree` 被拒（「车道产物没有同步指纹」）：车道最后一轮同步以退出码 2（测量有变化、待接受单）结束，旧规则不写可复用指纹，main 只能整轮重跑 96 个探针约 3.5 小时。
- 现在：车道同步**只差测量接受**（来源核验通过、导入成功、探针缓存发布成功，只是测量变化未接受）时也写 `sync_stamp.json`，多一个字段 `pendingAcceptance: true`。来源核验失败、导入失败、缓存发布失败照旧不写、删旧指纹。
- 合并时 `--from-worktree` 认这种指纹：照旧核对车道转换工具摘要（同步后没改过、与合并后 main 相同）和产物摘要（同步后没动过），对不上照旧退出码 3、不动 main。克隆后照旧按 **main 自己的同步基线**比较测量、跑来源核验；接受单、`--accept-additions`、`--accept-source-switch` 规则一条没动：没接受照样退出码 2，main 不留指纹、不登记；`合并车道.sh … --accept-changes <接受单>` 接着同步时会再次复用车道产物（几分钟），不再重跑。同步报告多一项 `fromWorktreePending: true`，日志写一行说明。
- `合并车道.py` 不用改：它本来就先试 `--from-worktree`，退出码 2 走接受单流程。
- 没有放松任何测量比较或接受规则；产物等价性靠的仍是原来那两道摘要核对（与已接受指纹同一前提），main 的来源核验（`验证西游来源.py` 核 manifest 的正式源路径、版本、输入 SHA）也照旧跑。
- 备选方案 2（把车道 incremental-cache 反向带回 main）没做：方案 1 改动更小（同步脚本约 20 行）、不碰缓存目录，且复用的是整份已核摘要的产物，不用逐探针命中。
- 回退：环境变量 `XIYOU_REUSE_PENDING_STAMP=0`（车道不写、合并不认待接受指纹，回到旧行为）；或删 `同步正式西游.py` 里 `pending = …` 那段与 `clone_from_worktree` 里 `pendingAcceptance` 的判断。
- 一次性代价：`同步正式西游.py` 在转换工具摘要里，合进 main 后，之前同步过的车道指纹对不上新 main，那几条车道合并时照旧整轮同步一次（或车道合 main 后重同步）。之后的车道都受益。
- 顺带：`参照批次.py check` 认「本树自己同步过（有效的新戳）」；以前车道同步退出码 2 没戳，会误报混批，现在有待接受戳就不再误报（产物确是本分支生成的）。

## 改动文件

- 改：`03_再刷重制_Godot/03_转换工具/同步正式西游.py`（`reuse_pending_stamp`、`write_stamp(pending=)`、`clone_from_worktree`、收尾写指纹判断、文件头说明）
- 改：`03_再刷重制_Godot/07_开发环境/测试合并工具.py`（`SyncStampTests` 加 2 项）、`测试增量同步.py`（`AcceptedBaselineTests` 加 1 项）
- 改：`03_再刷重制_Godot/03_转换工具/README.md`、`03_再刷重制_Godot/07_开发环境/长任务与增量同步.md`（说明）

## 验证

- 新测试（临时夹具，不碰 generated）：
  - `SyncStampTests.test_pending_lane_stamp_is_reused_but_main_still_needs_acceptance`：车道待接受指纹＋既有用例改变 → main 复用（报告无 `probes`、有 `fromWorktreePending`），仍退出 2、不留指纹、不登记；带接受单 → 0，产物与车道一致。
  - `SyncStampTests.test_pending_lane_stamp_keeps_tool_and_output_checks_and_switch`：转换工具不同 → 3；同步后产物被改 → 3；`XIYOU_REUSE_PENDING_STAMP=0` → 3；三种情况 main 产物不变。
  - `AcceptedBaselineTests.test_pending_stamp_only_when_outputs_are_faithful`：退出 2 写待接受指纹且摘要对；来源核验／导入／缓存发布失败不写；开关为 0 不写；接受后写的正式指纹不带 `pendingAcceptance`。
  - 反向验证：整体设 `XIYOU_REUSE_PENDING_STAMP=0` 跑前两类新测试，均失败（咬得住）。
- `测试合并工具.py` 整份 290 项通过（393 秒）；`测试增量同步.py` 整份 74 项通过（70 秒）。
- `工具回归.py` 11 项全过（60 秒）。
- 没跑 Godot 场景：`选测.py main --list` 因改了 `03_转换工具/同步正式西游.py` 按转换器组列出 68 个场景（xiyou_rules 全段、event_compare 等），但这次只改同步脚本的指纹记账，不改转换器、探针和任何产物，场景结果不会变；且 main 的 generated 正被整轮同步改写，本树没 `--补齐`（派单要求不跟 main 的同步抢、测试只用临时夹具），总装合并时按影响面选测即可。
- 没跑同步（派单要求）。

## 优化登记草稿

优化登记草稿：无

（流程工具改动，不是原版优化项；回退办法见「做了什么」。）

## 可优化（流程／工具／效率）

- 已做：车道只差测量接受时写待接受指纹，main 合并复用车道产物（回退 `XIYOU_REUSE_PENDING_STAMP=0`）。预计带测量变化的合并从整轮重跑（换源那次 3.5 小时）降到克隆＋比较几分钟。
- 建议（总装三十一方案 3，归工具车道）：智能 AI 探针单进程约 2.2 小时，可像事件状态探针那样按敌群分段并行，真要整轮时省 20～30 分钟。

## 变更记录草稿

## 2026-11-07 【cc·工具·未经审查】同步只差测量接受时写待接受指纹，合并复用车道产物（dev.待定）

- `同步正式西游.py`：车道同步只差测量接受（来源核验、导入、缓存发布都成功，退出码 2）时也写 `sync_stamp.json`，标 `pendingAcceptance`；总装 `--from-worktree` 照常核对转换工具与产物摘要后克隆车道产物，再按 main 自己的基线比较，接受单／`--accept-additions`／`--accept-source-switch` 规则不变。起因 11-07 换源合并因车道无指纹整轮重跑约 3.5 小时。回退 `XIYOU_REUSE_PENDING_STAMP=0`。
- 测试：`测试合并工具.py SyncStampTests` 加 2 项、`测试增量同步.py AcceptedBaselineTests` 加 1 项。

## 交接板

- 待交叉核查：cc/sync-reuse-pending（甲档：同步／合并流程，核「待接受指纹不放松接受规则」）

## 本分支提交

- a2b07a4c 同步只差测量接受时写待接受指纹，合并可复用车道产物
