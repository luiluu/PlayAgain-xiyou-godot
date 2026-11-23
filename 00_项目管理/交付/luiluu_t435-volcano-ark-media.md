# 交付：luiluu/t435-volcano-ark-media

- 车道／工作者：工具链／小A（T435）
- 状态：可合并

## 变更记录草稿

## 2026-11-23 【小A·未经审查】新增火山方舟出图出视频命令行工具（dev.待定）

- 依据 Kyo 11-23 事项 40，新增 [方舟出图.py](../../03_再刷重制_Godot/07_开发环境/美术工具/方舟出图.py)、假服务器单测 [test_方舟出图.py](../../03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py) 并补充 [美术工具 README](../../03_再刷重制_Godot/07_开发环境/美术工具/README.md)，替代第三方 MCP 直接调用火山方舟接口。
  - 四条子命令：`txt2img`（`t2i`/`文生图`）、`img2img`（`i2i`/`图生图`，`--ref` 支持多张本地图自动转 Base64 Data URI）、`img2vid`（`i2v`/`图生视频`，`--first-frame` 与 `--ref` 互斥，建任务后轮询至完成并下载，遇 5xx/429/网络异常默认连续重试 3 次）、`fetch`（`resume`/`续取`，按 `--task-id` 续轮询并下载，避免超时/断网重复扣费）；默认 1:1 比例、关水印，模型 ID 可配（默认取当前 Seedream `doubao-seedream-5-5-261028` 与 Seedance `doubao-seedance-2-5-260628`，待有效钥匙实跑按控制台确认）。
  - `--green-key` 按需加载并复用同目录 `muse转精灵.py` 的 `key_mask` 与 `despill` 抠绿（默认保留 `*_raw` 原绿底图，避免重跑花钱），基础出图／出视频零第三方依赖。
  - 安全与格式校验（含核 r1 退回修复）：
    - 钥匙仅通过 `security find-generic-password -s ark-api-key -w` 从 macOS 钥匙串读取，不读环境变量或 `.env`、不落盘；报错、日志与 `--meta-out` 自动脱敏打码；下载结果文件时不携带 `Authorization` 头且拒绝非 `http/https` 链接。
    - P2-1：鉴权请求同时采用 `add_unredirected_header` 与 `_NoRedirectHandler` 拒绝 30x 自动跟随，防钥匙随重定向外泄。
    - P2-2：`--base-url` 与 `ArkClient` 仅放行 `https://ark.cn-beijing.volces.com` 与本地单测地址（`127.0.0.1`/`localhost`），其余一律拒绝且不读钥匙串。
    - P2-3：不抠绿出图按文件头魔数校验与 `--out` 扩展名是否一致（Seedream 5.x 自动请求对应 `output_format`，4.x 不传避免 400），不符时经 Pillow 或 macOS `sips` 自动转格式，无法转换则报错且绝不写入伪 PNG。
  - 脚本头与 `美术工具/README.md` 均补全开通步骤、macOS 钥匙串存取命令与参考费用。
- 验证：
  - 系统 Python 假服务器单测：`python3 -m unittest -v 03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py` 16/16 通过（含文生图、图生图单／多图、图生视频轮询下载、任务失败、超时、5xx/断连重试与 `fetch --task-id` 续取、图片／视频 URL 过期、双本地服务器 302/307 防跳转外泄、`--base-url` 白名单、伪 PNG 魔数校验与 `sips` 自动转 PNG / 拒写、`--first-frame` 与 `--ref` 互斥、钥匙串缺失且忽略环境变量、报错脱敏与 `--green-key` 缺依赖提示）。
  - Pillow＋numpy 完整单测：`uv run --with pillow --with numpy python3 -m unittest -v 03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py` 16/16 通过（端到端验证 Pillow 转 PNG 与复用 `muse转精灵.py` 抠绿）。
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check` 退出码 0；`python3 03_再刷重制_Godot/07_开发环境/交付自检.py` 退出码 0。
  - 未动工程 `.gd` 文件，不涉及云端选测。
- 实跑说明：**钥匙串有值但鉴权 401，未实跑**。本机 macOS 钥匙串 `ark-api-key` 仍鉴权 401，按派单指令本轮不实跑，待 Kyo 核对更新有效钥匙后再另派实跑 M5a 1 张图＋1 段 4 秒视频并按控制台确认默认模型 ID。
- 提交：`725281c5c`（初版工具、单测与 README）、`f29b85b3f`（初版交付单）、`e9ea38a5d`（核 r1 退回 3 个 P2 与 2 个 P3 修复及回归单测）及本交付单更新提交。
- 未完成／已知问题：M5a 真实出图、4 秒视频实跑及默认模型 ID 控制台实测确认待有效方舟 API Key 就绪后另派验证。

## 交接板

- 下一步：待 Kyo 核对并更新 macOS 钥匙串 `ark-api-key` 后，另派单用 `方舟出图.py` 实跑 M5a 拔刀定妆图与 4 秒视频验证真实接口、默认模型 ID 与用量。
- 用户试玩说明：无（离线美术开发工具，不影响游戏内行为）。
- 需要用户决定：无（请核对火山方舟控制台 API Key 并重新存入钥匙串 `ark-api-key`）。

## 进度账

- 无（离线开发工具，不涉及游戏主表与扩展账进度变动）。

## 可优化（流程／工具／效率）

- 已做：基础出图／出视频全部用 Python 标准库 `urllib.request` 实现，无需安装 `requests` 或第三方 MCP；仅在加 `--green-key` 时按需加载 `muse转精灵.py`，且默认保留 `*_raw` 原始绿底图避免调抠绿阈值时重复花钱重生成（加 `--no-keep-raw` 可回退不保留）；无 Pillow 时退回 macOS 内置 `sips` 自动转换伪 PNG；轮询加连续重试并提供 `fetch --task-id` 续取避免超时断网重复扣费。

## 动了的共用函数和开关

无

## 本分支提交

- `725281c5c` 新增火山方舟出图出视频命令行工具、单测与说明（T435）
- `f29b85b3f` 补充 T435 火山方舟出图工具交付单
- `e9ea38a5d` 修复 T435 核 r1 退回的 3 个 P2 与 2 个 P3 并补齐回归单测
