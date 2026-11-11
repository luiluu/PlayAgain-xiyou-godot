# 交付：claude/project-thread-c90b30

- 车道／工作者：B 界面·天启篇标题页／cc（Pro，浏览器云端会话）
- 状态：可合并

> 总装合并前注意：本分支**没改 `entry.gd`**（天启篇开局第二批正在改它）。下面「合并时要加的接线」要在合并时手动加进 `entry.gd`，同时改 `tests/xiyou_input_handled.gd` 一处；不接线时新标题不会出现，原版标题照旧。

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

## 合并时要加的接线（`modes/xiyou/entry.gd`）

一共五处，都只在 `XTianqiTitle.available()` 为真时生效；`XTianqiTitle.ENABLED = false` 时走原代码一行不变。

**1. 成员变量**（放在 `var _cursor_t := 0.0` 下面）：

```gdscript
var _tq_title: XTianqiTitle       # 天启篇新标题（O-待定）；不用新标题或已换到别的页面时为 null
```

**2. `_ready()` 里启动动画结束的回调**：把

```gdscript
			intro.finished.connect(func():
				XWarningScreen.play(self).finished.connect(func():
					_title()
					XIntroAnim.fade_in_title(self)))
```

换成

```gdscript
			intro.finished.connect(func():
				XWarningScreen.play(self).finished.connect(func():
					_title()
					# 天启篇新标题自己从黑里亮起并睁眼（XTianqiTitle.play_entrance）；原版标题照旧整体淡入
					if _tq_title != null:
						_tq_title.play_entrance()
					else:
						XIntroAnim.fade_in_title(self)))
```

**3. `_clear()` 末尾**加一行（换页时丢掉新标题的引用，`is_title_page()` 才不会在读档页等子页里还算顶层）：

```gdscript
	_tq_title = null
```

**4. `is_title_page()`** 换成：

```gdscript
func is_title_page() -> bool:
	return not _commands.is_empty() or (_tq_title != null and _tq_title.is_title_page())
```

**5. `_title()` 开头**：在 `_clear()` 后面插入

```gdscript
	if XTianqiTitle.available():
		_tq_build_title()
		return
```

并在 `_title()` 后面加这几个函数：

```gdscript
## 天启篇新标题（XTianqiTitle，O-待定）：五项功能从这里传进去；版本号、导入导出、「继续」照原版标题加，挪进它的 extras 层（跟菜单一起淡入）。
## 原版 login 底图与粒子（_build_background）留在下面，被新底图整个盖住；读档、选存档位等子页仍以它为背景。
func _tq_build_title() -> void:
	var any := false
	for i in range(1, XSave.SLOTS + 1):
		any = any or XSave.exists(i)
	var actions := {
		"new_game": _on_new_game,
		"load": _choose_save,
		"options": _tq_open_options,
		"achievements": _tq_open_achievements,
		"check_update": _tq_check_update,
	}
	# 发行构建没有版本选择，不放「返回版本选择」（BI）
	if not ReleaseEntry.skips_menu():
		actions["back_to_menu"] = GameApp.return_to_menu
	_tq_title = XTianqiTitle.new()
	_tq_title.setup(actions, [] if any else ["load"])
	_layer.add_child(_tq_title)
	var before := _layer.get_child_count()
	var ver := XUI.label(ReleaseEntry.APP_NAME if ReleaseEntry.is_release() else "重制开发版 · 首期：开局区域", 18, XUI.DIM)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = get_viewport_rect().size - Vector2(330, 40)
	_layer.add_child(ver)
	if XPlatform.is_touch():
		_add_transfer_buttons()
	if XSave.exists_auto():
		_add_auto_button()
	for n in _layer.get_children().slice(before):
		n.reparent(_tq_title.extras, false)
	if OS.get_cmdline_user_args().has("--report-entry"):  # 冒烟：标题有没有「继续」（安卓实机冒烟.py）
		print("AUTO_SAVE_PRESENT=%s" % XSave.exists_auto())


## 新标题「游戏设置」：没读档也能开（XOptionsScene 对 XState.current 为空都有判断），关掉回标题
func _tq_open_options() -> void:
	_clear()
	var page := XOptionsScene.new()
	page.name = "OptionsPage"
	_layer.add_child(page)
	page.closed.connect(_title)


## 新标题「游戏成就」：显示全局已得的成就（本局计数为 0），关掉回标题
func _tq_open_achievements() -> void:
	_clear()
	var page := XAchievementScene.new()
	page.name = "AchievementPage"
	_layer.add_child(page)
	page.closed.connect(_title)


## 新标题「检查更新」：先只显示版本号和下载去处，不联网（Kyo 定做成什么后再改）
func _tq_check_update() -> void:
	_notice("检查更新", "当前版本：%s\n新版本请到 QQ 群下载。" % XVersionLabel.version_text())
```

**同时改 `tests/xiyou_input_handled.gd`**（它用 `title._commands` 选「返回版本选择」，新标题没有 `_commands`）：在 `if XDB.available():` 块的 `for` 前后关掉新标题，测的仍是原版标题按键处理：

```gdscript
	if XDB.available():
		var tq_title := XTianqiTitle.ENABLED
		XTianqiTitle.ENABLED = false  # 本段测原版标题图片指令的按键处理；新标题的按键由 xiyou_tianqi_title 测
		for code in [KEY_SPACE, KEY_J]:
			...（原样）
		XTianqiTitle.ENABLED = tq_title
```

接线后要在 Mac 上跑（云端没有转换产物，经过 `entry.gd` 的都跑不了）：

- 必跑：`xiyou_tianqi_title`、`xiyou_splash_autosave`、`xiyou_tianqi_opening`。
- 标题相关（新标题下节点名 `ReturnToMenu`、`ImportSave`、`ExportSave`、`ContinueAuto` 都保留，`is_title_page()` 接上了）：`xiyou_input_handled`（连同上面的改动）、`xiyou_entry_release`、`ui_smoke`、`xiyou_platform`、`xiyou_pause_save`。
- 实机看一眼：开场动画 → 声明屏 → 标题亮起、睁眼、Logo 浮出、菜单淡入；进场中按键跳过；设置页、成就页从标题打开再返回；安卓返回键在标题上是顶层。

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

- 下一步：合并时加上面的接线并在 Mac 上跑标题相关专项；Kyo 看过四个新按钮和菜单动效后，换图只换 `content/title/` 同名文件；美术拆好五层眼后换掉 `eye_0`～`eye_6`。
- 用户试玩说明：启动后开场动画合眼 → 免费声明 → 新标题从黑里亮起、眼睛睁开、Logo 浮出，菜单五项；「游戏设置」「游戏成就」在标题就能开；「检查更新」只显示版本号。
- 需要用户决定：
  1. 「检查更新」做成什么：现在只显示版本号和「新版本请到 QQ 群下载」、不联网。要不要联网查版本、跳转群链接，还是去掉这一项。
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
