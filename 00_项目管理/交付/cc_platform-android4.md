# 交付：cc/platform-android4

- 车道／工作者：平台／cc（BP，总装二十五派单第十一批）
- 状态：进行中

## 变更记录草稿

## 2026-11-06 【cc·平台·未经审查】平台三期：手机按键设置、安全区、存档导入导出（dev.待定）

- 依据：派单 BP（BH 交付单「下一步」）。原版参照：二合一包 v0.62.09 的 `assets/game/js/plugins/Codex_AndroidTouchSettings.js`、`android-integration.js`、`classes.dex`（只解到 scratchpad 看）。
- **手机按键设置**（原版在 `Window_Options` 末尾加「手机按键设置」，状态「调整」）：`options_scene.gd` 在触屏时把它加在列表最后（`TOUCH_OPTION`，非触屏不出现），确定音后打开新页 `modes/xiyou/ui/touch_options.gd`（`XTouchOptionsScene`，画法照消息提醒页）：显示屏幕按键、轮盘大小 70～170%、右侧按键大小 70～160%、顶部按钮大小 80～140%、按键透明度 0～80%（原版 limits，步长 5；左右键 ∓5，确定 +5 到顶回最小）、调整UI位置、恢复默认。
- `core/touch_controls.gd`：三组（movement＝摇杆、actions＝确定／取消／跑步、top＝隐藏按键）按大小缩放（贴原来那两条边缩放，100% 时位置与二期一模一样），透明度照原版 `opacity = 1 - 透明度/100`（调位置时不透明）；「调整UI位置」进布局编辑：按键全显示，拖哪组移哪组，上方「恢复位置」「完成」，返回键＝完成（`XPlatform.go_back` 返回 "layout"）；拖过的位置照原版存成安全区内 0～1 的比例（换屏幕、改大小后仍在范围内）。设置都存在原来的 `user://touch_controls.json`（旧文件只有 hidden 照读）。`XTouchControls.instance` 给设置页找它。
- **刘海／圆角安全区**：`XPlatform.safe_insets(viewport)` 把 `DisplayServer.get_display_safe_area()` 换成 1280×720 画面坐标的四边缩进（画面 keep 比例留黑边，落在黑边里的不算；桌面／headless 全 0；测试用 `safe_area_override`）。虚拟按键默认边距取 max(原边距, 缩进)（原版 `max(12px, env(safe-area-inset-*))`），拖动范围也扣掉缩进；标题页两个存档按钮的 y 也避开上缩进。HUD 不动：原版 MV 画面同样按比例留黑边、只有覆盖层按键看安全区，重制画面也是 keep 比例，安全区通常落在黑边里。
- **存档导出导入**（原版：标题右上「导入存档」「导出存档」，只在标题页；导出选已有存档→系统另存为 JSON；导入先选 JSON 查格式再选档位）：新 `modes/xiyou/core/save_transfer.gd`（`XSaveTransfer`），`entry.gd` 在触屏标题页右上放两个按钮（`ImportSave`／`ExportSave`，在「隐藏按键」左边）。文件选择走 `DisplayServer.file_dialog_show`（安卓是 SAF，返回的 content:// 直接给 FileAccess；设备没有原生对话框时提示导不了）。导出包一层 `{format: kyo-remake-save-json-v1, game, slot, exportedAt, data}`，data 是重制版自己的存档；导入也认没包外层的重制存档；原版 MV 的 `kyo-save-json-v1` 认出来、明确提示「重制版读不了原版存档」（规矩：不迁移 MV 旧存档）；用 `JSON.new().parse` 免得坏文件往日志打 ERROR。写入走临时文件再替换；那格已有档时先原样复制成 `save_N.json.before_import_<时间>.json`（O-待定-2）。
- 测试：`xiyou_platform` 38→72 项（新增：默认位置不变、按键缩放贴角、范围与对齐 5、透明度、摇杆缩放后方向、设置记住、安全区推默认位置、布局编辑全显示、拖动限制在安全区内且不触发方向键、返回键结束布局、位置记住、恢复默认、安全区换算（64×64 无头窗口左右各 4 像素＝画面 80）、无安全区为 0、设置列表末尾有／无「手机按键设置」、设置页改大小／开关／下限／恢复默认、导出包装、空格导出报错、另存为对话框参数与取消、读回一致、无外层也认、拒原版 MV、拒坏 JSON、导入空格、导入已有格先备份、档位越界、标题页两个按钮、标题导入「选文件→选档位」整条走通）。

## 优化登记草稿（总装合并时换成实际 O 号）

| 编号 | 位置 | 原版 | 重制 | 理由 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/ui/touch_options.gd` | 「手机按键设置」是 HTML 面板：单选、滑块拖动调大小／透明度 | MV 窗口列表：左右键 ∓5、点当前行／确定 +5（到顶回最小）；只做了显示按键、三项大小、透明度、调整位置、恢复默认 | 重制界面都是 MV 窗口画法，没有 HTML；滑块拖动要另做控件 | 无开关（界面画法差异）；要滑块另派 | cc（BP） | 已做，待用户确认 |
| O-待定-2 | `modes/xiyou/core/save_transfer.gd` import_to | 导入直接写进选的档位（未查到原生层另做备份） | 那格已有档时先复制成 `save_N.json.before_import_<时间>.json` 再写 | 先备份再动存档（玩家存档最重要），误选格子也找得回 | `XSaveTransfer.BACKUP_BEFORE_IMPORT = false` | cc（BP） | 已做，待用户确认 |
| O-待定-3 | `modes/xiyou/core/save_transfer.gd` | 导出 JSON 的 data 是 MV 存档，format `kyo-save-json-v1`；导入另带 aux（魔冠、云裳存档外的成长记录） | data 是重制版存档，format `kyo-remake-save-json-v1`；原版 JSON 认出来但不读；不带 aux | 规矩不迁移 MV 旧存档；aux 在重制里怎么存还没核 | 无开关（规矩所定） | cc（BP） | 已做，待用户确认 |

## 交接板

- 下一步：①安卓真机看：设置→手机按键设置里改大小／透明度、拖位置、刘海机上按键是否让开；标题页导入导出（SAF 选文件、写 content://）。②原版面板里没做的项（改版／原版按键样式、方向键模式、地图点击移动、战斗点击、A／B 两键、跑步键默认不显示、后台挂机开关、战力显示）另派。③导入导出的 aux（魔冠、云裳存档外记录）要不要带，先核重制里这两份记录存在哪。
- 用户试玩说明：手机版设置最后多了「手机按键设置」，能调按键大小、透明度和位置；标题页右上多了「导入存档」「导出存档」，可以把存档导出成文件换机再导回（原版西游 MOD 的存档读不了）。
- 需要用户决定：O-待定-1～3。

## 进度账

- 跨平台适配：安卓触屏选项与存档搬运补上，余项见「下一步」②③。

## 可优化（流程／工具／效率）

- 无

## 验证

（待写）

## 本分支提交

- 2fc6478e WIP：触屏按键大小／透明度／位置、安全区、设置页、存档导入导出
