# 交付：cc/save-rng-facade

- 车道／工作者：C 规则·存档与随机／cc 车道（Opus＋high，协调派单 task_80144e6aa6f3）
- 状态：可合并

## 方案（第一步，只读，2026-11-14）

依据：私密设计仓《天启篇整体架构（二）代码结构 v0.1》第四节「存档」「随机」、第五节「存档门面」「随机门面」、第七节短表；Kyo 11-14 读档总原则：**打完或点完就出结果的（含一场战斗掉哪几件装备，按这个存档的第几场战斗定）读档都不变；战斗过程（先手、暴击）可以变。**
基线：main `d45643f0b`（元素、核查返修已合）。在跑分支只读：`cc/tianqi-seed-fix` 到 `8ab6a8250`（返修四），`cc/save-data-cleanup` 到 `9f333861f`。路径相对 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/`。**没跑 Godot，没改代码。**

### 结论先说

1. **存档门面 `XTianqiSave`**：一张分区登记表（分区 → 现行版本、默认值、迁移函数、关开关时的反迁移），版本统一记在 `flags.tianqi.v`；**唯一的读档后入口挂在 `XState.from_dict` 末尾**，这样 `to_dict`→`from_dict` 的测试也走得到。分区**仍是用到时才建**（不在读档时一次建全），因为有模块拿「这个区在不在」当判断（招牌掉落「没账的不新建」、元素「老档没有 elements 不重建」）。
2. **随机门面 `XTianqiRandom`**：三类流——存档派生流（域＋稳定键＋计数）、战斗流（布阵与奖励按「本档第几场」钉住，回合内照旧可变）、表现流（随便取但要标注）。**现有各种存档派生写法只「搬家」不改公式**，老档的结果序列一个都不变，不用 Kyo 拍板也不用写一次性改变。
3. **普通战斗掉落钉住**的做法：天启篇存档里，战斗奖励流的种子改由「存档种子＋战斗键」派生，战斗键存进 `flags.tianqi`；奖励流再**按敌人分子流**（`敌人 stable_id＋用途`），所以谁先倒下、一共倒了几个都不影响别人掉什么；掉出来的装备用来源键 `b|战斗键|敌人|第几件` 入包——**正好接上 seed-fix 返修四的「来源键」机制**（招牌掉落已经是 `sig|键`），装备的随机身份、天启篇词条、底子数值（改绑 `XGear.roll_fn`）全部跟着钉住。西游档不进这条分支。
4. 分 6 批（存档 3 批、随机 3 批），每批可独立合并、带开关可回退；**随机门面第一批要等 seed-fix 合并**，存档门面第一批现在就能开（只最后一行挂钩等 seed-fix 合并后再加）。和 save-data-cleanup 不碰同一段。
5. 要 Kyo 定的 3 条，都带推荐（见第 4 节）：战斗键用「全局第几场」还是「这个敌群第几次」（推荐后者，理由是前者打一场小怪就能换掉 boss 的掉落）；开战布阵时掷的（异化挂谁、删栏重抽）算不算结果（推荐算）；西游档不钉（推荐）。

---

### 1. 存档门面

#### 1.1 `flags.tianqi` 字段清单（main d45643f0b＋seed-fix 分支，谁写谁读）

| 键 | 归属模块（写） | 主要读者 | 怎么建 | 现在的旧档处理 | 门面里的版本／迁移 |
|---|---|---|---|---|---|
| `rules` | `tianqi.gd` `start_new_game`（:235） | `XTianqi.active`（全工程门） | 开局一次 | 只判 `>= 1` | 根字段，不进分区；`v` 记 `root:1` |
| `difficulty` | 同上 | `tianqi_balance`、`tianqi_trim`、`gojo`、`tianqi_horsemen`、`tianqi_combat`、`tianqi_seg_alien`、`tianqi_weak_clear`、`tianqi_money`、`tianqi_trumpet`、`tianqi_elements`、`guardian_rework`、`zhenqi`、`tianqi_affix_roll`（14 处直读） | 开局一次 | — | 根字段；读者以后走 `XTianqi.row(s)`（战斗门面那一单），本单不动 |
| `lineup` | 同上 | `tianqi.gd:496` | 开局一次 | — | 根字段 |
| `draws`、`offer` | `tianqi.gd` 抽角色（:476、:487） | 同文件、`ui/` 抽角色页 | 用到时 | 缺当 0／缺当没抽 | 分区 `lineup_draw`（只登记，不搬键：两个键在根上，挪位置要迁移，收益小） |
| `line` | `tianqi.gd:617` | `XTianqi.line_of`、`tianqi_line` 等 19 处发行门旁 | 选线时 | — | 根字段 |
| `war`／`famine`／`plague`／`death` | `tianqi_line.gd:156` `progress(key)` 通用补 `{stage, seen}`；各线自己再加 `survived`、`cleared` 等 | 各线 `tianqi_*_line.gd`、`tianqi_horsemen` | 用到时 | 就地补 | 4 个分区，默认 `{stage:0, seen:[]}`，v1 |
| `famine_prologue` | `tianqi_famine_line.gd:36` | 同文件 | 用到时 | 就地补 `[]` | 分区（数组型） |
| `summit` | `tianqi_summit.gd:72` | 同文件 | 用到时 | 就地补 `{}` | 分区 |
| `reincarnate` | `tianqi_line.gd:397` | `tianqi_line`、`ui/save_scene.gd` | 一次 | 缺当 false | 根布尔，登记即可 |
| `weak_clear` | `tianqi_weak_clear.gd`（`FLAG`） | 同文件 | 用到时 | 缺当没有 | 分区 |
| `rewards` | `tianqi_rewards.gd:63-68` | 线奖励、`tianqi_alien_gear`（异化核） | 用到时；**`flags.tianqi` 不存在时会建一个空 `tianqi` 区** | 就地补 | 分区；门面的 `section` 在非天启篇档上返回不落盘的空表，不再建空区（行为变化，带开关，见 1.6） |
| `qiyin`（`opened/keys/shards/drop/bag/artifacts/field_keys/seed/rng_n/artifact_miss/dragon`） | `tianqi_qiyin.gd:101-116` `progress` | 七印全家（`_equip`、`_drop`、`_dragon_run`、`_rule`、`_show`、界面） | 用到时；逐键补；老档缺 `seed` 由 `orb_seed` 派生 | 逐键就地补 | **打样分区**：v1＝现在的逐键补搬进 `migrate`，`default` 里 `seed` 是函数（按 `orb_seed` 派生，公式不变） |
| `drop`（`seed`、`pity`） | `tianqi_drop.gd:245-255` `store` | 招牌掉落、图鉴指路 | 用到时；`seed` 由 `orb_seed` 派生（开关关时 `randi()`） | 就地补 | **打样分区**；`PITY_RESET_ON_SURE` 依赖「没账不新建」，所以保持懒建 |
| `elements`（`seed/floors/fixed/dropped_books/book_fails`） | `tianqi_elements.gd:102-113` `store`（11-14 新合） | 元素全家 | 用到时；`seed`＝`hash32([tianqi_elements, orb_seed, 难度])` | 「老档没有 elements 就不重建牌组」 | 分区；保持懒建 |
| `money` | `tianqi_money.gd:69` | 金钱重构 | 用到时 | 就地补 | 分区 |
| `trumpet`（`dropped`、`fails`） | `tianqi_trumpet.gd:265` | 号卷 | 用到时 | 就地补 | 分区 |
| `skill_grow` | `tianqi_skills.gd:1309` | 同文件 :1288 | 用到时 | 就地补 | 分区 |
| `no_diff_passive` | `tianqi_no_diff_passive.gd`（`MARK`） | 同文件，`XState.sync_difficulty_after_load` 里跑 | 新开局记；读档剥／补 | 自带标记，开关关时反迁移 | 并进 `v`：`v.no_diff_passive`；旧 `MARK` 键只读兼容一个发行版本 |
| `gojo_trials`、`gojo_adv_v` | `tianqi_gojo_trial.gd`（`PASSED_KEY`、`MIGRATE_KEY`） | 同文件，`XSave._load_data` 里跑 | 开局／入队记版本 3；读档按档型迁移 | 自带版本 3、反迁移记 2 | **打样分区** `gojo`：`v.gojo` 取代 `gojo_adv_v`（旧键只读兼容）；`migrate` 就是现在的 `migrate`；反迁移登记为 `revert` |
| `affix_roll_n`、`affix_src_n`（seed-fix 返修二、四） | `tianqi_affix_roll.gd` `_default_rng` | 同 | 用到时 | 缺当 0 | 随机门面的计数区 `rng`（见 2.3），不另开分区 |
| `src_n`（seed-fix 返修四） | `tianqi.gd` `on_register` | 同 | 用到时 | 缺当 0 | 同上 |
| （在跑）教派 `tianqi-sect-b`／`-ren` 若加键 | — | — | — | — | 合并时按登记检查（1.5）补登记 |

`tianqi` 区之外：`flags._gojoTrial`（进行中的试炼，`XSave._load_data` 里还原）——登记成「区外键」，不搬；顶层 `lotteryRandom`（西游也用，O-389）不归天启篇门面；全局配置的 4 个 `codexTianqi*` 是局外数据，不归存档门面。

**装备上的键**（登记表 `GEAR_KEYS`，键 → 归谁、复制时带不带走）：`tianqi_affixes`、`tianqi_prefix`、`tianqi_desc_base`（词条，带走）；`qiyin`、`tq_reward`、`tq_reward_fight`、`tq_relic_target`、`tq_relic_death`、`tq_seal_war`、`tq_seal_death`（来源标记，带走）；`tq_reforges`、`tq_bought`、`tq_buy_price`（金钱，带走）；`tq_seed_id`（随机身份，**不带走**）、`tq_rng_n`（装备上的随机计数，**不带走**，复制品从 0 开始）。seed-fix 在魔冠重发、云裳发货、仓库原版复制三处手写了「去掉 `tq_seed_id`」，门面合并后这三处改叫 `XTianqiSave.strip_on_copy(item)`，以后新加不带走的键只改登记表。

#### 1.2 门面接口

```gdscript
class_name XTianqiSave  # core/tianqi_save.gd
## flags.tianqi 的分区登记、默认值、版本与迁移。规则见本文件头注释，也抄进车道须知短表。
static var ENABLED := true   # O-待定：false＝after_load 不跑登记表里的迁移（各模块旧的就地补照旧生效，见 1.6）
const SECTIONS := {
	"qiyin": {"v": 1, "default": "_qiyin_default", "migrate": "XTianqiQiyin.migrate"},
	"drop":  {"v": 1, "default": "_drop_default",  "lazy": true},
	"gojo":  {"v": 3, "keys": ["gojo_trials"], "migrate": "XTianqiGojoTrial.migrate", "revert": "XTianqiGojoTrial.revert", "legacy_v": "gojo_adv_v"},
	...
}
const ROOT_KEYS := ["rules", "difficulty", "lineup", "line", "draws", "offer", "reincarnate"]
const OUTSIDE_KEYS := ["_gojoTrial"]   # flags 顶层，归天启篇
const GEAR_KEYS := {"tq_seed_id": {"owner": "random", "copy": false}, ...}

