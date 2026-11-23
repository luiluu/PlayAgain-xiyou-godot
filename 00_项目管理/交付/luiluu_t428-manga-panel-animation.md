# 交付：luiluu/t428-manga-panel-animation

- 车道／工作者：三阶漫画动画③／小A（T428）
- 状态：可合并

## 变更记录草稿

## 2026-11-23 【小A·界面·未经审查】T428 三阶漫画动画③：P1 实时入格网点 Shader、P10 劈页碎格与 P11 破边残格气泡（dev.待定）

- 依据：私密仓 `重制设定/二阶到三阶_徐凤年回归动画_分镜_v0.5.md`（基于 v0.4 `b220f6e0` 与 T426 文字审定稿）第 1、2、4、7、8 节拆卡 3。
- 代码与着色器改动：
  - 新增 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/shaders/comic_halftone.gdshader`（含 `.gdshader.uid`）：兼容 `gl_compatibility`（GLES3 / OpenGL 3.3 Core，无 `hint_screen_texture`），实现四邻亮度梯度墨线轮廓（`#0B0B0E`）、45° 旋转半调网点（`#F4F2EC` 纸白／`#0B0B0E` 墨点）、中心二阶漩涡高紫度区域克制留紫微点（`#8F5CEB`），并提供 `mix_amount` 与 `zoom` 统一参数。
  - 升级 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/rift3_anim.gd`（保持 T425 拆卡 2 全部接口、状态字段、抗变速齿轮、保护期跳过与 `missed_lines` 口径 100% 兼容）：
    - **P1 实时入格（`0.0–2.6s`）**：绑定 `comic_halftone.gdshader`，`0.0–0.30s` 由全屏 `1280×720` 微弹收束进左格 `(48, 56, 560×440)` 并同步显现黑白半调网点与 5px 粗白边框，`0.30–2.60s` 格内 `1.00×→1.04×` 缓推；未传视口贴图时提供含方桌与幽紫漩涡的程序占位底图。
    - **P10 实时劈页碎格（`15.0–17.3s`）**：`PhaseP10` 不设任何全屏不透明底板，用两块斜切 `Polygon2D` 沿右上→左下对角线 `(1120,0)→(160,720)` 切开 P9 尾帧画页；`15.00–15.10s` 两半画页触发 `gl_compatibility` 轻量反色冲击帧＋12px 重震屏＋收尖纯白／朱红刀光＋「斩」刀意字砸入与末段碎散；`15.40–16.35s` 两半加速滑开出屏实时透出底层真实 `Map004`；`P10ShardParticles`（`CPUParticles2D`，`amount = 96`）爆发黑白网点碎纸飞溅；M6 透明挥斩（`0.82×→1.18×`）冲破裂口劈散下方四缕残余紫烟后收势消隐（缺 Muse 资产时自动走黑白朱红程序占位图）。
    - **P11 破框残格三连对白与碎页收尾（`17.3–26.0s`）**：左侧 `PortraitShard` 改为带阴影与锯齿破边的斜切漫画残格（多边形裁切复用 M5a 并缓推 `1.00×→1.03×`）；右侧白底黑粗框漫画对白气泡补齐指向左侧残格的尖尾三角形、切句轻弹入与 2 行自然折行（左上朱红名签 `徐凤年` 全程常驻不闪烁）；P11b `21.2s` 仅在残格右侧破边与气泡右下外角触发单拍 `2px` 幽紫电纹与微颤，正文始终保持深墨 `#0B0B0E` 不变紫；P11c 叠加红带微风飘尘与蓄势微推；`24.7s` P11d 触发 `P11ShardParticles`（`CPUParticles2D`，`amount = 20`，与 P10 合计 `116 <= 120`）向右上方飘散＋底部居中半透明墨黑底浅银白字（`#DCDCE0`）`after` 旁白条，`26.0s` 或中途跳过退出时立即停粒子并 `queue_free()` 零节点泄漏。
