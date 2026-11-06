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
- ~~**商人界面期二**~~ 已交（见「DG 期二」节，9f3bf894）。原派单要点留作核查参照：（协调 11-06 16:06 派）照 `installAbyssMerchantRuntime.js` 的 Scene_Merchant29 做原版布局。
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

## DI：保住 31 段 o 变体的原版文字对照（协调 11-06 16:16 派，审查 50 P3-1）

### 变更记录草稿

#### 【cc·八戒·未经审查】零效果判定加「文字轨迹相同」，加回 31 个走进别的对话的 o 变体

- **判定**：`事件空绿扫描.py` 新加 `zero_effect(v, base_trace)`：效果指令一条都没走到（`reached[0]==0` 且该页有效果指令），**并且** trace 与基础用例（`generated/oracle/events.json`）相同，才算「预设没生效」。`check_variants` 改用它。
- **剪枝同口径**：`事件祖先预设.py --prune` 新加 `--states event_states.json`：目标没执行到、但文字轨迹和基础用例不同的变体留下；不给 `--states` 时行为不变。
- **回退**：`事件空绿扫描.TEXT_TRACE_COUNTS = False` 回到旧判定（只看 reached）；剪枝加 `--old-zero-effect`。工具开关，不是游戏行为，没登 O 项。
- **加回的 31 条**（4c60db31 删的 82 条里 trace 与基础用例不同的；和审查给的一致）：插回 `event_presets.json` 原来的位置（9670 → 9701 例）。每条差在第一个选项框的 pick（走了另一个选项），后面跟出的对话不同：
  - 守层者「有什么需要的吗？」选第 2 项（索要礼物等）：m116e1p1、m117e1p1、m118e3p1、m119e13p1、m120e1p1、m144e1p1、m145e1p1、m147e1p1、m155e1p1、m182e1p1 的 #o2；m30e8p1、m32e1p1、m33e3p1、m45e1p1、m47e13p1、m64e1p1 的 #o4。
  - 心法选项公共事件：ce1088#o2、ce1089#o2／o2_2、ce1090#o2／o2_2、ce1092#o2。
  - 其他：m225e9p0#o2（福利助手）、m18e2p0#o2、m18e2p2#o2（知识贤者，少一句）、m4e56p0#o2／o2_2／o2_3（第 3 个选项框）、m220e10p0#o4（小毒，多两句）、m195e23p1#o4（传承强化说明，少一句）、m66e3p0#o4（符石师）。
- 新源 v0.62.12 上 31 条的基础用例都在，没有 goneIn；和现有预设不撞号。

### 验证（DI）

- 探针：`XIYOU_APP=…/v0.62.12/app.nw node event_state_probe.cjs <31 个>`（前缀多带出 6 个已有变体，和现有结果逐字相同），31 例都是 `reached[0]==0`、delta 空、trace 与基础用例不同；只把这 31 例按预设顺序补进本树 `generated/oracle/event_states.json`（9701 例）。
- `xiyou_event_compare --only=<31 个>`：37 例全一致（31＋前缀带出的 6），11/11。
- `事件空绿扫描.py --check` 过（空绿 99 例都在基线内，基线没动）；把 `TEXT_TRACE_COUNTS` 改成 False 时正好报这 31 条，旧判定可回。
- 剪枝：临时预设文件造 4 个变体（3 个文字不同、1 个文字相同）、目标都没执行到：新口径只剪掉文字相同的那个，`--old-zero-effect` 和不给 `--states` 都剪掉 4 个。
- `工具回归.py`：6 项过，`插件备注覆盖` 1 项挂（豁免键 codexaura 找不到）：本树 generated 是新源导出的，同分支同提交的 charming-chatterjee 工作树（旧 generated）跑同一测试是过的，跟本单无关，算 DD 的换源问题。没改 .gd，`语法检查.py` 沿用期二的 0 问题。

### 给总装（DI）

- 集成树下次同步会重量 event_states.json（9701 例），不用手补。

### 待交叉核查（DI）

- `事件空绿扫描.py`（zero_effect／TEXT_TRACE_COUNTS）、`事件祖先预设.py`（--states／--old-zero-effect）、`event_presets.json`（加回 31 条）。

