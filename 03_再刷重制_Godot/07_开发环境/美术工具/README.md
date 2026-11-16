# 待机漂移量测

`idle_drift.py` 为离线只读美术量测工具（Pillow），放 `07_开发环境/美术工具/`：对所有重绘角色复用，且完全移出 Godot 工程，避免 all_resources 导出带入离线工具。默认扫描本工程 content 新绘图集与 generated 中 Codex 战斗图／逐帧形态，运行时 content 素材覆盖同名 generated 图；另只读 git 中 gpt/yunshang-v2 的云裳 T113 样板。云裳样板左上为空，按其 README 明确量第二排 wait，报告标“sample wait (not wired)”，不假冒已接线的实际 walk。

运行：`python3 ../07_开发环境/美术工具/idle_drift.py --out /tmp/idle_drift.json`。也可重复传 `--sheet <MV图集>` 只测指定图；默认阈值为原始像素1，`--threshold` 可调。图集取 walk 左上三格，逐帧资源取动作0前三张；单帧形态不制造三帧，报告 frame_count。

报告每帧外接框、脚底、上半身／左右手所在带的alpha质心与外接框边缘跨度，以及实际最底行接触点跨度。超过1px记REVIEW；这是一份审图筛查名单，不自动判定坏图，不做任何修图。头区可能含头发、手区可能含衣摆／尾巴，轮廓变化不一定是锚点移动；脚只量最底接触行，避免把尾巴当脚。不同格尺寸按原始像素量，报告保留cell供缩放评估。完全不移动轮廓的纯内部颜色变化不会被alpha指标发现，仍需看动图。

检测器自验：0px与1px平移不提示，2px平移提示REVIEW；宿傩原图能检出头部2px漂移，修后头手脚指标为零。T123实测25组，具体名单见 `00_项目管理/交付/附图/gpt_mira-feet/T123/idle_drift_summary.md`，没有自动修改超标角色。
