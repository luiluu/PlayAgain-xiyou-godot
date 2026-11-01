# 交付：cc/bailong-cat-trial1

- 车道／工作者：E 角色专属／白龙_13（cc）
- 状态：进行中
- 分支从 cc/bailong-exclusive-gaps1 末端 b825c89f 切出（总装十一派单），**包含 yunshang9～11 与 exclusive-gaps1**，那几张交付单照它们自己的合；开工时合过一次 main（5bbccdcc）。
- 范围：小猫剑圣守誓巨龙试炼（公共事件 9018，小猫进阶石 2900 唯一来源），顺带进阶速剑多一次行动、178 在队号角不能用；终技品质 10 查明看不出差别，不做。

## 变更记录草稿

## 2026-11-01 【cc·白龙_13·未经审查】小猫剑圣守誓巨龙试炼；速剑多一次行动、号角不可用（dev.待定）

1. **守誓巨龙试炼**（installImportedBalanceRuntime.js 第 247～263 行，CodexCat.startTrial／restoreTrial 与几处包装）：小猫剑圣 35 级、持剑、在队时用技能「守誓巨龙试炼」，队伍只留 178 独自打敌群 1999（不能逃、可以输），开战回满生命与 TP；巨龙按回合轮换出招（守誓龙爪、铜焰蓄息、铜焰吐息、空一回合、巨龙扫尾），蓄息时日志提示「巨龙昂首蓄息！…」；巨龙能力值用数据库原值，不吃塔内 22 个难度强化状态。打完还原原队伍：第一次赢给小猫进阶石 ×1 并提示，之后不再给；输了 178 倒下时留 1 血、提示可再挑战。读档时存档里留着试炼就还原队伍。之前重制里条件够时什么也不发生，小猫进阶不了。
   - 代码：`XCat`「守誓巨龙试炼」节（start_trial／restore_trial 存 s.flags 的 `_codexCatTrial`、`_codexCatTrialWon`，同原版 $gameSystem 名）；钩子各一行：`mv_script.gd`（CodexCat.startTrial(this) 换队、host.start_battle、还原提示）、`battle_logic.gd`（decide 接巨龙出招、execute 加蓄息日志、开战回满、make_action_times）、`enemy.gd`（add_state 挡难度状态、param 最外层原值）、`xsave.gd`（读档还原）。
2. **进阶速剑**（同文件第 118 行 makeActionTimes 包装）：进阶且学了速剑 10442，每回合多 1 次行动。
3. **号角**（第 122 行 canUse 包装）：178 在队时伙伴号角 2899 在物品菜单里「使用」灰掉（`item_scene.gd` 一行）。
4. **不做**：进阶后至圣斩说明按品质 10 显示（helpItem）——七档品质里 9（传家宝）与 10（远古）都是「不朽」，名字色、说明卡边框、品质行都一样，玩家看不出差别；专项里断言了这一点。
- 参照：新探针 `mv_oracle/cat_trial_probe.cjs`（不进同步，产物拷成 `tests/fixtures/cat_trial_oracle.json`）：真实 startTrial／restoreTrial、makeActions 12 回合、startBattle、startAction、param、addState、makeActionTimes、canUse、helpItem；SceneManager.push 与 toaster 拦下。新专项 `xiyou_cat_trial`。

## 优化登记草稿

无。

## 验证

- 专项 xiyou_cat_trial 53/53：条件三种不够、换队与记下的队伍、开战回满、经 decide 的 12 回合出招与目标、经 act 的蓄息日志、8 项原值参数、24 个状态在试炼中／还原后、五次还原（首胜、再胜、输倒下、输没倒、-1）、存档往返后还原、速剑四种组合、号角在队／离队、品质 9／10 同档、事件脚本开战／输／条件不够。
- 反向验证 12 处全抓到：出招不减 1、decide 不接巨龙、不回满、不挡难度状态、参数不用原值、首胜可重复给、输了不留 1 血、不还原出战栏、速剑不加、号角不看在队、蓄息不加日志、脚本不开战。
- 语法检查通过。
- 选测：（进行中）

## 交接板

- 下一步：角色专属缺口表（见 cc_bailong-exclusive-gaps1 交付单）里小猫剑圣四项已清；剩下渡鸦魔法反射累计、饿狼琦玉输入阶段认真一拳、甚尔读档 repair、黑闪遗忘清空等。
- 用户试玩说明：小猫剑圣 35 级持剑后可以用「守誓巨龙试炼」独自挑战巨龙，第一次打赢得小猫进阶石，小猫可以进阶了；进阶并学了速剑后每回合多动一次；小猫在队时伙伴号角用不了（同原版）。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：小猫剑圣 +0.03（试炼与进阶材料来源、速剑、号角），按工作量估。

## 可优化（流程／工具／效率）

- 无新增。

## 待交叉核查

- 共用核心各一行钩子：`battle/battle_logic.gd`（decide、execute、start_battle、make_action_times 四处）、`core/enemy.gd`（add_state、param）、`core/xsave.gd`（load_slot）、`ui/item_scene.gd`（_usable）、`map/mv_script.gd`（startTrial 分支）。
- `core/cat.gd`「守誓巨龙试炼」节；新探针、夹具、专项。
- 请重点看：巨龙出招按 decide 时的 `turn`（OTB 在 getNextSubject 时 makeActions，同一时点）；队伍还原直接写 party／battle_slots，不走 add_actor（原版也是直接赋值）。

## 本分支提交

- 前面同 exclusive-gaps1（到 b825c89f），合 main
- c2c25026 WIP: 参照 cat_trial_probe
- b74649bd WIP: 重制与专项 53/53
- 本提交：交付单