static func root(s) -> Dictionary          # 天启篇档返回 flags.tianqi；非天启篇返回不落盘的空表
static func section(s, name) -> Variant    # 取分区；缺了按默认建并记 v；缺键按默认补（默认值可以是按存档算的函数）
static func peek(s, name) -> Variant       # 只看不建（给「没账就不新建」这类判断用）
static func version(s, name) -> int
static func after_load(s) -> void          # 唯一读档后入口：按 SECTIONS 次序逐个比版本、跑 migrate／revert；幂等
static func strip_on_copy(item) -> void    # 复制装备时去掉 copy=false 的键
```

- 迁移函数签名统一 `migrate(s, from_v) -> void`，`from_v` 是档里的版本（没有记录＝0）；登记表写函数名字符串、门面里逐行直呼（不依赖「数组里存静态函数引用」，第二份附录说这个写法没做小样验证）。
- 版本放 `flags.tianqi.v = {分区: 版本}`。**分区存在但 `v` 里没记**＝老档，`from_v = 0`，跑一次 v0→v1（就是把现在 `progress()`／`store()` 里的「缺键就地补」搬过去，结果逐键相同）。**分区不存在**不建、不记，等第一次 `section()` 时按默认建、记现行版本。
- 反迁移（关开关读档还原）：分区登记 `revert`；`after_load` 在模块开关关着时调 `revert(s)`，由模块把 `v` 记成它认的旧版本（五条悟现在就是这么做的，记 2）。
- 两个自带标记（`no_diff_passive`、`gojo_adv_v`）读的时候「新 `v` 优先，没有就看旧键」，写只写新 `v`；旧键保留一个发行版本后由「开关退役」那条删。

#### 1.3 读档后次序

现在两处入口：`XState.from_dict` 中段的 `sync_difficulty_after_load`（含难度被动 `sync_after_load`，在 `_become_current` **之前**）；`XSave._load_data`（五条悟还原＋迁移、星辰仓库事务等，需要存档原文或存档位）。seed-fix 又在 `from_dict` 末尾加了 `XTianqi.assign_all`。

目标次序（写进 `after_load` 头注释）：

1. `from_dict` 中段：难度被动照旧在 `sync_difficulty_after_load` 里（它要在角色能力刷新之前剥被动，挪位置有风险）；只是读写标记改走 `XTianqiSave.version`。
2. `from_dict` 末尾、角色 `param_refresh` 之前：**`XTianqiSave.after_load(s)`** 一行，依次：
   1. 各分区 `migrate`／`revert`（登记表次序：根 → 四线 → 七印 → 掉落 → 元素 → 金钱 → 号卷 → 技能 → 五条悟版本迁移）；
   2. `XTianqiRandom.after_load(s)`：给老装备补随机身份（seed-fix 的 `assign_all`，挪到这里调用，顺序与公式不变）。
3. `XSave._load_data`：只留确实要用原文或存档位的——五条悟**试炼现场还原**（`_restore`：改队伍）和星辰仓库事务。五条悟的**进阶版本迁移**挪到第 2 步（它只改 `actor_advance` 和 flags，不碰队伍；现在跑在 `_restore` 之后，两者互不读对方写的东西，次序可换——实现时加一条断言钉住）。

#### 1.4 共用测试夹具 `tests/lib/tq_save_kit.gd`

（`preload` 用，不加 `class_name`，不进发行包。）从 seed-fix 的 `xiyou_tianqi_seed_fix.gd:75-90` 那几个小函数提出来：

| 函数 | 做什么 |
|---|---|
| `new_game(diff := "", lineup := [])` | 走 `XTianqi.start_new_game` 真开局（不手写 `flags["tianqi"]`） |
| `setup(name)`／`teardown()` | `XSave.dir_override`、`XConfig.path_override`、`XStarWarehouse.path_override` 指到 `user://test_<name>`，收尾清掉（「测试别读本机设置」那个坑一并处理） |
| `roundtrip(slot := 1) -> XState` | `XSave.save` 真写盘 → `XSave.load_slot` 真读档，走全两处入口，经过 JSON（整数变浮点、整数键变字符串都会露出来） |
| `edit_raw(slot, fn)` | 读存档文件原文→`fn` 改字典（删键造老档、改版本号）→`XSave._write` 写回 |
| `legacy(slot, keys)` | `edit_raw` 的常用法：删掉 `flags.tianqi` 下这些键，模拟老档 |
| `with_switch(obj, name, value, fn)` | 临时改开关，跑完还原（关开关读档那类断言用） |
| `each_seed(seeds, fn)` | 多种子循环（改 `orb_seed`；默认三个种子） |
| `reload_same(roll_fn)` | 「存 → 掷 → 读 → 再掷，结果相同」一行断言 |

