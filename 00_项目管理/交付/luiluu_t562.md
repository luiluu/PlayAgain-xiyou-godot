# 交付：luiluu/t562

- 车道／工作者：T562 天启篇原名二创角色改名（D294）／小o（co，gpt-6.2-sol＋high）起手做完主体，小o 5 小时额度用完后 cc（Opus＋medium）接手核查、补漏、跑测试、交付
- 状态：可合并

## 变更记录草稿

## 2026-11-27 【co＋cc·T562·未经审查】天启篇 57 名原名二创角色改用新名（D294，dev.待定）

- 依据：D294（Kyo 11-27 事项 85）；名单取私密设计仓 `协作交接/核查报告/T560_原名二创角色改名名单.md` 第二节主推列 55 人，加第三节 127 小铃兰→我们的光、85 爱莉→粉红妖精。
- 一处名字表：`modes/xiyou/tianqi_data/actor_names.json`。`names` 是角色号→新名（57 条），其余位置一律写 `{角色号}` 引用；Kyo 以后要改哪个名字，只改 `names` 里那一行，全部界面跟着变。
  - `tables`：按「表名／记录号／字段[／备注行号]」或地图事件下标精确定位，每处给 [原文字, 新文字] 对，34 张表与地图共约 1240 处（角色名、称号、职业、专属技能／羁绊／觉醒／进阶名与描述、号角、进阶石、专武备注、换装卡、召唤公共事件 320 改名、地图对话）。不做全局字符串替换：黄泉寒气、不渡黄泉、土遁黄泉沼、火影里的孙悟空（四尾）、单字陈／橙都保留原样。
  - `advance`：进阶插件 `Star_ActorAdvanced` 的进阶名；`wardrobe`：典藏衣橱里的角色条目 -72／-74／-75／-99。
  - `saved_names`：旧天启档里由事件 320 存进 `looks.name` 的原名，显示时换成新名（存档里的值不动；玩家自己改的名字不动）。
- 只在天启篇生效：`XTextFix.patch_actor_names`／`actor_name`／`tianqi_actor_text` 都先判 `tq_on()`；西游档读到的表、地图、衣橱、进阶名与原文件逐字相同（`xiyou_text_fix` 的 d294_legacy_* 断言）。换档时 `System`、`Plugins` 也跟着清缓存重读。
- 十几个 gd 的写死文字改为取名：`gojo.gd`（角色名、解锁提示、眼罩、觉醒／领域状态、进阶名）、`tianqi_gojo_trial.gd`（试炼对白、敌人影子名走 `gojo_trials.json` 的 `foe`）、`sukuna.gd`、`toji.gd`、`garou.gd`、`liuying.gd`、`yomi_jingliu.gd`、`dungeon.gd`、`mv_script.gd`、`rift.gd`／`rift3_anim.gd`（徐凤年过场）、`imported_balance.gd`、`item_marks.gd`、`tianqi_hall_text.gd`（向导文本用 `{角色号}`）、`character_help.gd`（奈叶并肩说明）、`skin_skill_page.gd`（「伊莉雅被动」技能类型角标照旧显示「专」）、状态页／人物页称号走 `display_nickname()`。
- `actor_notes.json`（T556 人物图鉴备注）57 人的 `name` 改新名，故事／特点里的角色原名一并改写。
- 顺带 T556 复核 P3：`天启篇数据校验.py` 把「收藏、模板、编入、暂未」从通用禁词挪出：特点行照旧逐词禁，故事行只禁「暂未(被)编入天启篇」「角色／人物／战斗模板」这类出戏说法；单测改成逐词独立反例（`test_trait_meta_each_word`、`test_story_word_in_context`）。91 特点行「自带开局替身免死与再动机制」改成「开局可用替身保命并再次行动」。新增 `actor_names` 表格式校验（57 条、引用的角色号必须存在）。
- cc 接手补的两处（ef54a9426）＋四个测试基线（a9924d9bf，见「测试」）：① 专武 2003「腾云斡旋势」的特效行改成「刀神武士复活术」后，`<KyoUnique: 龙马复活术>` 标签没跟着改，天启篇「◆唯一」标记会对不上，补改备注第 29 行；② 公共事件 1710／1711 战斗提示「琴里切换炮／斧形态」改为新名。两处都加了天启／西游两档断言。
- 合并 main（fa8fa07ab）：T528 改了 skill_rework.json 里 127、159 的数值，和本单改名在同几行冲突，取 main 的数值＋本单的新名。T528 还新写了贝吉特 10563～10566 四个形态技能的天启篇卡面（名字「超级贝吉特…」、描述「贝吉特会倒下」），一并改成新名；同时发现小o 的表对这四个技能按「贝吉特」→新名替换，会拼出「超级超级逼王」，改成整段「超级贝吉特」→{164}（5f40d630c 加了断言）。
- 防回流：`天启篇数据校验.py` 的 actor_names 检查加 `actor_names_leftover_rules`——skill_rework.json 玩家可见字段（跳过 `_` 注释键和 `note_*` 正则）再出现已改名角色的原名就报错，「黄泉路见」等同形字列白名单；单测 `test_skill_rework_leftover_old_names`。
- 不改：非角色皮肤名（典藏衣橱纳西妲、芙宁娜等，换装卡 6808 一拳超人／6812 佩恩／6816 白胡子）、12 人待确认名单里除 127、85 以外的 10 人、已隐藏的 161 胡桃／166 利姆露、已化名角色称号里的原作名，都留给另单。
- 玩家可见：天启篇里 57 名角色换成新名（如 五条悟→5t5、宿傩→大爷、伏黑甚尔→爹咪、小铃兰→我们的光、爱莉→粉红妖精），连带称号、职业、专属技能、号角、进阶石、专武说明、换装卡与对话；西游档不变。

