# 交付：cc/bailong-exclusive-gaps1

- 车道／工作者：E 角色专属／白龙_12（cc）
- 状态：可合并（在 yunshang11 之后合）
- 分支从 cc/bailong-yunshang11 末端 a63b2c96 切出（总装十一派单），**包含 yunshang9～11**，那三张交付单照它们自己的合；没合 main。
- 范围：盘点角色专属剩余缺口（下表）；做了米拉深渊掉落黑龙进阶石；删两处过时注释。表里最大的一项「小猫剑圣·守誓巨龙试炼」上下文不够做完，留给下一期（计划见文末）。

## 盘点：角色专属剩余缺口

来源：`modes/xiyou/core/` 各专属模块文件头的「未移植」节，逐条 rg 过代码与专项确认。熟练度相关的（渡鸦熟练度上限、宿傩熟练度上限、饿狼 skillMasteryLevel、甚尔说明框熟练度行）归八戒熟练度三期，没列。

| 角色 | 缺口 | 原版位置 | 玩家看得到吗 | 处理 |
| --- | --- | --- | --- | --- |
| 小猫剑圣 178 | 守誓巨龙试炼（公共事件 9018 `CodexCat.startTrial`）：只带小猫独自打敌群 1999，巨龙按 5 回合轮换出招（爪、蓄息、喷焰、空、尾）、蓄息时提示、能力值用数据库原值、不吃塔内强化状态（22 个）、开战回满；赢了第一次给小猫进阶石 2900，结束还原队伍 | installImportedBalanceRuntime.js 第 242～266 行（约 25 行，压缩写法） | 看得到，而且**小猫进阶石只有这一处来源，小猫现在进阶不了** | **最大，下一期做** |
| 小猫剑圣 | 进阶后学了速剑，行动次数 +1（makeActionTimes 包装） | 同上第 118 行 | 看得到（战斗多动一次） | 小，可跟试炼一起做 |
| 小猫剑圣 | 小猫在队时号角 2899 不能用（canUse 包装） | 同上第 122 行 | 看得到 | 小 |
| 小猫剑圣 | 进阶后终技（至圣斩）说明与名字按品质 10 显示（helpItem） | 同上第 145～146 行 | 看得到（显示） | 小 |
| 米拉 168 | 深渊地图胜利 1/30 掉黑龙进阶石 2903（米拉三次进阶都要 1 个，只有这一处来源） | installNativeMiraRuntime.js 第 392～401 行 | 看得到，原来米拉进阶不了 | **本期做了** |
| 米拉 | 黑龙形态的战斗图（BlackDragon_Mira_Enemy，缩 0.55、下移、藏武器） | 同上 updateBitmap 包装 | 看得到（画面） | 留画面车道 |
| 渡鸦 167 | 魔法反射时对自己累计伤害、行动结束追加；收割／回响特效动画（R.Fx） | installNativeRavenRuntime.js 第 999～1098 行一带 | 反射支看得到（少见）；特效是画面 | 未做 |
| 宿傩 172 | 神灶选目标窗只列已蓄力的敌人；战斗日志文字 | installNativeSukunaRuntime.js | 看得到（界面） | 留画面车道 |
| 饿狼 173 | 琦玉时输入阶段的认真一拳可选（原版看已排行动）；0 伤不暴击；胜利提示文字、法宝说明 describeRelic、图鉴立绘 | installNativeGarouRuntime.js | 看得到（少见／显示） | 未做 |
| 黄泉／镜流 169／170 | 隐藏呼吸技能分类、图标与品质色；镜流星魂说明行、技能图标、追加段日志 | installNativeYomiJingliuRuntime.js | 看得到（显示） | 留画面车道 |
| 甚尔 171 | 读档时 repair（武器库与霸王血铠修复） | installNativeTojiRuntime.js | 只有坏档才看得到 | 未做 |
| 黑闪（宿傩／甚尔） | 遗忘 10225 或觉醒技时清空黑闪；说明框实时状态行、宣告弹字 | installNativeBlackFlashRuntime.js | 少见／显示 | 未做 |
| 三法宝（谷雨） | 说明卡的法宝条目改写 relicLines | installThreeGrowthRelicRuntime.js | 看得到（显示） | 未做 |

过时注释（已删改）：`black_flash.gd` 写「甚尔的额外一击未移植」，其实 `toji.gd` 段数里已有（黑闪觉醒中游云多 1 段）；`cat.gd` 写「Map132 商店补号角未移植」，其实 `XItemMarks.LOBBY_CAT_HORN` 已做。

交接板遗留：「白龙报 55 级黄泉技能伤害绝对值比原版低约 3.9%」那条没有核（上下文不够），请总装看是否已被战斗核心车道消掉。

