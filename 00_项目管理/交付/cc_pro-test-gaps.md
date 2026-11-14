# 交付：cc/pro-test-gaps

- 车道／工作者：补 core 类测试缺口／cc（Pro，云端线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【cc·Pro·未经审查】补 5 个 core 类的专项测试（dev.待定）

- 盘点 `modes/xiyou/core/*.gd` 每个 class_name 在 `tests/*.gd` 里被几个文件引用，≤1 的 36 个；逐个看了引用它的测试，多数已有自己的专项或由原版参照间接测到（表见下）。按「存档／物品发放先、分支多的次之、纯显示最后」挑 5 个补专项，只加测试、不改游戏代码：
  - `xiyou_save_transfer`（XSaveTransfer，存档导出导入）：37 项＋1 项 skip；
  - `xiyou_treasure_map`（XTreasureMap，藏宝图挖宝发奖与扣图）：24 项；
  - `xiyou_runewords`（XRunewords，符文之语挂起与结算）：23 项；
  - `xiyou_skill_share`（XSkillShare，技能共享装备学与光环共享）：28 项；
  - `xiyou_lead_actor`（XLeadActor，领袖技能学与忘）：20 项＋1 项 skip。
- 测试场景按 `tests/*.tscn` 自动发现，不用另外登记；`选测对照.json` 的 refs 按 class_name 会把它们选进改了对应类的选测。
- 玩家可见：无。

## 盘点表

引用数＝`tests/*.gd` 里出现该 class_name 的文件数（不含本分支新加的）。「已覆盖」指引用它的那个测试是它自己的专项、或用原版参照把它的主流程整体测过。

