# 交付：luiluu/t381

- 车道／工作者：T381（K6）发行空壳隔离名单复核／cc（Opus 5.5＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 日期 【cc·发行·未经审查】T381 发行空壳隔离名单复核：dev.664～845 新增脚本（dev.待定）

- 复核范围：`git diff --diff-filter=AR 9e8bf4ee5（dev.664 收尾）..c5ee6451e（dev.846 收尾）` 下 `01_Godot工程` 新增的 56 个 `.gd`（不含 tests/）；这段没有改名的脚本。
- 结论：**名单没有缺口，`EXTRA`／`MIXED_OK`／特例表都不用改**。`发行空壳.py check` 0 报错（80 个空壳脚本，773 个函数都有），suspects 为空；`发行空壳.py tree` 建出的空壳树过 `发行内容审计.py --tree`（✓ 天启篇脚本都是空壳，没有没归类的）；空壳树前台开战冒烟（xiyou_battle、xiyou_battle_ui）通过。
- 逐个归类（56 个）：
  - **换空壳（16）**，类名带 `XTianqi` 前缀自动进名单：`battle/` tianqi_enemy_ai、tianqi_sear_bar、tianqi_swap_view、tianqi_weak_badges；`core/` tianqi_base、tianqi_brand、tianqi_gem_power、tianqi_growth、tianqi_guardian_gift、tianqi_hall、tianqi_hall_text、tianqi_six_dim、tianqi_weak_b2、xinmo_traits（文件名不带 tianqi，类名 `XTianqiXinmoTraits` 进名单）；`ui/tianqi/tianqi_hall_intro`、`ui/tianqi_start_page`。卡上点名的「无限成长、六维」就是 XTianqiGrowth、XTianqiSixDim，已在空壳里；「集火」查过是原版西游的 XDamage／XEnemy，没有新模块。
  - **西游档也走、真脚本带进包（5）**：battle_eval（我方 XSmartAI 估值内核，西游自动战斗用）、battle_stream（多段逐段结算 O-609，所有战斗）、main_thread（交接线程的界面入口保险）、xconfig_transfer＋config_transfer_options（设置导入导出，玩家建议，西游档可用）。
  - **新界面专用、真脚本带进包（35，其中 3 个早已在 MIXED_OK：skin_battle_2c、skin_seal_dial、skin_six_dim_radar）**：battle_layout、party_fold、turn_marker 和 `ui/skin/` 下 32 个 skin_* 页面与小件。理由：都只在 `XUiSkin.on()` 为真时走；发行包里 `XUiSkin.parse_cli` 在 release 恒返回 -1（命令行强开不认）、`FORCE` 为 false、最后一道 `XTianqiLine.open_for` 换空壳后恒 false，所以新界面整套恒关；新界面美术 `content/ui_skin/*` 在 DENY 里不进包。这与 dev.664 之前 skin_* 的做法一致。按天启篇关键词（天启、七印、骑士、烙印、启封、心魔、号卷）查过这 35 个的字符串常量：只有 skin_save_page 的 `T_LINE := "天启之路"` 一个标签，线名、骑士名都从空壳 XTianqi 取（发行为空），不透露设计。
- 测试 `测试发行空壳.py` 加两例：`test_k6_dev664_845_classification` 钉住上面三组（16 个必须在空壳名单、12 个必须是真脚本、7 个新界面战斗件源码要挂 `XUiSkin.on()`）；`test_k6_new_ui_gate_closed_in_release` 钉住新界面发行门（parse_cli release 返回 -1、on() 末尾经 XTianqiLine.open_for、FORCE 默认 false、XTianqiLine.open_for 空壳返回 false）。反向验证：往空壳组塞 battle_eval、往新界面组塞 main_thread，用例红（1 失败），还原后全绿。
- 不改游戏代码，西游档与发行包行为零变化。

## 云端选测

- 提交 6622d01206，选测 5 个场景、1 片，全绿：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45029747968
- 本机：`工具回归.py` 全部通过（109 秒）；`python3 -m unittest 测试发行空壳` 全绿；空壳树开战冒烟（xiyou_battle、xiyou_battle_ui）通过。改动只有 Python 测试，`选测.py main --list` 选到 Godot 场景 0 个。

## 交接板

- 下一步：见「可优化」两条，派给发行工具／修行文字的车道。
- 用户试玩说明：无（只加测试）。
- 需要用户决定：无。

## 进度账

- 部分 16（发行）：70→75，依据：K6 dev.664～845 新增脚本整体复核完、名单无缺口并加回归钉住（折合 +0.25，按 K5 之后算）。

## 可优化（流程／工具／效率）

- 建议：混合脚本里的天启篇字符串常量会随真脚本进包。复核时看到 dev.664 之后 `modes/xiyou/core/zhenqi.gd`（闭关页烙印、心魔的菜单与提示文字，T117／T140）和 `modes/xiyou/core/guide.gd:470`（修行指引里炼狱、证道难度和号卷的一句，11-17）把天启篇玩法名写进了西游脚本。走不到（都在 `XTianqiBrand.on()`／`XTianqi.active()` 后面，空壳里恒 false），但字在包里，解包能看到。suspects 只看文件名、头注释和 DENY 路径，查不到这一类。建议给 发行空壳.py 加一条「非空壳脚本里的天启篇关键词字符串」报告（白名单登记），或把这些文案挪进 XTianqi* 模块。这不在本单的独占范围（要改 suspects 逻辑或游戏代码），归发行工具车道，预计半天。
- 建议：K6 的归类目前靠人看头注释。以后再新增不带 XTianqi 前缀、只给天启篇用的模块，最省事的做法是派单时就要求类名带 `XTianqi` 前缀，这样空壳名单自动跟上，不用再登记 EXTRA。

## 本分支提交

- 见 git log（T381）