约定（写进车道须知短表「测试怎么写才算数」）：新专项、以及以后改到存档字段的旧专项，必须用 `roundtrip`；带随机的用 `each_seed`＋`reload_same`。现有 52 个天启篇专项**不一次改完**：9 个只 `to_dict/from_dict` 不经 JSON 的列成清单，随下次改动迁（或单独派一张 Sonnet 机械单，见 3.1 的 S3）。

#### 1.5 工具：存档字段登记检查

`07_开发环境/天启篇存档登记.py`（只读，几秒）：rg `flags.tianqi[...]`／`.get("…")`／`tq["…"]`（在天启篇脚本里）出现的键，不在 `SECTIONS`／`ROOT_KEYS`／计数区里的报错；装备上 `tq_` 前缀的键不在 `GEAR_KEYS` 的报错。挂进 `检查.sh` 和 `工具回归.py`。这样教派等车道新加字段，合并时就会被提醒登记，不靠核查人肉看。

#### 1.6 行为变化与开关

- 迁移搬家后结果逐键相同，不算行为变化；`XTianqiSave.ENABLED=false` 时 `after_load` 只跑旧的两处，各模块里保留的旧 `progress()` 就地补照旧兜底（迁移期两套并存一个发行版本，之后删旧写法）。
- 唯一真正的变化：`tianqi_rewards.progress` 在非天启篇档上不再建空 `tianqi` 区（第二份第四节指出的那个空区）。开关 `XTianqiSave.NO_EMPTY_ROOT`（O-待定），关掉回到建空区。

---

### 2. 随机门面

#### 2.1 现有写法盘点（main＋seed-fix，比第二份多两种）

| # | 写法 | 谁在用 | 身份绑在什么上 | 读档后 | 门面里归哪类 |
|---|---|---|---|---|---|
| 1 | 运行时主种子 `random_master` 派生：战斗规则流、战斗奖励流、宠物流、装备流、世界事件流（`xstate.gd:104-132`），**主种子不进存档** | 战斗全过程；原版掉落掷哪几件（`battle_logic.gd:3488`）；天启篇通用掉落（`tianqi_drop.gd:480`）、异化装备（`tianqi_alien_gear.gd:276`）、元素书（`tianqi_elements.gd:1039`）、删栏重抽（`battle_logic.gd:3448`）、米拉（`mira.gd:356`）、流萤残核（`liuying.gd:796`）；装备底子（`XGear.roll`→装备流） | 运行时第几场／第几次 | 会变 | 规则流＝B 战斗流（可变）；奖励流＝B 战斗流（**天启篇档改钉住**，2.4）；装备流＝A 按来源键（2.5） |
| 2 | 存档种子＋键＋该键的总次数，做一次 sha256 | 招牌掉落 `tianqi_drop.gd:278` | 某个键的第几次 | 不变 | A `by_key`（公式原样保留） |
| 3 | 存档种子派生、每开一条流计数 +1 | 七印祭坛、七首之龙、首杀招募（`tianqi_qiyin.gd:62-78`） | 本域第几条流 | 不变 | A `by_count`（公式原样） |
| 4 | 整个发生器状态存进存档 | 抽奖（`lottery_rework.gd:59-80`，顶层 `lotteryRandom`，**西游档也用**） | 本档第几抽 | 不变 | 不归天启篇门面；守卫白名单 |
| 5 | 本轮种子＋已用次数×104729 | 深渊商人（`tianqi_merchant.gd:91`） | 本轮第几抽 | 不变 | A `by_count`（公式原样，包一层） |
| 6 | 全局 `randf()`／`randomize()` | 重铸、锁词条重铸、异化兜底与重抽、抽角色候选首次 | 无 | 会变 | **seed-fix 已改成 7、8**；剩 `tianqi_elements.gd:1062`（`rand` 无效时兜底 `randf()`，待查能不能走到）、`tianqi_drop.gd:249`（开关关时的旧路） |
| 7 | 存档种子 `hash32` 存进分区，再 `String.hash()` 拼键 | 元素牌组、楼层元素、骑士元素（`tianqi_elements.gd:116-122、169、368、426`，11-14 新合） | 某个键（楼层、骑士） | 不变 | A `by_key`（公式原样；新代码不要再用 `String.hash()` 定种子，用 `XRandomStream.derive`） |
| 8 | seed-fix：`orb_seed`＋键＋计数（`save_stream`）；装备随机身份 `tq_seed_id`＋装备上计数（`item_roll`）；来源键＋来源计数（`src_n`、`affix_src_n`） | 重铸、异化、抽角色候选、新装备天启篇词条、各入口来源 | 存档第几次／某件装备第几次／某来源第几件 | 不变 | 就是门面的 `by_count`／`by_item`／`by_source`，**整组搬进门面** |

另有「掷一次把结果存下来」（抽角色候选 `offer`、深渊商人货架）——这是正确做法的另一种，门面头注释里写成第四条身份规则：「掷完要给玩家看、不满意也不能重来的，掷完就存结果」。

#### 2.2 三类流与读档总原则的对应

