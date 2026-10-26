# 交付：codex/passive-content-book-capacity

- 车道／工作者：规则／沙僧（Codex，重制_沙僧_73）
- 状态：进行中
- 基线：34184d36；同树接续，权能五本上一期已独立交付，不重做。

## 本小期范围

- 容量满变量9返书／预约1317：先实采真实物品入口、未满／满额／重复／取消／缺书，以及普通容量与权能类别限额的关系，再设计接线。
- 已定位冻结源 rpg_οbjects.js 的 itemEffectLearnSkill：仅技能类型5受变量9约束，按队伍选定角色的 skills() 数量判断；满额 gainItem(this.item(),1) 与预约1317，否则学习。权能实际为类型4，另有先行类别守卫。公共事件1317仅提示。
- 开工工作区干净，HEAD34184d36；新分支名未占用，已从该点切出。额度五小时84%、周13%。共用登记只读；所有提交待Claude，不自销核、不自评完成度。
- 当前：基础5冒烟＋18例与898项已验；完整Scene_Item界面发现自动回背包续用层，已补运行时草稿。原版两页完整样本有效，重制UI首轮66/73，尚待修提示框行高／核帮助卡／最终回归；仍不可合并。长任务共用四槽，保留全部.sandbox／失败／generated／工作树。

## 交接板

- 下一步：完成在途窗口诊断与原版帮助卡补读，修正Toast后固定版本验收；容量交付后另期开PREE／ASUP。
- 用户试玩说明：类型5抽奖被动技能书容量满时返还本道具，执行容量提示后回原列表继续操作；主帮助卡显示结果，技能附卡保留。
- 需要用户决定：无。

## 进度账

- 由Claude合并与交叉核查时登记，不自评。

## 可优化

- 建议（工具车道）：共用槽的单槽任务缺少排队先后保证，本期两项定向取样已等超过半小时；可试FIFO或批任务让出一次再派下一场，保留四槽上限并可回退。另沿用Parse明确失败早退的建议，不在本车道修改工具。

## 冒烟与首轮矩阵

- 原版5例冒烟与17例首轮矩阵均errors空，源指纹一致；满额仍canUse=true，实际先扣再返1本、预约1317，回地图解释器清槽后提示；重复与取消／缺书无变化。直接learnSkill不受变量9约束，所以上限挂点不能放actor.learn_skill。
- 选定角色与效果目标不一致时，原版以选定角色计数并提示其名字，学习仍给效果目标；准备保留该语义。权能类型4与普通主动书不受变量9限制。
- 首轮17中power.class-full实际是已学权能的重复拒绝，不能称权能满额实采；保留原件book_capacity_initial17.json，修正命名并追加角色1四本后第五本的真实类别满额，后续以18例为准。
- 设计：独立XPassiveBooks接效果43，仅类型5在物品效果层检查正式选定角色的skills()，满额返当前物品并预约共享单槽1317；不改actor学习。UI记录本次选定角色、消费顺序与预约回地图，公共事件1317按原脚本翻译提示。不碰mv_event_core／formula_execution。

## 重制接线与当前验证

- 新XPassiveBooks仅在物品效果43处理类型5容量，使用选定角色的skills()计数；不限制直接actor.learn_skill。物品页消费顺序改为先扣再效果返还，_after_use检查现有共享预约槽；CE1317在MVScript按真实完整脚本翻译。不改mv_event_core或formula_execution，未改切片／generated。
- 18例修正参照唯一ID且errors空，新增真实角色1四本后第五本权能拒绝；fixture保留源runtimeInputs。Godot专项898/898通过（task7bf2744c22b94bb6936e940d0ef28010），导入taskb4988aa0643c41ebb050f111dba5b58b无Script／Parse／Compile错误。
- 首轮专项EventHost误用RefCounted而解释器要求Node，留下Parse Error，已保存godot原日志并只停本车道已知无效子进程32604；改成Node后专项通过，失败日志全保留。
- 当前仍进行中：直接依赖回归与界面成对图／实际读数尚未完成，不称可合并。item_target_actor_id为会话内物品选人上下文，每次物品使用重设，未增加存档迁移。

