# 待机漂移量测

`idle_drift.py` 为离线只读美术量测工具（Pillow），放 `07_开发环境/美术工具/`：对所有重绘角色复用，且完全移出 Godot 工程，避免 all_resources 导出带入离线工具。默认扫描本工程 content 新绘图集与 generated 中 Codex 战斗图／逐帧形态，运行时 content 素材覆盖同名 generated 图；另只读 git 中 gpt/yunshang-v2 的云裳 T113 样板。云裳样板左上为空，按其 README 明确量第二排 wait，报告标“sample wait (not wired)”，不假冒已接线的实际 walk。

运行：`python3 ../07_开发环境/美术工具/idle_drift.py --out /tmp/idle_drift.json`。也可重复传 `--sheet <MV图集>` 只测指定图；默认阈值为原始像素1，`--threshold` 可调。图集取 walk 左上三格，逐帧资源取动作0前三张；单帧形态不制造三帧，报告 frame_count。

报告每帧外接框、脚底、上半身／左右手所在带的alpha质心与外接框边缘跨度，以及实际最底行接触点跨度。超过1px记REVIEW；这是一份审图筛查名单，不自动判定坏图，不做任何修图。头区可能含头发、手区可能含衣摆／尾巴，轮廓变化不一定是锚点移动；脚只量最底接触行，避免把尾巴当脚。不同格尺寸按原始像素量，报告保留cell供缩放评估。完全不移动轮廓的纯内部颜色变化不会被alpha指标发现，仍需看动图。

检测器自验：0px与1px平移不提示，2px平移提示REVIEW；宿傩原图能检出头部2px漂移，修后头手脚指标为零。T123实测25组，具体名单见 `00_项目管理/归档/交付截图/gpt_mira-feet/T123/idle_drift_summary.txt`，没有自动修改超标角色。

## T127 动作参照与初判（WIP）

新增 `motion_reference.py`（18动作＋四方向取帧）与 `motion_triage.py`（并排GIF、初判总表）。均需 Pillow；当前会话临时解释器为 `/tmp/t127-venv/bin/python`，重启或换机需自行提供 Pillow 环境。

```sh
python3 motion_reference.py --sheet <原始图集.png> --out <私密输出目录>
python3 motion_reference.py --sheet <行走图.png> --kind walk --character-index 6 --out <私密输出目录>
python3 motion_triage.py --project <Godot工程根> --manifest <T124的manifest.json> --out <T127私密证据目录>
python3 -m unittest discover -s . -p 'test_motion*.py'
```

先对两位参照分别运行提取，输出目录固定为 `gouxiaoyao/battle`、`gouxiaoyao/walk`、`reid/battle`、`reid/walk`，再运行初判。`--project` 应指向素材完整的只读工程；不要为测量改动 content。

初判当前范围 Actors169～179，含形态19组，排除T124重复本体、旧云裳、米拉、萨姆、五条悟，补哈基米；云裳取已合u2。每动作对照每位参照的完整分区向量，不拼指标包络。容差为两参照同指标差值加 `max(0.5px,较小参照值×25%)`，两参照互比须通过；最大归一化偏差≤1判“好”，≤2判“轻微”，>2判“要修”，代码定帧单列“要修”。这些分级是自动初判，不是已批准的人体动作合格区间。

局限：手区含衣摆、头区含武器；缺测可能只是某分区无像素，不能认定缺动作。逐帧素材量测全部可用帧，观察GIF暂取前4帧；不模拟动作回退、状态覆写与实际播放速度。行走暂取本体共用图，形态接线待核。头身比需要人工头部边界，不以半格分区伪造。测试文件为工具专项回归入口，尚未接入统一工具回归登记；该项留待接续。

## Muse 视频转战斗精灵（T352）

`muse转精灵.py`：把 Muse 出的纯绿底 mp4 转成 128 格 MV 侧视战斗图集（9×6，1152×768，18 动作×3 帧）。只读输入，不改 content/；输出放私密设计仓审样，定稿后再由接线车道搬进工程。依赖 Pillow＋numpy＋ffmpeg／ffprobe（系统 python 没有 Pillow 时先 `python3 -m venv <目录> && <目录>/bin/pip install pillow numpy`）。

```sh
python3 muse转精灵.py --ref <定妆图.png> --out <私密输出目录> \
  --clip swing=<挥.mp4> \
  --clip thrust=<刺.mp4>@0.8,1.25,1.9 \
  --flip
python3 muse转精灵.py --selftest        # 合成绿底视频自测 13 项，退出码 0＝通过
```

