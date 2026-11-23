# 交付：luiluu/t425

- 车道／工作者：三阶漫画动画②／小A（T425）
- 状态：可合并

## 变更记录草稿

## 2026-11-23 【小A·界面·未经审查】T425 三阶漫画动画②：新增 XRift3Anim 播放器骨架（dev.待定）

- 依据：私密仓 `重制设定/二阶到三阶_徐凤年回归动画_分镜_v0.4.md` 拆卡 2，以及 T426 文字审定稿 `重制设定/二阶到三阶_徐凤年回归动画_分镜_v0.5.md` 第 7 节。
- 代码改动：
  - 新增 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/rift3_anim.gd`（`class_name XRift3Anim extends CanvasLayer`，含 `.gd.uid`）：
    - **层级与守卫**：`CanvasLayer` 层级 `88`；`available()` 同时校验 `XRift3Anim.ENABLED`、`XRift.STAGE3`（并动态兼容后续拆卡 5 在 `XRift` 新增的 `RIFT3_ANIM` 开关，未动 `modes/xiyou/core/rift.gd`）及 4 个必需漫画资源（`rift3_comic_mid.ogv`、`rift3_m6_slash.webp`、`rift3_p9_end.webp`、`rift3_m5a_portrait.webp`），缺任一资源时返回 `false` 不报错；支持 `play(..., allow_placeholder=true)` 程序占位模式跑通全 26.0s 链路。
    - **四段状态机与抗变速齿轮**：P1（`0.0–2.6s`）→ MID（`2.6–15.0s`，仅入段播 `.ogv`、出段停播）→ P10（`15.0–17.3s`）→ P11（`17.3–26.0s`，`24.7s` 起 P11d 退左侧残格与名签）；`_process` 与 `VideoStreamPlayer.speed_scale` 均除掉 `maxf(Engine.time_scale, 0.001)`，按真实秒计时。
    - **保护期跳过与 `missed_lines`**：`0.0–0.8s` 保护期吃掉下层输入且不触发跳过（全用 `XKeyMap.handled(self)`，不直调 `set_input_as_handled`）；`0.8s` 后任意按键／鼠标左键／触屏／手柄按一次触发 `0.25s` 压黑退出，按跳过瞬间 `_t` 依据 5 句阈值（`2.2s`/`19.4s`/`22.1s`/`24.3s`/`25.7s`）按序写入静态 `missed_lines`；自然播满 `26.0s` 时 `missed_lines` 为空。
    - **v0.5 第 7 节定稿叠字与对白框**：7 处拟声字（`嗡——`/`咔嚓！`/`嘶啦！`/`轰——！`/`唰！`/`铮！`/`锵——！`）＋1 处唯一刀意字（`斩`，`0.45s` 后消失）按时间码叠字；5 句对白正文与名签运行时直读 `XRift.RIFT3_LINES` 零重复写死——P1 `whisper` 细白边黑底旁白框去 `<??????>` 标头与前导换行、单行居中整句即显，P11a～c `sense`/`hint`/`follow` 白底黑粗框气泡配左上常驻朱红名签 `徐凤年`、跨句间隙不闪烁且整句即显，P11d `after` 底部半透明墨黑底浅银白字（`#DCDCE0`）收尾旁白条。
- 专项与验证：
  - 新增专项 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim_player.tscn`（含 `.gd` 与 `.gd.uid`）：本机 `--headless --audio-driver Dummy` **59/59 通过**，覆盖缺资源／逐一缺 1 资源／开关关闭守卫、`layer==88`、`Engine.time_scale=1.6` 确定性与真实帧循环计时、`<0.8s` 保护期、1.0s/10.0s/23.0s 及临界阈值写 `missed_lines`（5/4/2 条与跳过瞬间时间冻结）、播满 26.0s `missed_lines` 为空、v0.5 7 拟声＋1 刀意字「斩」、P1/P11 对白与常驻名签、`after` 字色 `#DCDCE0`、源码零写死 5 句正文及不直调 `set_input_as_handled`。
  - 本机相关回归：`tests/xiyou_input_handled.tscn` **10/10 通过**（`--headless --audio-driver Dummy`）。
  - `03_再刷重制_Godot/07_开发环境/发行空壳.py check`：81 个脚本 782 个函数全部通过（退出码 0）。
  - 云端选测（提交 `e69808d1cc`，基准 `35bb9fbd0efd42fc03a542a850eb5d7484a131cf`）：**通过**（4 片 77 个场景全绿，最长一片 8.3 分钟），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45199620395 。

## 交接板

- 下一步：合并 `luiluu/t425` 后可解锁拆卡 3（P1 实时入格 Shader／P10 劈页碎格粒子／P11 残格视觉增强，续改 `modes/xiyou/ui/rift3_anim.gd`）与拆卡 5（`rift.gd` 新增 `XRift.RIFT3_ANIM` 开关与事件替换接线、`mv_script.gd`、`map_scene.gd`、`tests/xiyou_rift3_anim.gd`）。
- 用户试玩说明：无玩家可见变化（本单仅新增未接线的 `XRift3Anim` 播放器骨架与专项测试，且 4 个漫画资产尚未入仓、`available()` 当前为 `false`）。
- 需要用户决定：无。

## 进度账

- 西游／三阶过场漫画动画：完成拆卡 2 `XRift3Anim` 播放器骨架与专项测试（按分镜 v0.5 定稿），主表百分比不变。

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

无（本单仅新增独占文件 `modes/xiyou/ui/rift3_anim.gd` 与专项 `tests/xiyou_rift3_anim_player.*`，未修改 `core/`、`battle/`、`skin/` 下任何已有文件；`XRift3Anim.available()` 通过 `XRift` 脚本动态兼容读取未来拆卡 5 在 `rift.gd` 新增的 `RIFT3_ANIM` 开关）。

## 云端选测与独占范围

- 云端选测（提交 `e69808d1cc`，基准 `35bb9fbd0efd42fc03a542a850eb5d7484a131cf`）：**通过**（4 片 77 个场景全绿），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45199620395
- 截图：不涉及（本单为播放器骨架＋程序占位单测，无正式美术资产入仓）。
- 本单新增文件（严格在独占范围内，未碰 `rift.gd` 等其他文件）：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/rift3_anim.gd`
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/rift3_anim.gd.uid`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim_player.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim_player.gd.uid`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_rift3_anim_player.tscn`
  - `00_项目管理/交付/luiluu_t425.md`

## 本分支提交

- `f869bb7c4` T425 三阶漫画动画②：新增 XRift3Anim 播放器骨架与专项测试（按分镜 v0.5 定稿）
- `e69808d1c` Merge branch 'main' into luiluu/t425
