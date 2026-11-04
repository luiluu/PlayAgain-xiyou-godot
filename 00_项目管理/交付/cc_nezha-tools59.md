# 交付：cc/nezha-tools59

- 车道／工作者：D 工具／哪吒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】总装合并中不拦车道；反向验证先校验清单；选测加漏网回归集（dev.待定）

只改 `07_开发环境`，不碰 Godot 工程。

- **① ② 总装合并/同步中，车道不被主工作区的 generated/ 拦**（回退 `XIYOU_IGNORE_MERGE_FLUX=1`）：`参照批次.py` 新增 `flux <主 .git 目录>`：读 `lane-merge/state.json` 的 phase，处在 merged／synced／numbering／versioned／prepared（合并已动手、还没收尾提交）时打印说明、退出 4。`新建工作树.sh --补齐` 遇到 4 就不从主工作区刷新 oracle、不记批次（原来会把总装未验收的新参照拷走，挡住车道同步，悟空 tail3 报）；`并行测试.py` 的 `stale_generated` 遇到 4 就不比对、打一行说明（原来拿未定稿的主工作区当标准拦车道，悟空 tail2 报）。planned、committed 或没有合并状态都照旧。
- **③ 反向验证先校验清单**：`反向验证.py` 新增 `validate()`，读完清单先一次说全：tests 非字符串列表、items 缺 name／file／find／replace（`to` 会提示应写 `replace`）、类型不对、find 为空；有问题退出 64，不跑基线、不动文件，`--dry-run` 同样先校验。多余字段只提醒不拒。
- **④ rules4 为什么选不到 xiyou_status_power_panel，有无系统补法**：
  - 原因：该场景只引用 `XPower`，不引用 `XStateEffects`；依赖链是 `XPower → clone_battler → … → effect_program 预览 → state_effects.gd`，选测的 refs 只看文件名／class_name 一层。选测对照里 `battle` 组此前没点名它，rules5（2c3cd3ac）才点名加进组，所以对 rules4 当时的合并选测与云端选测都选不到（这批是云端全量抓到的）。
  - 传递闭包不可行：用 class_name 引用图实测，以 state_effects.gd 为起点，1 层选 125／299 个测试，2 层 264／299（才含它），3 层 295／299，等于全选。
  - 系统补法（已做）：对照表新增 **`escapes`（漏网回归集）**——云端／全量／合并抓到「选测没选到、改动却把它搞坏」的场景，就把（改动文件通配, 场景通配）记一条；以后改到这些文件就一并选上，抽样不砍。已登记第一条：`state_effects.gd` 和 `state_effects_probe.cjs` → `xiyou_status_power_panel`（按文件兜一层，不依赖 battle 组点名）。`选测.py` 读它，`load_table` 校验非空，`测试选测.py` 校验所列场景真有对应测试（改名不会悄悄失效）。**用法**：抓到漏网就往 `选测对照.json` 的 `escapes` 加一条，交付单写一句。
  - 没做的：给每个新 state_effects op 自动配回归集——op 是数据驱动、新增 op 的位置在 `state_effects.gd` 一个文件里，已被上面这条按文件覆盖，不另拆。

## 交接板

- 下一步：车道遇到「总装合并中」的提示是正常的，等合并收尾后再 `--补齐`；漏网例随抓随记进 `escapes`。
- 用户试玩说明：无（工具改动）
- 需要用户决定：无

## 进度账

- 无（工具类）

## 可优化（流程／工具／效率）

- 已做：见上（回退 `XIYOU_IGNORE_MERGE_FLUX=1`；`escapes` 删条目即回退）。
- 建议（小）：`云端选测.py report` 在失败场景「不在本机选测名单」时直接打印可粘贴的 `escapes` 条目，让记账更省事（工具车道，约半小时）。

## 本分支提交

（见 git log）

## 验证

- 工具测试：`测试参照批次.py` 20 个、`测试反向验证.py` 5 个、`测试选测.py` 108 个（新增 3 个），全部通过。没碰 Godot 工程、转换器、探针，不跑 Godot。
