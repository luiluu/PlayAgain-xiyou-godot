# 交付：claude/bailong-yomi

- 车道／工作者：白龙·专属角色期一 169 黄泉／白龙（Claude，重制_白龙_5）
- 状态：可合并

## 变更记录草稿

## 2026-10-26 【Claude·白龙·未经Codex检验】169 黄泉第一期：XYomiJingliu 共用框架、能力值／被动、公式、伤害钩子、号角招募，切片加 169（dev.待定）

- **依据**：正式 `js/codex/runtime/installNativeYomiJingliuRuntime.js`（W.CodexYomi／W.CodexJingliu，169 黄泉与 170 镜流共用一个模块）。本期做共用框架与黄泉，镜流下期；做法照 167／168／172／173 的第一期（XActorModules）。
- **新模块** `core/yomi_jingliu.gd`（XYomiJingliu）：文件头写了每层包装对应原版哪段与「未移植」清单。
  - 能力值：paramPlus 学了 10176 幸运＋888、10177 速度＋777、10182 攻击＋888；param 进阶 2 次且学了 10186 攻击＋floor(幸运×1.88)；xparam 学了 10185 暴击＋9.99（原版不生效，见下「与原版不同」）；actionPlusSet 学了 10175 追加 1（必定再动）。
  - 公式 `CodexYomi.damage(a,b,id)`（10171～10174）：按目标负面状态数 n（2627 集真赤或备注 `<BuffType:破甲|损伤|毒|…>`，不重复计）线性加，攻击／速度／幸运三项系数照原表。转换器 `formula_program.py` 把这四条登记为模块公式 `yomi`，`formula_execution.gd` 分派到 XYomiJingliu.formula。
  - 伤害钩子 yomi-jingliu（原版 `CodexDamageHooks.push`，装在 number-pools 3 与 sukuna 7 之间）并进 XActorDamageHooks（顺序号 3 不变）：物理；物理受伤率与属性抗性穿透各 0.22×（10178／10181／10184 进阶 1／10186 进阶 2）；10179 普通伤害＋0.88；10180 雷＋0.77；10183 暴伤＋6.66；10185 技能倍率 ×16.55（10174 为 ×1.33）；戴赤雨双缨且目标有集真赤（10174 除外）×1.77。
  - **原版里不生效的几层没移植**：模块还包了 makeDamageValue（同样几项乘法）、applyCritical、sparam(6)、calcElementRate，但 installDamageElementRuntime（main.js 装在本模块之后）整个换掉 makeDamageValue、不回调旧链，这几层实际走不到，伤害只走上面的钩子。
  - 招募（公共事件 9004 `CodexYomi.recruit();`）：已在队不做事；没戴赤雨双缨 4578 时背包有就拿、没有就生成，装进它装备类型的槽；入队；右上角两条提示「小伙伴 黄泉 加入队伍」「获得并装备专属法宝：赤雨双缨」。`mv_script.gd` 认这条脚本。
  - 开机数据：本模块不在运行时改 `$data*`（只核对数据在不在、预载图标），转换器无需复现。
- **挂点**（沙僧独占文件只加单行）：
  - `core/actor.gd` `action_plus_set()` 末尾 `XActorModules.action_plus_set(self, out)`（新增一行）。
  - `core/actor.gd` `_param_plus()` 末尾 `return v` 改为 `return XActorModules.param_plus(self, i, v)`（改一行）。
  - battler.gd、damage.gd 未改。param／xparam 用已有挂点。
