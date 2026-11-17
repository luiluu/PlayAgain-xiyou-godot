# 交付：luiluu/cc-t104-gear-params

- 车道／工作者：T104 T012-b 二期：装备八项统一入口（cc，Opus＋medium，P8；甲档，请小A 主核、小o 第二道）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·T104·未经审查】天启篇期四装备八项统一入口 XTianqiGear.effective_params，读装备八项的地方逐个接（dev.待定）

- 照《天启篇_基础数值重构_v0.4》第五节第 1、6 条、第七节第 2 条「装备八项」那一行、第十节 T012-b 第 3、8 条。**只认期四总开关 `XTianqiBase.PHASE4`（默认关）**：关着、西游档一律返回实例原来的 `params`（同一个数组），逐字节同原来；装备实例一个字节不改、不写存档。
- `XTianqiGear.effective_params(装备)`（`core/tianqi_gear.gd` 末段 D 节）：开着、而且这件读表（`applies`：武器／防具、部位 1～10 且不在 `gear_base.json` 例外里、有 `<req_level>` 和品质标记、不是天启篇奖励装备）时
  - 新底子＝标准线(1＋装备等级×98÷90，等级夹 0～90)×部位系数×品质系数；主攻看原版那件（底装备模板）物攻、魔攻哪个高，一样高各一半；物防魔防都读 def 列；魔法上限表里没有部位系数＝0。七印装备（`qiyin` 标记）照同一张表，武器和真印再 ×1.1。
  - 加 换算比 ×（词缀固定属性＋镶嵌固定值＋宝珠固定加减＋吸取特效加的属性）：词缀按 `affixIds` 用 `XGear.affix_template` 重拼减底装备模板；镶嵌按 `upgrades` 历史从物品数据重算（同 `XGearUpgrade.apply_effects`）；宝珠按孔里的宝珠重算（同 `XRaceBattle.weapon_body` 的认法）；吸取视图＝视图减本体。换算比按装备等级查 `gear_base.json` 的 `ratio`，魔法借生命列。
  - 差值退路（稿第五节第 6 条）：实例里剩下的（随机镶嵌 1826～1828 的掷值、符文之语、别的没记录的成长）只在镶嵌历史里有随机项或有符文之语时才算，乘换算比后夹在新底子 ±10%；都没有时剩下的只是生成浮动，天启篇不算（同一件掷两次，有效八项一样）。
  - 按 `instanceId` 缓存；八项、镶嵌条数、词缀数组、等级、品质、宝珠变了就重算。`param_of(装备, i)`、`flat_ratio(装备, i)`、`applies`、`new_base`、`orb_fixed`、`upgrade_fixed` 一并给出。
- 接线（13 处，清单见下）：角色属性 `XActor._param_plus`、灵族武器本体 `XRaceBattle.weapon_body`（宝珠固定值按同一换算比扣）、战力评分 `XPower.equipment`（缓存签名用有效八项）、自动选装 `XEquipment`、排序 `XGearQuery.metric`、说明卡 `XHelpCard.desc_params`、装备信息 `gear_info`、检索标签 `gear_search`、物品状态 `item_status_painter`、商店对比三处 `shop`、新皮装备页 `XSkinEquipPage.main_param／param_of`、异化工坊 `alien_workshop`。
- `XTianqiBase.rows_state` 加 `gear` 一行（一致性断言跟总开关走），表头注释换成已接。
- 发行空壳特例补 `XTianqiGear.effective_params`（原样返回 params）、`param_of`：自动生成的是 `return []`／`0.0`，发行包会把所有装备八项清成 0，`发行空壳.py check` 只报了 `param_of`。
- 新专项 `xiyou_tianqi_gear_params` 35 项：关着同一个数组；开着武器／盔甲底子、主攻判定、浮动不算、词缀和镶嵌固定值 × 换算比、差值退路夹 ±10%（以及没有记录时丢掉）、七印武器／套装／真印、法宝／奖励装备／没等级需求的不读表、数据库原件也读表；开着但西游档原样；角色属性、灵族武器本体、排序、商店、新皮装备页、说明卡、战力读到同一组数；镶嵌和改等级后缓存重算。
- 玩家可见：无（总开关关着）。

## 直接读装备 params 的地方：完整清单（稿第五节第 6 条要求，核查照单查）

`git grep params` 在 `modes/xiyou/`（core、ui、battle、map，测试除外）共 70 个文件。逐个标：

**接了（改走 `effective_params`／`param_of`，关着同原来）**

