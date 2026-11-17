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