- **与原版不同（原版缺陷，待总装分 O 号登记优化登记）**：10185 说明写「暴击率＋999%」，原版包的是 `Game_BattlerBase.prototype.xparam`，但 dsPassiveSkill 在插件加载时已把 `Game_Actor.prototype.xparam` 存成别名 `_Game_Actor_xparam`，角色的 xparam 走不到这层包装，加成实际不生效（slice_probe 65／99 级参照暴击仍是 0.55）。重制照说明生效；回退＝`XYomiJingliu.CRIT_FIX` 改 false。`xiyou_rules` 比角色等级采样时，按这个开关给参照 xparam[2] 补 9.99。
- **说明卡**：`ui/character_help.gd` 黄泉「段数」行改调 `XYomiJingliu.repeats(a, id)`（同一公式，供第二期 numRepeats 共用）；幸运现在含 10176 的＋888，段数随之跟原版一致。
- **人物图鉴**：169 进切片后 SV 图随之导出，照参照画数据库 battlerName `Codex_Yomi_SV`；`xiyou_actor_book` 的 NO_SPRITE 移出 169。
- **切片**：`xiyou_slice.json` actors 加 169；`xiyou_actor_p0` RECRUIT_8 加 9004→169（招募、初始装备技能、参照行、伤害行、actor_passive 各等级对上）。
- **未移植（第二期）**：必中不闪避、集真赤与随机负面、残梦（满 9 层放 10174）、numRepeats 连击、扩散伤害、技能使用条件与消耗、隐藏呼吸技能分类、图标与品质色、Map132 商店补号角、旧档迁移；镜流全部。
- **测试**：`xiyou_actor_modules` 加黄泉 22 项（技能表、追加行动、公式含负面计数、能力值加成、进阶 2 攻击、穿透、钩子帧操作、招募）。
- **同步**：worktree 跑 `同步正式西游.py --accept-additions`（新增用例已接受：slice_d1～d6 加 169 与 1252 条伤害行、actor_passive 加 5 个 169 用例、help_cards／wtype 相应增加；另有同批 main 带来的 Map069／088／089／091／112 等）；`内容覆盖检查.py` 无基线外新问题（hard 0、new 0）。
- **验证**：`检查.sh --affected main --oracle`（129 个场景）：首轮 rules_d1c～d6c 各 2 项（169 lv65／lv99 xparam，即上面 10185 的原版缺陷）失败，其余 123 个全过；修后单跑 `xiyou_rules_d1c～d6c`（各 115746／115746）、`xiyou_actor_modules`（56／56）、`xiyou_help_card`（992／992）、`xiyou_actor_book`（22／22）、`xiyou_actor_book_review`（6／6）全过。非 Godot 项只有「失效链接 交接板.md -> a」（main 的交接板正文「[萧萧](a)」，不是本分支改的）。169 伤害行在六难度全部对上 mv_oracle。

## 交接板

- 下一步：白龙期二 170 镜流（同模块：paramBase 星魂、技能整理 normalizeJingliuSkills、公式、钩子、招募 9005）；黄泉第二期（战斗机制）待排期
- 用户试玩说明：用黄泉号角（公共事件 9004）能招募黄泉并自动装上赤雨双缨；黄泉技能伤害、学到被动后的幸运／速度／攻击与暴击加成、必定再动一次与原版一致。连击段数、扩散、残梦、集真赤等战斗机制下一期，现在黄泉技能只打一段、不挂印记
- 需要用户决定：黄泉 10185「暴击率＋999%」原版不生效，重制默认照说明生效（CRIT_FIX，可回退）——总装分 O 号登记

## 进度账

- 专属角色模块：167／168／172／173 之后加 169（第一期），完成度按总装口径＋1 个角色

## 可优化（流程／工具／效率）

- 无（本轮临时输出都在会话 scratchpad，工作树没留临时文件）

## 本分支提交

- 2d18e477 WIP：169 黄泉第一期接线（XYomiJingliu、挂点、伤害钩子、模块公式、号角招募、切片、专项）
- 33eafe73 10185 暴击原版不生效，重制照说明生效、CRIT_FIX 可回退；xiyou_rules 按开关比参照
- 845cdbf6 人物图鉴 169 照参照画 Codex_Yomi_SV
- （本提交）交付单