| 文件:函数 | 读什么 | 怎么接 |
|---|---|---|
| `core/actor.gd` `_param_plus` | 身上每件装备的八项（经 `stat_list`），被动 WPNM／ARMM 放大也用这个数 | `param_of(e, i)` |
| `core/race_battle.gd` `weapon_body` | 灵族武器本体＝武器八项减宝珠固定加减 | `param_of`；宝珠那项 ×`flat_ratio`（开着时有效八项里宝珠已按换算比放大过） |
| `core/power.gd` `equipment` | 装备评分基础属性；缓存签名 | `applies` 时用 `effective_params`，签名也换成它；数据库原件（`base_params`）开着也读表 |
| `core/equipment.gd` `optimize` | 最强装备：八项之和 | `effective_params` |
| `core/gear_query.gd` `metric` | 按某项排序 | `effective_params` |
| `ui/help_card.gd` `desc_params` | 说明卡属性行（商人 29 页、成长说明经它） | `effective_params`（法宝照走 `XYunshang.relic_params`） |
| `ui/gear_info.gd` | 装备信息属性行 | `effective_params` |
| `ui/gear_search.gd` | 检索结果的属性小标签 | `effective_params` |
| `ui/item_status_painter.gd` `_equip_info` | 物品页装备八格 | `effective_params` |
| `ui/shop.gd` 三处 | 商店对比（购买页、按属性看全队、同类最低那件） | `param_of` |
| `ui/skin/skin_equip_page.gd` `main_param`、`param_of` | 新皮装备页候选行主属性与差值 | `effective_params` |
| `ui/alien_workshop.gd` | 异化工坊「装备属性」一行 | `effective_params` |

**故意不接**

| 文件 | 理由 |
|---|---|
| `core/gear.gd`（create／roll_item／combine／revert）、`core/gear_upgrade.gd`、`core/runewords.gd`、`core/orbs.gd`、`core/garou.gd`、`core/growth_forge.gd`、`core/tianqi_qiyin_equip.gd`、`core/tianqi_rewards.gd`、`core/fest_ring.gd`、`core/yunshang_orders.gd`、`core/alienation.gd`（借用效果空 params） | **写**实例的八项（生成、镶嵌、符文之语、宝珠、成长、锻造、七印生成、奖励装备）。实例必须照原版存，有效八项只在读的时候算 |
| `core/affix_absorb.gd`、`core/cat.gd`（sword_view 签名与翻倍视图）、`ui/gear_detail.gd`、`ui/merchant29_page.gd`、`core/xsave.gd`、`core/gear_query.gd:135` | 缓存键、存档校验、视图构造：比的是实例原数，换成有效八项反而会让键随总开关跳。178 持剑翻倍视图只给特性／被动缓存用，八项由 `_param_plus` 自己算两遍，已经走 `param_of` |
| `core/yunshang.gd` `relic_params`、`XActor.magic_param` | 法宝（类型 13），`gear_base.json` 例外：成长满相当于半件同级装备的规则属于法宝重构（稿第五节第 2 条末），不读这张表 |
| `ui/inlay_book.gd` | 符文之语／镶嵌图鉴显示的是**配方模板**加的数，不是哪件装备；开着时这些加值落在差值退路里（夹 ±10%），图鉴照原数。要不要按换算比显示见下「我不同意的地方」第 4 条 |
| `core/enemy.gd`、`core/power_enemy.gd`、`core/fest_road.gd`、`core/guardian_rework.gd`、`core/tianqi_horsemen.gd`、`core/tianqi_qiyin_rule.gd`、`core/tianqi_qiyin_dragon_run.gd`、`core/tianqi_death_alien.gd`、`core/tianqi_gojo_trial.gd`、`core/tianqi_summit.gd`、`core/tianqi_sect.gd`、`core/gojo.gd`（敌人记录）、`core/cat.gd:759`（龙） | 敌人八项，不是装备 |
| `core/actor.gd:1215`、`ui/actor_book.gd`、`core/actor.gd:1263`（custom params） | 职业曲线、<Custom Parameters>（公式参数，按等级和变量求值，不看实例八项） |
| `core/power.gd` `state_params`、`core/battler.gd`、`core/state_effects.gd` | 状态的八项倍率、状态效果的参数列表 |
| `core/tianqi_skills.gd:1473` | 技能卡成长配置的 params 字段 |
| `core/tianqi_alien_affix.gd`、`core/tianqi_elements.gd`、`core/mv_event_core.gd`、`core/rift.gd`、`map/*`（6 个）、`ui/map_transfer.gd`、`core/hang_up.gd`、`ui/hang_up_options.gd`、`ui/message_box.gd`、`core/designation.gd`、`battle/battle_scene.gd`、`battle/boss_hp_bar.gd`、`core/demon_crown.gd`、`core/garou.gd` 注释 | 事件指令 parameters、插件参数、词条参数表、注释，与装备八项无关 |
| `ui/status_page.gd`、`ui/equip_scene.gd`、`ui/skin/skin_gear_detail.gd`、`ui/enemy_book.gd`、`ui/item_status_painter.gd:19`、`core/yunshang.gd:1558` | 只读术语表 `terms.params`（属性名），或读角色 `a.param`（已经过 `_param_plus`） |
| `core/tianqi_base.gd` | 表头注释（本单改成已接） |

