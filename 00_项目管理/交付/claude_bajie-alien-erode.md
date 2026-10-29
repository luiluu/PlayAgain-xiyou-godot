# 交付：claude/bajie-alien-erode

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_87）
- 状态：可合并
- 本期：异化词条③剩余之**期 C**——蚀术 erosion；百相切换仿形的选择窗（期 B「界面待做」）。④吞器、献器、夺舍不在本期。

## 变更记录草稿

## 2026-10-29 【Claude·八戒·未经Codex检验】异化词条③期 C：蚀术；百相切换仿形选择窗（dev.待定）

1. **蚀术 erosion**（`alien_battle.gd` 文末「词条效果③：蚀术」）：
   - 只扣护盾（executeHpDamage 包装，Adv:124，最外层）：蚀术者用选定技能（config.skillId，templates.attack）、或在选定技能的行动根里造成的正生命伤害只扣目标护盾（扣到 0 为止），生命不变，结果记生命伤害 0。
   - 封印（Game_Action.apply 包装＋A.sealLast，Adv:123、182）：选定技能命中后，封印目标上次用的技能（startAction 记的、>2 且在 templates.attack 里；目标已有异化封印就不封），封印成功也封自己的选定技能。
   - 被封的技能不能用（isSkillSealed／meetsSkillConditions 包装，Adv:145、183），敌我都算；敌人选技（`enemy_action` 经 `can_use`）自然避开。
   - 解封（startAction／endAction 包装，Adv:184-185）：技能行动（含防御）开始时，能动、且不看异化封印也合技能条件的封印列入待解，这次行动结束时解掉（原有合法行动窗口）。
   - 封印、上次用的技能记在本场 logic 的异化存储里，战斗结束随 logic 丢掉（原版 endBattle 清 _alienSeals）。A.blocksDamage 的蚀术段（Adv:190）条件与 Adv:124 相同，被外层先拦下，走不到，不另接。
2. 接点：`battle_logic.gd` `can_use`（`sealed`）、`execute` 开头与防御分支（`start_action`）、`apply`（原 apply 之后 `seal_last`，命中＝testApply 过且未落空、未闪避）、`execute_hp_damage` 最外层（`erosion_shield`）、`act` 收尾（O-116 `idle_window`）；`alien_battle.gd` `finish` 里解封。
3. **百相切换仿形选择窗**（新 `battle/alien_mimic_window.gd` `XAlienMimicWindow`，`battle_scene.gd` `_pick_action_list`／`_pick_mimic`）：战技列表确定切换仿形（10197）时先开选择窗——宽 380、x＝(1280−380)/2、y＝100，行数＝记录数（普通 Window_Command：行高 36、字号 26、内边距 14、文字边距 6，不吃 Olivia 0.8 缩放），只写技能名；当前仿形不可选（半透明、确定蜂鸣），光标在第一项。选定后 `XAlienBattle.choose_mimic` 记下再照原 onSkillOk 选目标；取消回技能列表原位、不记选择；之后取消选目标时选择作废（原版选择记在这次输入的行动上，不带到别的回合）。
4. 参照探针 `mv_oracle/alien_affix_probe.cjs` 加 1 例（共 28 例）：`battle.erosion`（选定 1924：打没用过技能的 e1→e1 用合成技能 13（不在模板）→再打 e1（不封）→e0 用 1926→e0 护盾 1000→打 e0（扣盾 253、封 e0 的 1926 与自己的 1924）→硬用 1924（扣盾、自己解封、e0 已有封印不再封）→e0 用 1928（解封）→打 e0（封 1928）→普攻（自己解封、正常伤害先吃护盾）→队友普攻）；新增步骤 `shield`（直接写护盾），蚀术另记角色 1 与各敌人的封印、ERODE_WATCH（1、1924、1926、1928）里各自能用哪些。`oracle_additions.py` 已按 id 登记，不用改。
5. 专项：`xiyou_alien_affix` 逐步对照 erosion 例、`o116.*` 三项；`xiyou_battle_ui` 加 `alien_mimic_*`（窗口位置尺寸、行与可选、确定不可选项不动、取消回列表、选定后进选目标、取消选目标选择作废）与截图 `battle_54_alien_mimic`。

## 原版依据

