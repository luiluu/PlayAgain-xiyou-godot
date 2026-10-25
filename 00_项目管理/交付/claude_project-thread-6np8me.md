# 交付：claude/project-thread-6np8me

- 车道／工作者：翻译·状态效果 js 再翻译／云端（Claude，云端项目线程）
- 状态：进行中

## 变更记录草稿

## 2026-10-25 【Claude·云端·未经Codex检验】状态效果 js 再翻译第一、二批：叠毒、开战／回合开始加状态、暴击后加状态、开战与胜利回复、开战设变量、原版语法错误块（dev.待定）

- **范围**：冻结 v0.28 `States.json` 里 444 块未翻译的 `<Custom … Effect>`（`op: js`）按整块记号匹配再翻 98 块，剩 346 块。匹配只认原版测过的完整形状（formula_program 记号逐个比），改一个记号就退回 js；原版自己报错或不生效的块不「修」成生效。
- **第一批 叠毒 `_stackingPoison`（51 块）**：Apply 加层 18、Remove 清零 18、Regenerate 按来源能力扣血 15（106／732 读装备等级、551 变量名拼成 damag，原文本身报错，留 js）。`XBattler.state_data` 存状态脚本私有字段（角色随存档写 `stateData`，空的不写）；`poison_tick` 层数 `|| 1` 写回、伤害式经 formula_program 编译（来源是 a、持有者是 b），扣血走 `XResourceContext.gain`（护盾吸收、死亡），每个状态新结果槽；弹字与动画经 `emit` 进回合结束的 regen 记录，`battle_scene` 播动画。
- **第二批（47 块）**：`add_state` 23（开战／回合开始 `user.addState(N)`；Establish 暴击后给行动者或目标加状态，`addState` 第二个回合参数原版不认，照状态自身回合）、`gain_steps` 11（`user.gainHp/Mp/Tp` 与 `var` 局部量，只许持有者 mhp／mmp、数字、`Math.floor/ceil`）、`set_variable` 4（开战 `$gameVariables.setValue`，编号超出 `System.variables` 的原版忽略：1683 号状态写 1683 号变量不生效）、`syntax_error` 9（原版解析失败只报错，按整块 SHA256 认，执行时什么都不改）。加状态走 isStateAddable（活着、未抵抗、本结果槽没刚去掉）。
- **开战顺序修正**：原版 `Game_Unit.onBattleStart` 每方先各成员 onBattleStart（初始随机 TP 0～24）再跑 Battle 脚本；Godot 原先先跑脚本后初始 TP，开战 TP+200 的 607 等被盖掉。改为我方（初始 TP→Battle 脚本）再敌方；Battle／Turn Start／Victory 分发带上规则随机流与变量。
- **参照**：新探针 `mv_oracle/state_js_probe.cjs`（登记进 `同步正式西游.py` PROBES 与 `oracle_additions.py`），11 组用例：叠毒清单／生命周期／共用层数／扣血逐行（含护盾、致死）／真实回合结束接线，加状态（含倒下）、暴击后加状态、回复三种起点、设变量、真实开战 TP 顺序、语法错误块。探针按代码形状独立扫块，与转换器两边对数。
- **测试**：新专项 `xiyou_state_js`（1670 项）；`07_开发环境/测试状态js翻译.py`（清单与改一个记号退回 js 的边界，接进 `检查.sh` tools）。相关 12 个场景（state_effects、battle、battle_events、random_streams、party、party_skills、zhenqi 三项、costumes、costume_battle、shield）通过。
- **改了沙僧独占文件**：`core/state_effects.gd`（新 op）、`core/battler.gd`（`state_data` 一个字段）、`core/xstate.gd`（存读 `stateData`）、`battle_logic.gd`（开战顺序、regen 记录、分发上下文）。都是新增分支或接线，没动已有 op 的行为；合并时请沙僧知会。
- 同步：转换器改动只改 `States.json` 的 `effects`（第一批 18 个状态、第二批 46 个状态），其余导出不变；新增参照 `state_js.json`。

## 交接板

- 下一步（云端暂停，2026-10-25 16:05 用户要求先把额度留给小小鱼审查）：第三批状态计数 _stateCounter 已 WIP 提交（转换、运行时、原版测量都在，Godot 专项 1733 项中 57 项未过：counter_init 没写进计数，待查）；两批合起来的全量检查被中断，没跑完。之后状态效果 js 剩 346 块，第三批候选（按块数）：复活／倒下时 deselect 家族、强制暴击 select／deselect、泡泡护盾 react／remove、`_stateCounter` 计数 apply（23 块，G_StateParam 按计数乘，要连同能力值一起做）、Regenerate 额外伤害（475／566／577／224／260／1006）、反伤 react（378 起）
- 用户试玩说明：中毒叠层（叠毒类状态）每回合按层数掉血并弹字、播动画；开战 TP 加满类被动（607 等）开战后 TP 正确；暴击后附加状态、开战加状态、开战／胜利回复生效
- 需要用户决定：无

## 进度账

- 状态效果 js：未翻译 444 → 346 块（叠毒 51、第二批 47）

## 可优化（流程／工具／效率）

- 已做：云端没有 macOS `sips`，导出用 PIL 小垫片（只在云端临时目录，不入库）
- 建议：`检查.sh` 的失效链接检查在云端（没有 `04_验证/本地结果`）报 26 项本地结果链接，云端跑时可按「目标在本地结果目录」降级为提示（哪吒）

## 本分支提交

- dab2ac7 第一批：叠毒 _stackingPoison
- fac06a8 第二批：加状态、暴击后加状态、回复、设变量、原版语法错误块
- （WIP）第三批状态计数