## 交接板

- 下一步：T012-c 翻总开关前，界面几处（说明卡、商店、新皮装备页）开着时实机看一眼数字量级；`gear_base.json` 魔法列、武器副属性（见下）等协调／Kyo 定。
- 用户试玩说明：无（暗装，总开关关着）。
- 需要用户决定：无（下面几条是口径，按默认做了，协调看要不要转 Kyo）。

## 我不同意的地方／口径（按默认做了，请协调看）

1. **武器、防具原版自带的「副属性」开着时没了**：例如魔钢匕首原版物攻 56、敏捷 10，开着只剩物攻 656（武器部位表只有主攻）；净化长袍原版魔法 300、敏捷 10 也归零。这是稿「只换底子」的直接结果，但原版有不少靠副属性区分的装备（加敏捷的匕首、加魔法的法袍）。建议：要么认（差别交给词条，稿原意），要么 `gear_base.json` 给「原版这一项非零就给一小份」的规则。T012-c 量之前定一下。
2. **魔法上限**：部位表没有魔法列，开着装备不给魔法上限（词缀、镶嵌加的魔法照换算比给）；换算比也没有魔法列，借了生命列（标准线两者都是 ×25）。
3. **差值退路触发条件**：只在「有随机镶嵌（数据里只有 1826～1828 三种材料）」或「有符文之语」时算。符文之语的加值其实能按模板重算（`XRunewords.template_id`），我没做，落在 ±10% 夹值里——符文之语原版加得多的（几十到上百）开着会被压小。要精确的话可以补一条按模板重算，属于本单范围外的细化，先报。
4. **镶嵌图鉴（inlay_book）**照原数显示配方加值；开着时实际加到装备上的是 ×换算比（固定镶嵌）或夹值后的（符文之语）。T012-c 前要不要在图鉴里也乘换算比，看界面要求。
5. **1～9 级的约 20 件神话**（多带 `req_actors`）照读表（D137「专属武器八项同样读这张表」），1 级底子很小；没有加例外。
6. 法宝不读表（例外），开着时法宝八项还是原版量级，相对新量级几乎没有；这是法宝重构那条线的事，不在本单。

## 可优化（流程／工具／效率）

- 建议：`发行空壳.py check` 的 PASSTHRU 识别只认「return … 参数名」，像 `return item.get("params", [])` 这种原样传回参数字段的没认出来，按类型给了 `[]`，check 不报（本单 effective_params 就是这样，发行包会清空全部装备属性）。建议把「返回参数的字段（参数.get(...)／参数.字段）」也算 PASSTHRU、强制写特例（收益：防一类发行包静默坏；归工具车道，Sonnet＋medium）。

## 待交叉核查

- 甲档。改了原 Codex 核心文件 `core/actor.gd`（`_param_plus` 一行）；另 `core/race_battle.gd`、`core/power.gd`、`core/equipment.gd`、`core/gear_query.gd`、`core/tianqi_gear.gd`（新 D 节）、`core/tianqi_base.gd`（rows_state、注释）、7 个界面文件、`07_开发环境/发行空壳特例.json`。
- 请重点看：①关着时每处逐字节不变（`effective_params` 第一句 `not PHASE4` 直接返回同一个数组；`flat_ratio` 恒 1；`power` 的 `eff == null`）；②缓存过期条件够不够（卡的改写视图是浅拷贝，所以没比对象本身）；③清单里「故意不接」的理由。

## 验证

- `xiyou_tianqi_gear_params` 35／35（本机）。
- `语法检查.py` 通过；`发行空壳.py check` 通过（628 个函数）；`工具回归.py` 全部通过。
- 并入 main（b501d4b8b，T137／T146，没冲突、没碰切片转换器探针）后 `检查.sh --oracle --affected main --cloud`：云端选测 535 个场景、16 片全部通过（提交 2518a70ad，运行页 actions/runs/44074163555；`xiyou_again_use` 一次偶发、单跑通过），MV 参照引擎过、发行空壳覆盖过，退出码 0。之后只加了交付单。

## 进度账

- 天启篇基础数值重构期四：T012-a 填表 → T012-b 接线（T081）→ T012-b2（T130）→ T012-b3（T137）→ **T012-b 二期装备八项（本单）** → T012-c 量 K、翻开关。