- `js/codex/runtime/installAlienationAdvanced.js`（Adv）：20（词条说明）、45（就绪：选定技能在 templates.attack、本来会）、123（apply 包装）、124（executeHpDamage 包装）、145（meetsSkillConditions 封印）、182（sealLast）、183（isSkillSealed）、184-185（startAction／endAction 解封）、190（blocksDamage 蚀术段）。
- `installAlienationRuntime.js`：93-94（startAction／endAction 行动根）、97（executeHpDamage 里的 blocksDamage）。
- `installAlienationWorkshop.js`：30-34（Window_AlienMimic、createAllWindows 处理器、onSkillOk 包装）。

## 优化（O-116，已加登记表行）

- O-116：蚀术封印的敌人能动却没有有效行动的回合也算一次原有合法行动窗口（`XAlienBattle.o116_idle_release`，alien_battle.gd `idle_window`）。原版只在 startAction 判解封；敌人能用的行动全被封（如只会一招模板攻击）时没有有效行动、不 startAction，封印永不解，整场再也不行动。回退：`o116_idle_release = false`（专项对照时关）。

## 没移植／差异（写明）

- 原版 startAction 包装另排除云裳赠行／储行（`_yunDerived`、`_yunActionSource`）：重制没有这两种行动来源。
- 解封判「合技能条件」用重制 `can_use`（不看异化封印），它另查技能类型已添加（原版 meetsSkillConditions 不查）；角色没添加选定技能的类型时本来也用不了这招，影响面只在硬用。
- 百相选择窗没有原版截图参照（ui_reference 里没有异化夹具），位置、尺寸、字体照原版源码（Window_Command 默认度量）。窗口开着时技能说明卡关掉（原版技能窗隐藏、帮助窗留着上一条说明）。

## 验证

- 合过 main（334e64c3，碰的是共用文件与合并工具，没碰切片、转换器、探针与本车道文件）后，工作树跑 `同步正式西游.py --accept-additions` 通过（测量不变、无 issues，留了产物指纹）；之后只改了选仿形窗的函数名（不涉探针），指纹仍有效。
- 选测（`并行测试.py`，并行 2，58 个场景全部首轮通过，4181 秒，日志 `04_验证/本地结果/并行测试/20261029_221908_c7z4qc7e`）：`xiyou_alien_affix` 1325/1325、`xiyou_alien_battle` 330/330、`xiyou_alien_config` 95/95、`xiyou_alien_workshop` 45/45、`xiyou_attack_query` 375/375、`xiyou_battle_ui` 152/152；另 `xiyou_rules` 全部 24 段与 `xiyou_smart_ai` 四段（`can_use`、`execute_hp_damage`、`act` 是热路径）、`xiyou_battle*`、`xiyou_shield`、`xiyou_otb`、`xiyou_hangup*`、`xiyou_module_hooks`、`xiyou_actor_p0`、`xiyou_combat`、`xiyou_cat`、`xiyou_wtype`、`xiyou_boss_output*`、`xiyou_zhenqi*`、`xiyou_imported_balance`、`xiyou_loose_fixes`。
- 反向验证：临时去掉封印与只扣护盾，`xiyou_alien_affix` 失败（已还原）。
- 偶发：无。
- 没覆盖：选仿形窗的截图（测试在无头模式下不截图；位置、尺寸、行与可选状态有断言）；原版选仿形窗没有参照截图。

## 改了的原沙僧核心文件（待交叉核查点名）

- `battle_logic.gd`：`can_use` 加 `sealed`；`execute` 开头、`act` 防御分支加 `start_action`；`act` 收尾加 `idle_window`；`apply` 加 `seal_last`；`execute_hp_damage` 最外层加 `erosion_shield`。
- 另：`battle_scene.gd`（选技段）、新文件 `battle/alien_mimic_window.gd`；测试 `tests/xiyou_alien_affix.gd`、`tests/xiyou_battle_ui.gd`。

## 交接板

- 下一步：④吞器、献器、夺舍待派。
- 用户试玩说明：异化装备的蚀术（选定攻击只打护盾、命中封印对手上次用的攻击，自己的这招也封一次行动）在战斗里生效；百相用「切换仿形」时弹出选择窗，可指定换成哪一项。
- 需要用户决定：O-116 去留（默认保留，可回退）。

## 可优化（流程／工具／效率）

- 新建 `class_name` 文件后，`并行测试.py` 不自动导入，测试直接报「找不到类型」并且要排队到槽才看到失败（本次排了 10 分钟）。可在 `并行测试.py` 开跑前比对 `.godot/global_script_class_cache.cfg` 与工程里的 `class_name`，缺了就提示先 `godot --import`（或自动占槽导入一次）。

## 本分支提交

- 见 git log（claude/bajie-alien-erode）。