## 沙僧72：95%额度停手现场（2026-10-26）

- 五小时95%、周15%，按用户规则WIP保存并停；不自动新建会话／automation继续消耗。当前分支codex/passive-content-book-capacity，基线34184d36，全部提交待Claude；权能上一期交付不变。
- 已验：原版5冒烟＋修正18例；Godot容量898/898；导入无Script／Parse／Compile错误；原检查.sh文档块（JSON／链接／编号）通过、node语法通过、MV守卫16/16、UI服务守卫12/12、git diff --check通过。
- 收尾时已结束：boss72-capacity-deps.log，直接依赖7场（actor_p0、event_compare、passive_content、power_books、power_books_boundary、power_books_menu、item_use）。用等待任务.sh每次--timeout45查看终态，不重复启动、不绕共用四槽、不杀别人的进程。最终done exit0（taskb9827362d8e945628b1918ec63849d21），七场均首轮通过且逐日志无Script／Parse／Compile错误，无在途任务；状态及日志指纹在[结构化进展](../核查范围/技能书容量进展_20261026.json)。
- 下一步先实查额度，再读本节与交付单顶部、git status/log；全部文件命令显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b。只用原树，不写main／共用登记，不reset／cherry-pick／合main，不建或清worktree，不向别的已有会话发消息。
- 已核完依赖终态及每场Script错误，仍需真实物品满额→回地图提示的原版／Godot成对截图与实际布局读数。当前尚无本期成对图，不能借上一期权能图称本期验完；未标可合并。无切片变化，不扩同步或难度四段。后续PREE／ASUP等不混本期。
- 原版冻结宿主：rpg_οbjects.js 1954～1987，CE1317完整脚本已存在generated；18例fixture在tests/fixtures/book_capacity_oracle.json，原件全部留.sandbox。首轮17误把重复权能命名class-full，已另存book_capacity_initial17.json并修正后重采18，不能用首轮冒称满权能。actor2初始2771保留。
- 本期运行时5c5d3a70（XPassiveBooks＋battle效果＋xstate选人上下文＋item消费／回图＋MVScript的CE1317）；专项宿主修正3f085eee。直接actor.learn_skill不受普通容量限制；选定角色计数与效果目标的反例两条已实采且对照。
- 首次专项Parse Error已保存boss72-capacity-first-parse.log与失败长任务日志，已只停止本车道已知无效子进程32604；第二次898通过，不把首次算通过。所有.sandbox／失败日志／generated／整树保留；本轮成功临时输出暂保留，待后续最终精简验收后再清自己的成功输出。
- 可优化建议（工具车道）：并行测试遇到首屏脚本Parse Error会一直等600秒；本期通过临时HOME的godot.log确认后仅停已知子进程，未改共用工具。若能在明确Script加载失败时提早退出，可减少占槽；保留原日志并可回退。

- 收尾补记：七场断言依次actor3212、事件5、物品11、普通被动113142、权能核心6136／边界55682／菜单1068，全部等额通过；首轮无偶发。当前只剩本期成对界面证据及最终交付收尾，额度95%不再启动新任务。

## 72恢复（2026-10-26）

- 用户明确继续，实查五小时0%、周15%，HEAD61a2158a工作区干净，继续本期界面补证。已通过专项与依赖不重复整轮。
- 成对图采用相同地图5（无自动执行地图事件）、角色2、已有6301、物品1461三本、变量9=1。走真实物品选人入口与地图预约消费，不替换容量规则或1317执行；原版截图宿主临时恢复__ilr.newGame禁用的原生Game_Map.updateInterpreter，确保不是手工弹提示冒充。

- 原版界面首轮取到选人页后等回图提示超时，未验过；该页与来源指纹留原版_首轮未完成，失败日志留boss72-capacity-native-ui.log。新截图宿主增加超时现场诊断，尚未因此改游戏运行时。