- `--ref`：定妆图，透明 PNG 或绿底 PNG；也可给视频＋`--ref-time 秒` 取一帧（定妆图没出时临时用）。
- `--clip 动作名=视频[@起势秒,发力秒,收势秒]`：可重复；动作名用 MV 的 18 个英文名（walk、wait、chant、guard、damage、evade、thrust、swing、missile、skill、spell、item、escape、victory、dying、abnormal、sleep、dead）。不写时间就自动挑：发力＝离首帧轮廓差最大的帧，起势／收势＝发力前／后同时离两端最远的帧。自动挑只是起点，挑得不对就手写时间。
- `--flip`：水平翻转。MV 我方侧视图面朝左，Muse 出的人朝右时加。
- 其余可调：`--height`（定妆图人高在格内像素，默认 100）、`--baseline`（脚底行，默认 127）、`--axis`（中轴列，默认 64）、`--key-threshold`、`--erode`、`--despill-band`、`--coverage`、`--colors`（色板色数，默认 48）、`--min-island`、`--color-mode vote|mean`、`--align frame0|ref`。

做法：

1. **抠绿**：`g - max(r,b)` 大于阈值算绿底；前景先收 1 像素，边缘 3 像素内去绿溢色（g 压到 max(r,b)，内部颜色不动）；缩小后按覆盖率 ≥0.5 二值透明。
2. **缩放只算一次**：`s = --height / 定妆图人高`，按「视频与定妆图同取景」换成视频缩放（再乘定妆图宽／视频宽），所有动作共用，不逐帧、不逐视频自适应。
3. **锚点**：定妆图的脚底（最低不透明行）对到格内基线，身体中轴（人高 30%～95% 带内不透明像素 x 的中位数）对到格内中轴。每段视频默认用首帧量同样两点对齐（`--align frame0`），这一偏移整段共用，所以挥砍前冲、后撤的位移保留；`--align ref` 则假定视频取景与定妆图逐像素一致。
4. **色板锁定**：从定妆图源分辨率前景取色（按 RGB 4 位分桶、桶权重取像素数开方后中位切分，再加权 k-means 3 轮——直接按像素数切分时大片黑发会吃掉大半色数，金甲分不到颜色）。所有帧的源像素就近映射到这套色板，再按面积投票定每个目标像素（`vote`，保住硬色块；`mean` 先平均再映射，偏糊，留作对照）。
5. **一致性报告** `report.html`／`report.json`：每帧人高比、色板偏差（源像素到色板的平均距离、距离 >48 的占比）、外接框、出格深度（缩放前在源图量前景超出采样框多深，换算成格内像素；缩小后的格子看不出被裁，脚被向下裁时 bottom 仍是 127，所以必须在源图上量；≥1 像素标红「出格被裁」，不到 1 像素只记录）、脚底离基线、删掉的孤点；每段视频的首帧人高比（判断取景是否与定妆图一致）。超阈值标红。阈值在脚本顶部 `THRESHOLDS`：首帧人高比 0.96～1.04；每帧人高比 0.80～1.08（蹲伏、跳起会正当触发，只作提醒）；色板平均偏差 ≤14；色板外占比 ≤5%；脚离基线 >2 行。
6. **输出**：`图集_SV_128.png`（缺的动作留空，报告列出）、`图集_x4.png`（4 倍＋动作名）、每动作 `<动作>_0..2.png`、`<动作>_x4.png`（4 倍最近邻＋蓝基线红中轴）、`<动作>.gif`、`<动作>_源帧.png`（取到的原视频帧）、`定妆图_128.png`、`色板.png`。

注意：

- **定妆图和视频必须同取景**（最好是用定妆图做图生视频）。不同取景时首帧人高比会标红，此时不要逐视频改缩放，先换视频。T352 用作废的米拉 v1 定妆图配样片实测首帧人高比 0.903，已标红。
- 视频首帧要是站姿（与定妆图同姿势），否则 `frame0` 对齐会把整段带偏；首帧不是站姿时改用 `--align ref`。
- 精灵自检（`../精灵自检.py`）现按 64 格写死：待机条 192×64、行走 144×192、待机脚底 64，128 格图集第一项 `native_size` 就失败退出，后面的检查都不跑。要支持 128 需按格尺寸换算这几项（另开卡，不在 T352 改）。
- 样片演示（swing，样片第 0 帧当临时定妆图）与取景不一致示例在私密设计仓 `协作交接/附图/T352/`。

## 火山方舟 Agent Plan 出图（T435）

`方舟出图.py`：直接调用火山方舟 Agent Plan（Volcengine Ark）REST 接口的命令行工具，替代第三方 MCP。基础出图仅用 Python 标准库（零第三方依赖），开启 `--green-key` 时按需复用同目录 `muse转精灵.py` 的 `key_mask` 与 `despill`（此时需 Pillow＋numpy，可用 `uv run --with pillow --with numpy` 或 venv）。

> **重要防误扣费说明**：Kyo 订阅的是火山方舟 **Agent Plan**，图片生成必须走专属前缀 `https://ark.cn-beijing.volces.com/api/plan/v3`（出图拼 `/images/generations`，即 `https://ark.cn-beijing.volces.com/api/plan/v3/images/generations`）。**请勿使用 `https://ark.cn-beijing.volces.com/api/v3`，接入会产生额外费用**；工具已硬拦截 `/api/v3` 前缀，且不调用任何探测接口。当前订阅不含 Seedance 视频生成，故 `img2vid`／`fetch` 子命令默认禁用并提示「订阅不含 Seedance，需另购，地址未知」。