| 类 | 是什么 | 读档后 | 用在哪 |
|---|---|---|---|
| **A 存档派生流** | 种子＝`derive(hex64(orb_seed), 域｜稳定键｜计数)`，计数随存档 | 同样操作结果相同 | 一切「点完就出结果」：重铸、异化、抽角色、商人、七印、招牌掉落、号卷、商店／事件得到的装备、新装备词条 |
| **B 战斗流** | 每场一个 `XBattleRandom`：`rule`（回合内）、`setup`（布阵，新增）、`reward`（结算）、`pet` | `rule` 会变；天启篇档里 `setup`、`reward` 按战斗键钉住 | 先手、暴击、命中、AI 选招 → `rule`；开战掷的（2.4 第 2 条） → `setup`；掉哪几件、掉落词条 → `reward` |
| **C 表现流** | 抖动、裂纹、呼吸相位、NPC 走动 | 无所谓 | 随便取，但行尾注 `# 表现` |

#### 2.3 接口

```gdscript
class_name XTianqiRandom  # core/tianqi_random.gd
## 读档后不该变的随机全部从这里取。头注释是「身份规则」一页（下面五条），车道须知短表抄一份。
static var SEED_FROM_SAVE := true        # 即 seed-fix 的 XTianqi.SEED_FROM_SAVE（O 号沿用），搬家不换号
static var BATTLE_FROM_SAVE := true      # O-待定：天启篇档战斗布阵／奖励按战斗键钉住；false＝回到运行时主种子

# A 存档派生
static func by_count(s, domain) -> XRandomStream            # 本档这个域的第 n 次（计数 flags.tianqi.rng[domain]）
static func by_key(s, domain, key, n := -1) -> float        # 某个键的第 n 次；n=-1 用门面计数，>=0 调用方自带计数（招牌掉落的 total）
static func by_item(s, item, domain) -> Callable            # 某件装备的第 n 次（tq_seed_id＋tq_rng_n），即 seed-fix item_roll
static func by_source(s, item, source) -> void              # 入包分配随机身份，即 seed-fix on_register
static func gear_stream(s, source) -> Callable              # 有来源键的装备生成时：底子＋天启篇词条一起用这条（2.5）
# B 战斗
static func battle_key(s, troop_id) -> String               # 天启篇档：取并推进战斗键（Kyo 定 2.4 第 1 条）
static func battle_random(s, troop_id) -> XBattleRandom     # 天启篇档：setup/reward 由 battle_key 派生；rule/pet 照旧运行时
# 读档
static func after_load(s) -> void                           # 老件补随机身份（seed-fix assign_all）
# 旧写法原样包一层（公式不改，只是有了统一的入口和名字）
static func qiyin_seed(s, domain) / drop_hash(seed, key, total) / elements_seed(s) / merchant_roll(seed, used)
```

计数区统一到 `flags.tianqi.rng = {域: n}`；seed-fix 已经写在档里的 `affix_roll_n`、`affix_src_n`、`src_n`、`draws`、`qiyin.rng_n` **不搬**（搬就要迁移、还可能写错一次让老档序列跳号），门面按旧位置读写，登记表里注明「计数在哪」。只有门面以后新开的域用 `rng` 区。

**身份规则**（门面头注释）：
1. 这个存档里发生的第几件事（抽角色、新装备掷词条）→ `by_count`。
2. 同一个东西反复试、要带保底（招牌掉落、号卷）→ `by_key`，保底计数和键放在一起。
3. 对这件装备做第几次操作，装备会被搬来搬去 → `by_item`；身份写在装备上，复制时不带走（`GEAR_KEYS`）。
4. 有稳定来源的东西进包（商店、事件、掉落）→ 入包时按来源键分配身份 `by_source`；同一个来源键在本档第几件。
5. 战斗：回合内 → `rule`；开战布阵和结算 → 天启篇档由战斗键钉住；纯表现 → 随便，行尾注 `# 表现`。
（另：掷完要给玩家看、不能重来的，掷完就把结果存下来。）

#### 2.4 普通战斗掉落按「本档第几场」派生

**做法**（天启篇档、`BATTLE_FROM_SAVE` 开时；西游档完全不进）：

1. 开战（`battle_logic.gd:140` 的 `s.reserve_battle_random()`）改经门面：`XTianqiRandom.battle_random(s, troop_id)`。它取战斗键并把计数 +1 写进 `flags.tianqi.rng`（**随存档**，与运行时的 `battle_serial` 分开，后者照旧给回放用）。种子＝`derive(hex64(orb_seed), "battle|" + 战斗键)`。
2. 奖励流**按敌人分子流**：`XBattleRandom` 加 `reward_for(key) -> XRandomStream`，天启篇档里按 `key` 现开一条 `derive(本场种子, "reward|" + key)`；西游档里直接返回原来那一条 `reward`（行为字节相同，`xiyou_determinism` 和回放不受影响）。7 处调用改成：原版掉落、删栏重抽 → `reward_for(stable_id(e) + "|drop")`；天启篇通用掉落 → `reward_for("tianqi_generic")`；异化装备 → `reward_for(id + "|alien")`；元素书 → `reward_for("elem_book")`；米拉、流萤残核 → `reward_for("mira")`／`reward_for(stable_id(e) + "|liuying")`。**为什么要分子流**：原版 MOG_TrPopUpBattle 开着时掉落在**倒下动画结束时**就掷（`drops_of`，`battle_logic.gd:3441`），谁先倒下是战斗过程（暴击、先手决定），一条顺序流会让过程变化串到掉落上；分子流后每个敌人掉什么只看「本场＋这个敌人」。
3. 掉出来的装备入包：`gain_gear(kind, id, 1, "b|" + 战斗键 + "|" + stable_id + "|" + 第几件)`（seed-fix 返修四已给 `gain_gear` 加了 `source` 参数，招牌掉落传 `sig|键`；普通掉落现在传空，改成传这个）。于是这件装备的**随机身份、天启篇词条**按来源键派生（返修四已有的路径），**底子数值**也改走 `gear_stream(s, source)`（2.5），整件装备读档后一模一样。
4. 第 2 条决定（Kyo）：开战布阵时掷的（`tianqi_seg_alien` 按段异化挂谁、神话判定、`XTianqiGear.reroll_drops` 之外的布阵掷骰）是否改用 `setup` 流。推荐改：这几样决定「这场打什么、能掉什么」，按总原则属于结果；改法是 `XBattleRandom` 加 `setup` 流，布阵阶段的取数从 `rule` 挪到 `setup`（实现时要先盘点布阵阶段到底从 `rule` 取了哪几次，列清单再挪）。不改的话，读档能把「这场异化挂谁」重掷。

**与掉落、词条、招牌掉落的关系**：

| 层 | 现在 | 改后（天启篇档） |
|---|---|---|
| 掉不掉、掉哪件（原版掉落表、天启篇通用掉落、异化装备、元素书） | 运行时奖励流，读档变 | 战斗键＋敌人分子流，读档不变 |
| 招牌掉落中没中 | 存档掉落账 `drop.seed`＋键＋总次数（不变） | **不变**（它本来就钉住，而且有保底账；不并进战斗键，免得保底和战斗键两套身份打架） |
| 掉出装备的随机身份 `tq_seed_id` | 普通掉落按 `instanceId`（返修四：上层问题另定） | 按来源键 `b|战斗键|敌人|k` |
| 掉出装备的天启篇词条 | 返修二、四：本档 `affix_roll_n` 全档计数（先买别的会挪号） | 按来源键（`affix_src_n` 路径），不受别的装备影响 |
| 掉出装备的底子数值 | 运行时装备流，读档变 | `gear_stream(s, 来源键)` |
| 战斗过程（先手、暴击、命中、AI） | 运行时规则流 | **不变** |

