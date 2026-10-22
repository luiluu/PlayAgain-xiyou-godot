# 交付：claude/wukong-hajimi

- 车道／工作者：A 内容·角色／悟空（Claude；第一期 悟空_37，剑技连携与使用条件 悟空_38 接手）
- 状态：可合并
- 本分支从 `claude/wukong-next` 切出；`wukong-next` 已在 main 合并为 dev.127，本分支不再带它的交付单。

## 变更记录草稿

## 2026-10-22 【Claude·悟空·未经Codex检验】178 哈基米：招募、能力值、剑技公式、剑技连携、使用条件、说明卡（dev.待定）

- 做了什么：
  - **原版查清**：哈基米不是单独文件，是 `installImportedBalanceRuntime.js` 第 50～278 行「小猫剑圣 v1.0」段（`W.CodexCat` 1.0.1）。数据库记录（角色 178、职业 176、技能 10437～10450、状态 2713～2717、号角 2899、进阶石 2900、法宝 7999、敌人／敌群 1999、公共事件 9017／9018）都已在 `data/*.json`，开机只多登记一个强者编号与巨龙固定能力值，不用转换器复现。
  - **第一期（悟空_37）**：新增 `core/cat.gd`（XCat）。
    - `actor.gd`：`equip_slots` 去掉副手、`is_dual_wield` 对 178 恒假；`param` 覆写走 `XCat.param`（10 级起学了 10442 速度 ×1.88，装着 7999 时攻击／速度／幸运 ×1.6）；`sparam` 6／7 持剑 ×0.8／×0.88；`param_plus` 持剑时＝全量＋(全量−去掉武器槽)；新增 `stat_equips()`（持剑时武器槽换成 `XCat.sword_view` 翻倍视图），`trait_objects` 与 `refresh_passive` 改读它（非 178 与 `equip_list` 相同）。
    - 转换器 `formula_program.py`：整条公式是 `CodexCat.formula(user,item,b)` 的五个技能编译成 `status: "module", module: "cat"`，`xiyou_export.py` 统计加 `moduleSupported`；`formula_execution.gd` 的 `run_item` 按 module 分派到 `XCat.formula`。全库公式拒收 81→76。
    - `mv_script.gd`：公共事件 9017 的 `CodexCat.recruit()` 走 `XCat.recruit`；标记照原名记在 `s.flags`，不改存档结构。`xui.gd` `icon_texture`：图标 280000～280008 画 `img/system/CatSwordSaint_Icons`。
    - 178 加进切片 `actors`、`xiyou_actor_p0` 新增 `RECRUIT_8 = {9017: 178}`；`systemImages` 加 `CatSwordSaint_Icons`。
  - **剑技连携（悟空_38，期一）**：原版四个剑技的行动序列只有 `CAT BEGIN`，由 `processActionSequence` 包装逐段插 `CAT STRIKE`。Godot：
    - `action_sequence.gd` `_command` 只加 CAT 分支（5 行）：`CAT BEGIN／CAT STRIKE` 且 `XCat.casts(行动者, 技能)` 时调 `XCat.cast`，把全部剑段打完；其余情况与原版一样什么都不做。
    - `XCat.cast`：开招快照（剑心、速度、目标识破／剑痕），按剑技排剑段（斩 1＋剑心≥1 时 1；十字斩 2＋剑心≥2 时 2；连斩 4＋剑心 3 层 2＋非连携速度段 0～2＋剑痕 2，消费标记；至圣斩 1＋剑痕 2 段剑影，消费标记、冷却到回合＋4）；每段是一次独立的 `logic._invoke`（技能换成该段剑技，照常有反射／反击／掩护、伤害走沙僧的 cat-sword 钩子），公式用开招速度与段倍率（连携段 0.6）；打完一招按条件连携下一招（斩→十字斩、十字斩有识破→连斩、连斩有剑痕→斩、至圣斩消费过标记→斩，连携招不再连携）；斩给识破、十字斩相邻两段都中给剑痕，目标身上 2716／2717 跟着同步。
    - `battle_logic.gd` 加 5 行挂点：`certain_hit` 认必中剑段（开招时有识破且不是斩：命中 1、不被反击）；`_apply` 必中剑段且学了 10443 时暴击率 1；`act` 与强制行动后调 `XCat.end_action`（连携过剑心＋1；防御且学了 10443、带法宝时每回合一次剑心＋1 并把最近目标的标记续到下回合）；`end_turn` 调 `XCat.end_turn`（删过期标记）。
    - 战斗数据挂在本场 `XBattleLogic` 的 meta 上，新战斗自然清空（同原版 startBattle／endBattle 的 reset）；剑心与标记状态都是 removeAtBattleEnd。
  - **使用条件（期二）**：`XCat.legal`，`battle_logic.can_use` 加 1 行：剑技要 178、持剑、学会、到等级（1／10／20／30），至圣斩不在冷却；试炼 10446 要 35 级、持剑、不在战斗中；剑影 10445 不能直接用；178 没持剑不能用物理技能（stypeId 1）。
  - **说明卡**：`XCat.help_text`（C.helpText）——伤害行按成长写系数、抱剑护身按速度写减伤、进阶相关行按未进阶写「条件：…」；`help_card.gd` 对 `<CodexCat:>` 技能卡套用、目标排在伤害属性前；`xiyou_help_card` 用 10 级的 178 比参照。原版小猫卡走 characterHelpView（Godot 未移植，用普通视图近似）：伤害属性行不着色、字号 14、不与目标并行——这是按参照里 10437／10438 两张卡对齐的近似，完整 characterHelpView 留给界面车道。
  - **参照与测试**：`mv_oracle/cat_probe.cjs` 共 22 例（第一期 13 例＋连携 8 例＋使用条件 1 例，只增）。连携例用真实 BattleManager 跑整个行动序列（Math.random 0.5、关五乘区修正 O-044），记每段 key／命中／暴击／连携、公式原值、伤害、剑心、标记、冷却、喵铃回合；使用条件例 330 行（5 个等级 × 3 种武器 × 2 个回合 × 11 个技能）。`xiyou_cat` 622→942 项；Godot 用随机数全取 0.5 的流跑同样的行动。变异验证：关掉必中剑段与连斩速度段时 68 项失败；`legal` 恒真时 `legal.rows` 失败。
