# 交付：luiluu/t435-volcano-ark-media

- 车道／工作者：工具链／小A（T435）
- 状态：可合并

## 变更记录草稿

## 2026-11-23 【小A·未经审查】新增火山方舟出图出视频命令行工具（dev.待定）

- 依据 Kyo 11-23 事项 40，新增 [方舟出图.py](../../03_再刷重制_Godot/07_开发环境/美术工具/方舟出图.py)、假服务器单测 [test_方舟出图.py](../../03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py) 并补充 [美术工具 README](../../03_再刷重制_Godot/07_开发环境/美术工具/README.md)，替代第三方 MCP 直接调用火山方舟接口。
  - 三条子命令：`txt2img`（`t2i`/`文生图`）、`img2img`（`i2i`/`图生图`，`--ref` 支持多张本地图自动转 Base64 Data URI）、`img2vid`（`i2v`/`图生视频`，`--first-frame` 建任务后轮询至完成并下载）；默认 1:1 比例、关水印，模型 ID 可配（默认取当前 Seedream `doubao-seedream-5-5-261028` 与 Seedance `doubao-seedance-2-5-260628`）。
  - `--green-key` 按需加载并复用同目录 `muse转精灵.py` 的 `key_mask` 与 `despill` 抠绿（默认保留 `*_raw` 原绿底图，避免重跑花钱），基础出图／出视频零第三方依赖。
  - 钥匙仅通过 `security find-generic-password -s ark-api-key -w` 从 macOS 钥匙串读取，不读环境变量或 `.env`、不落盘；报错、日志与 `--meta-out` 自动脱敏打码；下载结果文件时不携带 `Authorization` 头。
  - 脚本头与 `美术工具/README.md` 均补全开通步骤、macOS 钥匙串存取命令与参考费用。
- 验证：
  - 系统 Python 假服务器单测：`python3 -m unittest -v 03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py` 11/11 通过（含文生图、图生图单／多图、图生视频轮询下载、任务失败、超时、图片／视频 URL 过期、钥匙串缺失且忽略环境变量、报错脱敏与 `--green-key` 缺依赖提示）。
  - Pillow＋numpy 完整抠绿单测：`uv run --with pillow --with numpy python3 -m unittest -v 03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py` 11/11 通过（端到端复用 `muse转精灵.py` 对绿底合成图完成抠绿）。
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check` 退出码 0；`python3 03_再刷重制_Godot/07_开发环境/交付自检.py` 退出码 0。
  - 未动工程 `.gd` 文件，不涉及云端选测。
- 实跑说明：**钥匙串有值但鉴权 401，未实跑**。检查到本机 macOS 钥匙串已存在 `ark-api-key` 项（长度 46 字符，未读取打印明文），但对火山方舟正式接口 `https://ark.cn-beijing.volces.com/api/v3` 鉴权返回 `HTTP 401 AuthenticationError（The API key or AK/SK in the request is missing or invalid）`，经协调者确认先交付工具、单测与文档，待 Kyo 核对更新有效钥匙后再另派实跑 M5a 1 张图＋1 段 4 秒视频。
- 提交：`725281c5c`（工具、单测与 README）及本交付单提交。
- 未完成／已知问题：M5a 真实出图与 4 秒视频实跑待有效方舟 API Key 就绪后另派验证。

## 交接板

- 下一步：待 Kyo 核对并更新 macOS 钥匙串 `ark-api-key` 后，另派单用 `方舟出图.py` 实跑 M5a 拔刀定妆图与 4 秒视频验证真实接口与用量。
- 用户试玩说明：无（离线美术开发工具，不影响游戏内行为）。
- 需要用户决定：无（请核对火山方舟控制台 API Key 并重新存入钥匙串 `ark-api-key`）。

## 进度账

- 无（离线开发工具，不涉及游戏主表与扩展账进度变动）。

## 可优化（流程／工具／效率）

- 已做：基础出图／出视频全部用 Python 标准库 `urllib.request` 实现，无需安装 `requests` 或第三方 MCP；仅在加 `--green-key` 时按需加载 `muse转精灵.py`，且默认保留 `*_raw` 原始绿底图避免调抠绿阈值时重复花钱重生成（加 `--no-keep-raw` 可回退不保留）。

## 动了的共用函数和开关

无

## 本分支提交

- `725281c5c` 新增火山方舟出图出视频命令行工具、单测与说明（T435）