| 类 | 文件 | 行数 | 引用数 | 引用它的测试 | 选没选 | 原因 |
| --- | --- | --- | --- | --- | --- | --- |
| XRiftAlien | rift_alien.gd | 566 | 1 | xiyou_rift_alien | 否 | 自己的专项，72 项 |
| XXuanTusuArt | xuan_tusu_art.gd | 357 | 1 | xiyou_xuan_tusu_art | 否 | 美术显示类，有专项 |
| XTianqiQiyinArt | tianqi_qiyin_art.gd | 252 | 1 | xiyou_tianqi_qiyin_art | 否 | 美术显示类，有专项 |
| XBulkPills | bulk_pills.gd | 233 | 1 | xiyou_bulk_pills | 否 | 自己的专项＋参照，46 项 |
| XAlienHide | alien_hide.gd | 225 | 1 | xiyou_alien_hide | 否 | 自己的专项，52 项 |
| XTianqiAlienAffix | tianqi_alien_affix.gd | 208 | 1 | xiyou_tianqi_alien_affix | 否 | 自己的专项；词缀线（tianqi_affix_roll）在改 |
| XSaveCheck | save_check.gd | 199 | 0 | （xiyou_save_corrupt 经 XSave.valid_data） | 否 | 间接测到，49 类坏档逐类拒 |
| XTreasureMap | treasure_map.gd | 191 | 1 | xiyou_treasure_batch（xiyou_common_scripts 经事件间接） | **是** | 扣图／发奖，玩家丢东西；参照只跑了事件整流程，候选为空还图、预掷池边界、整段重来、v0.29 按首尾找没单测 |
| XSkillShare | skill_share.gd | 188 | 1 | xiyou_party_skills | **是** | 学／忘技能，分支多；参照测整体，equip_changed、提示「等N项」、离开出战栏遗忘、O-095 开关两边没单测 |
| XWeakChallenge | weak_challenge.gd | 184 | 1 | xiyou_weak_challenge | 否 | 自己的专项＋参照，含最终战回退 |
| XTreasureBatch | treasure_batch.gd | 178 | 1 | xiyou_treasure_batch | 否 | 自己的专项，35 项 |
| XTianqiLook | tianqi_look.gd | 173 | 1 | xiyou_tianqi_look | 否 | 显示类，有专项 |
| XNanoha | nanoha.gd | 164 | 1 | xiyou_nanoha | 否 | 自己的专项＋三份参照 |
| XQualityIcons | quality_icons.gd | 160 | 1 | xiyou_quality_icons | 否 | 显示类，有专项 |
| XExtDot | ext_dot.gd | 130 | 1 | xiyou_dot | 否 | ext_dot 线在改 |
| XAutoSave | auto_save.gd | 122 | 1 | xiyou_pause_save | 否 | 专项 43 项，切后台、检查点、事件战斗分支都测了 |
| XSaveTransfer | save_transfer.gd | 118 | 1 | xiyou_platform | **是** | 存档类；平台专项只测主流程，越界存档位、坏档导出、外层 game 不对、未来版本、写不进的位置、导入后读档没测 |
| XTianqiMerchant | tianqi_merchant.gd | 111 | 1 | xiyou_tianqi_affix_roll | 否 | 测试在 tianqi_affix_roll 线里，那条线在改 |
| XPowerEnemy | power_enemy.gd | 104 | 1 | xiyou_boss_status | 否 | 只供显示、面板默认关，战力系统要重构 |
| XCatDamageHooks | cat_damage_hooks.gd | 97 | 1 | xiyou_module_hooks | 否 | 伤害钩子（damage／actor_damage_hooks 线在改） |
| XDifficultyNotice | difficulty_notice.gd | 93 | 1 | xiyou_difficulty_notice | 否 | difficulty_notice 线在改 |
| XTianqiReforge | tianqi_reforge.gd | 84 | 1 | xiyou_tianqi_reforge | 否 | tianqi_reforge 线在改 |
| XRunewords | runewords.gd | 83 | 1 | xiyou_equipment | **是** | 装备永久属性；参照只核做成后的属性与单颗挂起，挂起后接上／断开／孔用完／挂起作废这一串没测 |
| XTianqiPetHide | tianqi_pet_hide.gd | 80 | 1 | xiyou_tianqi_pet_hide | 否 | 自己的专项，26 项 |
| XScreenFx | screen_fx.gd | 80 | 1 | xiyou_screen_fx | 否 | 显示类，有专项 |
| XPartySkills | party_skills.gd | 78 | 1 | xiyou_party_skills | 否 | 自己的专项＋参照 |
| XLeadActor | lead_actor.gd | 77 | 1 | xiyou_party_skills | **是** | 学／忘技能；参照测整体，首位空、换领袖、首位换成非领袖记录不清、O-095 两边没单测 |
| XStarburstBooks | starburst_books.gd | 76 | 1 | xiyou_starburst_books | 否 | starburst_books 线在改 |
| XZhCollation | zh_collation.gd | 69 | 1 | xiyou_gear_search（xiyou_side_status_order 用 ICU 参照） | 否 | 间接测到：side_status_order 用 zh_collate_names.json 的 ICU 排序逐个比 |
| XPreempt | preempt.gd | 69 | 1 | xiyou_preempt | 否 | 自己的专项＋参照 |
| XPingbi | pingbi.gd | 63 | 1 | xiyou_options_misc | 否 | options_misc 用参照测了行、整档切换、掉落过滤、存档往返 |
| XConfusion | confusion.gd | 60 | 1 | xiyou_confusion | 否 | 自己的专项＋参照 |
| XBossOutputContext | boss_output_context.gd | 54 | 1 | xiyou_boss_sequence（xiyou_boss_output_context 按文件名） | 否 | 自己的专项（没写类名，按 new() 用） |
| XLifeSteal | life_steal.gd | 49 | 0 | （xiyou_life_steal 经战斗逻辑） | 否 | 间接测到，86 例参照 |
| XActorDamageHooks | actor_damage_hooks.gd | 32 | 1 | xiyou_actor_modules | 否 | actor_damage_hooks 线在改 |
| XPassiveBooks | passive_books.gd | 22 | 1 | xiyou_book_capacity | 否 | book_capacity 用参照测了 |

## 新专项

预期都取自类的文件头注释（写的是原版插件／运行时的规则）；没有现成参照能直接对上（相关参照 party_skills_oracle、common_scripts、equipment 的符文之语段已被原有专项用来比整体结果），所以这里核的是单个分支。都不需要新的参照数据、不改 fixtures。