- 验证（车道不跑全量，只跑相关专项）：见下「验证」。
- 未完成／已知问题：
  - **进阶**：Godot 没有角色进阶次数（`_AdvancedNum`），`XCat.advanced` 恒假——35 级后成长恒 1、进阶额外行动、至圣斩追加剑心段剑影、满层冷却 3、进阶结算 ×2 都不生效（连携里这些分支照原版写了，读到的都是未进阶）。
  - **守誓巨龙试炼**（9018，`CodexCat.startTrial`、巨龙行动表与固定能力值、试炼难度状态屏蔽、奖励进阶石）没做；沙僧的巨龙减伤钩子要宿主传 `battleRound`，试炼开放时一并接。
  - **号角 2899 入队后不能用**：Godot 物品菜单目前不支持范围 0 的公共事件物品（`item_scene._usable` 只认范围 7～11），所有伙伴号角在菜单里都用不了，这条规则暂无处可挂；Map132 商店补号角（Map132 不在切片）也没做。
  - **画面**：原版段间插 `WAIT 6`，Godot 剑段的伤害记录直接接在 `CAT BEGIN` 那条序列条目后面，演出节奏没有逐帧对照。
  - 熟练度：Godot 技能熟练度恒 0，`XCat.mastery` 与剑技备注的 `Custom DAMAGE Mastery Formula` 都读到 0（原版新游戏里也是 0）。
  - 原版 `end_action` 在 endAction 里结束剑技，Godot 在 `act`／强制行动收尾处调用，时点等价（都在行动全部结算之后）。
  - 招募时原版对法宝槽、练习剑装备失败会抛错，Godot 只 push_error 并返回 false。

### 附：一护彩蛋 962 查证（不改代码）

- Map213 EV2「来修炼卍解吧！」第 1 页要求角色 109 在队**且变量 1309 ≥ 1**；第 2、3 页要求本事件的独立开关 B／A，而这两个开关只由第 1 页设。冻结 v0.28 全部地图事件、公共事件（指令 122 区间与脚本）、`js/` 插件与数据库备注里都**没有任何地方写变量 1309**。另外角色 109 是「牢大」，不是黑崎一护（148），敌群 962 也没有成员。结论：原版死内容，正常流程永远不出现，Godot 照现在不放（`xiyou_floor_run` 的 `UNOPENED_EVENTS` 已核它不在地图上）。