### 完整物品页宿主新增发现

- 截图追踪明确：冻结installItemBagContinuationRuntime.js的Scene_Item.useItem包装在1317执行后立即返回Scene_Item并加“事件已执行：…（未检测到可确认的变化）”第二条提示。原5＋18例是Scene_ItemBase与效果层参照，不包含该Scene_Item包装；前述基础规则结论有效，但不能将其“回地图”当完整物品页终态。
- 四轮未完成截图都保留（其中第四轮trace记录Item→Map、1317原提示、Map→Item、续用结果提示），不是容量原版规则错误。修正截图终点并补本期容量的续用返回，不借此扩全部普通物品续用系统。冻结147本类型5书全部仅一个43效果，拒收后无其他效果。

- 续用接线草稿：只为本期真实满额返书设置会话内容量标记，地图消费1317后重新打开同分类、同物品的列表并显示原版续用消息；状态切换／地图变化／预约被覆盖即不恢复，不扩大所有公共事件道具续用。XMapScene仅菜单创建／预约结束挂点，原菜单调用保留默认参数。待原版最终完整样本后验收，不称完成。

- 原版完整物品页两页取样task5d37893c8c3b4722a8101caa7f4749f6已done exit0，来源前后指纹一致、页面errors与Chrome错误均空；真实trace已确认1317在Map执行、立即回Item，结果两条提示分别(460,30,260,62)、(460,102,260,83)，字号18、内边距10。对应fixture已落盘，重制成对专项待运行。

- 首轮完整重制UI专项66/73，发现现有XToast的长提示行高比原版高、第二条叠放位置偏移；另有测试取消步数写错（原版列表先回分类再回主菜单），已仅修测试为两次取消。容量898、物品11、事件5均通过，首败日志保留。续用核心只保留上下文与规则，恢复列表绘制移到XItemScene，避免规则核心依赖UI类型；接下来取窗口图与实际字行读数再定样式修正。

- 完整续用还会把主帮助卡换成结果消息，技能书的技能附卡保留。已按冻结Sprite_ItemHelp.setText实现主卡替换，沿用现有O-007（最小字号16）／O-008（贴行摆放），不把原版12号小字与旧摆位冒称逐项一致；实际正文、品质框与附卡保持关系会在成对图验。当前Godot诊断渲染和原版帮助卡补读都在等共用槽，不绕槽。

## 沙僧72→73（同树上下文接力，非额度停手）

