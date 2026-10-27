# 交付：claude/bajie-review-mergemain-3

- 车道／工作者：核查／八戒（Claude，八戒_77）
- 状态：可合并（只改文档，代码没动）
- 基线：93f2e00b（claude/bajie-f2f5f6）
- 范围：沙僧 14 期集成（codex/passive-content-merge-main-in，dev.187，集成 HEAD 23519cff）里，期一、期二之外的其余 8 张原交付单。沙僧侧是一条线性链（d6045c3e..5761f01f），按每张单首次出现的位置切出各自的提交范围；四零散是 a6795df2 合进 2g 的第二父链。

**结论：8 张都通过，没有 P0、P1 或 P2。** 记了 3 条 P3，不挡合并，代码都没改；其中 1 条要总装分配编号。

## 逐张结论

| 原交付单 | 核查范围 | 结论 | 要点 |
| --- | --- | --- | --- |
| four-loose-fixes | 926f914f..b135ee33 | 通过 | 见下文 |
| state-effects-2g | dc65ca43^..026f6ee3 | 通过 | 见下文 |
| rng-compare-review | 026f6ee3..b495833a | 通过 | 只改测试，见下文 |
| actor-bonus | b495833a..7ef7584a | 通过，带 P3-1 | 见下文 |
| actor-bonus-states | 7ef7584a..7bfb4807 | 通过 | 见下文 |
| passive-content | 7bfb4807..eb6fff3f | 通过 | 见下文 |
| passive-content-power-books | 1132e919..34184d36 | 通过，带 P3-3 | 见下文 |
| passive-content-book-capacity | 34184d36..5761f01f | 通过，带 P3-2 | 见下文 |

**four-loose-fixes**
- ConsumeReduce 与 dsPassiveSkill 第 1260～1272 行、第 1825～1850 行逐项一致：
  - 按技能、按类型（Zj 是 stype 1，Mf 是 stype 2）、All 三项相加；
  - 封顶 100；MP 和 TP 各自 floor；
  - 只对角色生效，敌人不打折。
- cat 的 tpGap 豁免已删，1817 的 TP 改成严格比较。
- 敌人元素加成和冻结源 `installDamageElementRuntime.ownBonus` 一致：
  - 正则同为 `/gi`，全部匹配都相加；
  - 编号按数值比；
  - 对象是敌人本身、身上状态加行动表技能。
- 图鉴即时计数在期一已核过。

**state-effects-2g**
- 转换器只认整段 Battle 块 `user.gainTp(200);`／`user.gainTp(50);` 的 token 签名，执行走资源域 `gain`。
- 预览的 `context_for` 不借用真实的 lifecycle_context。
- 影子克隆跳过 lifecycle_context 和状态来源，其他属性的 detached 守卫没有放宽。

**rng-compare-review**
- 只改测试。半值流 OracleHalfStream 覆盖了 next_float、next_index_mod、next_int_inclusive 三个对外入口；next_uint 只在内部用。
- 原来五种种子的场景保留，半值只在 `xiyou_troop_events_half` 注入，没有删掉或放宽原检查。
- 状态 44 的检查本期没改。

**actor-bonus**
- 永久加算从 param_base 移到 `_param_plus`，和装备同层。对照原版：
  - MV paramPlus 本来就是 `_paramPlus` 加装备；
  - 小猫剑圣的「全量−去武器」差值里永久加成两边抵消，不会被放大；
  - 专属角色模块包装看到的值和原版一样含 `_paramPlus`。
- `XParamPlus.add` 之后调 `release_to_party`，对应原版 addParam→refresh→releaseUnequippableItems。
- 宠物后六项走 `traits_sum`。

**actor-bonus-states**
- 四个完整签名的 `param_add`。
- 克隆实例 `can_add_param` 为假，不写真实账本。
- `target_dead` 照原版：HP≤0 独立成立，死亡状态则要求已出现。

**passive-content**
- 生产代码只把效果 43 提到读 value1／value2 之前（道具 1998 缺这两个字段）。
- 其余都是对照测试，338 例。