## DJ：地图释放后事件解释器还在跑（协调 11-06 16:27 派，DD② 的 Godot 侧）

开工先合了 cc/newsrc-switch 21cd90eb（2c79f4e4）。

### 变更记录草稿

#### 【cc·八戒·未经审查】地图释放后挂起的事件不再往下跑

- **归类**：本机跑 empress_draw、skill_menu_events、casino_batch、save_events、transfer、party，断言全过，报错全是同一个根因：事件挂在 await 上（223／224／236 等帧、230 等待、205／213 等走完、文字），测试结束释放地图后它醒来接着调宿主：`host.get_tree()` on freed（mv_interpreter 218／245）、`host.show_message`（69）、`host.character`（272）；save_events 是宿主还在但不在树上，`host.get_tree()` 为 null（278）。casino_batch 上一棒在测试里绕开过，这次本机已不报。
- **修法**（`map/mv_interpreter.gd`）：新加 `host_alive()`（宿主没释放、没排队释放）。`_step` 开头和每次 await 回来都先看，宿主没了就返回 false，事件停下、照常发 finished；收尾的宝箱收获提示与 `XDungeon.event_finished` 只在宿主还在时做；`_notice`、`flush_message`、`_data_changed` 同样判。帧等待统一走 `_frames(n, physics)`：用 `Engine.get_main_loop()` 的 SceneTree 等帧（宿主暂时摘下树时照常等完，原来报 null），每帧前看宿主还在不在；205／213 的循环同样加判。
- **不改正常事件流**：只在宿主已释放时停；宿主在树上或暂时摘下（打开存档等界面）时行为不变。没加回退开关（修崩溃，不是改原版行为）。
- **全量 grep**：`host.get_tree()` 别处只有 `core/bulk_pills.gd` 一处，它在跑完一个公共事件后用 `host.is_inside_tree()`，地图已释放时会报错，改成先 `is_instance_valid(host)`。其余 `await get_tree().…_frame` 都是节点自己等自己（自己释放后协程不会再醒），不是同类。协调说的 151 处 set_input_as_handled／get_viewport 那类这次没碰。
- **测试** `tests/xiyou_interp_host_freed`（新，5 项）：223 等 30 帧时释放宿主 → 停下、发 finished、后一句不显示；230 等待时释放 → 第二句不显示；宿主摘下树但没释放 → 230 照常等完、第二句照常显示。用旧 mv_interpreter.gd 跑这个测试会报 `get_tree on previously freed` 而失败。

### 验证（DJ）

- 本机新源：上面 6 个＋`xiyou_interp_host_freed`、`screen_fx`、`opening_branches`、`bulk_pills`、`dungeon` 全过，日志 0 条 SCRIPT ERROR；`xiyou_event_compare` 全量 15660 例，一致 15652，8 例是原来登记的，regressions 空。
- `语法检查.py` 0 问题；`事件空绿扫描.py --check` 过。

### 待交叉核查（DJ）

- `map/mv_interpreter.gd`（host_alive／_frames／_step）、`core/bulk_pills.gd`、`tests/xiyou_interp_host_freed.*`。

## DM：楼层跑图一组（协调 11-06 16:53 派）

### 分类表（本机新源，XIYOU_APP=v0.62.12、XIYOU_SKIP_GENERATED_CHECK=1）

| 场景 | 修前 | 分类 | 处理 | 修后 |
| --- | --- | --- | --- | --- |
| xiyou_floor_run | 挂 2 项（f1_door_walk_step、floors_cleared） | C（测试） | 见下 ① | 273/273 |
| xiyou_floor_run_b | 挂 2 项（f13_door_walk_step、floors_cleared） | C（测试） | 同 ① | 332/332 |
| xiyou_floor_run_c | 挂 2 项（f21_door_walk_step、floors_cleared） | C（测试） | 同 ① | 560/560 |
| xiyou_floor_fortress029 | 71/71，退出时 2 resources still in use | C（测试） | 见下 ② | 71/71，无报错 |
| xiyou_floor_reach041 | 本机复跑已过 12/12 | A | 合并 DJ 后复跑即过，没再改 | 12/12 |