- 用户已明确“继续”，五小时已重置；72末次实查五小时32%、周20%。到上下文接力线，72创建73后停止，73唯一后续执行者；先实查额度，五小时95%才WIP停手、周98%收尾。设计／疑难high，机械步骤只有真实接口才称切medium。
- 第一条及全部文件命令显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b。只用该树，当前codex/passive-content-book-capacity，HEAD以本节提交为准；不写main或共用交接板／变更记录／步骤／当前状态，不合main、不reset／cherry-pick、不建或清worktree、不建automation、不向唐僧或其他已有会话发消息。全部自己提交待Claude，不自销核／不自评进度。保留全部.sandbox／失败与不完整采样／generated／整树。
- 开工只读共用交接板顶部／自己车道行、git status/log、get_usage_limits，以及本单顶部和本完整节，不重读整段过程。上一期权能五本已可合并，最终34184d36之前，不重做。
- **重要修正**：原版5＋18例probe用Scene_ItemBase；规则层返书／1317／重复／取消／缺书／选人反例等均有效，Godot898/898和此前7场依赖通过。但完整Scene_Item额外包了installItemBagContinuationRuntime.js：Item→Map执行1317原提示→立即返回原物品列表→第二条“事件已执行：书名（未检测到可确认的变化）”。前述回地图不是完整终态，不能再说本期只缺截图。
- 已定位并补续用草稿：18e90c17核心上下文与map菜单挂点；622b9810将恢复列表绘制从XPassiveBooks移到XItemScene；9df4ceea补主帮助卡替换。XPassiveBooks仅真实类型5拒收设capacity_refund和capacity_bag_return会话meta；item_scene先消费再返、_after_use记原分类／物品；XMapScene.open_menu默认参数不变，CE消费后take_return验证当前state／地图／空预约槽，再延迟重开菜单与该物品列表。只做本期满额书，不扩全部公共事件道具的续用。actor.learn_skill不限制普通容量；formula_execution／mv_event_core没动。
- 基础原版18例和Godot898已全过，七场老依赖也全过（见前节和结构化进展）。完整UI首轮task347f17bda65946cab2b6b879d54687f2：容量898、物品11、事件5通过；UI66/73，首轮无Parse错误。失败：toast0盒高77 vs62、文字高57 vs42；toast1盒y104 vs102／高107 vs83，文字高87 vs63；另取消到主菜单测试少按一次，已修两次（列表→分类→主菜单）。失败日志全留，不能称全绿。
- **在途2项不重复启动**（均在等共用四槽，render已等约12分钟，native-ui6约10分钟，别绕槽／改上限／杀别人／动工具车道）：boss72-capacity-render.log（task387393f8563f426699354efe50dd6776，Godot窗口诊断截图，输出核查范围/技能书容量界面_20261026/Godot_首轮诊断）；boss72-capacity-native-ui6.log（原版补读主帮助卡，输出同目录/原版）。用等待任务.sh每次--timeout45，最多60秒；长批python3 -u＋XIYOU_TEST_HEARTBEAT=30＋长任务.py start。render排队期间又补了9df4ceea帮助卡，故仅诊断；之后必须在固定最终版本取干净验收。
- **有效原版完整样本**：task5d37893c8c3b4722a8101caa7f4749f6 done exit0，source_before==after、Chrome/page errors空。现在保存在“原版_有效无帮助读数”目录（已入Git），包括选人／最终回物品两页png+json、run和来源指纹。fixture tests/fixtures/book_capacity_ui_oracle.json仍是此有效版本。native-ui6只加help字段，成功后核对完整性／来源／errors，再用它更新fixture与最终原版目录。
- 原版最终两条Toast盒(460,30,260,62)、(460,102,260,83)，字号18、padding10，文字分别容量原提示与续用结果；原版消息span的内联包围宽约239，不等于Godot Label容器240，不强行比宽，但x/y／行高／盒高要比。首轮Godot的字高57／87很像字体本身27高＋默认line_spacing3，与CSS两行42／三行63不同；这是**待运行时读数证实的假说**，不能当结论。
- renderer已在tests/xiyou_book_capacity_ui.gd输出fontHeight／lineSpacing／lineCount／expectedTextSize。先看实际Godot_首轮诊断的json与图片，再改XToast行高；目前**尚未改toast.gd**。GameFont.current和原版CodexUserUI都用同一FZLanTYJW_ZhongCu.TTF，别擅换字体。可考虑局部FontVariation.spacing_top/bottom或LabelSettings按CSS21行高，但必须以真实引擎读数、两端图为据，不盲试；公共XToast要改时补notice_options等直接依赖。已有XWebPanel._fixed演示LabelSettings，但其line_spacing只影响行间，不能假设直接解决首行高。
- 新主帮助卡：原版Sprite_ItemHelp.setText做fakeItem.descParams单行消息，字号RJO.HE.ItemDescOtherSize（源码默认12），gray quality0，技能附卡保留；native-ui6会给实际help.rect／padding／rows／texts。Godot的XItemScene.restore_capacity_return已替换主卡rows、quality0并保留extras，复用XHelpCard.layout、沿用既有O-007最小16和O-008贴行，不冒称和原版12小字/旧摆位逐项一致。新UI测试需加原版help字段处理：actor_expected删help（通常null），result expected删help后另比正文rows，记录实际优化后矩形与字体并看图。不要为了新小期修改现有O项。
- 两页取图：review_book_capacity.py/.js/.cjs，只读服务沿用serve守卫；setup真实map5(10,10,2)、party[2]、6301、book1461×3、变量9=1；__ilr.newGame临时禁用的原生Game_Map.updateInterpreter已恢复，真实CE自动消费。P.trace仅包goto／$.toaster观察并调用原函数，不替换规则。最初4轮因错误等待Map最终停住而失败，目录原版_首轮未完成～第四轮未完成全部保留且不入Git，logs全留。第五轮正确终点通过，第六轮补help在途。
- Godot真实UI专项XMapScene→open_menu→物品分类／列表／操作／选人→返书1317→回该列表／双Toast→取消分类／主菜单；不是手工弹Toast。基础专项与完整UI专项各独立，渲染脚本render_book_capacity.py用临时HOME，不读玩家存档，按result_ok查真实退出码和Script错误，不用--script --check-only缺autoload预检。
- 收尾：修Toast／补help比对后，固定版本跑UI＋容量＋物品＋event_compare（必跑）与直接依赖；map open_menu有改可选flow专项看实际风险，不扩全量或切片同步。窗口render取图，逐页看两端图及读数；无切片变化不加难度1四段。原检查.sh文档块、node语法、MV守卫16/16与UI守卫12/12、git diff --check；本轮最新node／两守卫／diff已通过。成功临时输出等最终精简证据后再仅清自己的成功日志，失败／.sandbox／generated／整树保留。
- 结构化进展“技能书容量进展_20261026.json”仍是WIP，会记录原版5／18和898及老7场，不得用它冒称新续用9df4ceea已最终验收。最终整理本单顶部与变更记录草稿／交接板／可优化节后才写可合并，全部待Claude。可优化已记排队公平性与Parse失败早停，工具车道不在本期动。
- 后续顺序：容量小期完整交付→PREE／ASUP→WPNM／SkEType与race-battle等八戒接口→全部做完且额度足才核别人；旧确定性8个early_inventory_rule失败不夹带修复、不称整轮全绿。两块TP／敌人永久账本仍留后续。

