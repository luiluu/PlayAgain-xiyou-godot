# 交付：claude/bajie-skill-changeto

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_80）
- 状态：进行中
- 基线：claude/bajie-weapon-unleash-4656d6 末端 965f8b91（上一期武器解放，未进 main 时接着做）。
- 本期：武器解放交付单遗留 2——TorigoyaMZ_SkillChangeTo 的 `<ChangeTo[id]: 条件>` 技能替换，先补原版探针再改。

## 原版查下来的结论（TorigoyaMZ_SkillChangeTo.js v1.1.0 与 skill_change_to_probe 实测）

- **插件无参数**（plugins.js 里 `parameters: {}`）。插件只包 `BattleManager.startAction`：取 `subject.currentAction().item()`，按 `item.meta` 里键含 `ChangeTo[数字]` 的条目（MV extractMetadata 的对象键序＝备注里首次出现的顺序，同键后者覆盖）逐条 `eval(条件)`，第一条为真就 `setSkill(id)`（物品则 `setItem(id)`），然后才进下一层 startAction。
- **条件**是 JS 表达式，`a`＝行动者（eval 在 doEval 里，只有参数 a；全局如 $gameVariables 也能读，但正式数据没用）。先把「小于／大于／&lt;／&gt;」换成 `<`／`>` 再 trim。eval 抛错算假。
- **不看换出来的技能能不能用**（不 canUse、TP／MP 不够照样换，之后照新技能付费）；**不递归**（换出来的技能即使也带 ChangeTo 也不再换；正式数据里换出的技能都不带）；每条条件里的 `Math.random()` 每次求值掷一次，第一条为真就停。
- **先后**（startAction 链，外到内）：Codex 运行时各包装（智能 AI 的 currentAction 复核在最外）→ MOG 连击 → **SkillChangeTo** → OTB → YEP_BuffsStatesCore 行动开始状态效果 → WUL 武器解放 → YEP_BattleEngineCore startAction（付费、选目标）。所以 ChangeTo 在行动开始状态效果和武器解放**之前**。换出普攻时武器解放照常接着判（正式数据没有换成普攻的）。
- **哪些路径触发**：凡走 startAction 的都触发——角色手动、自动战斗、挂机、智能 AI、敌人行动、强制行动。敌人先过 processTurn 的 isValid（能不能用的是原技能），再进 startAction。反击不走 startAction，不换。
- **掷骰**：原生 `Math.random()`。

### 正式数据（67 个技能，全部在 Skills；物品、装备、状态、敌人、角色上没有）

- **纯几率 `Math.random() < x`**：65 个技能——188、223、227、228、329、377、378、379、530、533、689、737、738、739、1009、1013、1802、2118、2121、2124、2125、2684、2799、3178、3632、3635、3638、3641、3644、3651、3681、3688、3695、3761、3907、3908、4410、4748、4750、4752、4755、4757、4759、4774、4783、4788、4793、4808、4811、4814、4845、4917、5110、5424、5596、6929、6930、7117、7126、7222、7223、9917、9919、9921、9924。其中 689、2118、2121、2124、2125、4755、4757、4759 是 `< 1`（必换），379 第一条也是 `< 1`。
- **纯几率 `Math.random() <= x`**：2004 大威天龙*普渡（≤0.35 换 2011）。
- **血量条件 `a.hp < (a.mhp * x)`**：4938 落尘定相笑*春（依次 25%→4941、50%→4940、75%→4939，不掷）。
- **其他写法**：无。
- 谁会用：敌人 28（188）、79（227）、889（530）、974（2121）出招表里有；职业习得 20 个（3635、3641、3644、4410、689、4845、530、223、228、329、378、379、2004、2121、2124、2125、2684、3761、7222、7223）；其余 45 个靠别的途径学（技能书、事件、被动等），本期不查可达性，探针直接让角色 1 放。

## 变更记录草稿

