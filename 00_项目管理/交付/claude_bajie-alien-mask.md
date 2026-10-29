# 交付：claude/bajie-alien-mask

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_86）
- 状态：可合并
- 本期：异化词条③剩余之**期 B**——百相 mimic、无相（词条名「无面」faceless）。期 C 蚀术、④吞器／献器／夺舍不在本期。

## 变更记录草稿

## 2026-10-29 【Claude·八戒·未经Codex检验】异化词条③期 B：百相、无面（dev.待定）

1. **技能表**（`actor.gd`）：`skills()` 拆出 `native_skill_ids()`／`native_skills()`（A.nativeSkills：异化各包装之前的技能），`XAlienation.native_skills` 改读它（原先读 `skills()`，百相、无面一改技能表，就绪检查里的「已学会主动技能」会把被替换的漏掉）。`skills()` 经 `XAlienBattle.skill_ids` 套百相、无面的包装（Affixes:21），饕餮吞噬仍在其后。
2. **百相 mimic**（`alien_battle.gd` 文末「词条效果③：百相、无面」）：
   - 被替换的技能（config.replace）战斗内外都从技能表拿掉、不能用（当前仿形除外）。
   - 敌人行动根用的可借技能（A.borrowable）在 finishAction 末尾记进每个活着的百相出战者，不重复、最多 3 项，第一项自动成为仿形，提示「…的百相记录了 …」（Affixes:24，Runtime:91）。
   - 战斗中技能表加当前仿形（可借才加、不重复）；记录两项以上加切换仿形 10197（Affixes:21）。
   - 能不能用（Affixes:22）：切换仿形要记录两项以上；记录了但不是当前仿形、又不是自己本来会的不能用。
   - 切换仿形的 apply 不走原 apply、每次行动只换一次（Affixes:26）：窗口选了的（`choose_mimic`）照选的换，没选换成第一个不是当前仿形的记录；O-115 开时按记录顺序轮换。
3. **无面 faceless**：各对被替换的技能（replaceId）拿掉、不能用；借来的技能（可借才加）进技能表；借来的要来源队友还在队伍里且仍会才能用（Affixes:20-22）。
4. 接点：`battle_logic.gd` `can_use`（`blocks_borrowed`）、`apply` 开头（`apply_switch`）；`alien_battle.gd` `finish` 末尾 `observe`。
5. 参照探针 `mv_oracle/alien_affix_probe.cjs` 加 2 例（共 27 例）：`battle.mimic`（替换万剑诀 160：硬用被替换的→敌人普攻（不记）→敌人用 1924（记、成为仿形）→用仿形→敌人用 1926（记）→用没选中的（不能用）→切换（缺省换到 1926）→…→敌人用 1928（记满）→1930（不记）→切换（缺省回 1924）→窗口选 1928 切换→用 1928）、`battle.faceless`（借角色 8 的 1924、1926 替换 160、311：用借来的、硬用被替换的、用没替换的 502、来源忘掉 1924）；角色 1 另记仿形记录、当前仿形、WATCH 里哪些在技能表、哪些能用。新增参数 `teach`（角色 8 先学会）、步骤 `forget`、`choice`（action._alienChoice）。敌我技能都挑 0 MP、方差 0、不暴击的测试技能 1924／1926／1928／1930，伤害不受随机取整差异影响。`oracle_additions.py` 已按 id 登记，不用改。
6. 专项 `xiyou_alien_affix`：两例逐步对照（含技能表、能不能用；能不能用只比已添加技能类型的，重制 can_use 另查技能类型）；`o115.mimic_cycle_third`（O-115 开时第二次切换换到第三项）。

## 原版依据

- `js/codex/runtime/installAlienationAffixes.js`（Affixes）：8（originalActive）、9（borrowable）、14-15（ready）、19-20（blockedSkills、borrowedPair）、21（skills）、22（meetsSkillConditions）、23（skillMasteryLevel）、24（observe）、25（switchMimic）、26（切换 apply）。
- `installAlienationRuntime.js`：74（lockParty 建 observed／selected）、91（finishAction 末尾调 A.observe）、canEquip 包装（A.ready）。
- `installAlienationWorkshop.js`：32-34（Window_AlienMimic、onSkillOk 包装写 action._alienChoice）。
- 数据：技能 10197 切换仿形（scope 11、无费用、无效果）。