B 类（要新源参照才能判）：这组没有。

- ① 新源大厅首次进入多了漩涡过场（Map4 EV76，自动执行），接在开场 EV20 之后。前一个自动执行事件结束到下一个启动之间，地图有一帧 busy 是 false；测试 `_wait_idle` 只看一帧，就在过场开始前按方向键，过场一开走不动，判成 walk_step 失败、整段中断。`tests/xiyou_floor_run.gd` 的 `_wait_idle` 改成连续两帧空闲才算，过场照常放完再走。原有 walk_step 断言就是在旧代码上会挂的那条，没另加。
- ② 同一个过场：本测最后辛德瑞回大厅，过场接着开场，测试收尾退出时它还挂在 223 等待上，退出报 MVInterpreter 资源未释放。照 xiyou_screen_fx、casino_batch 的做法把 rift1 记成看过（本测不测过场，过场由 opening_branches、floor_run 覆盖）。退出资源检查是在旧代码上会挂的那条。
- 观察（没改游戏代码）：自动执行接自动执行之间那一帧，重制 busy 为 false（MV 同一帧里接上）。这次实测玩家按着方向键也没走出去（同帧 _process 先启动了下一个自动执行），没发现可见影响，记下不修。

### 验证（DM）

- 上表 5 个本机全过，日志 0 条 SCRIPT ERROR；只改了两个测试文件，没改游戏代码，event_compare 沿用 DJ 的全量结果（15660 例，regressions 空）。
- `语法检查.py` 0 问题；`事件空绿扫描.py --check` 过。

### 待交叉核查（DM）

- `tests/xiyou_floor_run.gd`（_wait_idle）、`tests/xiyou_floor_fortress029.gd`（rift1）。

## 接续要点二（接班八戒 40% 交接，11-06 18:10）

- 本棒交了 DG 期二（647abfa2）、DI（2bb94754）、DJ（a45f4383，之前合了 newsrc-switch 21cd90eb）、DM（0f753038），各节见上。
- 工作树仍是 quizzical-neumann-d318e5，generated 是新源（DI 手补了 31 例 event_states）。测试跑法：`XIYOU_APP=…/冻结正式源/v0.62.12/app.nw XIYOU_SKIP_GENERATED_CHECK=1 python3 并行测试.py ./godot ../01_Godot工程 --full <场景>`；zsh 里变量当多个参数要写 `${=VAR}`；mv_oracle 探针只写 `.sandbox/`。
- 已知与本棒无关：`测试插件备注覆盖.py` 在新源 generated 下挂（豁免键 codexaura），旧 generated 过。
- 还没做：DD②（等总装同步后的失败表）；深渊商人界面没在真地图上点过整条流程；专武·特效吸取（openAbsorb）、路线预览（openPreview）没移植。

## DR：地图事件覆盖（协调 11-06 17:30 派，集成分支线；失败表到了切 DD②）

- 分支改为 `cc/bajie-newsrc4`（从 cc/bajie-newsrc3 5a82db93 切出），工作树 `.claude/worktrees/busy-engelbart-02a39c`；generated（新源，含 DI 手补的 31 例 event_states）、`.godot`、node_modules 从 quizzical-neumann-d318e5 克隆，没跑同步。
- DD② 基线：上一棒候选 7 个（interp_host_freed、casino_batch、empress_draw、save_events、transfer、floor_fortress029、skill_menu_events）本机新源全过，0 条 SCRIPT ERROR。

### ① 新源现状数

- `xiyou_event_compare --coverage`（新源，15660 例，一致 15652，regressions 空）→ `事件写法覆盖.py --missed 121,122,123,125,127,129,201,301,311～317,355`（同审查 50 的口径）：**没执行到 11645 个实例、6912 簇**（v0.28 上是 14721）；门是简单条件、能直接写预设的 11090 个（6784 簇）；不能直接写的门 111 类 380、411 类 78 等。分 466 组（图／公共事件）。
- 前 20 大块（实例｜簇｜主要的门｜有候选预设的实例）：