## 2026-10-28 【Claude·八戒·未经Codex检验】技能替换（TorigoyaMZ_SkillChangeTo）：行动开始时按技能备注 <ChangeTo[id]: 条件> 换成别的技能（dev.待定）

1. `battle_logic.gd`：新增 `change_to(u, skill)`、静态 `change_to_conditions(rec)`（照 MV extractMetadata 认 `<…ChangeTo[id]…: 条件>`，键序、同键覆盖同原版，按备注缓存）、`_change_to_test`（条件换成 Godot Expression：`Math.random()` 换成调 `change_to_roll()`，只认 `a.hp`／`a.mhp` 两个标识符，别的写法算假；不另写 JS 求值器）、`change_to_roll()`（rule 流 `"changeto"`）。`execute` 在敌人 can_use 判定之后、`XStateEffects.run("action_start")` 之前调用，所以先于武器解放。换出来的技能照常付费、选目标、记 action。
2. 原版探针 `skill_change_to_probe.cjs`（202 例）：走真实 `BattleManager.startAction` 链（只把最后的 BEC startAction 换成记录），只给 doEval 里的取数喂磁带；65 个纯几率技能各「全中换第一条／全不中／只有最后一条中」，`<` 与 `<=` 等于几率的边界，第二／三条中，TP／MP 为 0 仍换，4938 按血量比例与 mhp 485 的 25／50／75% 两侧整数，敌人（敌群 1）也换，普攻与物品不掷。登记 `同步正式西游.py` 探针表与 `oracle_additions.py` KEYS。
3. 专项 `xiyou_skill_change_to`：带 ChangeTo 的技能全集、每例解析出的条件（id＋原文）、真正开始的行动技能、ChangeTo 取数次数都与参照一致。

## 改了的原沙僧核心文件（待交叉核查点名）

- `battle_logic.gd`：新函数 `change_to`、`change_to_conditions`、`_change_to_test`、`change_to_roll`；`execute` 在 `XStateEffects.run("action_start", u)` 之前加一行 `skill = change_to(u, skill)`。
- 另改：探针 `skill_change_to_probe.cjs`；`同步正式西游.py`、`oracle_additions.py` 各加一行登记；专项 `xiyou_skill_change_to.gd`／`.tscn`。

## 没做（原版能做、正式数据没用到）

- 条件里 `a.hp`／`a.mhp`／`Math.random()` 之外的写法（别的属性、$gameVariables、$gameSwitches、函数调用等）：重制一律算假。以后数据用到新写法时在 `_change_to_test` 的白名单里加（属性名要与 XBattler 一致）。
- 物品上的 ChangeTo：代码照原版支持（物品换物品），正式数据没有，没补探针。

## 遗留

1. **外层 startAction 包装看到的是换之前的技能**（同武器解放遗留 1）：原版 Codex 运行时包装、MOG 连击在 ChangeTo 之外；重制 `XRaceBattle.begin`／`XAlienBattle.begin` 在 execute 里更晚，拿的是换后的技能，与原版读取时机（只存行动引用、之后才读）一致；`act()` 末尾的 `XCat.end_action` 拿的是换前的技能，但它只看是不是防御（技能 2），ChangeTo 不涉及。没为此单独补探针。
2. 探针里 startAction 链另有 2 次 Math.random（不是 ChangeTo 的；探针回 0.5 并记 `otherRolls`，专项不比）。

## 交接板

- 下一步：无新增（SkillChangeTo 完成）。
- 用户试玩说明：带「几率变成别的招」的技能（连环斩、利刃风暴、善恶有报、万剑归一、爆踢、三魔术*火等 67 个）现在会按原版几率变招；落尘定相笑*春按血量变招（血越少越强）。变出来的招照它自己的消耗付费。
- 需要用户决定：无

## 进度账

- 战斗规则：TorigoyaMZ_SkillChangeTo 技能替换补齐（正式数据用到的写法）。

## 可优化（流程／工具／效率）

- 待写

## 验证

- 待写

## 本分支提交

- da10cbbd WIP：探针、专项、battle_logic.change_to
