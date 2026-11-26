# 交付：luiluu/t531-cultivation-whiteboard-stat

- 车道／工作者：天启篇数值（T531）／小A（Hydrogen＋默认，P7）
- 状态：可合并

## 变更记录草稿

## 2026-11-26 【小A·未经审查】T531 天启篇修炼改乘白板合计每级 1%＋六维预算带调整（super 24～30、weak 11～20）（dev.待定）

- 查重与真实位置核实：
  - 查重确认 `main` 及所有在途工作树（`glaucus`／`tautog`／`tellin`／`t518` 等）均未改天启篇修炼白板公式与六维预算带，零重复、零撞车。
  - 独占文件真实位置落定：修炼入口与白板聚合在 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/actor.gd`（`param_base`），天启篇修炼加成计算实际在 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_money.gd`（`training_bonus`，经 `training.gd` 转发）；六维表在 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/six_dim.json`；数据校验在 `03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`。
- 按预算稿 `重制设定/天启篇_全局数值预算_v0.16.md @093e51d1` 九.4、九.15 及 D290、D238（拆卡草稿 `协作交接/拆卡草稿/T522_后续卡草稿.md` N08）：
  - **修炼改乘白板合计（每级 1%，满 10 级白板 +10%、基准攻防下伤害约 +13%）**：
    - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/actor.gd`：拆出 `_param_base_core(i)` 与 `param_whiteboard(i)`（不含修炼的基础值经 `XActorModules.param_base` 加上装备／加值白板 `param_plus(i)`）；天启篇白板修炼开启时 `param_base(i)` 先经 `XActorModules.param_base` 再叠加 `XTraining.param_bonus(self, i)`，避免镜流星魂把装备白板修炼也翻倍；西游档或回退关时严格走原路径。
    - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_money.gd`：新增可回退开关 `TRAINING_WHITEBOARD := true` 与 `training_whiteboard_on(s)`（受 `TRAINING` 与 `XTianqi.active` 守卫）；`training_bonus(a, i)` 开启时底数改为 `maxf(0.0, a.param_whiteboard(i))`，关闭时回退 `a.param_base_direct(i)`。
  - **六维预算带调整（改带子不改人）**：
    - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/six_dim.json`：仅调整 `budgets`：`super` 由 `[20, 26]` 改为 `[24, 30]`、`weak` 按 D238 下移 2 分由 `[13, 22]` 改为 `[11, 20]`，其余带子与全员六维字母一字不动；同步 `_note` 说明。
    - `03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：同步 `SIX_BUDGETS`（`super: (24, 30)`、`weak: (11, 20)`）。
    - R4 报告对比：超强者超出预算由 14 份降至 1 份（仅停用角色全 C 18 分）；弱者 85 份总分 10～27（中位 19，新预算 11～20 超出 29 份）。
- 专项与单测更新：
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_money.gd`：更新并新增白板合计纳入装备／加值、1 级 +1%、10 级满级白板 +10%（基准攻防比 `def=0.35×atk` 下伤害增幅落在 12%～14%）、镜流 35 级星魂不翻倍装备白板修炼、`TRAINING_WHITEBOARD = false` 回退旧公式、以及西游档零改动（`XTianqi.active` 为假时 `training_whiteboard_on` 为假且原版修炼不受装备白板影响）。
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_six_dim.gd`：新增 `budgets_t531` 验证六组预算带与 156 人表未变。
  - `03_再刷重制_Godot/03_转换工具/测试天启篇数据校验.py`：`SixDim.test_budgets_t531` 验证新预算带与旧值反例。
- 验证：
  - 本机前台（`--headless --audio-driver Dummy`）：
    - `res://tests/xiyou_tianqi_money.tscn` 82/82
    - `res://tests/xiyou_tianqi_six_dim.tscn` 70/70
    - `res://tests/xiyou_tianqi_six_dim_resist.tscn` 69/69
  - 工具校验：
    - `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：全部通过（退出码 0）
    - `python3 03_再刷重制_Godot/03_转换工具/测试天启篇数据校验.py`：156/156 OK（退出码 0）
    - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：86 个脚本、846 个函数全有（退出码 0）
    - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：1242 个 `.gd`，0 个问题（退出码 0）
  - 云端选测（提交 `26ade6ea59`，基准 `6a8fb8cf39ee6fd8c2700e617ee9ba1b50c3258f`，474 个场景、16 片，最长一片 16.7 分钟，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45823651628 ）：
    - 473/474 通过（其中 `xiyou_tianqi_ring_style.tscn` 为并行偶发、单跑通过算通过）。
    - 唯一失败场景 `xiyou_tianqi_shell_hide.tscn`（14/15，`FAIL shell_count 271`，断言 `240..260`）：经核实为基线 `e3724922e`（T524 改 `skill_rework.json` 增封技能后空壳数升至 271）既有问题，与本单改动（`actor.gd`／`tianqi_money.gd`／`six_dim.json`）无关，本单未动该文件。
- 玩家可见：天启篇全队修炼由仅按角色本体基础值每级 +1% 改为按角色本体与装备／加值白板合计每级 +1%（满 10 级白板 +10%，实战伤害约 +13%）；西游档无任何变化。

## 交接板

- 下一步：T531 可合并；另记基线既有问题 `xiyou_tianqi_shell_hide.gd:65`（T524 合入 `skill_rework.json` 后空壳数为 271，超出原断言 240～260）及 `03_再刷重制_Godot/07_开发环境/六维打分.py:53`（旧 `BUDGET` 常量）可由对应卡或总装跟进处理。
- 用户试玩说明：天启篇全队修炼现乘白板合计（本体＋装备／加值白板），每级 1%、满 10 级约 +13% 实战伤害；修炼页预览自动反映新数值；西游档照旧。
- 需要用户决定：无

## 进度账

- 天启篇数值（T531 / 草稿 N08）：修炼改乘白板合计每级 1%（可回退开关 `XTianqiMoney.TRAINING_WHITEBOARD`，严格受 `XTianqi.active` 守卫）与六维预算带调整（`super` 24～30、`weak` 11～20，不改人）落地，数据校验与专项全绿，云端 474 场景除基线 T524 遗留 `xiyou_tianqi_shell_hide.tscn` 外 473/473 全绿。

## 可优化（流程／工具／效率）

- 建议：`03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_shell_hide.gd:65` 断言 `n >= 240 and n <= 260` 已被 T524（`e3724922e` 扩 `skill_rework.json`）推高到 271，建议总装或 T524 后续单调整上限以免阻塞后续分支云端选测；另 `03_再刷重制_Godot/07_开发环境/六维打分.py:53` 的 `BUDGET` 常量后续若重跑打分脚本需同步更新为 `super: (24, 30), weak: (11, 20)`。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XActor.param_base` | 35 处（`git grep -nE '[^[:alnum:]_]param_base[[:space:]]*\(' -- '*.gd'`） | 调用方 35 处逐处结论：8 处为各模块自身定义（`actor.gd:1241`、`actor_modules.gd:105`、`battler.gd:225`、`enemy.gd:261`、`power.gd:488`、`tianqi_base.gd:168`、`yomi_jingliu.gd:470`）及内部委托（`actor.gd:1219,1239,1245,1247`、`actor_modules.gd:106`）；1 处核心生产调用方 `battler.gd:839`（`param_base(i) + param_plus(i)`）在天启篇且 `TRAINING_WHITEBOARD=true` 时叠入白板修炼、西游档与开关关时完全等价旧逻辑；7 处敌方／外部测试（`xiyou_tianqi_famine.gd:277`、`xiyou_tianqi_plague.gd:277`、`xiyou_tianqi_seg_alien.gd:204`、`xiyou_tianqi_war.gd:257,258`、`xiyou_zhenqi_break.gd:129,231`、`xiyou_zhenqi_daofa.gd:189`）及 3 处 `XTianqiBase.param_base` 测试（`xiyou_tianqi_phase4.gd:133,380,806`）不经 `XActor.param_base`；3 处西游档角色测试（`xiyou_actor_bonus.gd:31`、`xiyou_jingliu.gd:158`、`xiyou_passive_content.gd:36`）在西游档下 `training_whiteboard_on()` 为假零改动；3 处 `xiyou_tianqi_gongfa_shop.gd:148,156,171` 测时修炼等级为 0 不受影响；1 处调试打印 `k_calibrate.gd:462` 仅打日志；5 处 `xiyou_tianqi_money.gd:241,251,277,369,371` 为本单专项断言。 |
| `XTianqiMoney.training_bonus` | 2 处（`git grep -nE '[^[:alnum:]_]training_bonus[[:space:]]*\(' -- '*.gd'`） | 调用方 2 处逐处结论：`tianqi_money.gd:294` 为自身定义；唯一外部调用方 `training.gd:69` 仅在 `XTianqiMoney.training_on(s)`（受 `XTianqi.active` 守卫）为真时转发，开 `TRAINING_WHITEBOARD` 时按白板合计每级 1% 返回、关时回退本体基础值，西游档不进入该分支。 |
| `XTianqiMoney.TRAINING_WHITEBOARD`（新增回退开关） | 3 处（`git grep -n 'TRAINING_WHITEBOARD' -- '*.gd'`） | 调用方 3 处逐处结论：`tianqi_money.gd:32` 定义（默认 `true`）、`tianqi_money.gd:249`（`training_whiteboard_on`）与 `tianqi_money.gd:301`（`training_bonus`）读取；设为 `false` 立即完整回退旧修炼公式，西游档下恒不生效。 |

## 本分支提交

- 26ade6ea5 T531 天启篇修炼改乘白板合计每级 1%＋六维预算带调整（super 24~30、weak 11~20）
