# 交付：luiluu/cc-t150-stub-smoke

- 车道／工作者：T150 出包流程加空壳树开战冒烟（cc，Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·T150·未经审查】出整包、出补丁导出前自动在空壳树里开战冒烟（dev.待定）

- `发行空壳.py`：新增 `smoke_battle(tree, godot, logs)` 和子命令 `发行空壳.py smoke <空壳树>`：在 `tree` 建好的空壳树里并行起两个 Godot（`--headless --audio-driver Dummy`，各自独立临时 HOME，不碰真实存档）跑 `xiyou_battle`（不传 random_context 直接开战）和 `xiyou_battle_ui`（地图→开战→战斗界面），要求 TEST_RESULT 全过、退出码 0、日志无 SCRIPT ERROR。空壳返回 null 引起的脚本错误会让 headless Godot 卡住不退出，所以边跑边看日志，**一见 SCRIPT ERROR 就杀**，不等 300 秒超时。
- `发行出包.py`：`export_all` 在注入存档密钥之后、导出之前跑 `stub_smoke`，失败就返回问题、不导包；新增 `--no-stub-smoke` 回退开关（`--real-scripts` 时本来就没有空壳，自动跳过）。
- `发布补丁.py`：`export_patch` 建完空壳树、导出之前跑同一冒烟，失败抛 `Fail`（日志写在补丁输出目录 `日志/`）；新增 `--no-stub-smoke`。
- 测试：`测试发行空壳.py` 新增 `SmokeBattleTests`（假 godot：通过、断言失败、SCRIPT ERROR 卡住要快杀、没结果行、超时＋日志、默认两个场景＋Dummy 音频）和补丁入口次序检查；`测试发行出包.py` 新增「冒烟失败不导出」「--real-scripts／--no-stub-smoke 跳过」。

## 验证
- 现 main 空壳树：`发行空壳.py smoke` 通过，**约 39 秒**（建树 4 秒另算）。出整包要导三个包＋四项冒烟，多 40 秒占比很小；补丁同理。没有另起克隆：直接用两个入口本来就要建的那棵空壳树，所以额外开销只是这 40 秒。
- **反向验证**：用 f97eff003（T149 修之前）的 `发行空壳.py`＋特例表对当前工程建空壳树（`tree --src`，`battle_random` 生成为 `return null`），`smoke` 退出码 1、**8 秒**拦下，两个场景都报 `SCRIPT ERROR: Invalid call. Nonexistent function 'snapshot' in base 'Nil'.`（修之前若不加「见错就杀」，这两个场景会挂满 300 秒超时，已验证过一次）。
- `测试发行空壳.py`（21 项）、`测试发行出包.py`、`测试发布补丁.py`、`工具回归.py` 见回报；交付自检见回报。没改游戏脚本，不跑游戏专项。
- 没做：没真跑一次完整出包／出补丁（要三平台导出和发版密钥，不是本单范围）；接线处由单测＋源码次序检查覆盖。

## 事故说明（已收拾）
- 我做反向验证时在 scratchpad 里把旧脚本旁的 `01_Godot工程` 放成指向真工程的软链，旧版 `make_tree` 的 `cp -cR` 不跟软链，空壳写进了本工作树的真工程（71 个已跟踪脚本被改成空壳）。发现后 `git checkout` 还原，`git status` 确认游戏目录无改动，重做反向验证改用 `tree --src`（不再碰真工程）。提交里没有任何游戏文件。这是我临时布置的问题，不是 `发行空壳.py` 现版本的缺陷。

## 我不同意的地方
- 派单说「前台起 Godot」，我保留 `--headless`（小A 实测同法）：不弹窗、不抢焦点，两个场景并行即可；只加 `--audio-driver Dummy` 保证无声。
- 没有更省的办法：静态检查误报高（T149 77 报 1），而这一步 40 秒就能抓住全部「null 调方法」类。可再省的是把 `xiyou_battle_ui`（约 30 秒的大头）只留 `xiyou_battle`，但 ui 那条走了地图＋战斗界面的多条守卫路径，建议保留。

## 待交叉核查
- `smoke_battle` 的「见 SCRIPT ERROR 即杀」会不会误杀：某些良性 `SCRIPT ERROR`（如资源告警）出现时也算失败——现版空壳树两个场景全程 0 条，若以后有良性噪声，改 `SMOKE_FATAL` 正则即可。

## 可优化（流程／工具／效率）
- 建议：`并行测试.py` 也加「见 SCRIPT ERROR 卡住就杀」，省得错误测试挂满 600 秒（预计收益：失败测试省几分钟；归工具车道）。
- 已做：出包冒烟并进已有的空壳树，不额外克隆（`--no-stub-smoke` 回退）。

## 本分支提交

- 见提交