## 交接板

- 下一步：Kyo 说「个别我另说」，要改哪个名字先改 `actor_names.json` 的 `names` 一行，数据库、地图、进阶、衣橱、gd 文案全跟着变；但 `skill_rework.json`（天启篇技能卡面，新名出现约 150 次）和 `actor_notes.json`（图鉴备注）是小o 直接写的新名字面量，改名时要同步改这两张表（数据校验的回流检查只认原名，不认「旧的新名」）；122／123 共用的「黑白狂人」前缀在 6 处替换里也是字面量。建议另开一单让 XTianqiSkills 读卡面时也套 `{角色号}`，做到真正一处改。
- 用户试玩说明：天启篇开档看图鉴、编队、状态页、技能页、号角与换装卡，原名二创角色都显示新名；西游档照旧。
- 需要用户决定：见回执「要 Kyo 定」——91 一打七的图鉴故事里还写着「宇智波一族」（姓氏，不是角色名；T556 Kyo 定稿原文，没动）。

## 进度账

- 天启篇·文字与命名：D294 落地，无百分比变化。

## 可优化（流程／工具／效率）

- 已做：cc 接手时用临时 Godot 探针把天启档全部表、地图、进阶行、衣橱读一遍搜原名（探针没入仓），补出上面两处漏改。建议：以后同类「文字定向替换」单，把这种全量扫描做成正式专项（预计少一轮核查返工，归文字车道）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTextFix.patch_table`／`patch_map`（去掉 `any_on()` 早退，加 `patch_actor_names`） | 5 处（`git grep -nE 'XTextFix\.patch_(table\|map)\(' -- '*.gd'`，另 `load_table` 内部 1 处） | 调用方 5 处逐处结论：xdb.gd:255 读图、text_fix_dump、xiyou_text_fix、xiyou_tianqi_guardian_gift 四处；开关全关时 OVERRIDES 为假跳过覆盖，`patch_actor_names` 在西游档 `tq_on()` 为假直接返回，随后照旧因五个开关全假返回，西游档结果与原来相同；天启档开关全关时仍改名（名字是内容，不是文字修正），符合 D294。 |
| `XTextFix.clear_cache`（多清 System、Plugins） | 换档 `sync_mode`、`set_all` 等 | 只让这两张表下次重读，`XGojo.patch_plugins`、`patch_actor_advance` 会重新套，结果同口径。 |
| `XActor.data()`（`looks.name` 过 `saved_actor_name`） | 全部 `display_name()` 读法 | 只在天启档、且 `looks.name` 正好是登记过的旧名时换；自订名字、西游档原样（d294_old_save_name_view、d294_custom_name）。 |
| `XDB.table`（System 套改名、Plugins 套进阶名） | 全部读表处 | 西游档两个函数都直接返回。 |
| `CACHE_VER` 4→5，签名加 `actor_names.json` | 文字修正磁盘缓存 | 改名表一变旧缓存就作废。 |

## 测试

- 本机：`xiyou_text_fix` 77/77、`xiyou_tianqi_skills` 248/248、`xiyou_tianqi_t528` 19/19（合并 main 后重跑）；`xiyou_garou_progress` 180/180、`xiyou_liuying` 144/144、`xiyou_tianqi_pool_text` 28/28、`xiyou_victory_text_flow` 4/4（修测试基线后重跑）；`天启篇数据校验.py` 全部通过；`测试天启篇数据校验.py` 166 个单测 OK；`发行空壳.py check` 退出码 0。
- 云端选测第一轮（ef54a9426，基准 ca8e1fa545）：733 个场景，729 过、4 个失败、1 个偶发（xiyou_tianqi_enemy_ai_scene 单跑通过算过）。https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45927470580
  - 失败 4 个都是测试基线没跟上小o 的取名改动，不是游戏逻辑问题：`xiyou_garou_progress`、`xiyou_victory_text_flow` 拿带 `%s` 的 `XGarou.CATALYST_TEXT` 直接比；`xiyou_liuying` 拿已去掉首行的 `XLiuying.RECRUIT_TEXT` 比；`xiyou_tianqi_pool_text` 的天启篇备注期望值没套 152 专武行改名。cc 改了这 4 个测试（a9924d9bf）。
- 云端选测第二轮（a9924d9bf，基准 ef54a9426，只选改过的 4 个测试）：4/4 通过。https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45929949542
- 云端选测第三轮（5f40d630c，合并 main 后，基准 f7bd82c19）：88 个场景，87 过、1 失败、1 偶发（xiyou_tianqi_followup_kill 单跑通过算过）。https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45930813606
  - 失败的 `xiyou_tianqi_t528` 写死「战斗结束时，贝吉特会倒下」，T528 卡面现在是天启篇新名；改成按 `XTextFix.actor_name(164, …)` 断言（aa495569b），本机 19/19。
- 云端选测第四轮（aa495569b，基准 5f40d630c）：1/1 通过。https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45932118261
- 截图：没截（本单验收不要求；名字由 xiyou_text_fix 两档断言覆盖）。

## 本分支提交

- 341529a0d T562 天启篇 57 人按角色与记录位置启用新名（小o）
- ef54a9426 T562 补漏：专武唯一标签跟特效行同改、琴里切换形态提示改新名（cc）
- a9924d9bf T562 测试基线跟上取名改动：饿狼触媒、流萤入队、天启篇专武备注（cc）
- f7bd82c19 T562 交付单：可合并（cc）
- fa8fa07ab 合并 main 进 luiluu/t562：skill_rework 冲突取 main 数值＋天启篇新名；补贝吉特 10563～10566 新名、原名回流校验（cc）
- 5f40d630c T562 断言贝吉特四个形态技能取新名、不叠「超级」（cc）
- aa495569b T562 T528 专项的贝吉特代价描述按天启篇新名断言（cc）
