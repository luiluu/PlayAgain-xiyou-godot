# 交付：claude/bajie-alien-mp

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_85）
- 状态：进行中
- 本期：异化词条③剩余之**期 A**——缄默、饕餮（MP 费用类），连同沙僧第六期 P1／P3（付费后行动快照负 MP）。期 B（百相、无相）、期 C（蚀术）另起分支交。

## 变更记录草稿

## 2026-10-29 【Claude·八戒·未经Codex检验】异化词条③期 A：缄默、饕餮；付费后照 YEP useItem 截 MP（沙僧第六期 P1／P3）（dev.待定）

1. **P1／P3 付费刷新**（`battle_logic.gd` `execute`）：付费后原先只调 `param_refresh`（只刷能力缓存），付不起的角色（原版角色不看 isValid，照样付）MP 减成负数进了行动记录快照（角色 1 MP 4 用消耗 5 的技能 9，快照记 -1）。改为照 YEP_BattleEngineCore.useItem 付费后立即 `refresh`：走 `refresh_resources`（Game_BattlerBase.refresh，把 MP／TP 截回 [0, 上限]），被导入平衡挡下的 useItem 原版直接返回不 refresh，仍只刷缓存。`xiyou_attack_query` skip.actor1-mp-short 补「行动快照 MP＝参照付费后的 0」断言（撤掉修复时该断言记 -1 失败，已验）。
2. **缄默 silence**（`alien_battle.gd` 文末「词条效果③」）：
   - 选定技能（config.skillId，templates.silence）MP 费用为 0（skillMpCost 包装，Adv:132；`battle_logic.skill_cost` 新参数 `panel := false`，面板费用 A.panelMpCost＝mcr 记 1、不归零，Adv:131）。
   - 每次施放锁 面板费用／开场 MP 上限×20% 的生命上限（A.lockFee，Adv:133），生命截到新上限（Adv:143）；生命上限＝max(1, ⌊原值×(1−已锁)⌋)（param 包装，Adv:58）。
   - 锁满（累计＋本次 ≥100%，或锁后生命上限不到 1）就不能用；硬用（角色不看 isValid）时整次不付 MP／TP、不再锁（canPaySkillCost／paySkillCost 包装，Adv:134、143）。
   - 选定技能不受魔法沉默状态（名字或备注带沉默、不限制行动、特性全是封这个技能类型）封印，别的来源照封（Adv:145-149）——原版对角色从不生效，见 O-113。
3. **饕餮 glutton**：
   - 战斗中实际 MP 上限 0（Adv:59）；公式里（evalDamageFormula 包装，Adv:129）行动者、目标读开场 MP 上限；gainMp 一律无效（Adv:111）；战后 MP 还原为 min(开场 MP, 开场上限)（Adv:196）。
   - 锁队时 MP 清零，身上的登记增益状态（statePairs 的键）与增益按剩余回合吞成饥饿储备（Adv:76）；战斗中别人给的登记增益状态、增益不挂上，同样吞掉（addState／addBuff 包装，Adv:161、172）。储备：状态 +max(1, ⌊开场MP×min(15%, 强度×10%)×回合/2⌋)、增益 +max(1, ⌊开场MP×2.5%×回合×层数⌋)，回合夹在 1～5，储备不超过开场 MP 两倍（A.feed／feedBuff，Adv:150-151）。
   - MP 费用的可付判定与扣除都读饥饿储备（Adv:135、144）：付不起照样付，储备扣到 0 为止。
   - 战斗中技能表多吞噬 10198（10 TP，Adv:86）：吞目标第一个登记增益状态，没有就吞第一个增益（2～7），结果只记成功（Game_Action.apply 包装，Adv:152）。
   - 挂机选技（makeAction 包装，Adv:138-142）：挂机表排的技能（>2、已有）按手动输入的合法性判断（储备够就用），不够再走原生选技。
   - 没移植：吞噬的 Game_Action.evaluate（Adv:153）只给 MV 旧自动战斗（XdRs_HangUp 的 IsOldAi 分支）用，重制挂机不走这条路。