- 专项测试与验证：
  - 新增专项 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim_fx.tscn`（含 `.gd` 与 `.gd.uid`）：
    - 本机 `--headless --audio-driver Dummy`：**27/27 通过**；
    - 本机实机窗口 `gl_compatibility`（OpenGL 4.1 Metal Compatibility，`--audio-driver Dummy`）：**35/35 通过**，无着色器报错，实测真开 `Map004` 验证 P1 半调对比度与去色度、P10 裂口后实时透出真实 `Map004`、P11 残格／气泡／名签零遮挡与 2 行排版、全树 `CPUParticles2D` 总预算 `96 + 20 = 116 <= 120`、自然播满与 P10 粒子中途跳过均零节点泄漏。
  - 回归既有专项：
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim_player.tscn`（`--headless --audio-driver Dummy`）：**59/59 通过**；
    - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_input_handled.tscn`（`--headless --audio-driver Dummy`）：**10/10 通过**。
  - `03_再刷重制_Godot/07_开发环境/发行空壳.py check`：81 个脚本 782 个函数通过（退出码 0）；`随机守卫.py`：83 个天启篇脚本通过（退出码 0）。
  - 云端选测（提交 `1cccf53d37`，基准 `ee7cd3b85942a3da36b45d969a61079217c6fc28`）：**通过**（6 个场景、2 片全绿，最长一片 3.4 分钟），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45224452124 。

## 交接板

- 下一步：合并 `luiluu/t428-manga-panel-animation` 后，拆卡 2＋3（`XRift3Anim` 播放器骨架＋实时网点／劈页／残格气泡）全部就绪，待拆卡 5（T430 事件替换接线）与拆卡 1／4（T427 Muse 资产与离线合成 `.ogv`）落地后即可直连正式片源。
- 用户试玩说明：无玩家可见变化（拆卡 5 事件接线与拆卡 4 漫画资产尚未合入，`XRift3Anim.available()` 当前为 `false`，不会改变线上过场表现）。
- 需要用户决定：无。

## 进度账

- 西游／三阶过场漫画动画：完成拆卡 3（P1 实时入格网点 Shader、P10 劈页碎格粒子、P11 破边残格尖尾气泡与退场清理）及实机截图验证，主表百分比不变。

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

无（本单仅修改独占文件 `modes/xiyou/ui/rift3_anim.gd` 并新增 `modes/xiyou/ui/shaders/comic_halftone.gdshader` 与专项 `tests/xiyou_rift3_anim_fx.*`，未改动 `core/`、`battle/`、`skin/` 下任何已有函数或开关）。

## 云端选测与截图验收

- 云端选测（提交 `1cccf53d37`，基准 `ee7cd3b85942a3da36b45d969a61079217c6fc28`）：**通过**（6 个场景、2 片全绿，最长一片 3.4 分钟），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45224452124
- 实机 `gl_compatibility`（真实 `Map004` 叠加，缺 Muse 视频／图时走程序占位）验收截图（已全部入仓）：
  - `00_项目管理/归档/交付截图/luiluu_t428/01_p1_halftone.png`（P1 `1.00s`：真实 `Map004`＋二阶漩涡经 `comic_halftone.gdshader` 收束入左格＋`whisper` 旁白框）
  - `00_项目管理/归档/交付截图/luiluu_t428/02_p10_slash_split.png`（P10 `15.22s`：右上→左下对角白红刀光＋「斩」刀意字＋P9 两半初裂）
  - `00_项目管理/归档/交付截图/luiluu_t428/03_p10_shards_reveal.png`（P10 `15.75s`：两半滑开实时透出真实 `Map004`＋碎格粒子飞溅＋M6 透明挥斩掠散紫烟）
  - `00_项目管理/归档/交付截图/luiluu_t428/04_p11a_sense_bubble.png`（P11a `18.20s`：左侧破边残格＋右侧尖尾气泡与常驻朱红名签 `徐凤年`，`sense` 2 行整句即显）
  - `00_项目管理/归档/交付截图/luiluu_t428/05_p11b_hint_purple_edge.png`（P11b `21.25s`：`hint` 句仅残格破边与气泡外角单拍幽紫微闪，正文保持纯深墨 `#0B0B0E`）
  - `00_项目管理/归档/交付截图/luiluu_t428/06_p11d_scatter_after.png`（P11d `25.05s`：末段 20 片碎纸飘散＋底部居中 `#DCDCE0` `after` 旁白条归还真实 `Map004`）

## 本分支提交

- `1cccf53d3` T428 三阶漫画动画③：P1 实时入格网点 Shader、P10 劈页碎格与 P11 破边残格气泡