**影响**：
- 只在天启篇档；西游档、`--oracle` 对照、`xiyou_determinism`、战斗回放（`battle_replay.gd` 记的是 `XBattleRandom.snapshot`，西游档里 `reward_for` 返回原流，快照不变；天启篇档的快照要多记本场种子，回放才能重放子流——实现时补）全部不变。
- 天启篇老档：读进来以后下一场起按新规则掷，之前的不追溯，不需要迁移；战斗键计数从 0 开始。
- 测试：要钉运行时主种子的天启篇专项（`battle_same` 那类）改成只钉存档种子；`xiyou_tianqi_affix_seed` 的 `real_*` 三条从「只打 INFO」改成断言相等。
- 剩下能「换掉落」的办法只有改变结果本身（换个敌群打、少杀一个敌人），这是总原则允许的。

#### 2.5 装备底子也钉住（商店、事件、掉落）

`XState.gain_gear` 在带来源键、天启篇档、`SEED_FROM_SAVE` 开时，临时设 `XGear.roll_fn = XTianqiRandom.gear_stream(s, source)`，生成完还原（与深渊商人现在设 `roll_fn` 的写法一致；`roll_fn` 已优先于装备流）。这样「商店买一件、不满意读档再买」底子也一样。词条流和底子流用同一个来源键的不同域，互不挪号。西游档不进。

#### 2.6 全局随机的禁用办法：`07_开发环境/随机守卫.py`

- 范围：发行空壳认的天启篇脚本全集（`modes/xiyou/**/tianqi*.gd`＋`gojo.gd`、`fabao_feed.gd`、`guardian_rework.gd`、`lottery_rework.gd`，清单制落地后直接读那份清单）＋两个门面文件。
- 报错的写法：前面不带 `.` 的全局 `randf(`、`randi(`、`randf_range(`、`randi_range(`、`randfn(`、`randomize(`、`seed(`；任何 `.randomize()`、`XRandomStream.fresh_seed(`、`pick_random(`、`.shuffle(`（后两个用全局发生器）；`RandomNumberGenerator.new()` 后 3 行内没有 `.seed =`。
- 放行：行尾注 `# 表现` 或 `# 随机守卫：<理由>`（如「开关关时旧路」「种子由存档派生」）。现有合规点（七印展示抖动、元素 3 处已定种子的发生器、七首之龙招募、掉落开关关时的 `randi()`）第一批一次性补注记。
- 挂进 `检查.sh`（不占测试槽）和 `工具回归.py`；配一个反例测试（故意写一行 `randf()` 必报）。seed-fix 交付单里手工那张「漏网清单」从此由它出。

---

### 3. 迁移计划

#### 3.1 分批（每批可独立合并、带开关可回退）

| 批 | 内容 | 前置 | 碰的文件 | 开关 | 配置 | 核查 |
|---|---|---|---|---|---|---|
| **S1** 存档门面骨架＋打样 | `tianqi_save.gd`（登记表全量登记 1.1 的键，`v` 区）；`drop`、`qiyin`、`gojo` 三个分区的 `progress()`／`store()`／`migrate` 改走门面；`after_load` 一行挂 `from_dict` 末尾；五条悟进阶迁移从 `_load_data` 挪过来；`tq_save_kit.gd`；`天启篇存档登记.py`；新专项 `xiyou_tianqi_save`（每个打样分区：新档／删键老档／`v` 缺失老档／关开关读档／开→关→开往返，全走 `roundtrip`） | 无；**挂钩那一行等 seed-fix 合并后再提交**（同一处 `from_dict` 末尾，seed-fix 刚加了 `assign_all`） | 新 `core/tianqi_save.gd`；`tianqi_drop.gd`、`tianqi_qiyin.gd`、`tianqi_gojo_trial.gd`、`tianqi_no_diff_passive.gd` 各几行；`xstate.gd` 1 行；`xsave.gd` 1 行（删五条悟迁移那半） | `XTianqiSave.ENABLED`、`NO_EMPTY_ROOT` | Opus＋medium | 甲档（存档） |
| **S2** 其余分区搬家 | 四线、`famine_prologue`、`summit`、`weak_clear`、`rewards`、`elements`、`money`、`trumpet`、`skill_grow` 的就地补换成 `section()`；`strip_on_copy` 接到 seed-fix 那三处复制路径 | S1、seed-fix 合并 | 各模块 1～3 行 | 同 S1 | Sonnet＋medium（机械） | 乙档 |
| **S3** 旧专项改走真实存读 | 9 个只 `to_dict/from_dict` 的天启篇专项改用 `roundtrip`；6 个手写 `flags["tianqi"]` 的改 `new_game` | S1 | 只动 tests | — | Sonnet＋medium | 丙档抽核 |
| **R1** 随机门面骨架 | `tianqi_random.gd`：seed-fix 的 `save_stream/save_roll/seed_id/item_roll/on_register/before_renumber/all_gear/assign_all` 原样搬过去（派生字符串一字不改），`XTianqi` 留同名转发一个发行版本；身份规则头注释；`随机守卫.py`＋补注记；`kit.each_seed`／`reload_same` | **seed-fix 合并** | 新 `core/tianqi_random.gd`；`tianqi.gd` 删搬走的部分；`xstate.gd` 1 行（`assign_all` 改由 `XTianqiSave.after_load` 调） | 沿用 seed-fix 的 O 号 | Opus＋medium | 甲档 |
| **R2** 旧写法收进门面 | 2、3、5、7 类改调门面的同名包装（公式不变）；`tianqi_elements.gd:1062` 的 `randf()` 兜底查清能否走到，能走到就改 `by_key` | R1 | `tianqi_drop.gd`、`tianqi_qiyin.gd`、`tianqi_merchant.gd`、`tianqi_elements.gd` 各几行 | 不加新开关（数字不变）；每处加「老档同种子序列不变」断言（用打补丁前的结果当基线写死） | Sonnet＋medium | 乙档 |
| **R3** 战斗布阵／奖励钉住＋装备底子钉住 | 2.4、2.5：`XBattleRandom.reward_for`／`setup`、`battle_random`、7 处奖励取数、`gain_gear` 掉落来源键、`roll_fn` 绑定；回放快照补本场种子；专项 `xiyou_tianqi_battle_seed`（存→打→读→再打，掉落件、词条、底子全同；换打法（不同击杀顺序）掉落同；少杀一个只少那一个；换敌群不同；关开关回运行时；西游档字节相同） | R1；Kyo 定第 4 节第 1、2 条 | `battle_logic.gd`（约 10 行）、`battle_random.gd`、`xstate.gd`、`mira.gd`、`liuying.gd`、`tianqi_drop.gd`、`tianqi_alien_gear.gd`、`tianqi_elements.gd` | `XTianqiRandom.BATTLE_FROM_SAVE`（O-待定） | 规则核定 Opus＋high，实现 Opus＋medium | 甲档＋`--oracle`（碰 `battle_logic.gd`，确认西游档不变） |