### 给其他车道的发现

- **八戒（战斗规则）**：Godot `battle_logic.act` 的防御分支没有给行动者技能 2 的 TP 获得（原版防御也走 `Game_Action.apply`，`applyItemUserEffect` 按 tpGain×tcr 加 TP，实测 +10）。`cat_probe` 的 `chain.full` 第 3、4、7 步能看到（参照 TP 110，Godot 100）；`xiyou_cat` 里防御步暂不比 TP。
- **八戒（界面）**：物品菜单不支持范围 0、带公共事件效果的物品（伙伴号角等），见上。
- **沙僧**：原提案 1（元素增幅走 `stat_equips`）与 2（cat-sword 钩子）已由 `codex/module-hooks-cat` 落实，本分支直接用；连携段的伤害对照（逐段伤害与原版一致）也就验证了钩子在真实战斗路径里的效果。其余 167～177 的挂接点用例表照旧（渡鸦、米拉、甚尔、饿狼还包了 `makeDamageValue`）：改结算模式、加算池、乘区、防御与穿透、enter 临时改目标、makeDamageValue 外层。

## 交接板

- 下一步：「下一步」里「未接：一护彩蛋 962」改为「一护彩蛋 962 是原版死内容（变量 1309 无处写入），不做」。
- 下一步：0d 条改为「178 哈基米已加回（招募、能力值、剑技公式与连携、使用条件、说明卡、伤害钩子；进阶、守誓巨龙试炼、号角限制未做）；167～177 按预检表排期，可用沙僧的模块挂接点」。
- 用户试玩说明：哈基米可以通过公共事件招募（自带法宝抱剑喵铃与练习剑），剑技在战斗里会逐段出剑并连携（斩→十字斩等），剑心、识破、剑痕会显示为状态；进阶与巨龙试炼还没有。
- 需要用户决定：无。

## 进度账

- 角色：178 第一期＋连携与使用条件，粗估 +0.05 点（第一期原估 +0.03），交沙僧复核

## 验证

- `git merge main`（0a72150，含沙僧 module-hooks-cat）后 `新建工作树.sh --补齐`；交付前再合 main：已是最新。
- `同步正式西游.py --accept-additions`（长任务，退出 0）：「新增用例，已接受（不登记）」，changedInputs／changedMaps 为空，来源 issues=[]；测量变化只有新增（178 进切片带来的 slice_d1～d6 伤害行与角色、help_cards 技能卡 621→626、actor_passive 740→745、wtype 15624→15736，及新文件 cat.json 22 例）。备份 `04_验证/本地结果/自动同步/20261022_170218_770732_v0.28-v0.28`。
- `内容覆盖检查.py`：new 0、resolved 0，基线不用更新。
- 相关专项（`并行测试.py`，并行 2）47 场景：首轮 46 过、`xiyou_help_card` 2 项失败（小猫卡伤害属性行，见上），修好后单独重跑 970/970。其余：xiyou_cat 942、xiyou_actor_p0 3212、xiyou_imported_balance 273、xiyou_module_hooks 1310、xiyou_action_sequence 115、xiyou_sequence_visual 70、xiyou_battle 8、xiyou_battle_events 108、xiyou_battle_options 92、xiyou_battle_ui 58、xiyou_battleback_save 5、xiyou_qiyu 231、xiyou_wtype 15770、xiyou_formula_program 43458、xiyou_skill_page 21、xiyou_power 137、xiyou_status_power 36、xiyou_status_power_panel 11、xiyou_smart_ai 四份 48363、xiyou_rules 24 份全过（每份 63763～63950）。无偶发。
- 变异：关掉必中剑段与连斩速度段 → xiyou_cat 68 项失败；`XCat.legal` 恒真 → `legal.rows` 失败。

## 本分支提交

- 4ea173d 178 哈基米第一期：XCat、cat_probe 13 例、xiyou_cat 622 项
- 23d4714、b0afad1 WIP：交付单草稿、说明卡、一护彩蛋查证
- 4693809 合并 main（含沙僧 module-hooks-cat）
- 93b8491 剑技连携：cat_probe 加 chain 8 例，xiyou_cat 939 项
- 4c76710 使用条件：cat_probe legal 330 行，xiyou_cat 942 项
