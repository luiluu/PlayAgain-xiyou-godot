# 交付：cc/platform-gaps4
- 车道／工作者：平台／cc（FB 第四单，接在 cc/platform-gaps3 之后切出；含 gaps1～3）
- 状态：可合并

## 变更记录草稿

## 2026-11-07 【cc·平台·未经审查】安卓模拟器上验切后台自动存档的钩子（dev.待定）

- 第六节剩下的项除这一项外都要真机或已由 Kyo 定了；这项关系玩家进度，又能在云端模拟器上验。
- 游戏只在带 `--report-entry` 时多打两行日志，不改流程：`XAutoSave.on_pause` 打 `PAUSE_SAVE=<结果>`（`modes/xiyou/core/auto_save.gd`，on_pause 拆成外层打印＋`_on_pause`），西游标题打 `AUTO_SAVE_PRESENT=<有没有「继续」>`（`modes/xiyou/entry.gd` 一行）。
- `安卓实机冒烟.py` 加一轮：新游戏进地图 → HOME 切后台 → 读 PAUSE_SAVE → 杀进程 → 用同一把 key 的基础副本重开 → 读 AUTO_SAVE_PRESENT。存成了（saved）就要求标题有「继续」、进程活着；没存成只记 INFO。
- 云端结果：真安卓上切后台钩子会触发（PAUSE_SAVE 打了两次，PAUSED 和 FOCUS_OUT 各一次），结果是 `skip:event`：新游戏一进地图就是 Map001 的开场自动事件（312 条指令，有对话、选项、循环），事件中照原版不存；试过连按 40 次确认也没点完，就退回只验钩子（脚本里写明了）。真存一份、重开有「继续」那一步留在安卓清单第 16 步给真机。
- 顺带看到：模拟器（swiftshader）上 logcat 有 5 次 `SceneShaderGLES3: Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`，是 3D 场景着色器超了软件渲染的上限，没影响进标题、按键和存档流程；真机 GPU 上限高得多，真机清单里看画面有没有缺东西就行，不另做处理。
- 测试：`测试安卓实机冒烟.py` 12→15 项（存成了要有「继续」、存了重开却没有判失败、事件中没存只记 INFO）。
- 验证：语法检查通过；工具回归全过；云端选测 f76b5cf42b 十个场景全过（[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42393271365)，含 xiyou_pause_save、xiyou_entry_release）；云端导出冒烟四任务全过（[42393274477](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42393274477)，安卓 14 PASS＋1 INFO）。之后只把等待从 3600 帧改成 7200 帧（中间试过的 40 次确认版本跑在 42394753813，也全过），没再上云，假 adb 测试过。

## 交接板
- 下一步：平台能自动验的都做完了；剩下的是真机清单（Windows 22 步、安卓 27 步），等 Kyo 有设备时点。
- 用户试玩说明：无
- 需要用户决定：无

## 进度账
- 扩展账「跨平台（PC／安卓）」：依据补「真安卓上切后台存档钩子会触发」。

## 可优化（流程／工具／效率）
- 无

## 本分支提交
- f76b5cf4 打印两行＋自动存档一轮
- 之后两个：试连按确认、退回只验钩子＋本交付单