顺序：**S1 现在开**（挂钩行最后提交）→ seed-fix 合并 → R1 → S2、R2 可并行（碰的文件不重叠：S2 碰 progress 一类函数，R2 碰随机取数；同文件的 `tianqi_drop.gd`、`tianqi_qiyin.gd` 由 S1 已搬完存档部分，R2 只动随机那几行）→ R3 等 Kyo 拍板。S3 任何时候插空。

#### 3.2 和在跑车道的冲突

| 车道 | 它碰的 | 和本方案 | 办法 |
|---|---|---|---|
| `cc/tianqi-seed-fix`（返修四待复核） | `tianqi.gd`、`xstate.gd`（`gain_gear`、`register_gear`、`from_dict` 末尾）、`tianqi_affix_roll.gd`、`battle_logic.gd` 2 行、复制路径 3 处 | R1 整个是把它的入口搬家；S1 和它都在 `from_dict` 末尾加一行 | R1 必须等它合并；S1 先做门面和打样分区，`xstate.gd` 那一行最后合 main 后再加。本方案**不要求 seed-fix 再改**：它的派生公式、计数位置、来源键原样保留 |
| `cc/save-data-cleanup` | `xsave.gd` `_write`／`save`、`star_warehouse.gd`、`save_transfer.gd`、`entry.gd`、新 `save_slim.gd` | S1 动 `xsave.gd` 的 `_load_data`（删五条悟迁移半行），不碰 `_write` | 文本不重叠；谁后合谁合 main。可优化：它的「写盘时去掉的装备字段」以后可以并进 `GEAR_KEYS`（加一列 `save: false`），本单不做 |
| `cc/tianqi-sect-b`、`-ren`（教派） | 可能新加 `flags.tianqi` 键 | S1 合并后 `天启篇存档登记.py` 会报它们没登记的键 | 后合的一方补登记一行；派单里提醒教派车道按「现在」那栏写，合并时登记 |
| 战斗门面（第二份「现在就该做」第 4 条，未派） | `battle_logic.gd` 大面积 | R3 在 `battle_logic.gd` 改约 10 行 | R3 和战斗门面不同时开；建议 R3 先（小），或并进战斗门面的第一步 |

#### 3.3 工作量与风险

| 批 | 量 | 主要风险 | 怎么压 |
|---|---|---|---|
| S1 | 中（门面约 200 行、测试约 300 行） | 默认值和各模块现在的「就地补」不逐键一致；五条悟迁移挪位置后次序变化 | 每个打样分区一条「新旧写法对同一份老档补出来逐键相等」的断言；挪迁移加次序断言；甲档核 |
| S2 | 小（机械） | 漏一处 `is Dictionary` 初始化 | 登记检查工具兜底 |
| S3 | 小到中 | 改测试把原本测到的东西改没了 | 断言数不减；`反向验证.py` 抽 3 个 |
| R1 | 小到中（搬家） | 搬的时候改了派生字符串，老档身份全变 | 「老档补号结果与搬家前逐件相同」断言，用搬家前生成的存档文件做夹具 |
| R2 | 小 | 同上，公式抄错 | 每处写死搬家前的结果序列做基线 |
| R3 | 中偏大 | ① 布阵阶段从 `rule` 取了哪几次没盘全；② 回放快照漏了本场种子；③ 掉落数值改变（不该变，只是不再随读档变）被误当回归 | ① 实现前先跑一场带日志列出布阵取数；② `xiyou_determinism`＋回放专项；③ 掉率统计专项跑多种子，对比改前分布（均值落在误差内） |

总计约 5～7 个车道工作日（S1 两天、R3 两天、其余各半天），甲档核查 3 批（S1、R1、R3）。

---

### 4. 要 Kyo 定的（3 条，都带推荐）

1. **战斗键用什么**（决定 R3 的身份）：
   - A．本档第几场战斗（Kyo 原话的字面意思）：简单；但「存档 → 打 boss 掉得不好 → 读档 → 先打一场小怪 → 再打 boss」就换了一套掉落，代价只是一场小怪。
   - B．**这个敌群号＋本档打这个敌群的第几次（推荐）**：同样钉住「这场掉什么」，而且打别的战斗挪不动它；想换只能真的再打一次同一个敌群（那本来就是一次新的掉落机会）。实现成本和 A 一样（键不同而已）。
2. **开战布阵时掷的算不算结果**（异化挂谁、神话判定等，决定 R3 要不要加 `setup` 流）：**推荐算**，一起按战斗键钉住；只有回合内的先手、暴击、命中、AI 选招读档可变。不算的话，读档能重掷「这场哪个怪异化」进而换掉落。
3. **西游档要不要也钉掉落**：**推荐不钉**。西游是 1:1 重制，原版读档会变，`--oracle` 对照也按原版；钉住只做天启篇档。

（其余都按推荐默认继续：旧写法只搬家不改公式；分区懒建；计数不搬位置。）

## 协调批复（2026-11-14）

方案批了，三条按推荐：①战斗键＝敌群号＋本档打这个敌群第几次；②开战布阵掷的（按段异化挂谁、神话判定）算结果、一起钉住；③西游档不钉（协调转告 Kyo，有异议再改）。本车道做 S1；R1 等 seed-fix 合并后再开；R3 合并加 `--oracle`；S2、S3、R2 由协调另派。

## S1 实现（本分支）

| 处 | 做了什么 |
|---|---|
| 新 `modes/xiyou/core/tianqi_save.gd`（`XTianqiSave`） | 登记表：`SECTIONS` 16 个分区（版本、归谁、`vkey`、分区自带的根上老键）、`ROOT_KEYS`、`COUNTER_KEYS`（seed-fix 的 `affix_roll_n`／`affix_src_n`／`src_n`）、`OUTSIDE_KEYS`（`_gojoTrial`）、`GEAR_KEYS` 10 个装备键（`copy`）；`WIRED` 列已接进门面的 3 个分区。接口 `root`／`peek`／`section`／`version`／`set_version`／`versions`／`after_load`／`strip_on_copy`。头注释是规矩一页 |
| `xstate.gd` `from_dict` | 一行 `XTianqiSave.after_load(s)`（在 `XPets.loaded` 之后、`XWeakChallenge.after_load` 之前） |
| `tianqi_drop.gd` | `store` 改走 `section(s, "drop")`；原来的建账、补 `pity` 搬成 `fill(s, d, made)`（种子公式一字不改，只在新建时给）；两处「有没有账」的判断改 `peek`（必掉不新建账的行为不变） |
| `tianqi_qiyin.gd` | `progress` 改走 `section(s, "qiyin")`；逐键补搬成 `fill(s, p)`，逐键与原来相同 |
| `tianqi_gojo_trial.gd` | 版本读写改走 `XTianqiSave.version`／`set_version(s, "gojo", …)`，存储仍是 `flags.tianqi.gojo_adv_v`；`after_load` 照旧（还原试炼现场＋迁移），迁移幂等所以门面先迁一次、这里再调是空转 |
| 新 `tests/lib/tq_save_kit.gd` | 共用夹具：`new_game`（真开局）、`roundtrip`／`reload`（`XSave.save`→`XSave.load_slot` 真写盘读档）、`raw`／`edit_raw`／`legacy`（改存档文件造老档）、`reload_same`、`each_seed`、`teardown`；构造时把存档目录和配置指到 `user://test_<名>/` |
| 新专项 `xiyou_tianqi_save` | 36 条，见「验证」 |
| 新 `07_开发环境/天启篇存档登记.py`＋`测试天启篇存档登记.py`（8 条） | 游戏代码里字面量／同文件 const 的 `flags.tianqi` 键、别名 `var tq = s.flags.tianqi` 的键、`XTianqiSave.section(s, "名")` 的分区名、装备 `["tq_x"] =` 赋值，不在登记表的逐条报；接进 `检查.sh`（文档与登记段，探针登记检查之后，失败算 FAIL）、`检查.sh` tools 组、`工具回归.py` 门禁；`测试选测.py` 文档类改动的检查名单随之加一项 |