4. 两个词条加进 `STATUS_AFFIXES`（锁队时记开场生命／法力参照）；`push_formula` 帧多记 `formula`（区分公式求值与整次伤害计算）。
5. 接点：`actor.gd` `skills()` 末尾饕餮加吞噬；`battle_logic.gd` `skill_cost`（panel、缄默归零）、`can_use`（缄默绕过沉默、锁满不可用、饕餮读储备）、`execute` 付费（缄默锁上限、饕餮扣储备）、`apply` 开头吞噬、`auto_battle_action` 饕餮挂机。
6. 参照探针 `mv_oracle/alien_affix_probe.cjs` 加 2 例（共 25 例）：`battle.silence`（盗梦 3648，MP 5000，每次锁 30.9%：施放→挨沉默→沉默中施放→沉默中火球术→施放→自然到期→锁满）、`battle.glutton`（开场带野性印记 116 与攻击增益：队友给登记增益／增益／回蓝→敌人给自己挂 116 与敏捷增益→吞噬 ×3→火球术、暴风雪（储备不够照付）、火球术）；缄默、饕餮的用例另记角色 1 的生命／法力上限、已锁比例、饥饿储备。新增参数 `level`、`pre`（开战前状态与增益，回合写定）。`oracle_additions.py` 早已按 id 登记，不用改。
7. 专项 `xiyou_alien_affix`：两例逐步对照（含能不能用）；`o113.*` 两项（开关打开时沉默中缄默技能可用、锁定比例与原版一致）；`glutton.hang_up_*` 两项（储备够选排好的火球术、不够不选）。

## 原版依据

- `js/codex/runtime/installAlienationAdvanced.js`（Adv）：56-59（param 包装）、63（开场参照、capLock、hunger）、76（饕餮锁队）、86（技能表）、111-113（gainMp／setMp）、129（公式帧 mhp／mmp）、130-144（费用三件套、挂机）、145-149（沉默绕过）、150-153（吞噬）、161、172（吞增益）、196（战后还原）。
- `js/codex/runtime/installNativeTojiRuntime.js`:362-366：Game_Actor.prototype.isSkillTypeSealed 盖过 Adv:147 的 Game_BattlerBase 包装（O-113 依据）。
- `js/plugins/XdRs_HangUp.js` makeAutoBattleActions：evaluate 只在 IsOldAi 分支用。
- YEP_BattleEngineCore `Game_Battler.useItem`：付费后 `this.refresh()`（P1）。

## 优化（O-113，已加登记表行）

- O-113：缄默选定技能绕过魔法沉默（`XAlienBattle.o113_silence_bypass`，alien_battle.gd `silence_bypass`）。原版 Toji 模块 9 自定义的 Game_Actor.isSkillTypeSealed 盖过了异化包装，参照 silence 例第 3 步沉默中不能用；重制照词条说明可用。回退：`o113_silence_bypass = false`（专项对照时关）。

## 验证

- 专项（工作树，并行 2）：`xiyou_alien_affix` 1103/1103；`xiyou_alien_` 其余与 `xiyou_attack_query`（待填最终一轮）。
- 偶发：（待填）

## 改了的原沙僧核心文件（待交叉核查点名）

- `battle_logic.gd`：`execute` 付费后 refresh_resources（P1）；`skill_cost` 加 `panel` 参数（缺省 false，调用处已 rg 全工程含 tests）；`can_use`、`execute` 付费、`apply`、`auto_battle_action` 的异化接点。
- `actor.gd`：`skills()` 饕餮吞噬。
- 测试：`tests/xiyou_attack_query.gd`（快照断言）、`tests/xiyou_alien_affix.gd`。

## 交接板

- 下一步：期 B 百相、无相；期 C 蚀术（八戒_85 续做，另起分支）。
- 用户试玩说明：异化装备的缄默、饕餮词条在战斗里生效；缄默技能沉默中也能放（O-113）。

## 可优化（流程／工具／效率）

- 建议：`xiyou_alien_affix` 的 HalfStream 整数取法（返回 2147483648）和原版 Math.random 0.5 不同（状态随机回合 3～5 原版取 4、重制取 5），涉及状态回合的用例只能用自然移除绕开；把 `_take("int")` 改成按 0.5 比例取整可让回合也对得上（预计省一类绕路，归规则车道，改前要跑全部异化专项）。

## 本分支提交

- 3ca06c9c P1／P3 付费刷新与快照断言
- （其余见 git log）
