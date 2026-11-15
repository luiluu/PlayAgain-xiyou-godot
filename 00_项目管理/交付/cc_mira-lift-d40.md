# 交付：cc/mira-lift-d40

- 车道／工作者：C 战斗演出·米拉升空变身 D40／cc（Sonnet＋medium，派单定：一处位移参数小改＋一处显隐小修，不碰结算）
- 分支：`cc/mira-lift-d40`（从 main 切出）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·重制·未经审查】米拉升空变身 D40：起点放脚下、整段轨迹左挪、落地回正；P3 显隐不互相覆盖（dev.待定）

- 玩家可见：米拉变黑龙的升空演出开头，人形不再站在脚下右边 56 像素、一开始往右跳；现在从脚下起飞，升空时整段向左偏，落地约在左 25 像素，再平滑回到脚底变回黑龙，全程不跳。技能动画把米拉藏起来（闪屏隐藏）时，变身层也跟着藏，不会闪出人形或黑龙。
- 依据：Kyo 11-15 定 D40；P3 来自 mira-lift-u7 乙档核。D39（空中 1.9 倍）不动，等 D15。
- 改动（`battle/mira_lift_fx.gd`）：`KEYS` 第 4 列从「dx」改为绝对 x（0→…→−23@1050→−28@1210→−25@1530→−12@1660→0@1800），去掉 `X_OFFSET`，`body_point` 不再加 56；火屑跟随 `body_point` 照旧。时长、姿势、高度、淡化、缩放全不变。
- P3：`XBattlerSprite` 新增 `anim_hidden` 标志，`set_anim_hidden` 存标志并同步变身层（层 `visible`、本体显隐按 `XMiraLiftFx.body_shown()` 算）；变身层的 `_draw_at`、`finish` 改成 `not anim_hidden` 才显示本体，两边不互相覆盖。
- 开关：沿用 O-481 `XMira.LIFT_ART`（关＝旧表现，直接是黑龙，不走本路径），未另加子开关。
- 测试：`xiyou_mira_lift` 新增 `d40.*`（首帧在脚下 0±2px、1530 落地约 −25、末帧回原位、1×逐帧跳变 ≤8px、2×／4× 水平跳变 ≤8px、层首帧位置）与 `p3.*`（藏着时跨 tick／过 SETTLE／finish／cancel 都不闪出，取消藏后恢复显示）；旧断言 `start_right_56` 改 `start_at_foot`、peak 改 (−16,−116)、落地改只断言 y。57/57。

## 交接板

- 下一步：核查乙档（美术接入）→ 小A。
- 用户试玩说明：见上「玩家可见」。
- 需要用户决定：无。

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 无

## 验证

- 专项：`xiyou_mira_lift` 57/57（本机，6 秒）；`语法检查.py` 0 问题；截图 6 张：`03_再刷重制_Godot/04_验证/mira_lift_d40/mira_lift_{0000,0600,0920,1300,1530,2000}ms.png`（不入 Git）。
- 云端选测、发行空壳 check、交付自检：见回报。

## 本分支提交

- 见 git log

## 小A乙档核查

- **结论**：通过（无 P1 / P2 / P3；可合并）。
- **核查时间／对象**：2026-11-15，工作树 `mira-lift-d40`（`cc/mira-lift-d40`），审阅提交 `febdc0c92` / `b1d3a45a0` 与 `00_项目管理/交付/cc_mira-lift-d40.md`。
- **分项核查（区分已核规则与只看代码）**：
  1. **D40 轨迹规则与 6 张截图（0/600/920/1300/1530/2000ms）**：**已核规则＋截图像素边界核查**。`0000ms` 人形站位在脚底阴影正上方（主体 `x=240..351`、`y=256..399`，地面阴影 `x=236..363`、`y=400`），不再右跳约 70px；`0600ms`／`0920ms` 升空过程向左偏移（`-6`／`-16`）；`1300ms` 下降阶段明显左挪（主体中点 `267.5` vs 阴影 `299.5`）；`1530ms` 落地触地在左约 25px（主体中点 `274.5` vs 阴影 `299.5`）；`2000ms` 平滑回正为黑龙待机且与阴影重合（中点 `299.5`、`y=256..398`），无跳变。注：本次仅静态核对 6 张 2 倍截图，未做窗口实机连续录屏目视。
  2. **曲线连续性、倍速与暂停**：**已核规则＋专项实测＋代码／采样核对**。`mira_lift_fx.gd` 中 `KEYS` 第 4 列改为绝对 `x` 并去掉 `X_OFFSET`，相邻关键帧 `smoothstep` 插值、`body_point` 取整；Python 采样 `1×`/`2×`/`4×` 单帧水平最大位移分别为 `3px`/`5px`/`7px`（均 `≤8px`）；`appearance.gd` 的 `Codex_Mira_SV_u2`（底边 `y=61`）与 `UserSV_MiraDragon`（锚点 `(160,217)`）对齐 `HUMAN_ANCHOR`／`POSE_ANCHOR`（只看代码）；`1×`/`2×`/`4×` 帧数、中途变速与 `get_tree().paused` 同停已由 `xiyou_mira_lift` 实跑覆盖。
  3. **P3 显隐不互相覆盖（`anim_hidden`）**：**已核规则＋专项实测＋全库 `rg` 代码核对**。全局搜索 `set_anim_hidden`、`anim_hidden`、`sprite.visible` 与 `XMiraLiftFx`：`mv_animation.gd` 经 `set_anim_hidden` 调用；`battler_sprite.gd` 的 `set_anim_hidden` 同时约束 `lift.visible` 与 `sprite.visible = not h and not lift.body_shown()`；`mira_lift_fx.gd` 的 `_draw_at` 与 `finish()` 均遵守 `not sp.anim_hidden`，且 `finish()` 将层重命名为 `MiraLiftFx_done` 使同帧后续 `set_anim_hidden(false)` 时 `layer_of(sp)` 立即返回 `null`；`begin()` 在 `animate_on()` 为关或 `XMira.LIFT_ART == false` 时不改写 `sp.sprite.visible`；`battler_sprite.gd` 的 `blink()` 仅由 `XEnemy` 调用、不影响米拉。注：`p3.*` 单元测试已实跑通过，`mv_animation.gd` 与升空层真实并发播放为代码核对（未另跑战斗动画集成长测试）。
  4. **O-481 回退开关（`XMira.LIFT_ART`）**：**已核规则＋专项实测＋回退覆盖脚本核对**。`XMira.LIFT_ART = false` 时 `is_lift` 返回 `false`、`on_swap` 返回 `null` 直接切黑龙（中途关闭会在下一 `tick` 立即 `finish`），`rollback.no_layer` 通过且 `回退开关覆盖.py` 无缺口。
  5. **前台测试与留交总装项**：前台单跑 `xiyou_mira_lift.tscn` **57/57 通过**（约 7 秒），`语法检查.py` 947 个 `.gd` **0 个问题**。全量 `检查.sh`／选测长测试未在本次运行（按派单要求留给总装）；云端整轮既有 `text-fix-b` 引起的 12 个失败已由总装另行处理，不计入本单。