## 沙僧73接手（2026-10-26）

- 同树接续d70e31ce，五小时34%、周20%；仅四个原版未完成采样目录未跟踪，均保留。两项在途任务仍公平排队，不重复启动。继续核实际字体读数、帮助卡和最终界面回归；全部提交待Claude。

- 接线补漏：原先只在事件结束后检查空预约槽，无法区分已被覆盖并执行的其他事件。现把本次执行前预约ID传给take_return，仅1317可恢复；补五组一次性上下文守卫（正常／覆盖／仍有预约／换图／换局）。待专项实际通过，不提前记通过。

- UI验收脚本已补主帮助卡实际矩形／字号／正文与附卡读数：正文逐项对原版，附卡对使用前内容，沿用16号最小字号；尚等native-ui6的真实help字段才能验收。

- 原版补读仍未占到槽，已在其来源前后指纹中补入本次直接核对的HelpExtend、AXY_Toast与同一字体原件；不修改冻结源。

## 变更记录草稿（验收中，不可合并）

## 2026-10-26 【Codex·沙僧·未经Claude检验】类型5技能书容量与满额续用（dev.待定）

- 普通类型5书按原版菜单选定角色的已学技能数检查变量9；消费后满额返还本道具并预约1317。直接学习、权能类别与重复拒绝沿原有路径；不改actor学习入口。
- 完整物品页按冻结续用层执行1317后回原分类／原物品列表，显示容量与续用两条提示，以结果正文替换主帮助卡并保留技能附卡。主卡沿用O-007／O-008字号和位置优化，未将优化后版面当作原版逐项一致。
- 已有验证：原版5冒烟与18例、基础Godot898／旧7场依赖；文档块、node语法与MV16／UI12守卫通过。上述旧运行结果不覆盖最新续用接线；最终容量、完整UI、相关依赖与两端逐页图仍待本轮固定版本验收，详情见本单接手记录。
- 本期无切片变化，无同步／全量记录；不混修旧8个early_inventory_rule确定性失败。所有提交仍待Claude，进度由总装与核查者登记。

