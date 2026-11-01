# 交付：cc/bajie-sukuna3

- 车道／工作者：B 界面（总装十一派给八戒）／八戒（cc，八戒）
- 状态：可合并
- 分支从 cc/bajie-guyu5 末端 12cf24cc 切（要先合 guyu4、guyu5），工作树 `.claude/worktrees/ecstatic-archimedes-4ef973`。

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】宿傩画面遗留核对；黑闪弹字、日志与说明卡现况（dev.待定）

- 交接板「宿傩画面遗留（八戒 dev.236）」那一条逐项 rg 核对：①神灶选目标只列蓄力敌人（`XSukuna.selectable_enemies`，battle_scene 选目标池）、②逻辑层 battle_text 记录接战斗日志（battle_scene `_log_add`）、③宿傩技能分类与指令窗 [2,1,5,3,4]／[2,1,5,3]（`XActorModules.MENU_SKILL_TYPES`／`BATTLE_SKILL_TYPES`）都已由悟空 battlelog1／battlelog2（38465517、768e3515，dev.255）做完，专项 `xiyou_battle_log` 覆盖（sukuna.filter*、battle_text、技能分类）；2643 完全体外观悟空 battlelog3 已做。三项本分支没动，交接板这一条可以删。
- 那一条里剩下没做的是「黑闪弹字与说明框」（`installNativeBlackFlashRuntime.js` 62～74 announce、208～222 Sprite_ItemHelp.setItem 包装），本分支照原版接上：
  - 黑闪成功那一下：出手者头上弹 customPopup「黑闪！」「黑闪·二连！」「黑闪·三连！」「黑闪·四连！」（再往后「黑闪·n连！」），LGP 格式 2 伤害色、锚点 (0.5, 0.5)、原地不动、最后 10 次淡出，设置「战斗伤害显示」关掉时不弹；战斗日志加一行「名字打出了黑闪！」。逻辑层 `XBlackFlash._announce` 放进 `announced`，`XBattleLogic._apply` 扣血后取走挂到命中记录 `custom_popups`，画面 `_hit_visual` 弹字加行（行动序列与普通演出同一处）。
  - 说明卡：黑闪技能 10225 给当前角色（技能页 Scene_Skill._actor、战斗技能窗的角色；`XHelpCard.scene_actor`）有黑闪配置（甚尔／宿傩）时，卡尾加两行白色 18 号：「当前：集中N层；连闪N次；概率N%」或「当前：尚未解锁」、「觉醒：生效；剩余N个完整回合」或「觉醒：未生效」。原版 DisplayPreferences 的 setItem 包装在外层（main.js 安装次序 118 在黑闪 108 之后），所以两行加在 characterHelpView 整理之后、卡的最后。
- 文字与次序照源码移植，没加 mv_oracle 参照（只有字面量与两条现成状态值 B.status，状态值本身 dev.238 已有参照）。
- 改了原沙僧独占的核心文件：`battle_logic.gd`（_apply 扣血后三行挂 custom_popups），请重点核。没碰悟空的文件。

## 交接板

- 下一步：删掉「宿傩画面遗留（八戒 dev.236）」这一条（全部做完）。
- 用户试玩说明：宿傩、甚尔打出黑闪时头上会弹「黑闪！」（连闪时「黑闪·二连！」等），战斗日志多一行；技能页看黑闪的说明卡，最后两行写现在的集中层数、连闪次数、概率与觉醒剩余回合。
- 需要用户决定：无。

## 进度账

- 宿傩 172：画面遗留清完。

## 验证

- 新专项 `xiyou_black_flash_ui` 16/16（宿傩连闪两次弹「黑闪！」「黑闪·二连！」与日志行、不中不弹、第 5 次起字样、说明卡两行与不加的三种情形、倒下时「尚未解锁」、弹字锚点／不动／淡出／回复色）。
- 反向 3 处都抓到：不宣告（first、second）、说明卡不加两行（help_card_tail）、弹字锚点不是 0.5（popup_kind）。
- 选测 40 个全过（CHECK_JOBS=3）：xiyou_black_flash_ui、xiyou_sukuna_battle、xiyou_toji_battle、xiyou_popup_overlap、xiyou_regen_popup、xiyou_battle_log、xiyou_battle_ui、xiyou_skill_page、xiyou_window_rects、xiyou_help_card、xiyou_character_help_cost、xiyou_actor_book、xiyou_event_compare（必跑）、xiyou_battle、xiyou_action_sequence、xiyou_guyu_battle、xiyou_rules*（24 段）。日志 `04_验证/本地结果/并行测试/20261101_100728_vtd3brq4`。
- `语法检查.py` 0 个问题。没改切片、转换器、探针。

## 可优化（流程／工具／效率）

- 交接板遗留条目常已被别的车道做掉（这次三项都是）：总装派「遗留」类活之前先 rg 一下，或车道交付时顺手划掉交接板对应条目（写进交付单「交接板」节）。

## 本分支提交

- 黑闪画面＋专项 xiyou_black_flash_ui
- 交付单（本提交）
