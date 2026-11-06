# 交付：cc/bajie-newsrc3（续四，DD）

- 车道／工作者：A 内容·楼层／八戒（cc，第十四批 DD）
- 状态：① 做完（集成分支用，不合 main，不标可合并）；② 等总装失败表。
- 分支沿用 `cc/bajie-newsrc3`，开工合了 `cc/newsrc-switch` 7c2a3a7e（优化登记冲突：两边新增行都留）。工作树 `.claude/worktrees/quizzical-neumann-d318e5`；generated、`.godot`、`mv_oracle/.sandbox` 从集成树 `recursing-shamir-4cd3d8` 克隆（v0.62.12 新源）。
- 上一棒交付单 `cc_bajie-newsrc3.md` 的内容照旧有效（变更记录草稿、待核查、两条 O-待定），本单只写新增。

## 变更记录草稿

### 【cc·八戒·未经审查】换源追平续四：event_compare 新源基线重出、深渊赌场二阶段跟新源换序

- **深渊赌场 1434 二阶段**（event_compare ce1434#o5_3）：新源 v0.62.10 的 `installCasinoBatchRuntime` 里有 `fixAbyssStage2`，读入公共事件时把 1434 二阶段五对「1197 = v1191～1195、再重抽那一格」换成先抽再读（原注释：旧顺序 20 连后这几格残留约 ±30000）。数据文件本身没改，所以重制照数据跑就和参照对不上。参照探针打桩实测：执行到第 45 条时跑的是「1195 = 随机」。重制在 `XDB.table("CommonEvents")` 读入时调 `XCasinoBatch.fix_abyss_stage2` 做同样的换序；开关 `XCasinoBatch.ABYSS_STAGE2_ROLL_FIRST`（默认 true，false 回到 v0.28 数据原序），登「O-待定·深渊赌场二阶段」。casino_batch 加 abyss2.raw／roll_first／o-off 三项。
- **event_compare 基线按新源重出**：15565 例，一致 15556，登记 9 例（原有 3 例＋新进 6 例，理由都写进了基线的 note）；跳过基线收进 ce1370 四条（O_PUSH_RECAST 在战斗里补，地图对照认不出）和 ce9043 一条。
- **ce9039#n2／ce9026#n2**：上一棒给预设加的 `difficulty: 9` 是对的。集成树的事件状态产物是在这条预设改动之前量的，所以参照里还留着「超强者仅限地狱及以上难度获取」。用新源单跑这两例（`XIYOU_APP=…/v0.62.12/app.nw node event_state_probe.cjs 'ce9039#n2' 'ce9026#n2'`），提示没了，结果补进本树 generated 的 event_states 后两例一致。**集成树合本分支后的同步会重量这两例**（预设变了，增量键也跟着变），不用手补。

## event_compare 五例定性

| 用例 | 定性 | 处理 |
| --- | --- | --- |
| m148e38p0 | 新源数据：大厅 Map148 EV38 传到 Map234 凤凰殿，是新源新加的地图 234～239（v0.54 一护剧情），还没进 `xiyou_slice.json`，所以重制传不过去，战斗背景为空 | 进基线。**切片加 234～239 是另一件事**（盘点第 139 条早就列了，A 车道的独占文件），等总装决定派不派 |
| ce1434#o5_3 | 新源改动重制没跟上（上面） | 已修，现在一致 |
| m4e71p0 | 参照宿主的问题：jsdom 的同步读文件拿不到 `data/PlayerChangelog/*.json` 和 `data/ContentVersion.json`。新源单跑 `CodexGuide.readChangelog(37)` 得 null，`changelogEntries()` 得 0 条，所以参照只剩 Map004 里 v0.36 以前的那几页。真游戏读得到，重制先列 v0.62 是对的 | 进基线；**hboot 读文件这块交工具车道** |
| ce9039#n2、ce9026#n2 | 产物旧了（上面） | 现在一致；同步后照旧一致 |

另 3 例新进基线是上一棒定过性的：m4e69p1 及 #o4_2／#o4_3（O-待定·升级文字）、ce9043（流萤招募没做）。

## 验证

- 本机新源：`xiyou_event_compare` 全量 11/11（--update-baseline 那一轮；改前那轮 9/11，退步 6 例都是上表这些）、`xiyou_casino_batch` 261/261、`xiyou_floor_reach109` 过、`xiyou_determinism` 过。
- `casino_batch` 退出时有 3 条 SCRIPT ERROR（解释器在地图释放后还往下跑，`mv_interpreter.gd:218／245／69`），出在 TEST_RESULT 之后。并行测试因此判失败、重跑一次还是这样。**集成分支原版测试文件一样会出**（258/258 后同样 3 条），不是本单引起的，没查。
- `选测.py cc/newsrc-switch --list` 因为改了 `xdb.gd` 列了 387 个场景，没全跑：只有 1434 的读法变了，跑了引用 1434 的两个测试和 determinism。
- `事件空绿扫描.py --check`：空绿 96 例都在基线内，理由齐。
- `语法检查.py` 0 问题；`回退开关覆盖.py`：新开关算已覆盖。

