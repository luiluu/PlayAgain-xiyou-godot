# 交付：cc/tianqi-rules-1114

- 车道／工作者：C 规则·机制／cc（Orca 车道 tianqi-rules-1114，claude-opus-5-5＋medium）
- 状态：已交付

## 变更记录草稿

## 2026-11-14 【cc·tianqi-rules-1114·未经审查】天启篇三项小规则：号卷六号口粮透支照扣、五条悟证道前降炼狱、「已清除异化·某线」（dev.待定）

Kyo 11-14 定（协调转派）。三项分开提交，各有专项断言和反向验证。

1. **号卷六号不再免饥荒线的口粮与透支**（`core/tianqi_trumpet.gd`、`battle/battle_logic.gd` `pay_skill_cost`）：第 1 回合自己的技能全免照旧（MP、TP、HP、物品、噬主、缄默、米拉代价），但饥荒线异化的口粮、透支照常扣。口粮按「没有六号时」的原始费用判断零消耗（`XTianqiTrumpet.famine_raw` 临时关掉六号再算 `skill_cost`／`skill_hp_cost`）：原本零消耗的技能才交口粮，被六号免成零的带蓝技能不交。`can_use` 不用改：口粮 MP 不够改扣生命、透支只扣到 1 点，本来就不挡技能（第 1、2 回合一样，测试有断言）。开关 `XTianqiTrumpet.FAMINE_PAYS`（O-待定-1），设 false 回到口粮透支也免。
2. **五条悟「最强之名」证道开放前降到炼狱**（`core/gojo.gd`）：`unlock_difficulties()`：`XTianqi.ZHENGDAO_OPEN` 关着时认炼狱和证道，开放后只认证道；仍要队里有宿傩或甚尔。解锁记在全局配置 `codexTianqiGojo`，不收回。开关 `XGojo.BEFORE_ZHENGDAO_LIANYU`（O-待定-2）。
3. **「可轮回」改名「已清除异化·<线名>」**（`core/tianqi_line.gd` `clear_title`、`ui/save_scene.gd` `clear_mark`、`ui/tianqi_line_cards.gd`）：读档界面线名后面、36 层结局结算、选线竖卡（「★ 已清除异化」）都用新叫法；存档字段 `flags.tianqi.reincarnate` 不改，旧档照常显示新名字。选线画面「通关骑士剪影点亮」11-13 已做（跨存档徽记 → 露出立绘＋徽记），本单补断言和截图，没出新图。二周目仍不继承任何东西。
- 玩家可见：天启篇 36 层通关后的存档标记改叫「已清除异化·某线」；选线卡上的「★ 已通关」改为「★ 已清除异化」。（天启篇未对玩家发行，测试玩家可见。）

另：私密设计仓 `重制设定/天启篇_设计总览_v0.3.md`（提交 6b0ccd6，已推）记入 Kyo 11-14 全部决定；八九条养成线按 Kyo 改定的「乙——逐条重做，已定未设计」写。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `core/tianqi_trumpet.gd` `XTianqiTrumpet.FAMINE_PAYS`、`famine_free`、`famine_raw`；`battle/battle_logic.gd` `pay_skill_cost` | （天启篇新内容）号卷六号第 1 回合连饥荒线的口粮、透支也免 | 口粮、透支照常扣，口粮按没有六号时的原始费用判断零消耗 | Kyo 11-14：保住饥荒线压力 | `FAMINE_PAYS` 设 false | cc | 保留 |
| O-待定-2 | `core/gojo.gd` `XGojo.BEFORE_ZHENGDAO_LIANYU`、`unlock_difficulties` | （天启篇新内容）最强之名只认证道通关，证道没开放时谁都解锁不了 | 证道开放前炼狱 36 层也解锁，开放后自动只认证道 | Kyo 11-14：证道开放前临时降档 | `BEFORE_ZHENGDAO_LIANYU` 设 false | cc | 保留 |

## 验证

- 专项（本机）：`xiyou_tianqi_trumpet`（新断言 cavalry.famine.*、cavalry.overdraw.*）、`xiyou_gojo`（新 unlock_*、persist.*：XSave 真写盘读档＋XConfig 从盘重读）、`xiyou_tianqi_ending`（final_clear_said、final_no_old_name、save_clear_mark、old_save.* 4 条、card_lit、截图）、`xiyou_tianqi_famine`、`xiyou_tusu_battle`、`xiyou_tianqi_look`、`xiyou_tianqi_war`、`xiyou_tianqi_summit` 全过。
- 反向验证（`反向验证.py`）三份清单 12 项全部咬住：六号回到全免、口粮改按免后费用、raw 视角失效、FAMINE_PAYS 失效；证道关着只认证道、证道开了还认炼狱、开关失效、解锁不写盘；叫法退回可轮回、读档不标、卡上退回已通关、剪影不点亮。
- 选测：`选测.py main --list` 289 个场景（battle_logic 改动带出战斗核心），超 40 走云端：`云端选测.py run --no-upload`（提交 1e6cb589d，云端按基准取整轮 589 个），结果见下行。
- 云端结果：589 个场景 588 过，挂 1 个 `xiyou_tianqi_alien_gear`（review6_tier_again、review6_huaxing_same_again、review6_o-off：「再动」按级文案）。**与本分支无关**：把本分支 13 个改动文件全退回分叉点后本机重跑同样 54/57 失败；是 11-14 合并 cc/tianqi-review-fixes（d45643f0b）带进 main 的既有失败，main 至今没修。该文件属在跑的 tianqi_alien_gear 车道，本单没碰，请总装转给它或核查。运行页 actions/runs/43604531253。
- 语法检查 0 问题；工具回归全部通过（149 秒）。
- 截图：[选线竖卡·战争线已清除异化](cc_tianqi-rules-1114_截图/line_cards_war_cleared.png)（窗口模式 `-- --out=`；中间的成就弹窗是测试流程带出来的）。

## 交接板

- 下一步：无新增（三项已落地；设计总览 v0.3 第六节列了已定未实装的读档总原则、去 ×6、养成线逐条重做设计车道）
- 用户试玩说明：天启篇打通 36 层，读档界面线名后标「已清除异化·某线」；炼狱 36 层带宿傩或甚尔通关解锁五条悟；饥荒线带号卷六号，第 1 回合零消耗技能照交口粮
- 需要用户决定：无

## 进度账

- 无（天启篇规则小改）

## 可优化（流程／工具／效率）

- main 上 `xiyou_tianqi_alien_gear` 3 条 review6 断言失败（见验证），合并 cc/tianqi-review-fixes 时没被拦下，建议派给七印／异化装备车道修。

## 本分支提交

- 9446b53f0 号卷六号第 1 回合饥荒口粮、透支照扣
- 89a81a4e6 五条悟证道开放前炼狱也解锁
- 1e6cb589d 「可轮回」改名「已清除异化·某线」、剪影点亮断言与截图
- 34438a506 交付单、开关注释 O-待定-1／-2
