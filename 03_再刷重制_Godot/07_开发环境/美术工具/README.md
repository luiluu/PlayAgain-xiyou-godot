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

## 火山方舟出图出视频（T435）

`方舟出图.py`：直接调用火山方舟（Volcengine Ark）REST 接口的命令行工具，替代第三方 MCP。基础出图／出视频仅用 Python 标准库（零第三方依赖），开启 `--green-key` 时按需复用同目录 `muse转精灵.py` 的 `key_mask` 与 `despill`（此时需 Pillow＋numpy，可用 `uv run --with pillow --with numpy` 或 venv）。

### 怎么开通

1. 登录火山引擎控制台（`https://console.volcengine.com/ark`），完成实名认证并开通「火山方舟」。
2. 在「模型广场」／「开通管理」开通需要用到的模型（按量计费）：
   - 出图（Seedream）：默认 `doubao-seedream-5-5-261028`（也可通过 `--model` 指定 `doubao-seedream-5-0-pro-260628`、`doubao-seedream-5-0-lite-260128`、`doubao-seedream-4-5-251128` 或自定义推理接入点 `ep-xxxx`）。
   - 视频（Seedance）：默认 `doubao-seedance-2-5-260628`（也可通过 `--model` 指定 `doubao-seedance-2-0-260128`、`doubao-seedance-2-0-fast-260128`、`doubao-seedance-1-5-pro-251215` 或 `ep-xxxx`）。
3. 在「API Key 管理」新建一把 API Key，并确保账户有可用按量计费余额。

### 怎么存钥匙

本工具**只从 macOS 钥匙串读取**（`security find-generic-password -s ark-api-key -w`），不读环境变量或 `.env` 文件，不落盘，日志、报错与 `--meta-out` 均自动打码；下载结果文件时也不携带 `Authorization` 头。

```sh
# 存入或更新 API Key（回车后密文输入，不留命令历史）
security add-generic-password -U -a "$USER" -s ark-api-key -w

# 只验证是否已存（不打印内容）
security find-generic-password -s ark-api-key >/dev/null && echo "已存入"

# 如需删除
security delete-generic-password -s ark-api-key
```

### 每次大概花多少（人民币参考）

具体扣费随模型档位、分辨率与资源包浮动，以火山方舟控制台实时刊例为准：

- **Seedream 文生图／图生图**：按张计费，大致 **0.22～0.40 元／张**（如 5.0 Lite 约 0.22 元起、5.0 Pro 约 0.30 元起）。
- **Seedance 图生视频**：按分辨率与时长计费（底层折算 Token），大致折合：
  - `480p`：约 **0.46～0.70 元／秒**（4 秒约 **2～3 元**）
  - `720p`（默认）：约 **0.99～1.50 元／秒**（4 秒约 **4～6 元**）
  - `1080p`：约 **2.50～3.70 元／秒**（4 秒约 **10～15 元**）

### 常用命令与自测

默认均为 **1:1 比例**、**关闭水印**（加 `--watermark` 才开启）。本地参考图自动转 Base64 Data URI，无需公网图床。

```sh
# 文生图（支持别名 t2i / 文生图），加 --green-key 抠绿并保留 *_raw 原绿底图
python3 方舟出图.py txt2img --prompt "纯绿底侧视像素剑客" --out /tmp/role.png
uv run --with pillow --with numpy python3 方舟出图.py txt2img \
  --prompt "纯绿底侧视像素剑客" --green-key --out /tmp/role.png

# 图生图（支持别名 i2i / 图生图；--ref 可重复传多张本地图）
python3 方舟出图.py img2img --ref ref1.jpg --ref ref2.png \
  --prompt "保持造型，拔刀定妆，纯绿底" --out /tmp/m5a.png

# 图生视频（支持别名 i2v / 图生视频；建任务后自动轮询并下载）
python3 方舟出图.py img2vid --first-frame /tmp/m5a.png \
  --prompt "拔刀挥砍后收势" --duration 4 --ratio 1:1 --out /tmp/m5a.mp4

# 假服务器单测（11 项：三条路径、任务失败、超时、URL 过期、钥匙串缺失、脱敏与抠绿）
python3 -m unittest -v 03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py
uv run --with pillow --with numpy python3 -m unittest -v 03_再刷重制_Godot/07_开发环境/美术工具/test_方舟出图.py
```

图生视频输出的纯绿底 `.mp4` 可直接交给同目录 `muse转精灵.py` 转为 128 格战斗图集；如只想快速逐帧抠绿导出透明 PNG 序列，也可在 `img2vid` 加上 `--green-key`（输出到 `<视频名>_keyed/`）。