| # | 图／公共事件 | 实例 | 簇 | 门（前三） | 候选 |
| --- | --- | --- | --- | --- | --- |
| 1 | m149 无尽矿洞 | 1262 | 1021 | 111 物品 840、111 变量 300、411 否则（变量 120 | 有候选预设 1262 |
| 2 | m217 黑作坊 | 1071 | 639 | 411 否则（开关 648、111 开关 423 | 有候选预设 1071 |
| 3 | m173 桂树小屋 | 620 | 490 | 111 变量 620 | 有候选预设 620 |
| 4 | m219 黑作坊 | 531 | 531 | 111 开关 315、411 否则（变量 216 | 有候选预设 531 |
| 5 | m218 黑作坊 | 483 | 483 | 111 开关 267、411 否则（变量 216 | 有候选预设 483 |
| 6 | ce1213 命运之手 | 435 | 10 | 111 变量 219、111 角色 216 | 有候选预设 219 |
| 7 | m187 水栽培 | 288 | 144 | 111 物品 172、402 选项 116 | 有候选预设 288 |
| 8 | m4 方桌大厅 | 247 | 200 | 111 开关 119、402 选项 101、111 变量 16 | 有候选预设 245 |
| 9 | m5 一层:方间林地 | 220 | 82 | 402 选项 148、111 变量 72 | 有候选预设 220 |
| 10 | m186 神魔战场 | 146 | 126 | 411 否则（变量 100、402 选项 45、111 变量 1 | 有候选预设 146 |
| 11 | m147 25层 上行天 | 138 | 115 | 111 变量 108、402 选项 24、111 物品 3 | 有候选预设 137 |
| 12 | m121 墓池 | 128 | 64 | 402 选项 112、111 变量 16 | 有候选预设 128 |
| 13 | ce859 中级熟练度 | 123 | 41 | 111 变量 123 | 有候选预设 123 |
| 14 | ce1098 1号打工位 | 107 | 20 | 411 否则（开关 97、111 开关 9、411 否则（角色 1 | 有候选预设 106 |
| 15 | ce1099 2号打工位 | 107 | 20 | 411 否则（开关 97、111 开关 9、411 否则（角色 1 | 有候选预设 106 |
| 16 | ce1100 3号打工位 | 107 | 20 | 411 否则（开关 97、111 开关 9、411 否则（角色 1 | 有候选预设 106 |
| 17 | ce1101 4号打工位 | 107 | 20 | 411 否则（开关 97、111 开关 9、411 否则（角色 1 | 有候选预设 106 |
| 18 | ce1102 5号打工位 | 107 | 20 | 411 否则（开关 97、111 开关 9、411 否则（角色 1 | 有候选预设 106 |
| 19 | ce1103 6号打工位 | 107 | 20 | 411 否则（开关 97、111 开关 9、411 否则（角色 1 | 有候选预设 106 |
| 20 | ce1104 7号打工位 | 107 | 20 | 411 否则（开关 97、111 开关 9、411 否则（角色 1 | 有候选预设 106 |

- 公共事件里 ce1098～ce1106 九个打工位同形（各 107），ce1213 命运之手 216 个挡在「角色 94 子类 5」门（开不了的门，同 events12 记的）。

### ② 公共事件空绿定性

- `事件空绿扫描.py --check`（新源）：空绿 99 例（公共事件 61、地图 38），**全部已有走不到理由**，没有未核的。逐个对照 v0.28／v0.62.12 原始数据复核理由是否仍成立：
  - 公共事件 61 个里 57 个内容没变；ce9028／9029／9034 是新源新增（理由 bajie-newsrc2 已写）；**ce1370 斩天拔剑术再释放新源改了写法**（取 `BattleManager._subject`、行动 push 进 `_actions` 末尾，不再 forceAction），原理由「同 ce1354，战斗中 forceAction」过时，已改写；仍只在战斗里有意义。
  - 地图 38 个：1 个没变，其余新增／改动的理由都是 bajie-newsrc1／newsrc2／newsrc4 在新源上写的（深渊／不朽商人第 2 页、刷孔），仍成立。
- 结论：公共事件空绿全部定性，没有能补变体的。

### ③ 地图事件变体（两轮）