**与方案的两处出入**（都是往保守走）：

1. 方案说「两个自带标记并进 `v`，旧键只读兼容」。实际改成**不搬标记**：登记了 `vkey` 的分区（`gojo` → `gojo_adv_v`、`no_diff_passive` → `no_diff_passive`）版本就存在原来的键里，门面统一读写、`versions()` 一处看全。理由：搬标记就要一次数据迁移，而门面开关一关模块又要认旧键，两套位置并存更容易出错；不搬则零迁移、开关回退天然成立。
2. 方案说五条悟迁移「从 `XSave._load_data` 挪到 `from_dict`」并删 `_load_data` 那半行。实际**没动 `xsave.gd`**：门面在 `from_dict` 末尾先迁，`_load_data` 里的 `after_load` 照旧调（迁移幂等，第二次空转）；门面开关关着时由它照旧迁。好处是本单不碰 `xsave.gd`（save-data-cleanup 在改它）。次序变化：迁移现在在试炼现场还原（`_restore`）之前。两者不读对方写的东西；唯一交集是 `_restore` 把生命夹到 `mhp`，而反迁移（只在关两阶表开关时）会改阶数——只影响「关开关＋存档时正在试炼」这一种，可接受，记在这里。

**挂钩那一行**：协调说等 seed-fix 合并后再提交。我先试了合并：本分支与 `cc/tianqi-seed-fix`（`337270ec9`）、`cc/save-data-cleanup`（`9f333861f`）各做 `git merge-tree`，都**无冲突**（挂钩放在 `XPets.loaded` 后，和 seed-fix 加 `assign_all` 那行隔着两行），所以一并提交了。若总装仍想等 seed-fix 先合，本分支照样能后合（已验证三方都能干净合并）。

## 返修（小A 甲档核查 S1，3 条 P2＋2 项漏测，2026-11-14）

| 条 | 问题 | 改法 | 断言 |
|---|---|---|---|
| P2-1 | `section()`／`peek`／`version`／`set_version`／`versions` 判「`flags.tianqi` 是字典」，`root()`／`after_load` 判 `XTianqi.active`；西游档残留空 `tianqi` 表时 `section` 会往里写分区和版本 | 新 `XTianqiSave.live(s)`（＝`XTianqi.active`），门面全部入口只认它；非天启篇档（含残留空表、缺 `rules` 的）一律返回不落盘的临时分区 | `xiyou_empty_tq_detached`（取 drop／七印／famine_prologue、记版本都不写进空表）、`xiyou_empty_tq_disk`、`xiyou_empty_tq_disk_after_use`（XSave 真写盘读档后仍是空表） |
| P2-2 | `天启篇存档登记.py` 别名不认 `var X = XTianqiSave.root(s)`；装备键不认 `.tq_x = …` 和 `[CONST] = …` | 别名正则加 `XTianqiSave.root(…)`；装备键加点号赋值、同文件 const（值以 `tq_` 开头）下标赋值；比较、`set_meta` 不算 | `测试天启篇存档登记.py` 新 `test_root_alias`、`test_gear_dot_and_const`（旧脚本上两条都挂，10/10） |
| P2-3 | `famine_prologue` 登记 `array: true`，`section()` 却写死字典 | 新 `is_array(名)`；`section` 按标记新建／返回 `[]`（返回值改不定型），`peek`、`after_load` 按形状认；形状不对的值 `peek` 不认、`section` 换成正确形状 | `array_section_made`／`_same`／`_shape`／`_disk`、`dict_section_not_array` |
| 漏测 | 五条悟真实角色＋存档时正在试炼的存读次序交集 | 补测：老档（无标记、旧四阶 4 阶）试炼中存档，读档后迁移成 2 阶、补通过记录 [1, 2]、记版本 3，同时试炼现场还原（队伍、出战栏、战前生命） | `gojo_trial_begin`／`_saved`／`_migrated`／`_restored`／`_stable` |
| 漏测 | 天启篇档 `root()` 返回值 | 补测：返回 `flags.tianqi` 本体，经它写的键存读后还在 | `root_is_live`、`root_roundtrip` |
| 漏测 | `reload_same` | 留 R1／R3（随机门面用到时补） | — |

返修验证：专项 `xiyou_tianqi_save` 51/51；反向：把 `live()` 改回旧判断，`xiyou_empty_tq_*` 3 条挂（48/51），用旧版门面时数组断言在解析期就被拦；相关专项 23 个场景全过（`xiyou_gojo_trials`、`xiyou_gojo`、`xiyou_tianqi_drop*`、`xiyou_tianqi_qiyin*`、`xiyou_tianqi_famine*`、`xiyou_tianqi_e2e`、`xiyou_tianqi_title_flow`、`xiyou_tianqi_no_diff_passive`、`xiyou_tianqi_elements`、`xiyou_tianqi_money`、`xiyou_tianqi_trumpet`、`xiyou_fabao_rework`、`xiyou_determinism`）；`天启篇存档登记.py` 通过、`测试天启篇存档登记.py` 10/10；语法检查 0 个问题。行为变化：西游档带空 `tianqi` 表时，掉落账／七印不再写进去（原来会写，只有残留表的西游档受影响，天启篇档不变）。

## 变更记录草稿

## 2026-11-14 【cc·存档门面·未经审查】天启篇存档门面 XTianqiSave 骨架，掉落账／七印／五条悟三处打样（dev.待定）

