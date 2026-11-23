# 交付：luiluu/t435-volcano-ark-media

- 车道／工作者：工具链／小A（T435）
- 状态：可合并

## 变更记录草稿

## 2026-11-23 【小A·未经审查】新增火山方舟 Agent Plan 出图命令行工具并完成 M5a 实跑（dev.待定）

- 依据 Kyo 11-23 事项 40 与 Agent Plan 订阅口径，新增 [方舟出图.py](../../03_再刷重制_Godot/07_开发环境/美术工具/方舟出图.py)、假服务器单测 [test_方舟出图.py](../../03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py) 并补充 [美术工具 README](../../03_再刷重制_Godot/07_开发环境/美术工具/README.md)，替代第三方 MCP 直接调用火山方舟接口。
  - **Agent Plan 专属接口与防误扣费（R2）**：
    - `DEFAULT_BASE_URL` 定为 `https://ark.cn-beijing.volces.com/api/plan/v3`（出图拼 `/images/generations`）；`validate_base_url` 与 `ArkClient` 仅放行该前缀与本机单测地址（`127.0.0.1` / `localhost`），`/api/v3` 前缀与路径穿越一律硬拒绝并提示「接入会产生额外费用」，且不读钥匙串、不调任何探测接口。
    - 默认出图模型定为控制台原样 `doubao-seedream-5.5`（同时支持 `--model` 切 `doubao-seedream-5.0-pro`、`doubao-seedream-5.0-flash` 等），彻底删除所有带日期的猜测模型 ID。
    - 视频子命令 `img2vid`（`i2v`/`图生视频`）与 `fetch`（`resume`/`续取`）默认禁用，直接退出（退出码 2）并提示「订阅不含 Seedance，需另购，地址未知」，不读钥匙串、不发网络请求；底层轮询/重试/续取实现与假服务器单测仍保留，便于日后另购启用。
  - **子命令与抠绿**：
    - `txt2img`（`t2i`/`文生图`）、`img2img`（`i2i`/`图生图`，`--ref` 支持多张本地图自动转 Base64 Data URI），默认 1:1（`2048x2048`）、关水印、默认 `--response-format b64_json`（随 API 响应直回图片字节，规避跨区直连对象存储超时；显式 `--response-format url` 下载遇 5xx/429/网络异常仅自动重试下载，绝不重发生成请求）。
    - `--green-key` 按需加载并复用同目录 `muse转精灵.py` 的 `key_mask` 与 `despill` 抠绿（默认保留 `*_raw` 原绿底图，避免重跑花钱），基础出图零第三方依赖。
  - **安全与格式校验（含核 r1 退回修复）**：
    - 钥匙仅通过 `security find-generic-password -s ark-api-key -w` 从 macOS 钥匙串读取，不读环境变量或 `.env`、不落盘；报错、日志与 `--meta-out` 自动脱敏打码；下载结果文件时不携带 `Authorization` 头且拒绝非 `http/https` 链接。
    - P2-1：鉴权请求同时采用 `add_unredirected_header` 与 `_NoRedirectHandler` 拒绝 30x 自动跟随，防钥匙随重定向外泄。
    - P2-2：`--base-url` 与 `ArkClient` 白名单校验并在 R2 进一步收紧为 `https://ark.cn-beijing.volces.com/api/plan/v3` 前缀（＋本机单测），硬拒 `/api/v3`。
    - P2-3：不抠绿出图按文件头魔数校验与 `--out` 扩展名是否一致（Seedream 5.x 自动请求对应 `output_format`，4.x 不传避免 400），不符时经 Pillow 或 macOS `sips` 自动转格式，无法转换则报错且绝不写入伪 PNG。
  - 脚本头与 `美术工具/README.md` 均已同步 Agent Plan 开通配置、macOS 钥匙串存取命令、防误扣费警告与费用说明。
