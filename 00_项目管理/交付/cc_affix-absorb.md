# 交付：cc/affix-absorb
- 车道／工作者：B 界面＋C 机制／cc（玩家反馈线程「专武特效吸收点了没反应」）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·未经审查】专武·特效吸取移植（玩家反馈：技能「专武·特效吸取」点了没反应）（dev.待定）

- 原因：原版 10455「专武·特效吸取」在技能页用 → `CodexAbyssMerchant.openAbsorb` 打开商人界面的吸取模式；重制只学了技能、没移植吸取界面和吸取效果（`actor.gd` 注释早写着未移植），所以点了只响确定音、什么都不出。不是原版 bug，是移植缺口，没有回退开关、不占 O 号。
- 新 `XAffixAbsorb`（`core/affix_absorb.gd`，照 installAbyssMerchantRuntime v0.36）：开放专武（`XActor.absorb_owners`）、槽位按所属角色最高等级 1／35／60 开 1／2／3 条、`_codexAbsorbed29` 存每槽 {db,id}（旧单条字典照认）、额外特效识别（商人装备只认 `_codexExtraAffix29`，其它按备注含某条商人特效的全部 Mod／神话特效行，按 params／traits／note 去重）、吸取校验与原版错误文字、失败不扣材料。
- 效果视图：`XActor.equip_list()` 对吸取过的专武返回合并了开放槽位特效的复制品（`XGear.combine` 前缀，按本体会变的字段判过期缓存），能力值、特性、备注、被动都用它（原版 `Game_Actor.equips` 包装）；新 `raw_equip_list()` 给登记、镶嵌、熔炼、按引用找装备的地方用（xstate 登记／owns_gear、gear 专武词缀还原、growth_forge、star_warehouse、item_scene 装备列表、gear_query、alienation、yunshang_orders、demon_crown、tianqi_qiyin_equip），`stat_equips` 的 178 剑视图也先套吸取视图；说明卡（`XHelpCard.show_for`）和商人详情显示视图（原版 `Sprite_ItemHelp.setItem` 包装）。没吸取过的装备完全不变。
- 界面：`XMerchant29Page.mode = "absorb"`：专武列表「名字（n／m条）」→ 三个槽位（未开写「所属角色35／60级开放」）→ 背包材料（不含锁定、已装备）→ 选额外特效 → 确认消耗并吸取／取消；出错提示并在详情显示错误文字，成功提示「特效吸取完成。」回到槽位页。技能页 `use_skill` 遇 10455 不付消耗、打开吸取页（`XSkillScene.open_absorb`），关掉回技能列表；商人界面开着时不开。
- 与原版的差别：原版视图合并后再跑一次 `processYanflyTags`；重制的合并已合入解析好的 meta／yep，不再重解析备注（备注里写死 `<atk: …>` 的专武如斩月，原版这一步可能把浮动和强化值重置成备注值，未用参照核实，留给审查）。
- 测试：新 `tests/xiyou_affix_absorb`（42 项手算断言；没有 mv_oracle 参照，原版吸取走界面，探针未做）。
- 玩家可见：技能「专武·特效吸取」能用了：选开放专武和槽位，消耗一件带 Mod／神话特效的材料装备，把其中一条特效转到专武上（所属角色 1 级一条、35 级两条、60 级三条）。

## 交接板
- 下一步：v0.01.09 补丁带上本分支（玩家反馈修复）；审查线程核 `equip_list` 换视图后的引用比较点（本单列的 raw 改点之外是否还有改装备本身的地方）
- 用户试玩说明：技能页用「专武·特效吸取」打开吸取页，吸一条特效后看装备页／状态页的专武说明卡与能力值
- 需要用户决定：无

## 进度账
- 无（移植缺口补齐，不改完成度表）

## 可优化（流程／工具／效率）
- 建议：给吸取做一个 mv_oracle 探针（直接调 `CodexAbyssMerchant.absorb`／`absorbView` 比视图的 params／traits／note），顺带确认 processYanflyTags 是否重置备注属性；归 C 机制车道。

## 待交叉核查
- 改了原沙僧核心文件：`actor.gd`（equip_list／raw_equip_list／stat_equips）、`xstate.gd`（登记与 owns_gear 改用 raw）。

## 验证
- `语法检查.py` 通过；`xiyou_affix_absorb` 42/42。
- 本机选测 29 个相关场景全过（xiyou_affix_absorb、merchant29、equipment、determinism、combat、skill_page、help_card、item_bag、item_list、gear_ui、growth_forge、orbs、orb_ui、star_warehouse、alien_affix、demon_crown、tianqi_qiyin_equip、yunshang、gear_query_cache、save_events、param_cache、act_stat_memo、cat、dual_exclusive、custom_params、imported_balance、skill_menu_events、gear_detail、heartsteel，892 秒）；`选测.py main --list` 因改了 actor.gd／xstate.gd 列出 535 个场景（近全量），按派单「不推」没走云端，留给总装合并时按影响面选测。

## 本分支提交
- edb2f476f 专武·特效吸取移植（XAffixAbsorb、equip_list 吸取视图、商人页 absorb 模式、技能页入口、专项）