## 待交叉核查

- `casino_batch.gd`（fix_abyss_stage2、开关）、`xdb.gd`（读入时调用）、`tests/xiyou_casino_batch.gd`（abyss2 三项）、`tests/event_compare_baseline.json`（note 与 9 例）、`tests/event_skipped_baseline.json`、`优化登记.md`（O-待定·深渊赌场二阶段）。

## 交接板

- 需要用户决定：O-待定·深渊赌场二阶段（默认跟新源，可回退），连同上一棒那两条 O-待定，编号等总装分。
- 下一步：② 等总装同步后的失败表，再认领事件／地图项。

## 可优化（流程／工具／效率）

- **hboot 读不到 data 下的 JSON**（工具车道）：`CodexGuide.releaseInfo()`、`readChangelog()` 都是同步 XHR，参照宿主返回空。修好以后 m4e71p0 能对上，标题版本号相关的参照也能量。
- **切片加地图 234～239**（A 车道独占文件）：m148e38p0 和一护剧情的事件对照都等着它。
- 测试槽满的时候，event_compare 要等很久（这次 import 加对照前后等了约 30 分钟）；本机直接跑只要 7～8 分钟。

## 续：切片加地图 234～239、casino_batch 退出报错（协调 11-06 14:10 派）

### 变更记录草稿

#### 【cc·八戒·未经审查】切片加新源地图 234～239（一护剧情），casino_batch 退出不再报错

- **切片**：`xiyou_slice.json` 的 maps 末尾加 234 凤凰殿、235 完现术、236 麒麟殿、237 卧豚殿、238 不知道什么殿、239 灵王宫（v0.54 一护剧情，冻结后盘点第 78、139 条）。其它字段没改：转换器顺着地图指令自动收进敌群 2010～2013（死神觉醒浅打、银城空吾、医疗温泉、友哈巴赫）和它们的敌人、技能、素材。新源转换：地图 206→212，敌群 801，内容覆盖检查 7141 页全部可运行、0 缺素材、0 无效引用。
- **事件对照**：六张新图共 59 页，用新源 `event_probe.cjs m234…m239` 量过，59/59 一致；m148e38p0（凤凰殿战斗背景）随之对上，从基线删掉。全量 15629 例，一致 15621，登记 8 例。
- **事件状态预设**：凤凰殿五页 `补预设批量.py --map 234` 加 a1（e22 变量 1557=100；e46 四把斩月＋answers [0] 选「合成」；e26／e45／e49 各给一把对应武器）。e22、e46 走到全部效果；e26／e45／e49 是「简单的刷孔」，先失去再获得同一把武器、件数不变，对照看不到孔位，写进 `事件空绿走不到.json`，空绿基线 96→99。
- **casino_batch 退出报错**：3 条 SCRIPT ERROR 跟 newsrc3 碰到的是同一个原因：新源大厅漩涡过场（Map4 EV76，自动执行）挂在 223 色调等待上，测试释放地图后它接着跑。现在测试开头设临时存档目录与配置，把 rift1 记成看过，结束时删掉。261/261，日志 0 条 SCRIPT ERROR。

### 给总装

- 合并后要在集成树重出产物（`xiyou_export.py --app …/v0.62.12/app.nw`），并补量新图：event_probe 六张图、event_state_probe 的 m234 五条 a1、ce9039／ce9026 两条，敌群 2010～2013 相关的战斗探针（slice_probe 等按敌群分片的）也要补。本树的 generated 是我手工补进参照的，**不能拿去当产物指纹**。

### 验证（续）

- 本机新源：event_compare 全量 11/11（15621/15629，--update-baseline）、`--only=m234…m239` 59/59、casino_batch 261/261（无 SCRIPT ERROR）、reward_branches、json_cache、floor_reach041 过。
- `事件空绿扫描.py --check`：99 例都在基线内、理由齐。内容覆盖检查 0 新增。
- 没跑：敌群 2010～2013 的战斗对照（参照要同步时量）。

### 待交叉核查（续）

- `xiyou_slice.json`、`event_presets.json`（m234 五条）、`事件空绿走不到.json`／`事件空绿基线.json`、`tests/event_compare_baseline.json`、`tests/xiyou_casino_batch.gd`（rift1 与临时目录）。

## DG：深渊／不朽商人（协调 11-06 14:14 派，Kyo 定修）

### 变更记录草稿

#### 【cc·八戒·未经审查】深渊／不朽商人做活（MERCHANT29_FIX，可回退）