- **验证**：
  - 系统 Python 假服务器单测：`python3 -m unittest -v 03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py` **18/18 通过**（含文生图默认 `b64_json` 与显式 `url` 下载、`url` 仅下载重试不重发生成、图生图单／多图、Agent Plan `/api/plan/v3` 白名单与 `/api/v3` 硬拒、视频子命令默认禁用、底层图生视频轮询／失败／超时／重试／续取／互斥、图片／视频 URL 过期、302/307 防跳转外泄、伪 PNG 魔数校验与转换／拒写、钥匙串缺失且忽略环境变量、报错脱敏与 `--green-key` 缺依赖提示）。
  - Pillow＋numpy 完整单测：`uv run --with pillow --with numpy python3 -m unittest -v 03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py` **18/18 通过**（端到端验证 Pillow 转 PNG 与复用 `muse转精灵.py` 抠绿）。
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check` 退出码 0；`python3 03_再刷重制_Godot/07_开发环境/交付自检.py` 退出码 0。
  - 未动工程 `.gd` 文件，不涉及云端选测。
- **真钥匙实跑记录（M5a 图生图）**：
  - 首跑（旧默认 `url` 模式）API 鉴权与生成已 200 返回但跨区下载临时对象存储 URL 超时（`[Errno 60] Operation timed out`）；经协调者批准默认改 `b64_json` 并补 `url` 仅下载重试后，补跑 1 张一次成功。
  - 参数：`img2img`、模型 `doubao-seedream-5.5`、参考图私密仓 `重制设定/美术定妆图/徐凤年_形象参考_Kyo.jpg`、提示词取分镜 v0.5 第 3.2 节 Muse #5 Step 5a、`--size 1:1`（`2048x2048`）、`watermark=false`。
  - 产物：`00_项目管理/归档/交付截图/luiluu_t435-volcano-ark-media/M5a_seedream55.png`（原生真 PNG，`2048×2048`，8-bit RGB，6.6MB，无水印，黑白线稿网点＋朱红三色准确）。
  - 用量：`{"input_images": 1, "generated_images": 1, "output_tokens": 16384, "total_tokens": 16384}`。
  - 视频实跑：**未实跑**（订阅不含 Seedance，需另购，地址未知；视频子命令已默认禁用）。
- 提交：`725281c5c`、`f29b85b3f`、`e9ea38a5d`、`c667ea2de`、`d1452e326` 及本交付单更新提交。
- 未完成／已知问题：当前 Agent Plan 订阅不含 Seedance，故 4 秒视频未实跑且视频子命令默认禁用；待日后另购 Seedance 并确认接口地址与模型 ID 后再按需启用。

## 交接板

- 下一步：交核查（甲／乙档按分工）并供 Kyo 审阅实跑样图 `00_项目管理/归档/交付截图/luiluu_t435-volcano-ark-media/M5a_seedream55.png`；后续 Seedream 静图生产可直接复用 `方舟出图.py`。
- 用户试玩说明：无（离线美术开发工具，不影响游戏内行为）。
- 需要用户决定：无（`M5a_seedream55.png` 为工具实跑验证样图，如作正式动画定妆需另行定稿）。

## 进度账

- 无（离线开发工具，不涉及游戏主表与扩展账进度变动）。

## 可优化（流程／工具／效率）

- 已做：基础出图全用 Python 标准库 `urllib.request`，无需安装 `requests` 或第三方 MCP；默认改 `b64_json` 直接随 API 响应返回图片字节，彻底避免海外／弱网环境二次直连对象存储超时浪费额度，且 `url` 模式补齐仅下载重试（绝不重发生成）；仅在加 `--green-key` 时按需加载 `muse转精灵.py`，且默认保留 `*_raw` 原始绿底图避免调阈值重复生成；无 Pillow 时退回 macOS 内置 `sips` 自动转格式。

## 动了的共用函数和开关

无

## 本分支提交

- `725281c5c` 新增火山方舟出图出视频命令行工具、单测与说明（T435）
- `f29b85b3f` 补充 T435 火山方舟出图工具交付单
- `e9ea38a5d` 修复 T435 核 r1 退回的 3 个 P2 与 2 个 P3 并补齐回归单测
- `c667ea2de` 更新 T435 交付单（核 r1 修复与 16 项单测）
- `d1452e326` T435 R2 切换方舟 Agent Plan 接口、禁用视频、默认 b64_json 并实跑 M5a
