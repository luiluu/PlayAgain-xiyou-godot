# 交付：cc/platform-android-bgidle1

- 车道／工作者：平台·安卓后台真挂机（cc·平台 android-bgidle1，派单第十六批追加十七 GP2；Kyo 11-09 定 C）
- 状态：可合并（两期一起交：插件＋Gradle 出包＋服务起停，挂机逻辑接线）
- 基于：本库 main 70c22c2e2（scratchpad 里 `git clone --shared` 的 clone，见合并提示）。

## 变更记录草稿

## 2026-11-09 【cc·平台·未经审查】安卓后台挂机前台服务（dev.待定）

- **安卓插件 XiyouBgIdle（O-待定·安卓后台挂机前台服务）**：Kotlin，GodotPlugin v2，源码 `01_Godot工程/addons/xiyou_export/android_src/`（有 `.gdignore`）。挂机中切后台（活动 onPause）起前台服务 `XiyouIdleService`（`specialUse` 类型）：通知栏常驻、计时显示离开多久、点通知回游戏、「停止挂机」按钮；回前台（onResume）关服务，用 `SystemClock.elapsedRealtime` 记离开多久（含锁屏睡眠；按了停止只算到按的那一刻）。清单合并带上 FOREGROUND_SERVICE、FOREGROUND_SERVICE_SPECIAL_USE、POST_NOTIFICATIONS、WAKE_LOCK。安卓 13+ 第一次挂机时申请通知权限，不给也能起服务。
- **查到的限制**：Godot 切后台渲染表面被系统收走，GLSurfaceView 渲染线程停住，主循环就不跑了（拆 4.7.2 godot-lib 看过：GLThread 等 surface，onActivityPaused 停渲染线程）。所以前台服务只保证进程不被杀，离开的时间仍然在回前台时补跑。要原版那样后台一帧一帧跑，得改引擎重编导出模板。
- **游戏接线（`core/platform.gd`，`XPlatform.BACKGROUND_SERVICE`，默认开）**：挂机中每帧告诉插件「切后台就起服务」（`setArmed`）；回前台用插件量的真实离开时间补跑，上限 `SERVICE_CAP_SEC`＝4 小时游戏时间（8 倍速补 30 分钟）。在通知上按了停止的，只补到按的那一刻，补完（或点屏幕停补跑）就结束挂机（`XPlatform.idle_stopper`＝`XHangUp.stop_current`，西游地图设）。这次没起服务（没插件、起服务失败）自动退回 O-201。回退：`XPlatform.BACKGROUND_SERVICE = false`，回到 O-201（不起服务，游戏计时、最多 30 分钟）。
- **安卓导出改用 Gradle 构建**：`export_presets.cfg` 两个安卓预设 `gradle_build/use_gradle_build=true`；导出插件 `addons/xiyou_export/plugin.gd` 在 Gradle 构建开着且 aar 在时把 `addons/xiyou_export/android/xiyou_bgidle.aar` 加进包。`云端导出.py android-build`：把 android_source.zip 装成 `res://android/build`（同编辑器「安装 Android 构建模板」）、用模板自带的 gradlew 编插件。本机没装 JDK 17，**安卓包只能在 GitHub Actions「导出冒烟」出**；`环境登记.json` cloudExport 加 android_source.zip，build-tools／platform 跟模板 config.gradle 改成 36.1.0／android-36。`android/`、插件构建产物进 .gitignore。
- **冒烟**：`导出冒烟.py` 查 Gradle 构建的包里有插件登记、服务和三个前台服务权限；`安卓实机冒烟.py` 加一段：`_cl_` 带 `--smoke-arm-bgidle`（不挂机也让插件起服务，`XPlatform` 只在这个参数下打 `BGIDLE_ARMED=`）→ HOME 等 60 秒：进程还在、服务在跑、通知在；回前台服务停了、插件记的离开时长对得上。
- 玩家可见：安卓上挂机时切到后台，通知栏会出现「挂机中」和「停止挂机」按钮，游戏不容易被系统杀掉；回来按真实离开时间补挂机，最长 4 小时（以前最多 30 分钟）。第一次挂机时系统会问能不能发通知。

## 交接板

- 下一步：真机验收清单第 17a～17d 步（通知、长时间锁屏、通知上停止、关掉通知权限），SUN 拿真机测。补跑上限 4 小时、8 倍速是我定的默认，Kyo／SUN 觉得不合适再调 `SERVICE_CAP_SEC`／`CATCH_UP_SPEED`。
- 用户试玩说明：安卓包挂机切后台有通知和停止按钮；回来补跑按真实离开时间，最多 4 小时。
- 需要用户决定：「后台真跑」要不要做到引擎层（改 Godot 安卓渲染线程、重编导出模板，工作量大一个量级）；不做的话现在这版就是终版。

## 进度账

- 安卓扩展账「后台真挂机」：从「回前台 8 倍速补 30 分钟」到「前台服务保活＋通知＋停止按钮＋按真实时间补 4 小时」；后台逐帧真跑做不到（引擎限制），差这一条。

## 优化登记草稿

