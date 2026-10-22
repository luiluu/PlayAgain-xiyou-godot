# 交付：claude/bajie-menu-sys

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_52）
- 状态：进行中

## 盘点

主菜单（`modes/xiyou/ui/menu.gd` COMMANDS）里还灰显的 7 项，逐项对照冻结正式源 v0.28（`app.nw`，只读）。前三列是原版入口与规模，后几列是重制现状与依赖。

| 指令 | 原版入口 | 原版实现与规模 | 依赖的数据 | 重制依赖（未做的系统／他人独占文件） | 玩家可见度 | 粗估 |
| --- | --- | --- | --- | --- | --- | --- |
| 人物图鉴 actorBook | YEP_MainMenuManager Menu 82 → 公共事件 3 `SceneManager.push(Scene_ActorBook)` | `Star_ActorsBook.js`（20KB）＋`Codex_ActorBookSkillDetails.js`（14KB）。两页：左目录（宽 320、全部 `$dataActors` 槽，空槽「？？？」）＋右状态（SV 待机动画、职业 1 级八项初值、品质七档色、人物属性元素、最大进阶次数、主动／被动／其他三列技能、武器／防具掌握、`<ActorNote>` 备注）；确定进技能详情页（左技能列表 42%、右说明卡 Sprite_ItemHelp） | Actors／Classes／Skills／System 全表（生成数据里 166 个有名角色都在）、`Star_ActorAdvanced` 进阶表参数、CodexQuality、CodexElements；`$gameParty.ActorBookLite`，但 Codex 补丁打开即全解锁，**不需要新存档字段** | 无。说明卡已有 `XHelpCard`；人物属性画法已有（power_strip／power_panel）。切片外 17 个角色（108、143～145、157、160、167～177）缺 SV 图，先不画立绘（补图要改切片 extraImages，归悟空） | 主菜单常用；纯查阅 | **1 期** |
| 怪物图鉴 monsterBook | Menu 83 → 公共事件 2 插件指令 `EnemyBook open` | `AB_EnemyBook.js`（140KB，含大量未启用分支）。目录＋状态两页（达成率、能力值、命中回避、弱化／抗性属性、状态抗性、掉落、技能）；战斗里另有「怪物信息」「图鉴」两个指令（ShowCommandInBattle=1） | Enemies／States／Items，`$gameSystem._enemyBookFlags`（ResisterTiming=2：战斗结束时登记出现过的敌人） | 要新存档字段＋战斗结束登记钩子（战斗场景，非状态效果接线，可做）；战斗内指令要改战斗指令窗 | 中，图鉴是收集类 | 2 期（菜单图鉴＋登记；战斗内指令） |
| 制作 crafting | `hc.js` Recipe Crafting 自己 `addCommand("制作","crafting")` | hc.js（44KB）：四类别（炼金术／打造／加工／珠宝）、类别等级与经验、配方列表＋材料＋批量制作 | `data/Recipes.txt`（约 500 条配方）、配方习得 `crafting learn N`（公共事件与 Map006 的插件指令）、制作等级 | 新存档字段（已知配方、等级经验）；`crafting learn` 插件指令要接进事件解释器（`mv_script.gd`，悟空车道）；独立物品装备产出要走现有独立装备逻辑 | 中高（中后期装备进阶主要途径） | 2～3 期 |
| 种族祝福 race | `installNativeRaceRuntime.js` addOriginalCommands `addCommand('种族祝福','codexRace',!battle)` | 36KB。菜单本身是 CodexBinding 选单（选角色→换族／进阶／血契），简单；规则主体在战斗：七族增伤、猎物选择、血契扣血、回响、反攻等 | `CodexRaces.json`（已生成）、开关 281～287、`_codexRaceSupply`（xstate 已有 race_supply） | 战斗效果在 `damage.gd`／`battler.gd`／`battle_logic.gd`（沙僧独占）；只做菜单没有效果意义 | 高（开局就选） | 菜单 1 期＋规则 2 期（规则需沙僧或 C 车道） |
| 宠物 pet | Menu 80 → 公共事件 169 `SceneManager.push(Scene_PetSystem)` | `Star_PetSystem.js`（72KB）＋`Star_PetSynthesis`＋`Star_PetUpLevel`：宠物捕获（13／8／5 层等地图事件出现神秘生物，敌人 288～295）、宠物列表、升级（吃 426～431）、合成、出战 | 插件参数里的宠物地图表、敌人、物品；宠物实例存档 | 依赖楼层事件（切片／事件解释器，悟空）、宠物参战（战斗）；最大的一项 | 中 | 4 期以上 |
| 异化工坊 alienation | `installAlienationWorkshop.js` addOriginalCommands `addCommand('异化工坊','alienation',true)` | 四个模块共约 115KB；工坊是 DOM 叠加层（非 MV 窗口）：重抽、分解、战前技能配置、最近异化掉落 | 异化掉落与词条账本（installAlienationRuntime）、装备标记 | 异化词条的伤害钩子（`installAlienationAffixes` → damage 钩子，沙僧独占）、掉落生成（dungeon／掉落）；工坊无异化装备时没内容 | 中后期 | 3～4 期 |
| 反馈 feedback | `installFeedbackRuntime.js` 改 makeCommandList，在「设置」前插「反馈」；设置页另加「待提交反馈」 | 20KB：DOM 表单，POST 到外部服务 `https://kyo-game-feedback…chatgpt.site`（CodexFeedbackConfig） | 外部网址、作者密钥 | — | — | **不接**：只是原版作者的外部反馈渠道，按「重制不做外部渠道」处理，继续灰显（是否从菜单去掉留给用户，见交接板） |

**建议顺序**：人物图鉴（1 期，本分支期二做）→ 怪物图鉴（2 期，不碰独占文件）→ 种族祝福菜单（与沙僧／C 车道的种族规则同批）→ 制作（要悟空在事件解释器接 `crafting learn`）→ 异化工坊 → 宠物。

## 变更记录草稿

## 2026-10-22 【Claude·八戒_52·未经Codex检验】主菜单未接入系统盘点（dev.待定）

（待写）

## 交接板

- 下一步：（待写）
- 需要用户决定：主菜单「反馈」原版是作者的外部反馈服务，重制不接；是继续灰显，还是从菜单去掉？（默认继续灰显）

## 进度账

- （待写）

## 本分支提交

- （待写）
