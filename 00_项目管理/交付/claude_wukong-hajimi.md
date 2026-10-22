# 交付：claude/wukong-hajimi

- 车道／工作者：A 内容·角色／悟空（Claude，悟空_37）
- 状态：进行中
- 本分支从 `claude/wukong-next`（一期，xiyou_rules 拆四份）的交付提交切出，含一期提交；一期交付单 `claude_wukong-next.md` 随本分支一起合即可。

## 变更记录草稿

## 2026-10-22 【Claude·悟空·未经Codex检验】178 哈基米第一期：招募、能力值与持剑翻倍、剑技公式（dev.待定）

- 做了什么：
  - **原版查清**：哈基米不是单独文件，是 `installImportedBalanceRuntime.js` 第 50～278 行「小猫剑圣 v1.0」段（`W.CodexCat` 1.0.1）。数据库记录（角色 178、职业 176、技能 10437～10450、状态 2713～2717、号角 2899、进阶石 2900、法宝 7999、敌人／敌群 1999、公共事件 9017／9018）都已在 `data/*.json`，开机只多登记一个强者编号与巨龙固定能力值，不用转换器复现。
  - **参照**：新探针 `03_转换工具/mv_oracle/cat_probe.cjs`（13 例，产物 `cat.json`，已登记同步探针表与只增接受键）：模块编号；刚生成的槽位与双持；`CodexCat.recruit()`（入队、学 6216、忘 6235、生成并装上法宝 7999 与练习剑 2、背包不留、第二次返回 false、号角入队后不可用）；8 种装备配置（无、练习剑 2、法宝、两者、带特性 22 的剑 56、带元素增幅的剑 671、带 passiveHarmRi 的剑 1044、非剑的木棒 3）× 1／9／10／35／65／99 级的 param／paramPlus／xparam／sparam／元素增幅／攻击次数加值；五个剑技 × 10 个等级 × 未持剑／持剑＋法宝的 `CodexCat.formula`。
  - **实现**：新增 `core/cat.gd`（XCat）。
    - `actor.gd`：`equip_slots` 去掉副手、`is_dual_wield` 对 178 恒假；新增 `param` 覆写走 `XCat.param`（10 级起学了 10442 速度 ×1.88，装着 7999 时攻击／速度／幸运 ×1.6）；`sparam` 6／7 持剑 ×0.8／×0.88；`param_plus` 持剑时＝全量＋(全量−去掉武器槽)；新增 `stat_equips()`（持剑时武器槽换成 `XCat.sword_view` 翻倍视图），`trait_objects` 与 `refresh_passive` 改读它（非 178 与 `equip_list` 相同）。
    - 转换器 `formula_program.py`：整条公式是 `CodexCat.formula(user,item,b)` 的五个技能编译成 `status: "module", module: "cat"`（`MODULE_FORMULAS`，原文去空白后精确匹配），`xiyou_export.py` 统计加 `moduleSupported`；`formula_execution.gd` 的 `run_item` 按 module 分派到 `XCat.formula`（2 行）。全库公式拒收 81→76。
    - `mv_script.gd`：公共事件 9017 的 `CodexCat.recruit()` 走 `XCat.recruit`；标记照原名记在 `s.flags`（`_codexCatRelicGranted`、`_codexCatStarterGranted`），不改存档结构。
    - `xui.gd` `icon_texture`：图标 280000～280008 画切片新带的 `img/system/CatSwordSaint_Icons`（2 行）。
  - **测试**：新 `xiyou_cat` 622 项；把 XCat.param／sparam／持剑判断临时关掉时 341 项失败，证明测得出。
  - **加回**：178 加进切片 `actors`、`xiyou_actor_p0` 新增 `RECRUIT_8 = {9017: 178}`；`systemImages` 加 `CatSwordSaint_Icons`。
