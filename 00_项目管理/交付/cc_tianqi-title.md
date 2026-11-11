# 交付：cc/tianqi-title（原 PR #29 分支 claude/project-thread-c90b30，总装接线）

- 车道／工作者：B 界面·天启篇标题页／cc（Pro，浏览器云端会话）
- 状态：可合并

> 接线已由总装加在本分支（见「合并接线」）。

## 变更记录草稿

## 2026-11-11 【cc·Pro·未经审查】天启篇标题页：新美术＋接住启动动画的睁眼进场（dev.待定）

- 天启篇标题换成 Codex 出的新美术：底图 T1、书法 Logo T2、五个两态菜单字效 T3、三角光标 T4（`content/title/`，来历写在同目录 README）。原版标题（login 底图、图片指令、粒子）留着，`XTianqiTitle.ENABLED = false` 回到原版。
- 新类 `XTianqiTitle`（`modes/xiyou/ui/tianqi_title.gd`）：五项「新的游戏、旧的回忆、游戏设置、游戏成就、检查更新」竖排在天启之眼下方（中心 x 640、第一项 y 390、行距 50，照菜单动效 v2 样张量的）；选中项用两态图上半并放大到 1.1 倍，未选中用下半、0.9 倍，0.12 秒过渡；光标缩到 0.4 倍放在选中字左侧，切换时从左 4 像素 0.2 秒减速滑入。键盘上下（首尾循环、跳过灰掉的项）、手柄十字键、鼠标悬停、触屏点按都能选，确定键／点击执行。功能由 `setup(actions, disabled)` 传进来，本类不引用 `entry.gd`。
- 进场 `play_entrance()`（只在启动动画＋声明屏之后那一次）照启动动画 v8 成片后段：全黑 → 1.2 秒亮起（眼睛闭着）→ 第 26 帧起逐帧换 7 张睁眼帧、睁完去掉贴片 → 第 36～56 帧 Logo 从下方 8 像素上浮淡入 → 菜单 0.3 秒淡入。时间按真实秒计（除掉 1.6 倍速）。进场中按任意键、点一下直接跳到最终画面（这一下被吃掉，不会误点菜单）。从游戏回标题、读档页取消、没放启动动画时直接是最终画面。`XIntroAnim.ENABLED = false` 时也不做进场。
- 「检查更新」：游戏里没有这个功能，先弹一页显示当前版本号和「新版本请到 QQ 群下载」，不联网。
- 「游戏设置」「游戏成就」从标题直接打开（没读档也能开）：设置页里要存档的项照原样显示「进入游戏」或不生效，成就页显示全局已得的成就，本局计数为 0。
- 开发构建另有一个「返回版本选择」小按钮在左下角，不占五项的位置；版本号、触屏导入／导出存档、左上「继续」照原样保留，跟菜单一起淡入。
- 新专项 `xiyou_tianqi_title`（37 项，直接实例化 `XTianqiTitle`，不要转换产物）。
- 玩家可见：标题换成天启篇新画面：开场动画合眼后，标题从黑里亮起、天启之眼睁开、Logo 浮出，菜单是「新的游戏、旧的回忆、游戏设置、游戏成就、检查更新」五项；设置和成就在标题就能打开。

## 合并接线（总装已加，分支 cc/tianqi-title）

- `entry.gd` 照本单原稿加五处（成员 `_tq_title`、启动动画后 `play_entrance()`、`_clear()` 清引用、`is_title_page()`、`_title()` 分流到 `_tq_build_title()`）和 `_tq_open_options`／`_tq_open_achievements`。
- 「检查更新」按 update-check1 交付单接自动更新三处：按钮打开 `XUpdatePage.open(self)`（不再是只显示版本号的提示框）；建好新标题后 `XUpdateClient.instance(get_tree()).auto_check()`；红点看 `has_update()`，连 `checked` 信号查完刷新。红点由新加的 `XTianqiTitle.set_badge(key, on)` 画（按钮右上角 16 像素红圆）。
- `tests/xiyou_input_handled.gd` 照原稿在原版标题段前后关、开 `XTianqiTitle.ENABLED`；`xiyou_tianqi_title` 加红点三项（本机 40/40）。
- `选测对照.json` 加 `tianqi_title` 组。