| O-待定·安卓后台挂机前台服务 | `core/platform.gd` `XPlatform.BACKGROUND_SERVICE`＋安卓插件 XiyouBgIdle（`addons/xiyou_export/android_src/`） | 原版挂机中切后台用前台服务在后台按真实时间继续跑，通知栏常驻 | 前台服务（通知计时、点通知回游戏、停止挂机按钮）保活；Godot 切后台主循环必停，离开时间回前台按真实时长（含锁屏）补跑，最多 4 小时；按停止只补到按的那一刻、补完结束挂机；没起服务退回 O-201 | Kyo 11-09 定 C；Godot 引擎限制，做到能做的程度 | `XPlatform.BACKGROUND_SERVICE = false`（回到 O-201：不起服务、最多 30 分钟）；测试 `xiyou_platform` background_service_off 覆盖 | cc（平台 android-bgidle1） | 待用户确认 |

## 验证

- **Gradle 出包（云端，本机没 JDK 17）**：导出冒烟 run 42668732578／42676011733：`云端导出.py android-build` 装构建模板、插件 `BUILD SUCCESSFUL in 53s`（aar 10 KB）；「安卓 验收」Gradle 导出 77.8 秒、467 MB，`导出冒烟.py` 签名与包结构通过（含新加的插件登记、服务、三个前台服务权限检查）；「安卓 发行」也导出成功。模拟器 logcat：`Initializing Godot plugin XiyouBgIdle`／`Completed initialization`。
- **模拟器后台挂机（run 42676011733，安卓 14 x86_64）**：BGIDLE_ARMED=true；切后台 60 秒后进程同一 pid 活着；`dumpsys activity services` 有 XiyouIdleService；`dumpsys notification` 有 xiyou_idle 频道通知；回前台服务停了；插件记的离开时长 60.1 秒（实际约 60 秒）。全部 PASS。
- 同一轮模拟器另有 4 项失败：`android_keys_title_space_new_game`／`_j_`／`_enter_`（按完 1 步还在标题）和 `android_pause_hook_fires`。**main 上同样失败**（对照 run 42678614104，main 没有本分支改动，4 项一模一样），不是本分支带来的；logcat 看是第一下按键在进标题 1.3 秒后就按了、标题还没接住，新游戏没开、也就进不了地图存档。11-07 最后一次全过之后 main 有改动，建议派平台／界面车道查（见可优化）。
- **云端选测**（基准 github/main eb6ab526b，`选测.py` 列的 206 个场景、14 片）：全过，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42680616344 。
- **本机专项**：`xiyou_platform`（122／122，含新加的 13 项前台服务用例与 background_service_off 回退）、`xiyou_hangup`、`xiyou_hangup_auto`、`xiyou_pause_save`、`xiyou_mac_export`、`xiyou_determinism`、`xiyou_map` 全过。
- `语法检查.py` 659 个 .gd 0 问题；`工具回归.py` 全过（69 秒，含 测试安卓实机冒烟、测试导出冒烟 新用例）。
- 没跑：真机（通知权限弹窗、锁屏长时间、通知上「停止挂机」按钮、各厂商省电策略）——模拟器点不到通知按钮，写进验收清单 17a～17d。
- 说明：`--补齐` 跑到最后自带的事件状态探针时，因为 main 正在合 interp8（hboot.cjs 改了、探针要整份重量），会占 4 槽跑两小时多；本车道没改探针也不需要它，我把自己那组进程停了（只停本 clone 的进程组），产物和导入在那之前已经补好。

## 合并提示

- 工作区是 scratchpad 里的 clone：`/private/tmp/claude-501/-Users-kyo-Documents--------/593261a5-6f32-451d-b879-c3a9f13efc23/scratchpad/bgidle1`，分支推回本库后可删。
- 没碰切片、转换器、探针，不用重同步。
- 合并后安卓包只能用 Actions「导出冒烟」出（本机没有 JDK 17）。若要本机出安卓包，需在 `~/Library/Android/jdk` 放 JDK 17（导出冒烟.py 已认这个位置）。

## 可优化（流程／工具／效率）

- 已做：`选测对照.json` 加两条，`addons/xiyou_export/android_src/*`、`addons/xiyou_export/*` 归 export 组（以前落到「拿不准：整轮」）。回退：删这两行。
- 建议：模拟器冒烟的三组「标题一键开新游戏」和切后台存档在 main 上也挂（见验证），多半是标题接键时机变了，`--smoke-keys` 第一下前该等标题就绪；归平台或界面车道。
- 建议：`--补齐` 末尾的事件状态探针在总装合并改了 mv_oracle 公共 helper 时会整份重量、占满槽，车道不需要时可以加个跳过开关（如 `--no-state-probe`），归工具车道。
- 建议：GitHub 仓库公开后标准 runner 不计分钟，项目记忆里「Actions 分钟用完」那条对公开仓库已不成立（11-09 本车道实测 run 42668732578 正常跑完），总装可以核一下改记忆。

## 本分支提交

- d68e85e79 插件＋Gradle 构建＋导出冒烟接上
- GDScript 接线、xiyou_platform 专项、导出冒烟查插件
- 模拟器冒烟后台挂机一段、设计文档与验收清单
- 快速切回时先 startForeground 再停
- 选测对照归组、交付单