- 验证（车道不跑全量，只跑相关专项）：（待写）
- 未完成／已知问题：
  - **战斗里剑技还打不出伤害**：剑技的行动序列只有 `CAT BEGIN`，原版靠 `processActionSequence` 包装逐段插 `CAT STRIKE`（连携、剑心、识破／剑痕、按段 Game_Action）。Godot 的 `action_sequence.gd` 不认这条指令，跳过，所以 10437～10440 现在只扣 TP 不出伤害；普通攻击正常。下一期做（要在 `action_sequence.gd` 挂一两行，或等八戒行动序列这期合并后再挂）。
  - 技能使用条件（剑技要持剑、等级、至圣斩冷却、试炼不在战斗中、剑影不可直接用）、进阶（Godot 没有角色进阶次数，`XCat.advanced` 恒假，35 级后成长恒 1、额外行动不加）、守誓巨龙试炼（9018）、号角 2899 入队后不能用、Map132 商店补号角（Map132 不在切片）、帮助卡里的动态说明（`C.helpText`）都没做。
  - 熟练度：Godot 技能熟练度首期恒 0，`XCat.mastery` 照原版写了但读到的都是 0；剑技备注的 `Custom DAMAGE Mastery Formula` 同样没生效（原版新游戏里也是 0 级，结果一致）。
  - 招募时原版对法宝槽、练习剑装备失败会抛错，Godot 只 push_error 并返回 false。

### 给沙僧的提案（damage.gd，不由本车道改）

1. **元素增幅翻倍进伤害**：`XDamage._yep_objects` 现在直接读 `x.equip_list()`，178 持剑时剑的 `Element Amplify／Magnify` 翻倍读不到（`xiyou_cat` 里 671 剑这一项改比视图本身）。改成 `x.stat_equips()` 一词即可（非 178 返回值与 `equip_list` 相同）；`critical_multiplier_bonus` 同理。
2. **伤害钩子 cat-sword**（原版 `CodexDamageHooks` 的 build／enter，178 持剑才生效），等「模块挂接点表」接口：
   - build（行动者 178 持剑、技能是四个剑技或剑影 10445）：`normalAdd += 6`；元素 1、8 的 `elementAdd += 6`（加在元素加成上）；学了 10443 时 `finalAdd += 8`、`criticalAdd += 12`，进阶后结算倍率 ×2。
   - enter（目标是持剑的 178，抱剑护身）：`harmRe[1] += min(16000, ⌊3×速度⌋, 15030＋⌊速度/8⌋)`，元素 2～9、11～15 各 `+= min(18000, ⌊3.2×速度⌋, 16400＋⌊2×速度/11⌋)`；目标是敌人 1999（守誓巨龙）且 `(回合−1) % 5 ≠ 3` 时 `harmRe[1] += 1e11`、`harmRe[8] += 5e10`。只在本次结算里生效、结束后还原。
   - XCat 可以提供 `XCat.damage_frame(item, a, b, frame)` 由挂接点调用，数值逻辑放在 cat.gd，damage.gd 只留调用。参照：再补一批 `cat_probe` 伤害例即可对照。
3. 其余 167～177 的模块也都往 `CodexDamageHooks` 挂了钩子（谷雨 175 除外），挂接点表做好后各人都能用。

## 交接板

- 下一步：0d 条改为「178 哈基米第一期已加回（招募、能力值、剑技公式；剑技连携 CAT BEGIN／STRIKE、使用条件、进阶与试炼、伤害钩子未做）；167～177 按预检表排期，都依赖 damage.gd 模块挂接点」。
- 用户试玩说明：哈基米可以通过公共事件招募（自带法宝抱剑喵铃与练习剑），能力值与原版一致；**他的剑技在战斗里暂时打不出伤害**，普通攻击可用。
- 需要用户决定：无（是否在剑技连携做好前先不开放招募，由总装定；默认照现在开放）。

## 进度账

- 角色：178 第一期，粗估 +0.03 点，交沙僧复核

## 本分支提交

- 638f8b6、fb426a1 一期（见 claude_wukong-next.md）
- 4ea173d 178 哈基米第一期：XCat、cat_probe 13 例、xiyou_cat 622 项