## 选测对照（`选测对照.json`）

新组建议：

```json
"tianqi_title": {"说明": "天启篇标题页（XTianqiTitle 与 content/title/）：跑标题专项和开场专项", "scenes": ["xiyou_tianqi_title.tscn", "xiyou_splash_autosave.tscn"]}
```

匹配：`03_再刷重制_Godot/01_Godot工程/content/title/*`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/tianqi_title.gd`、`03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_title.*` → `tianqi_title`。

## 优化登记（草稿，由总装登记）

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/ui/tianqi_title.gd` `XTianqiTitle.ENABLED`；`entry.gd` `_title()` 分流；素材 `content/title/` | 原版标题：titles1/login 底图、MOG_TitlePictureCom 图片指令（新的游戏、旧的回忆）、MOG_TitleParticles 粒子 | 天启篇标题：底图 T1、Logo T2、五项两态菜单（新的游戏、旧的回忆、游戏设置、游戏成就、检查更新）、光标 T4；启动动画后从黑里亮起、天启之眼睁开、Logo 上浮（接 O-262 的合眼）；设置和成就在标题直接打开；检查更新先只显示版本号 | 天启篇改版的标题美术（Codex 出图，Max 交接） | `XTianqiTitle.ENABLED = false` 回到原版标题 | cc（Pro） | 默认开 |

## 交接板

- 下一步：Kyo 看过四个新按钮和菜单动效后，换图只换 `content/title/` 同名文件；美术拆好五层眼后换掉 `eye_0`～`eye_6`。
- 用户试玩说明：启动后开场动画合眼 → 免费声明 → 新标题从黑里亮起、眼睛睁开、Logo 浮出，菜单五项；「游戏设置」「游戏成就」在标题就能开；「检查更新」打开更新页（联网查新版，有新版时按钮亮红点）。
- 需要用户决定：
  1. （已定：检查更新走自动更新页，Kyo 11-11 批准自动更新）
  2. 另外四个按钮（旧的回忆、游戏设置、游戏成就、检查更新）和菜单动效 v2 还没看稿，现在先用。
  3. 睁眼是占位（v8 眼睑算法对 T1 算的 7 帧），等美术拆好五层眼再换。
  4. 读档、选存档位、设置等子页背后仍是原版 login 底图；要不要也换成 T1。

## 进度账

- 天启篇（扩展账）：标题页新美术与进场完成，待接线；不影响一比一还原主表。

## 验证

- 云端（Linux，Godot 4.7.2，无转换产物）：`xiyou_tianqi_title` 37/37 通过；`python3 07_开发环境/语法检查.py` 683 个 .gd 0 个问题。
- 反向验证（`07_开发环境/反向验证.py`，8 处都咬住）：选中项换成下半图、灰掉的项也执行、睁眼晚一帧、进场结束不去贴片、进场中按键不跳过、不除 time_scale、光标不滑入、关掉天启篇不影响开关。
- 截图（xvfb＋OpenGL 直接实例化 `XTianqiTitle`）：最终画面、进场睁眼中途，放在 PR 说明里看效果，不进仓库。
- `工具回归.py`：云端失败 1 项「选测替身与 检查.sh 解析」，把本分支改动 stash 掉在 main 上也一样失败（云端环境问题，与本分支无关）；其余都过。
- 接线代码试接进 `entry.gd` 跑过一次语法检查（0 个问题），随后还原，没提交。
- 没跑：经过 `entry.gd` 的整条标题流程和上面「接线后要在 Mac 上跑」那些（要转换产物，交给 Max）。没推 `ci/**`。

## 可优化（流程／工具／效率）

- 建议：`07_开发环境/语法检查.py` 在 Linux 云端会去调 `07_开发环境/godot`（指向 Mac 的 `当前Godot.app`），退出码 127；能认 `$GODOT` 环境变量就能在云端直接用（预计省每次手搭链接，归工具车道）。这次是临时建了个链接跑完再删的。

## 本分支提交

- （见 PR）