- 新 `XTianqiSave`（`modes/xiyou/core/tianqi_save.gd`）：`flags.tianqi` 的分区登记表（16 个分区＋根上散键、随机计数、区外键）、装备上天启篇键的登记表（复制时带不带走），统一的 `section`（缺了按默认建、缺键按默认补）、`peek`（只看不建）、版本 `version`／`set_version`（一般分区记 `flags.tianqi.v`，五条悟、难度被动沿用原标记键）、读档后唯一入口 `after_load`（挂在 `XState.from_dict` 末尾，只给已存在的分区补迁移、幂等）。
- 打样三个分区：招牌掉落账（`XTianqiDrop.store`）、七印祭坛（`XTianqiQiyin.progress`）改走门面，补法逐键与原来相同；五条悟进阶表版本经门面读写，读档迁移改在 `from_dict` 末尾先跑（只走 `to_dict`／`from_dict` 的测试也测得到），`XSave._load_data` 里照旧再调一次（幂等）。其余 13 个分区只登记，模块里照旧就地补，下一批接。
- 共用测试夹具 `tests/lib/tq_save_kit.gd`：真开局、真写盘读档、改存档文件造老档、读档再掷对照、多种子。新专项 `xiyou_tianqi_save`（51 条）。
- 新检查 `天启篇存档登记.py`：游戏代码里读写的 `flags.tianqi` 键、装备上新写的 `tq_` 键没在门面登记就报，进 `检查.sh` 与工具回归门禁。
- 开关 `XTianqiSave.ENABLED`（O-待定）：关掉读档不跑门面迁移、不记版本，模块取分区时照旧就地补，结果相同。
- 西游档不受影响（门面只认天启篇档；`from_dict` 上非天启篇档 `after_load` 直接返回）。存档里多一个 `flags.tianqi.v`（各分区版本，几十字节）。
- 玩家可见：无。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_save.gd` `XTianqiSave.ENABLED`（`after_load`、`section` 记版本）；`xstate.gd` `from_dict` 一行；`tianqi_drop.gd` `store`／`fill`；`tianqi_qiyin.gd` `progress`／`fill`；`tianqi_gojo_trial.gd` 版本读写；`tests/xiyou_tianqi_save.gd` | 天启篇存档字段散在各模块，旧档缺字段三种处理法并存（就地补／自带标记／不处理），读档后入口两处、测试只碰得到一处 | 存档门面统一登记分区、默认值、版本与读档迁移，读档后入口一处（`from_dict` 末尾） | 架构二第四、五节；协调派单 cc/save-rng-facade | `XTianqiSave.ENABLED = false` | cc | 保留 |

## 交接板

- 下一步：gpt 甲档核 cc/save-rng-facade S1；seed-fix 合并后派 R1（随机门面骨架，Opus＋medium）；S2（其余 13 个分区接门面＋`strip_on_copy` 接 seed-fix 三处复制路径，Sonnet＋medium）、S3（旧专项改真实存读）、R2 由协调派；R3 等战斗门面时机。
- 车道须知短表（私密设计仓架构二第七节）「存档字段写哪」「测试怎么写才算数」两行，S1 合并后改成「现在」就用门面与夹具（设计仓由协调改）。
- 用户试玩说明：无（玩家看不到变化）。
- 需要用户决定：无（方案三条协调已按推荐定，转告 Kyo）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`XSaveSlim` 写盘时去掉的装备字段与 `GEAR_KEYS` 合成一张登记表（加 `save` 列），以后加装备字段一处登记（S2 之后，归存档车道）。
- 建议：发行空壳清单制落地后，`天启篇存档登记.py`（以及 R1 的随机守卫）直接读那份清单认「天启篇脚本」。
- 已做：`天启篇存档登记.py` 接进 `检查.sh` 与工具回归门禁（回退：删 `检查.sh` 那两行和门禁一项）。

## 验证

- 新专项 `xiyou_tianqi_save` 36/36（全部存读走夹具的 `XSave.save`→`XSave.load_slot`）：登记表自洽（`wired_registered`、`vkey_sections`）；新档懒建、版本（`new_lazy`、`new_versions`、`drop_made`、`drop_same_dict`、`qiyin_made`）；残缺七印区补法与老写法逐键相同（`qiyin_fill_like_old`）；必掉不新建账、有账才清连败（`sure_no_new_acct`、`fails_no_acct`、`sure_resets_existing`）；真实存读（`rt_*`，含连续两次存读天启篇区一字不差 `rt_idempotent`）；老档整账缺失读档不建、首次用种子同新档公式（`legacy_drop_lazy`、`legacy_drop_seed`）；老档缺 `pity`／`v`／七印 `seed`／`rng_n` 读档补上、种子不动、记版本（`legacy_raw_stripped`、`legacy_after_load_fills`、`legacy_qiyin_seed`、`legacy_stamped`）；门面开关关→不迁不记、模块照补，再开补记（`off_no_stamp`、`off_module_fills`、`on_again_stamps`）；五条悟只走 `from_dict` 也迁移、关两阶表反迁移且幂等、门面关时 `load_slot` 照旧迁（`gojo_*` 5 条）；非天启篇档不建区、`after_load` 不动（`plain_*` 3 条）；复制去键（`strip_on_copy`）；三个种子懒建种子按公式、存读不变、种子间不同（`each_seed_*`）。
- 反向验证（`反向验证.py`，专项 `xiyou_tianqi_save`）9 处各改坏一次全部咬住：读档入口不挂、读档迁移不记版本、新建分区不记版本、门面开关不管读档、必掉也建账、七印老档不补种子、七印老档不补计数、复制不去键、五条悟反迁移版本不经门面写；源文件按备份还原。
- 本机专项：`xiyou_gojo_trials`、`xiyou_tianqi_drop*`、`xiyou_tianqi_qiyin*`、`xiyou_tianqi_e2e`、`xiyou_tianqi_title_flow`、`xiyou_tianqi_no_diff_passive`、`xiyou_determinism` 共 15 个场景全部通过。
- 选测：`选测.py main --list` 因为改了 `xstate.gd` 面很广，走 `云端选测.py run`（合 main `b6f94202f` 后，提交 `525fac8a6d`）：**通过**，486 个场景、9 片，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/43607873770 。
- 语法检查 0 个问题；`发行空壳.py check` 55 个脚本、445 个函数都有（`XTianqiSave` 自动进空壳）；`测试天启篇存档登记.py` 8/8；`测试选测.py CheckerTests CheckerStubParseTests` 32/32；`工具回归.py` 全部通过（131 秒）。
- 不需要 `--oracle`：西游档路径没变（`after_load` 对非天启篇档直接返回），没碰原版移植逻辑。

## 待交叉核查

- 返修（只核返修提交）：`core/tianqi_save.gd` `live`／`is_array`／`section`／`peek`／`after_load`；`天启篇存档登记.py` 别名与装备键三处正则；`tests/xiyou_tianqi_save.gd` `_gojo_in_trial`、`_review_fixes`；`测试天启篇存档登记.py` 两条。
- 甲档（存档）：`core/tianqi_save.gd` 全文；`core/xstate.gd` `from_dict` 一行；`core/tianqi_drop.gd` `store`／`fill`／两处 `peek`；`core/tianqi_qiyin.gd` `progress`／`fill`；`core/tianqi_gojo_trial.gd` `mark_table`／`migrate` 版本读写两处；`tests/lib/tq_save_kit.gd`、`tests/xiyou_tianqi_save.gd`。
- 工具：`07_开发环境/天启篇存档登记.py`、`测试天启篇存档登记.py`、`检查.sh` 两行、`工具回归.py` 一项、`测试选测.py` 一处期望。
- 重点：①补法逐键与原来相同（尤其掉落账只在新建时给种子、老账缺种子不补——与原写法一致）；②五条悟迁移挪到 `_restore` 之前的次序影响（上面「出入」第 2 条）；③`section` 对非天启篇档返回不落盘的临时表，原来 `progress`／`store` 在这种档上会直接报错，现在不会。