### 怎么开通

1. 登录火山引擎控制台（`https://console.volcengine.com/ark`），完成实名认证并开通「火山方舟 Agent Plan」订阅。
2. 控制台确认的视觉接口与模型 ID（原样，无日期后缀）：
   - 默认 Base URL 前缀：`https://ark.cn-beijing.volces.com/api/plan/v3`（完整图片生成地址 `https://ark.cn-beijing.volces.com/api/plan/v3/images/generations`）
   - 视觉模型 ID：`doubao-seedream-5.5`（默认）、`doubao-seedream-5.0-pro`、`doubao-seedream-5.0-flash`（可通过 `--model` 切换）
   - 视频模型（Seedance）：订阅不含 Seedance，需另购，地址未知（对应子命令已默认禁用）。
3. 在 Agent Plan 控制台创建专属 API Key 并存入 macOS 钥匙串。

### 怎么存钥匙

本工具**只从 macOS 钥匙串读取**（`security find-generic-password -s ark-api-key -w`，存 Agent Plan 专属钥匙），不读环境变量或 `.env` 文件，不落盘，日志、报错与 `--meta-out` 均自动打码；`--base-url` 仅放行 `https://ark.cn-beijing.volces.com/api/plan/v3` 前缀与本地单测地址（`127.0.0.1`/`localhost`），`/api/v3` 前缀一律拒绝并提示额外扣费；鉴权请求拒绝自动跟随 30x 重定向（并把 `Authorization` 放进 unredirected 头），下载结果文件时不携带 `Authorization` 头。

```sh
# 存入或更新 Agent Plan 专属 API Key（回车后密文输入，不留命令历史）
security add-generic-password -U -a "$USER" -s ark-api-key -w

# 只验证是否已存（不打印内容）
security find-generic-password -s ark-api-key >/dev/null && echo "已存入"

# 如需删除
security delete-generic-password -s ark-api-key
```

### 每次大概花多少

具体额度与刊例以火山方舟控制台实时页面为准：

- **Agent Plan 订阅内 Seedream 文生图／图生图**：走 `https://ark.cn-beijing.volces.com/api/plan/v3/images/generations` 计入 Agent Plan 套餐额度；切勿改用 `/api/v3`，否则会按量产生套餐外额外费用（标准按量参考约 **0.22～0.40 元／张**）。
- **Seedance 视频生成**：订阅不含 Seedance，需另购，接口地址与费用以另购控制台为准（本工具 `img2vid`／`fetch` 子命令已默认禁用）。

### 常用命令与自测

默认均为 **1:1 比例**、**关闭水印**（加 `--watermark` 才开启），默认模型 `doubao-seedream-5.5`，默认 `--response-format b64_json`（随 API 响应直回图片字节，避免跨区直连对象存储超时；显式传 `--response-format url` 时下载遇临时故障仅重试下载，绝不重发生成请求）。本地参考图自动转 Base64 Data URI，无需公网图床。出图不抠绿时按文件头魔数校验与 `--out` 扩展名是否一致（Seedream 5.x 自动请求对应 `output_format`），不符时自动转格式（Pillow 或 macOS `sips`），无法转换则报错且不写入伪 PNG。

```sh
# 文生图（支持别名 t2i / 文生图），加 --green-key 抠绿并保留 *_raw 原绿底图
python3 方舟出图.py txt2img --prompt "纯绿底侧视像素剑客" --out /tmp/role.png
uv run --with pillow --with numpy python3 方舟出图.py txt2img \
  --prompt "纯绿底侧视像素剑客" --green-key --out /tmp/role.png

# 切换 Agent Plan 其他视觉模型
python3 方舟出图.py txt2img --model doubao-seedream-5.0-pro --prompt "纯绿底侧视像素剑客" --out /tmp/role.png

# 图生图（支持别名 i2i / 图生图；--ref 可重复传多张本地图）
python3 方舟出图.py img2img --ref ref1.jpg --ref ref2.png \
  --prompt "保持造型，拔刀定妆，纯绿底" --out /tmp/m5a.png

# 假服务器单测（覆盖文生图、图生图、Agent Plan 前缀校验与 /api/v3 拒接、视频子命令默认禁用、底层视频轮询/失败/超时/重试/续取、URL 过期、防跳转外泄、伪 PNG 校验转换、钥匙串安全与抠绿）
python3 -m unittest -v 03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py
uv run --with pillow --with numpy python3 -m unittest -v 03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py
```

说明：`img2vid`（`i2v`/`图生视频`）与 `fetch`（`resume`/`续取`）当前默认禁用，调用时会直接退出并提示「订阅不含 Seedance，需另购，地址未知」。