- **w5**（全部簇里目标实例 ≥3 的，\`事件祖先预设.py --skip-bad\`）：出 527 个，新源参照探针单跑（约 10 分钟），全量对照：剪掉目标没走到的 144 个；m221e3p0#w5_3 参照没跑完（随机伙伴，要固定随机序列）删掉；四例不一致（ce9039#w5_67／68、m43e23p0#w5_98、m116e13p0#w5_290）都是参照摆预设时把超强者（142、148）进队挡掉、弹「超强者仅限地狱及以上难度获取。」——新源 installBossDifficultyRuntime 包了 addActor，和上一棒 ce9039#n2 同一回事，给这四个预设补 \`difficulty: 9\` 后一致。留 382 个。没执行到 11645→11428。
- **工具**：\`事件祖先预设.py\` 合成时预设里有超强者进队（角色备注 \`<KyoTier:超强者>\`／\`<CodexSuperStrong>\`）就自动带 \`difficulty: 9\`，以后不再出这类假不一致。
- **w6**（前 12 大块：m149、m217、m173、m219、m218、m187、m4、m5、m186、m147、m121、ce859；目标 ≥1，按「页形（数字归一）＋目标下标」去重，同形不同号的格子只出一个）：3936 簇去重到 862，出 735 个；剪掉 250 个；m4e60p1#w6_719（自定义单抽券不足）和基线里已登记的 m4e60p0#g3／p2#g3 同一原因（XCasinoBatch.open 只在地图场景开，事件对照宿主不是地图场景；xiyou_casino_batch 的 single.none／twenty.short 已有原版对照），重复，删掉。留 484 个。没执行到 11428→**10972**（6537 簇）。
- 合计：新增变体 866 个（w5 382＋w6 484），全部与原版一致；没执行到 11645→10972（−673）。event_compare 基线没改。
- 余下：大块多是同形格子（无尽矿洞每格一个变量、黑作坊三图同形），按页形去重后剩的独有形状不多；ce1213 命运之手 216 个挡在「角色 94 子类 5」；ce1098～1106 打工位九个同形。再出一轮收益递减。

### ③ 续：w7 随机门（协调 11-06 18:28 过渡单）

- 起点 10972。按前 20 大块（页形去重后 505 簇）再用祖先链合成，只出得了 13 个新变体：剩下的门大多紧跟在「122 随机赋值」后面（无尽矿洞 \`变量 488 = 随机 1～100\` 后判 ≥95／85…、桂树小屋 \`变量 214 = 随机 1～3\` 后判 ==1／3），直接设变量会被随机覆盖，往轮出过的都剪掉了。
- **工具**：\`事件祖先预设.py\` 的 trace_var 学会随机门——条件变量在门前被 122 随机赋值（操作「设」）、且页里门前只有这一条 122 随机时，改出 \`random_seq: [r]\`，r 取让 \`min + floor(r × (max−min+1))\` 正好等于目标值的中点；两道随机门合到一起时顺序认不准，当开不了的门。
- w7：全部簇按页形去重后挑合成结果带 random_seq、且预设没出过的，出 548 个；参照探针约 8 分钟。全量对照后删掉 7 个、剪掉 2 个，留 539 个：
  - 三例不一致（m142e3p1#w7_166、m169e1p3#w7_208、ce1422#w7_497，秘境抽奖被动书）：**对照工具口径不同，不是游戏不一致**——参照的 random_seq 只包 command122（脚本里的 Math.random 仍固定 0.5），重制的 \`MVEventCore.random_sequence\` 喂给全部随机（\`CodexMijing.pick\` 也吃序列），一用就抽到别的书。删掉，没进基线。
  - 四例新增跳过（ce631／ce978／ce325／ce976，滑稽弹再次／乱披风：战斗里 forceAction 追加释放）：只在战斗里有意义（同空绿理由「战斗中技能的追加释放公共事件」），删掉。
- 结果：没执行到 10972→**9909**（5992 簇）。event_compare 全量 17065 例，一致 17057，8 例原登记，regressions 空，11/11；空绿扫描 --check 过。基线没改。
- 可优化：random_seq 两边口径对齐（重制也只让 122 吃序列，或参照也包 Math.random），对齐后秘境抽奖这类带脚本随机的页也能出随机变体；改动在 \`tests/xiyou_event_compare\`／\`MVEventCore\` 与 \`event_state_probe.cjs\`，牵涉已有 907 个 random_seq 变体，要整轮重量，留给下一棒评估。

### 验证（DR）

- 本机新源：\`xiyou_event_compare\` 全量 16526 例，一致 16518，8 例是原登记的，regressions 空、oracleErrors 空，11/11。
- \`事件空绿扫描.py --check\` 过（99 例都在基线、都有理由）；\`语法检查.py\` 0 问题。
- 注意：generated/oracle/event_states.json 是本树手拼的（w5／w6 单跑后合进去）；集成树合本分支后同步会按预设重量这 866 个。

### 变更记录草稿（DR）

#### 【cc·八戒·未经审查】新源地图事件覆盖：没执行到 11645→9909，公共事件空绿全部定性

- 新源重数（同审查 50 口径）没执行到 11645 个实例（v0.28 时 14721），前 20 大块见交付单 DR①。
- 空绿 99 例在新源上逐个复核，理由都成立；ce1370 新源改了写法，理由改写。
- 三轮变体 w5／w6／w7 新增 1405 个（w7 是随机门 random_seq），全部与原版一致，没执行到降到 9909；\`事件祖先预设.py\` 合成时超强者进队自动带难度 9、学会随机门。

### 待交叉核查（DR）

- \`03_转换工具/event_presets.json\`（w5_／w6_／w7_ 变体）、\`03_转换工具/事件祖先预设.py\`（synth／super_ids／trace_var 随机门）、\`03_转换工具/事件空绿走不到.json\`（ce1370）。

### 可优化（DR）

- \`事件祖先预设.py\` 的 \`--tried\` 和 \`--min\` 共用一个门槛，往轮用别的门槛剪过的簇认不准；以后剪枝时把剪掉的 (页, 预设) 存一份，下轮用 \`--tried-presets\` 喂回去更稳。
- 大块里的同形格子（矿洞每格一个变量号）可以考虑在覆盖统计里按页形合并计数，数字更能反映「还有多少种没验证过的写法」。

## 接续要点三（DR 八戒交接，11-06 19:50）

- 本棒（工作树 \`busy-engelbart-02a39c\`，分支 \`cc/bajie-newsrc4\`）：DR ①②③ 与 w7，提交 3df5ce24、3a9586b7、7f8ca091（总装已记合并点）、78de61fd。没执行到 11645→9909。
- 本树 generated 是从 quizzical-neumann-d318e5 克隆的新源产物，\`generated/oracle/event_states.json\` 手拼了 w5～w7（备份在会话临时目录，不入库）；接手的人如果另开工作树，要么复制本树 generated，要么对 w5_～w7_ 变体重跑 \`XIYOU_APP=…/v0.62.12/app.nw node event_state_probe.cjs <变体号…>\` 再合进去。
- 一轮的做法：\`xiyou_event_compare -- --coverage=本轮.json\`（直接 godot --headless 跑 tscn，带 XIYOU_APP）→ \`事件写法覆盖.py --coverage 本轮.json --missed 121,122,123,125,127,129,201,301,311,312,313,314,315,316,317,355 --missed-json 簇.json\` → 按页形（数字归一）＋目标下标去重 → \`事件祖先预设.py --missed-json … --tag wN --skip-bad --min 1 --targets 目标.json\` → 参照探针只跑新变体 → 合进 event_states → 全量对照 → \`--prune --cur … --states …\`、删掉的同步从 event_states 去掉 → 再全量对照、重数。注意 \`--tried\` 会用当前 synth 重算往轮的簇，工具改了合成规则后别再喂往轮簇。
- 下一步候选：ce1213 命运之手 216 个挡在「角色 94 子类 5」；ce1098～1106 打工位九个同形（411 否则开关）；random_seq 两边口径对齐后补秘境抽奖类页面；多条 122 随机的页按执行顺序出序列。
- DD②（换源失败表）还没到，没开始。

### ③ 续：w8 全部簇页形去重（接续三棒，11-06）

- 起点 9909。往轮漏的两类：w5 只出了目标实例 ≥3 的簇，w6 只做前 12 大块，w7 只出带 random_seq 的；打工位这类一层套一层的「否则」链每轮只能往里挖一层。本轮对 missed3（5992 簇）全部按「页形＋目标下标」去重（2117 簇），合成后去掉往轮试过的（\`--tried\` 喂 w6 的 missed1_topu、w7 的 missed2_rand），出 1557 个。
- 参照探针四路并行约 10 分钟。注意 \`event_state_probe.cjs\` 的参数是前缀匹配（\`ce1098#w8_5\` 也匹配 w8_5x），分片会重复跑，合并时按 id 去重。
- 删掉 7 个：m221e3p0 五个参照没跑完（随机伙伴，同 w5_3）；ce1503#w8_834（移出结界，333 改全体敌人状态）、ce1619#w8_856（才艺展示，339 强制行动）是战斗里才有意义的，新增跳过，同 w7 删法。剪掉目标没走到的 411 个，**留 1139 个**。
- 结果：event_compare 全量 18204 例，一致 18196，8 例原登记，regressions 空，11/11；没执行到 9909→**8636**（5011 簇）。
- 空绿：ce1、ce1407、ce2460、ce2470、m220e10p0 五例补上变体后不再空绿，从 \`事件空绿走不到.json\` 删掉、基线重写（99→94）；\`--check\` 过；\`语法检查.py\` 0 问题。
- generated/oracle/event_states.json 仍是本树手拼（备份在会话临时目录）；集成树同步会按预设重量这 1139 个。
- 待交叉核查：\`event_presets.json\`（w8_ 变体）、\`事件空绿走不到.json\`／\`事件空绿基线.json\`（删 5 例）。

### ③ 续：w9 再挖一层（11-06）

- 同 w8 做法，对 missed4（5011 簇）页形去重 1357 簇，\`--tried\` 再加 missed3_allu，出 284 个；探针约 80 秒，全量无退化；剪掉没走到 22，**留 262 个**。
- 结果：event_compare 全量 18466 例，一致 18458，8 例原登记，regressions 空，11/11；没执行到 8636→**8289**（4776 簇）。
- 空绿：ce2471 补上，从走不到清单删掉、基线 94→93，\`--check\` 过。

### ③ 续：w10（11-06）

- 同法对 missed5（4776 簇，页形去重 1280）出 189 个，探针约 100 秒，全量无退化；剪 2，**留 187 个**。全量 18653 例，一致 18645，8 例原登记，regressions 空，11/11；没执行到 8289→**8046**（4624 簇）；空绿 93 例 \`--check\` 过。
- 递减：w8 −1273、w9 −347、w10 −243。剩下的大多是同形格子（页形去重后 1161 簇只合成出 189 个新的）。

### ③ 续：w11 同形格子不去重（11-06）

- 页形去重只验了每种形状一个格子；同形的其余格子（矿洞每格一个变量号、黑作坊三图、打工位九个等）数据号不同，本轮不去重全出：missed6（4624 簇）合成去掉往轮 \`--tried\`（missed1_topu、missed2_rand、missed3～5_allu）后 2454 个，探针六路约 8 分钟。
- 首轮全量：3 例不一致（m143e11p1#w11_356、ce1423#w11_651、ce1424#w11_653）都是秘境抽奖被动书带 random_seq，同 w7 记的对照工具口径不同（参照的序列只包 122、重制的也喂 CodexMijing.pick），删掉不进基线；ce977#w11_657（滑稽弹 355 给全队 _actions 插行动）战斗专用，新增跳过，删掉。剪掉没走到 150，**留 2300 个**。
- 结果：event_compare 全量 20953 例，一致 20945，8 例原登记，regressions 空，11/11；没执行到 8046→**5436**（2416 簇）；空绿 93 例 \`--check\` 过。

## 本分支提交

- 见 `git log cc/newsrc-switch..cc/bajie-newsrc3`；DR 在 `cc/bajie-newsrc4`（`git log 5a82db93..cc/bajie-newsrc4`）