## 沙僧73→74（同树上下文接力，非额度停手）

- 用户既定自动上下文接力继续，73创建74后停止，74唯一后续执行者。末次实查五小时52%、周23%，不是95%额度停手；先实查，五小时95%才WIP停、周98%收尾。
- 第一条及全部文件命令显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b。只用该树，分支codex/passive-content-book-capacity；本节提交为最新HEAD。开工只读共用交接板顶部／自己车道行、status／log、额度、本单顶部与本完整节；不要重读全部过程。禁改main／共用交接板／变更记录／当前状态／开发编号，不合main、不reset／cherry-pick、不建或清worktree、不建automation、不向其他已有会话发消息。保留全部.sandbox／失败与不完整目录／generated／整树；所有自己提交待Claude，不自销核、不自评完成度。
- 本期仍验收中；上一期权能五本已独立可合并，不重做。基础原版5＋18、Godot898和旧七场依赖有效，但不能拿它们给最新续用接线冒称最终验收。当前结构化进展JSON仍WIP。
- **两个在途任务完全没重启**：73末尾仍在等共用四槽，render已等约49分钟、native-ui6约47分钟。都是正常心跳，不绕槽、不加上限、不杀别人、不改工具。boss72-capacity-render.log，task387393f8563f426699354efe50dd6776，输出核查范围/技能书容量界面_20261026/Godot_首轮诊断；boss72-capacity-native-ui6.log（task2905c0dcf7494269a6d2cacceaa4c518），输出同目录/原版。日志都在03_再刷重制_Godot/04_验证/本地结果。用等待任务.sh每次--timeout45，最多60秒。render排队期间测试／运行时有补丁，只作诊断，必须在最终固定版本后干净验收。
- 原版native-ui6已从.log.status.json实查runId=2905c0dcf7494269a6d2cacceaa4c518，status=running、exitCode=null；render同为running。它的已启动命令是占槽.py --label capacity-native-ui6 -- node 03_再刷重制_Godot/03_转换工具/ui_reference/review_book_capacity.cjs 00_项目管理/核查范围/技能书容量界面_20261026/原版 --port=8778。当前两个队列任务进程是71294/71295与71590/71591（不要因此杀它们）。
- 运行时仍为72的18e90c17／622b9810／9df4ceea：完整Scene_Item满额后Item→Map执行1317→立即回原物品列表，双Toast＋结果主帮助卡，技能附卡保留。不是基础Scene_ItemBase的回Map终态。XPassiveBooks仅本期类型5拒收的会话meta；XMapScene.open_menu默认空参数保留原调用，不扩全部事件道具；formula_execution／mv_event_core未动。
- **73新增运行时6b45e436**：旧take_return仅看事件结束后空槽，无法拦住已被其他预约覆盖并执行的情形。现XMapScene在run_reserved_common_event之前取预约ID，传take_return(s,consumed_event)，只1317可恢复。基础tests/xiyou_book_capacity.gd补五组正常／覆盖／待执行／换图／换局的一次性上下文守卫，共20条，尚未跑引擎，不能算通过；预计旧898＋20但以真实结果为准。
- **73新增UI测试1eea509b／276fde57**：help_read读取卡实际rect／padding／rows／quality／fontSizes／visible／extras。actor_expected删help，result_expected删help后单比原版结果正文；断言主卡可见quality0、所有实际字至少16、技能附卡内容等于使用前。注意附卡基线必须在列表_refresh之后、进选人前取，actor模式会隐藏并清附卡；已修为此顺序。Toast额外输出fontAscent／fontDescent，原有fontHeight／lineSpacing／lineCount／expectedTextSize仍在。当前旧fixture没有help，诊断会因此多一项预期失败；等native-ui6成功后更新fixture再验。
- **73新增来源指纹5e535fe1**：review_book_capacity.py INPUTS增加HelpExtend.js／AXY_Toast.js／fonts/FZLanTYJW_ZhongCu.TTF；任务仍排队时改的，成功后source_before==after应含33项。未改冻结源。有效旧原版目录“原版_有效无帮助读数”30项指纹已复核当前完全相同；两端字体原件SHA相等db0fe73bff1d05a1ddb4eac5bd31b9fc971a30285cb9c14b81464ab697195f79。
- **仍未改toast.gd**。首轮完整UI66/73：两条Toast字高57/87 vs42/63，盒高77/107 vs62/83；第二条y104 vs102；取消少一步已改两次（列表→分类→主菜单）。先看诊断真实json和两张图：fontHeight／ascent／descent／lineSpacing／lineCount，再决定字体行高度量。相同字体不许换。可局部FontVariation.spacing_top/bottom＋line_spacing0试出CSS21行高，但必须引擎实测；仅改line_spacing可能无法修首行高，别当结论。Godot官方FontVariation／LabelSettings文档已查：spacing_top/bottom可调整额外像素，LabelSettings.line_spacing可负且仅加行间；本地XWebPanel._fixed可参考。改公共Toast后补notice_options等直接依赖。
- 原版有效旧两页已入Git，73已逐页看：选人只有actor卡，结果页确实回列表、双提示、结果主帮助卡／保留技能附卡。原版最终Toast盒(460,30,260,62)与(460,102,260,83)，字号18／padding10；span内联宽约239不等于Godot Label240，不强比容器宽，但x/y／高度要比。帮助卡原生12字，Godot沿既有O-007最小16／O-008贴行，不冒称逐项一致。native-ui6成功后核来源／errors／run两页完整性，更新tests/fixtures/book_capacity_ui_oracle.json的pages和sourceFingerprints；sourceIdentity沿原fixture保留。
- 修Toast并补原版help后，固定版本跑容量UI／容量规则／物品／event_compare与直接依赖（notice_options，map open_menu可加flow；帮助卡也可加help_card）。用长任务.py start，python3 -u＋XIYOU_TEST_HEARTBEAT=30；不绕共用槽。独立窗口render_book_capacity.py取两页最终Godot图，两端逐页看；诊断失败图不作最终成功证据。无切片变化，不跑同步／难度1四段／全量。
- 73机械项：MV守卫16/16、UI服务守卫12/12、review_book_capacity.js/.cjs的node语法、diff检查通过。原检查.sh文档Python块已提取原文执行通过（dev.173），日志boss73-capacity-docs.log；后来只补本单草稿及来源指纹，收尾再核最新JSON／链接。全量待核表123批并未自销，按用户顺序全部小期后才核别人。
- 99300117整理顶部交接板下一步／试玩说明、可优化与变更记录草稿，仍标验收中不可合并；最终用真实证据更新这些段和结构化进展后才能标可合并。只写本单，不写共用登记。可优化建议：单槽公平性（短任务已排近一小时）与明确Parse加载失败早退，工具车道不在本期动。
- 所有代码／文档已提交；仅原版_首轮未完成、第二轮未完成、第三轮未完成、第四轮未完成四目录未跟踪，全保留。不清成功日志直到最终精简证据入Git后，失败／.sandbox／generated／整树永不清。73没新增引擎测试结果，不要误算通过。
- 后续仍按容量完整交付→PREE／ASUP→WPNM／SkEType与race-battle等接口→全部完成且额度足才核别人；旧8个early_inventory_rule确定性失败不夹带修复。只读预研PREE：dsPassiveSkill.js2240附近PREE按出战成员逐技能加百分点、ASUP逐项乘剩余率后clamp；原版敏捷基率0.05/0.03，先制队伍能力×4、防偷袭能力先设0。真实开战要再采样，不能据静态读数实现；Olivia OTB有混淆不能凭grep无结果推断无效。此预研未实现、未取新参照，不当下期完成。两块TP／敌人永久账本留后续。