## 优化（O-115，已加登记表行）

- O-115：百相切换仿形没在窗口里选时按记录顺序轮换（`XAlienBattle.o115_mimic_cycle`，alien_battle.gd `apply_switch`）。原版换成「第一个不是当前仿形的记录」，记满 3 项时第三项不经窗口永远轮不到（参照 mimic 例第 11 步从 1926 换回 1924）；重制轮到下一项，末项回到第一项。回退：`o115_mimic_cycle = false`（专项对照时关）。

## 没移植／差异（写明）

- 技能熟练度包装（Affixes:23：借来的、仿形的熟练度取 min(自己、等级、来源)）：重制熟练度恒 0（`XBattler.skillMasteryLevel`），取 min 不变，没接。
- 原版 canEquip 包装带 A.ready：战斗中配置失效（无面来源队友忘掉借出的技能或离队、百相替换的技能被忘）后，下一次 useItem 的 refresh 经 releaseUnequippableItems 把异化装备卸回背包（锁队数据仍在，借技能照旧按锁队判断）；重制 `can_equip` 不带异化就绪、refresh 也不卸装（只在加减状态时卸），装备留在身上，下一场开战 `eject_invalid` 再卸并提示。参照 faceless 例把「忘掉」放在最后一步避开。影响面是通用的 refresh 卸装，没在本期动。
- 云裳赠行／储行的行动不能切换仿形（Affixes:22 的 `_yunActionSource`）：重制没有这两种行动来源，切换只看记录数。

## 验证

- 合过 main（dda696f1，碰的是地图事件与合并工具，没碰切片、转换器、探针与本车道文件）后，工作树跑 `同步正式西游.py --accept-additions` 通过（测量不变、无 issues，留了产物指纹）。
- 选测（`并行测试.py`，并行 2，55 个场景全部首轮通过，2973 秒，日志 `04_验证/本地结果/并行测试/20261029_190046_hua7kls3`）：`xiyou_alien_affix` 1245/1245、`xiyou_alien_battle` 330/330、`xiyou_alien_config` 95/95、`xiyou_alien_workshop` 45/45、`xiyou_attack_query` 375/375；另 `xiyou_rules` 全部 24 段与 `xiyou_smart_ai` 四段（`can_use`、`skills()` 是热路径）、`xiyou_battle*`、`xiyou_hangup*`、`xiyou_power_books*`（忘技能）、`xiyou_party_skills`、`xiyou_character_help_cost`、`xiyou_loose_fixes`、`xiyou_module_hooks`（覆写 `skills()` 的子类）、`xiyou_wtype`、`xiyou_cat`、`xiyou_combat`、`xiyou_actor_p0`。
- 偶发：无。
- 没覆盖：百相切换窗口（界面未做）；战斗中配置失效后的卸装差异（见「没移植／差异」）。

## 改了的原沙僧核心文件（待交叉核查点名）

- `battle_logic.gd`：`can_use` 加 `blocks_borrowed`；`apply` 开头加切换仿形。
- `actor.gd`：`skills()` 拆出 `native_skill_ids()`／`native_skills()`／`_skill_records()`，套百相、无面包装。
- 测试：`tests/xiyou_alien_affix.gd`。

## 交接板

- 下一步：期 C 蚀术（另起分支）；④吞器、献器、夺舍待派。
- 用户试玩说明：异化装备的百相（战斗中记录敌人用过的可借攻击，用切换仿形换）、无面（借队友的攻击技能替换自己的）在战斗里生效；百相切换缺省按记录顺序轮换（O-115）。
- 界面待做（归界面车道）：百相切换仿形的选择窗口（原版 Window_AlienMimic：用切换仿形时列出记录、当前仿形不可选）；选定后调 `XAlienBattle.choose_mimic(角色, 技能号)` 再执行行动即可。

## 可优化（流程／工具／效率）

- 无新增。

## 本分支提交

- 33b6110c 百相、无面实现、参照用例与专项、O-115
- （其余见 git log）