## 变更记录草稿

## 2026-11-01 【cc·白龙_12·未经审查】米拉深渊掉落黑龙进阶石；角色专属缺口盘点（dev.待定）

1. **米拉深渊掉落**（installNativeMiraRuntime.js 第 392～401 行，makeRewards 包装）：MapInfos 名字以「深渊」开头的地图上胜利，每场判一次，1/30 多给一个黑龙进阶石 2903（米拉三次进阶都要它，原版只有这一处来源，重制之前米拉进阶不了）。`XMira.abyss_bonus`（随机数取战斗奖励流，结果记在本场，`rewards()` 再调不重掷），`XBattleLogic.rewards` 里接一行。
2. **盘点**：角色专属剩余缺口一张表（见交付单）；`black_flash.gd`、`cat.gd` 两处过时的「未移植」注释改正。
- 参照：新探针 `mira_abyss_probe.cjs`（不进同步，产物拷成 `tests/fixtures/mira_abyss_oracle.json`）：真实 makeRewards，地图 37、58（深渊）与 4，Math.random 0／0.0333／0.034／0.5。新专项 `xiyou_mira_abyss`。

## 优化登记草稿

无。

## 验证

- 专项 xiyou_mira_abyss 41/41：12 例逐个比多出来的 2903 个数与地图名、再调 rewards() 不重掷、发进背包。
- 反向验证 3 处全抓到：结算不加、1/29、不看深渊。
- 语法检查通过。
- 选测：`选测.py a63b2c96` 因为改了 battle_logic.gd（战斗核心）选上百个连 rules 24 段；改动只是 rewards() 里一行、只在深渊地图名下加掉落，改跑与奖励、掉落、深渊楼层、米拉相关的 23 个全名（CHECK_JOBS=3，12 分钟）：22 过；xiyou_determinism early_inventory_rule 一处是 yunshang9 时就有的 main 掉落改动夹具问题（总装十说第六批收尾已修，本分支没合到那次修），不是本分支的。过的：xiyou_mira_abyss、xiyou_mira_battle、xiyou_battle_drop、xiyou_battle、xiyou_floor_abyss037、xiyou_floor_abyss174、xiyou_floor_abyss211、xiyou_floor_unknown160、xiyou_floor_run、xiyou_floor_run_b、xiyou_floor_run_c、xiyou_flow、xiyou_hangup_auto、xiyou_event_compare、xiyou_cat、xiyou_toji_battle、xiyou_sukuna_battle、xiyou_rules、xiyou_rules_d1b、xiyou_rules_d1c、xiyou_rules_d1d、xiyou_actor_modules。

## 交接板

- 下一步：小猫剑圣守誓巨龙试炼（见文末计划），顺带速剑多一次行动、号角不可用、终技品质 10。
- 用户试玩说明：米拉在深渊地图打赢有 1/30 机会掉黑龙进阶石，米拉可以进阶了。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：米拉 +0.02（进阶材料来源），按工作量估。

## 可优化（流程／工具／效率）

- 无新增。

## 待交叉核查

- `battle/battle_logic.gd`（rewards 一行）、`core/mira.gd`（abyss_bonus）；新探针、夹具、专项。

## 下一期计划：小猫剑圣·守誓巨龙试炼

1. 参照：新探针（不进同步）拦 `SceneManager.push`，走 `CodexCat.startTrial`：记队伍换成只有 178、BattleMaxSize 1、BattleManager.setup(1999, false, true)；开战回满与满 TP；巨龙 1999 的 makeActions 按 `(回合−1)%5` 取 [爪, 蓄息, 喷焰, 空, 尾]（OTB 用 round()）；蓄息时日志「巨龙昂首蓄息！下一回合将喷出铜焰，架剑防御！」；Game_Enemy.param 用数据库原值；addState 挡 22 个难度状态（trialDifficultyStates）；endBattle 后还原队伍，首胜给 2900 并提示「守誓巨龙认可了你…」（看第 242 行全文），读档时有残留试炼就还原。
2. 重制：`mv_script.gd` 里 `CodexCat.startTrial(this)` 现在条件够时「照旧算没认出」，要接成开战（参照地图事件开战的路子，战斗结束回调里还原队伍）；`XCat` 加试炼状态（存 flags）、巨龙出招、参数与状态过滤（在 enemy／battle_logic 的现有钩子里）。
3. 专项：试炼开战的队伍与回满、5 回合出招序列、难度状态挡下、胜利首次给石、第二次不给、失败与逃跑还原、读档还原。

## 本分支提交

- 前面同 yunshang11（到 a63b2c96）
- 米拉深渊掉落（WIP）
- 盘点、过时注释、交付单（WIP）
- 本提交：选测结果，交付单可合并