- **根因**：新源 v0.62.12 有 33 条 355 的 parameters 存成了字符串：CE1439 末条 `if(window.CodexAbyssMerchant)CodexAbyssMerchant.complete(this);`，以及 32 张商人地图 NPC 第 2 页的 `CodexAbyssMerchant.openCurrent(this);`。YEP command355 只 eval 第一个字符，所以战利品点从没发过，商人也从没出现过（v0.62.13 正式 MOD 已修）。切片里有 30 张商人地图（159、216 不在切片）。
- **开关**：`MVEvent.MERCHANT29_FIX`，默认 true，`MVInterpreter` 的 355 改取转换器留下的 `mvStringParameters`，整段执行；false 回到 v0.62.12 原版，只执行第一个字符、商人页不成立。登「O-待定·深渊商人」。原来的 `MERCHANT29_PAGE_GATE` 保留（false＝只看页面条件），`merchant29_present()` 改成看 `XAbyssMerchant.has_merchant`。
- **运行时** `core/abyss_merchant.gd`（XAbyssMerchant，照 installAbyssMerchantRuntime v30）：
  - 每轮记录：进商人路线地图时开新一轮（`Game_Map.setup` 包装，挂在 `XMapScene._load_map`，换图才算），记 sequence、claimed、appeared、used、seed。本轮记录存 `XState.flags._merchantRun29`，点数账存 `flags._codexMerchants29`，都随存档。
  - 开战／结束：`battle_logic` 在洪荒那两处旁边，记本场地图、敌群合不合格、身份、本轮序号、胜负。
  - `complete`：领 10 点。出现条件是 Math.random < 0.5，或该身份已经连续两次没出现（保底 3）。提示原文，出现了就打开商人。
  - 身份：未知存在地图按来源地图分开，不朽通关用 `immortal:` 键，其余用 `abyss:` 键。
  - `draw`：线性同余种子（本轮种子＋已抽次数×104729），先等概率选基础装备，再选本档特效（同库优先）。装备本身照 DreamX 生成：模板词缀表换成「这条前缀 100%」，随机数全用种子，预掷池这次从空开始、用完还原（`XGear.roll_fn` 新加的临时替换）。扣点，次数＋1，错误照原版文字。
- **转换器**：`xiyou_export.py` 新加 `export_merchants`，把 `data/CodexMerchants.json` 原样导成 `db/CodexMerchants.json`（旧源没有这个文件就写空表）。
- **界面** `ui/merchant29_page.gd`（XMerchant29Page，`XMapScene.open_merchant29`）：首页、完整装备池、三档抽取三页的行、标题与能否选照原版。**期一用 XYunChoicesWindow 单列加标题行**，原版左边列表、右边装备详情的两栏布局和详情翻页还没做。专武·特效吸取（openAbsorb，技能菜单里的入口）原来就没移植，不在本单。
- **参照** `mv_oracle/merchant29_probe.cjs`（不进同步，手工复制为 `tests/fixtures/merchant29_oracle.json`，26 例）：在新源上把那几条参数改回数组（等于 v0.62.13 修法），用真实的 Game_Map.setup、BattleManager.setup／startBattle／endBattle，Math.random 按用例给定。
- **测试** `tests/xiyou_merchant29`：65/65。覆盖 complete（各种胜负、敌群、换图、领两次、再进图、保底四轮、未知存在三种身份）、draw（三档、三个分组、生成的基础装备、名字、八项属性、特效、孔数、扣点、次数上限、点数不足、没有商人、档位无效）、装备池、回退开关、界面行。

### 验证（DG）

- 本机新源：`xiyou_merchant29` 65/65；`xiyou_floor_abyss037`、`floor_reach107`、`dungeon`、`floor_abyss211`、`floor_abyss174`、`honghuang_reward`、`determinism`、`equipment` 全过（9 个场景，并行测试）；event_compare `--only` CE1439 加 30 张商人地图的商人页，31/31。
- `事件空绿扫描.py --check` 过；`语法检查.py` 0 问题；`回退开关覆盖.py`：MERCHANT29_FIX 有字面量回退测试。
- 没测：真地图里打完 Boss 进 CE1439、商人出现后点开界面的整条流程（界面只测了行和标题文字，没截图）。

### 待交叉核查（DG）

- `abyss_merchant.gd`、`merchant29_page.gd`、`mv_event.gd`（MERCHANT29_FIX）、`mv_interpreter.gd`（355）、`mv_script.gd`（两句）、`map_scene.gd`（on_map_setup、open_merchant29）、`battle_logic.gd`（两处钩子）、`gear.gd`（roll_fn）、`xiyou_export.py`（export_merchants）、`merchant29_probe.cjs`、`tests/xiyou_merchant29.gd`、`优化登记.md`。

### 给总装（DG）