| 专项 | 类 | 项数 | 测了什么 |
| --- | --- | --- | --- |
| xiyou_save_transfer | XSaveTransfer | 37（skip 1） | 存档位 0／-1／31 拒且不写盘；导出空格、坏档；没选文件、文件打不开；顶层数组／字符串／空文本、game 不对或缺、format 不对、缺 data、不是存档；原版格式不论 game 都按原版拒；未来版本、读档校验会拒的坏档也拒；外层多字段不影响；写不进的位置；导出→导入空格→读档金钱物品回来、不留 .tmp、空格不留备份；导入有档格备份是原文；headless 没文件框时 pick 返回 false 不回调；替身给空路径回调 "" |
| xiyou_treasure_map | XTreasureMap | 24 | 不站在宝点只提示两行、不扣图；站上挖物品／防具／武器／公共事件（v%80 分档、v%长度 取候选、扣一张图、gn+1、记挖过）；只看第一个没挖过的宝点；候选为空还图并提示四种「…失败: 请重新使用」，gn 照样 +1；整段挖完同一次调用清掉重来、段外记录不动；预掷池 gn=15 不重掷、16 重掷、长度不对重掷（20 个都在 1～9999）；v0.29 路径：没图不动、不看站位不提示「挖宝成功」、跳过缺一类候选的宝点、全挖完取第一个、公共事件对不上按首尾找（1～10 落到 342） |
| xiyou_runewords | XRunewords | 23 | 模板（武器 wtype、防具 atype>0＋etype）；结尾匹配；can_grow 孔够／不够／没孔；数据库现找的 A=27 强能 [280,281]、B=28 超凡能量 [280,281,290,291]：做成 A 挂起、沿 B 镶仍挂起、镶完结算 B 清挂起；接一颗不相干的结算 A；没孔、孔不够镶完 B 都直接结算 A；挂起对不上清掉、挂起编号不存在照常结算；O-308 关做成就结算；真装备 check 挂起不加属性不改名、镶完一次加 B 模板只记一条、重复 check 不变 |
| xiyou_skill_share | XSkillShare | 28 | 出战栏原样；ShareLearnSkill 只算出战栏、学给装备的人、记录 equip／equipBy；equip_changed 顺序不同不算、增删算；换下就忘；O-095 开不忘本来会的、关照原版忘；光环要有标签才共享、共享给出战栏全体（不含替补）、sharedBy 不含本来会的；再刷不重复提示；离开出战栏忘；标签对不上可共享时交集空并忘掉；五个一起提示「前 4 个 等5项」＋全列；去标签后别人忘、本人留着 |
| xiyou_lead_actor | XLeadActor | 20（skip 1） | 同一角色取第一条；首位空且无记录不动；is_leader 要第 0 格；首位是领袖出战栏全体学（替补不学）、记 ranks／learners、再刷不变；换领袖忘旧学新；首位换成非领袖忘掉但记录留着；O-095 开本来会的不进 learners 不被忘、关照原版忘 |


## 发现

都不急，没改游戏代码；修好后把对应 skip 改成断言。

1. **同一秒内两次导入同一格，第一份备份被覆盖**（`core/save_transfer.gd` import_to，O-206）。备份名 `save_N.json.before_import_<时间>` 只精确到秒。
   - 复现：xiyou_save_transfer 里 slot 1 有原档 O；`import_to(1, A)` 留下备份＝O；同一秒内再 `import_to(1, B)`，备份文件名相同，被 A 覆盖。
   - 预期：O 仍能找回（备份名加毫秒或序号，或已存在就不覆盖）。实际：O 没了。
   - 影响：玩家要在一秒内连导两次才会碰到，界面上很难；记录在案。专项项 `import_twice_same_second_keeps_original` 标 skip（同一秒才判，跨秒时照常断言通过）。
2. **领袖技能：首位换成非领袖后记录不清，别处学到的同一技能会在下次刷新被忘**（`core/lead_actor.gd` refresh；文件头写「下次再忘一次，无害」）。
   - 复现：xiyou_lead_actor 里领袖 29 在首位，全队学 701；首位换成 8（不是领袖）→ 刷新忘掉 701，ranks 仍是 [29, 701]、learners 仍含 8；之后 8 用 learn_skill 学到 701，再刷新一次。
   - 预期（O-095 开时「只忘本系统学会的」）：8 留着 701。实际：被忘。
   - 影响：要有别的途径学到某个领袖技能才会碰到，是否存在这种途径没查；首位非领袖时清掉 ranks/learners 即可。专项项 `stale_record_keeps_other_source` 标 skip。
3. **导出空文件存档往日志打 ERROR**（`core/save_transfer.gd` export_text）。parse_import 特意用 `JSON.new()` 避免坏文件打 ERROR，export_text 还用 `JSON.parse_string`；结果正确（报「存档为空或损坏」），只是日志多一条 ERROR，并行测试会因此判失败，所以专项没测空文件那一例。改成和 parse_import 一样即可。


## 交接板

- 下一步：总装派车道看「发现」三条（都不急）；修好后把对应专项里的 skip 改成断言。
- 需要用户决定：无。

## 优化登记

- 无。

## 可优化（流程／工具／效率）

- 建议：盘点「类在测试里被引用几次」时，只按 class_name grep 会把按文件名、`new()` 或经别的类间接测到的算成缺口（本轮 36 个里约 30 个其实已有专项或参照）；可在 `选测.py` 旁加一个小脚本，同时按 class_name、文件名和「被哪些已测类调用」三种口径出表，归工具车道。

## 验证

- 云端线程（Godot 4.7.2 Linux，转换产物取 `refs/ci/generated/main` 快照）：`并行测试.py` 跑 5 个新专项全部通过（16 秒，单场景 5～6 秒）；只加测试、不改 modes/，所以没跑既有专项。
- 测试场景按 `tests/*.tscn` 自动发现，不用登记；`云端测试耗时.json` 没加（新场景都很快，云端选测缺省按 Mac 估值处理）。


## 本分支提交

- （见分支）
