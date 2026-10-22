# 交付：claude/jovial-napier-ef0df2

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_52 起头，重制_八戒_53 接 WIP 收尾；原分支 claude/bajie-menu-sys 已整支并入本分支）
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

## 2026-10-23 【Claude·八戒_52／53·未经Codex检验】主菜单未接入系统盘点；人物图鉴接入（dev.待定）

- **盘点**：主菜单灰显 7 项逐项对照冻结 v0.28 的入口、实现规模、数据与重制依赖（见本交付单「盘点」节，合并时可移到 `00_设计/` 或附在本条）。建议顺序：人物图鉴 → 怪物图鉴 → 种族祝福菜单（随种族规则）→ 制作 → 异化工坊 → 宠物；「反馈」不接。
- **人物图鉴**（新 `modes/xiyou/ui/actor_book.gd` XActorBook，照 Star_ActorsBook＋Codex_ActorBookSkillDetails）：目录窗（全部 `$dataActors` 槽，空槽「？？？」，Codex 补丁即全解锁，不加存档字段）；状态窗（SV 待机动画、职业 1 级八项初值、品质七档色、人物属性、最大进阶次数、主动／被动／其他三列技能、武器／防具掌握、`<ActorNote>` 备注；渡鸦 167／173 特殊版式）；确定进技能详情（抬头、带【类型】的技能列表、特殊角色未学会「未解锁」、宽 727 说明卡固定在 (545,8)）。
- **入口**：主菜单「人物图鉴」开放，照原版是公共事件 3（Menu 82 Ext）：菜单预约公共事件后关闭，地图执行 `SceneManager.push(Scene_ActorBook)` 打开图鉴、关闭回地图。预约走 dev.136 的 XState 单槽（`event_state.reserve_common_event`），与存档、成就同一条路。`mv_script.gd` 加一条 `SceneManager.push(Scene_ActorBook)` 识别、`map_scene.gd` 加 `open_actor_book()`，写法与成就的一致（这两处不是本车道独占，改动各几行，合并时请留意与悟空车道的冲突）。
- `help_card.gd` 加 `card_width`（默认 400，图鉴详情用 727），其余页面不变。
- **参照与测试**：`tests/fixtures/actor_book_oracle.json`（冻结 v0.28 浏览器参照，新局队伍 1/8/9/10：目录、各槽状态窗全部文字／图标、SV 图名、技能详情抬头、列表首屏与全部技能 ID）；新专项 `xiyou_actor_book` 逐槽对照并走一遍操作与主菜单入口；`xiyou_panels` 灰显名单 7→6 项。
- **与原版不同**：原版进过技能详情再返回，说明卡的品质边框留在状态页上，这里返回时整张卡隐藏（原版缺陷，不照搬）。
- **未做**：切片外 17 个角色（108、143～145、157、160、167～177）没导出 SV 图，状态页不画立绘；补图要扩切片 extraImages（悟空）。进阶系统未做，最大进阶次数按当前进阶 0 取表。

## 交接板

- 下一步：主菜单未接入系统按盘点顺序续做：**怪物图鉴**（2 期：菜单图鉴＋战斗结束登记新存档字段；战斗内「怪物信息」「图鉴」指令）→ 种族祝福菜单（与种族规则同批，规则在沙僧独占文件）→ 制作（要悟空在事件解释器接 `crafting learn`）→ 异化工坊 → 宠物。人物图鉴缺立绘的 17 个角色待切片 extraImages 补 SV 图（悟空）。
- 用户试玩说明：主菜单「人物图鉴」可以打开了：左边是全部角色目录，右边是所选角色的初始属性、品质、属性、技能、武器防具掌握和备注；按确定进技能详情，看每个技能的说明卡。部分特殊角色（渡鸦等 17 个）暂时没有立绘。
- 需要用户决定：主菜单「反馈」原版是作者的外部反馈服务，重制不接；是继续灰显，还是从菜单去掉？（默认继续灰显）

## 进度账

- 养成与周边系统：13% → 14%，人物图鉴（两个图鉴之一）整页按原版接入（八戒估，待沙僧复核）

## 本分支提交

- 02bcfd50 主菜单 7 项未接入系统盘点
- 1da02965 人物图鉴 XActorBook、主菜单接公共事件 3、专项对照原版参照
- （本提交）合 main 后菜单预约改走 XState 单槽，交付单

## 验证

- 相关专项（`并行测试.py`）：（待写）