**passive-content-power-books**
- 分档名单与冻结源 `CodexBossDifficulty` 的 strongIds、superStrongIds 逐个一致。`CodexZones.classOf` 也用这两份名单。
- 上限 3／4／6 一致。
- 普通遗忘只保护正式实例，与原版 `$gameActors._data[id]===this` 一致。
- CodexParamRate 照 Economy：已学技能逐项求和，再乘进 paramRate。

**passive-content-book-capacity**
- 与冻结 `itemEffectLearnSkill`／`checkPassiveSkillLimit` 一致：
  - 只有 stype 5 受限；
  - 按 `_targetActorId`（选定角色）的 skills() 计数，满了就返还本道具并预约 1317；
  - 直接 learnSkill 不受容量限制。
- CE1317 照整段原脚本翻译。

## P3 观察（不挡合并）

- **P3-1 优化项还没有编号**：actor-bonus 新加了可回退优化 `XPets.FIX_UNGRANTED_BONUS`（默认 true），至今没分到 O 编号，优化登记里也没有这一条。
  - 原版缺陷：宠物出战后新加入的角色没拿到属性，宠物休息时却照扣，会扣成负数。
  - 改法：只撤实际发过的加成；设为 false 恢复原版。
  - 变更记录 dev.187 里写的是「总装需分配 O 编号」。当前登记表已用到 O-103，建议分 O-104，补登记并改 `pets.gd` 的注释。
- **P3-2 偶发未复现**：book-capacity 交付单自己标了一次旧窗口没回列表，根因没证实，后来带轨迹运行没复现。本次 `xiyou_book_capacity_ui` 85/85 单次通过，也没复现。先记着，试玩时留意。
- **P3-3 付费遗忘后刷新不完整**：`XPowerBooks.forget_paid` 之后只调了 refresh_passive 和 refresh_resources。原版 refreshPower 是 `a.refresh()`（里面会 releaseUnequippableItems），再清战力缓存。现有五本权能书都不带装备许可标签，所以目前结果相同。以后权能书如果给装备许可，要补这一步。

## 验证

19 场全部单次通过，没跑全量和规则段，只改了文档。

| 张单 | 专项与项数 |
| --- | --- |
| four-loose-fixes | xiyou_loose_fixes 126、xiyou_cat 994、xiyou_enemy_book 93 |
| state-effects-2g | xiyou_state_effects_tp 537、xiyou_state_effects 19949、xiyou_formula_effects 908 |
| rng-compare-review | xiyou_recover_permanent 34、xiyou_troop_events 6574、xiyou_troop_events_half 2951（严格军团比较 19＋19） |
| actor-bonus | xiyou_actor_bonus 736 |
| actor-bonus-states | xiyou_param_states 582 |
| passive-content | xiyou_passive_content 113142 |
| power-books | xiyou_power_books 6136、xiyou_power_books_boundary 55682、xiyou_power_books_menu 1068、xiyou_power 137 |
| book-capacity | xiyou_book_capacity 918、xiyou_book_capacity_ui 85、xiyou_notice_options 72 |

日志：`03_再刷重制_Godot/04_验证/本地结果/20261027_八戒_期三/专项.log`（不入 Git）。

## 需要总装决定

- P3-1：给 `XPets.FIX_UNGRANTED_BONUS` 分配 O 编号（建议 O-104）并补登记，状态默认「待用户决定」。

## 待交叉核查

- 本单只改文档（执行者: Claude（八戒），核查: 待Codex）。

## 可优化

- 14 期的交付单是同一条线性链，原交付单里没写各自的起止提交，核查时要按每张单首次出现的位置自己切范围。建议以后多期连做的车道在交付单头部写「本期提交范围 A..B」。

## 变更记录草稿

## 2026-10-27 【Claude·八戒·未经Codex检验】核查沙僧 14 期集成期三：其余 8 张原交付单（dev.待定）

- 核查 23519cff（dev.187）期三：四零散、2g、随机对照、角色加成、永久状态、被动内容、权能五本、书籍容量 8 张都通过，相关 19 场专项单次全过。
- P3：宠物「未加先扣」修正 `XPets.FIX_UNGRANTED_BONUS` 尚无 O 编号，待总装分配；容量界面一次偶发未复现；权能付费遗忘后少一步卸装刷新（现有数据不触发）。