- 合并后集成树要重跑转换器（多出 `db/CodexMerchants.json`），`xiyou_merchant29` 才读得到数据。
- 需要用户决定：O-待定·深渊商人。Kyo 已定修，只等编号；界面两栏布局要不要做成原版样子，可以下一期再定。

## 接续要点（40% 交接，给下一棒）

- 工作树 `.claude/worktrees/quizzical-neumann-d318e5`，分支 `cc/bajie-newsrc3`，generated 是新源（手补过参照，别当指纹）。探针要显式设 `XIYOU_APP=/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/v0.62.12/app.nw`，新开 shell 会丢。
- **商人界面期二**（协调 11-06 16:06 派）：照 `installAbyssMerchantRuntime.js` 的 Scene_Merchant29 做原版布局。
  - 窗口：上方 Window_Help(2) 标题；左边 Window_Merchant29，宽 boxWidth×0.43；右边 Window_MerchantDetail29 装备详情，用 RJO.HE.getDescParams 的行，字号与颜色按行给，可翻页；最下面 Window_Help(1) 翻页条「◀ 上一页     n／m     下一页 ▶」，字号 20，点左半往前、点右半往后，滚轮也翻页。
  - 左边列表的帮助：有装备就显示 setEquipment29，没有就显示 help 文字，默认「确认选择；取消返回上一级。」。pageup／pagedown 翻详情页。
  - 装备池那一页的 help 用 detail(d)：名字＋分组＋「基础属性：…」＋说明＋三档说明那句。
  - 现有 `ui/merchant29_page.gd` 的 home_rows／tier_rows／pool_rows／home_info 可以留着当数据层，换掉 XYunChoicesWindow 就行。重制里找已有的装备详情绘制（RJO.HE 对应的）复用：`rg -n "getDescParams|desc_params" modes`。
  - 测试 `tests/xiyou_merchant29` 的 ui.* 照旧要过；界面参照（ui_reference）可以考虑加截图对照。
- **DD②**：等总装发同步后的失败表，再认领事件／地图领域还挂的项（候选：casino_batch、empress_draw、save_events、transfer、floor_fortress029、skill_menu_events）。

## DG 期二：商人界面照原版两栏（协调 11-06 16:06 派）

### 变更记录草稿

#### 【cc·八戒·未经审查】深渊／不朽商人界面换成原版左列表＋右侧装备详情

- `ui/merchant29_page.gd` 照 Scene_Merchant29.create 换掉期一的 XYunChoicesWindow 单列：上方两行标题 (0,0,1280,100)；左列表 (0,100,550,620)，16 行可见；右详情 (550,100,730,556)；右下翻页条 (550,656,730,64)「◀ 上一页     n／m     下一页 ▶」（20 号）。
- 列表的说明（updateHelp）：装备池那一页显示该装备的 getDescParams 行（`XHelpCard.desc_params`，武器 1、防具 2；池里是原件，没有吸取，absorbView 不改），其余显示 help 文字（22 号白），默认「确认选择；取消返回上一级。」；抽取那一页的三行补上原版说明「消耗本路线战利品点N；装备本体和具体特效随机。」。
- 详情分页照 render29／turn29：行间再加 8，页数 1＋ceil(溢出÷(内容高−40))，换内容回第一页；PageUp／PageDown 翻详情（列表不翻页）、详情上滚轮、点翻页条左半／右半。装备池那一页确定＝翻到下一页（equipmentDetail29）；抽取出错时详情也显示错误文字。
- 详情字号沿用说明卡 O-007（`XHelpCard.MIN_FONT`，0＝原版）。没有加新的回退开关：这一步是把期一的简化版补成原版样子，不是优化，回退等于退回不像原版的版面。
- 行距按 XHelpCard.layout（每行 字号＋8，分隔加 3）再加 8，不是逐像素对过 RJO.SW.textHeight；没和原版截图逐像素比。

### 验证（期二）

- 本机新源：`xiyou_merchant29` 75/75（新加 ui2.* 10 项：四个窗口矩形、首页标题与默认说明、抽取页说明、点数不足时的错误显示且不扣次数、装备池详情行＝desc_params、长文字分页页数、翻页 origin、首末不越界、装备池确定翻页）；`语法检查.py` 0 问题；`事件空绿扫描.py --check` 过（99 例都在基线内）。
- 非 headless 截了首页与装备池两张图（本机临时脚本，没进仓库），两栏、标题、详情颜色与翻页条都正常。
- 没测：真地图里从 CE1439 到商人打开这一整条流程的点击操作。

### 待交叉核查（期二）

- `ui/merchant29_page.gd`、`tests/xiyou_merchant29.gd`（ui_layout）。

## 本分支提交

- 见 `git log cc/newsrc-switch..cc/bajie-newsrc3`
