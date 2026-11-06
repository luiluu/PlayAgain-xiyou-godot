# 交付：cc/rules-newsrc6

- 车道／工作者：C 规则／rules（cc）。从集成头 21cd90eb 切出，交回集成分支。
- 状态：可合并（第三单 DV 有一处战斗核心钩子改动，见下）

## 任务（总装定）

DN 伤害取整口径：流萤二期 firefly 例里敌人普攻打流萤，基础 72×防御 0.05＝3.6，重制扣 4、原版参照扣 5。查原版在哪一步取整。

## 结论

**不是取整问题，是 `liuying2_probe.cjs`（cc/wukong-newsrc9 9ad2cb1d，未进集成）漏了 `superReference(w)`。**

- 在 v0.62.12 上用那个探针的同一场战斗量（临时脚本 `mv_oracle/.sandbox/dn_trace.cjs`，不入库）：这一击 `installDamageElementRuntime` 的伤害明细（`action._codexDamageBreakdown`）是 defense 0.05、incoming **1.5**，origins 「路线压制·承伤 ×1.5」。流萤是超强者（探针开了 2494），超强者路线压制让她承伤 ×1.5：72×0.05×1.5＝5.4，Math.round 得 5。
- 路线压制按 O-050 不移植，别的探针都用 `shared/host.cjs` 的 `superReference(w)` 去掉（binding、guyu、heartsteel、tusu 等）。同一脚本加上 `superReference(w)` 后，这一击是 4（3.6→4），暴击 5（5.4→5），与重制一致。
- 取整口径本身对得上：原版最后一步 `Math.round`（YEP DamageCore／installDamageElementRuntime 的最终值），最低 1；基础值扫 1～10000（×0.05：1→1、20→1、40→2、72→4、73→4、75→4、80→4、90→5，暴击另一列）都和 `js_round` 一致。重制 `core/damage.gd` 结算用 `XPower.js_round`（负数 .5 照 JS 往大取），固定减伤那处 `roundf` 只作用于非负值，等价。Math.random 0.5 时方差为 0，这次没另量方差。

## 建议（交总装派）

- `liuying2_probe.cjs` 照别的探针加 `superReference(w)`（`newGame` 之后要开 2494 的话用它返回的 `enableSuperSwitch()`），重出 `liuying2_oracle.json`；`xiyou_liuying2.gd` firefly 例去掉「生命按参照」那段覆盖，改回逐步比生命。属悟空 newsrc9 的分支，我没动。
- 第一期 `liuying_probe.cjs` 也没调 `superReference`，它只取我方天火伤害比值，应不受承伤影响，但顺手一起加更稳。

## 验证

- 没有 Godot 改动，没跑 Godot 测试。探针结论见上（v0.62.12，`XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`）。

---

# 第二单：DU 两个旧战斗 P2（总装加派，同分支）

## 结论：两项都早已修好，新源上原版行为没变，本单不改代码

- **① 武器解放误触发（清积压第七期 W1／P2）**：dev.225（八戒_90）修掉：不能行动时不掷解放；断言在 `xiyou_weapon_unleash`。
- **② 空行动收尾消耗行动结束状态（清积压第十期 P2，`bada3339`）**：dev.225 修掉：行动无效时不减行动结束状态；断言在 `xiyou_attack_query`。
- 进度核定 dev.239 已写「交接板里两条已知战斗 P2（W1、空行动收尾）都已修」，变更记录 1743 行（沙僧 P2 核对单）也复核过。
- **新源复核**：本树 generated 换成集成树 recursing-shamir（21cd90eb）的克隆，其中 `oracle/weapon_unleash.json`、`oracle/attack_query.json` 的 sourceIdentity 都是 v0.62.12。`并行测试.py … xiyou_weapon_unleash xiyou_attack_query`：2 个场景全部通过（321 秒，排槽）。即新源原版这两处行为与旧源一致，重制照旧对得上。
- **要改的只有文字**：`重制步骤清单.md`「战斗规则与战斗画面」一行的「旧依据」末尾仍写「武器解放误触发（第七期 W1／P2）、空行动收尾消耗行动结束状态（第十期 P2）仍待修」，已过时。进度账归审查线程，我没改，请总装转审查线程改成「已修（dev.225）」。

## ③ 近 10 期核查报告（40～50 期）里提到的战斗相关项（只列，没逐条核是否已销账）

下表按报告原文摘出；「状态」只写报告里自己说的，后续报告没提到的标「未见销账」，需要总装或审查线程再对一下。

| 出处 | 项 | 状态 |
|---|---|---|
| 审查 42 P2-1 | events4 `_actors_add_state` 给已死亡的角色也加状态，原版不加 | 未见销账 |
| 审查 42 P3-1～3 | raven1：`xiyou_raven_reflect` 只比比例盖住设置差；反射分支只补渡鸦的 `applied`；10124 神话形态被反射时黑暗侵蚀增伤晚一击，原因没查清 | 未见销账 |
| 审查 43 P3-1、P3-2 | `act()` 开头清所有角色 `stale_state_ids` 可能偏早；`apply` 开头无条件置 `rv_tp_refreshed=false`，嵌套 apply 会冲掉外层 | 未见销账（45 的 P3-2 与 43 P3-1 相关） |
| 审查 45 P3-1、P3-2 | raven4：setHp「值变了」判早了；跨行动清除点比原版少 | 审查 47 称已由 raven5 修掉 |
| 审查 45 P3-3 | events6 回退支：同一次得经验连升多级没量 | 未见销账 |
| 审查 41 P3-4 | `XSvPngFd.scale` 读 `skill_ids`，原版读 `skills()` | 未见销账 |
| 审查 40（12 条 P3） | dot 恒真断言（`xiyou_dot.gd` 142、339）、rules8 732 跳过变体、dot2 `or true` 恒真等 | 未见销账，没逐条看 |

非战斗的（界面、工具、事件）没列。没有找到别的「仍待修」战斗 P1／P2。

---

# 第三单：DV 旧核查开着的战斗项逐条销账（总装加派，同分支）——已交（第二棒）

## 接续（给下一棒）

- 分支 `cc/rules-newsrc6`，工作树 `.claude/worktrees/happy-mestorf-5d6198`；**generated 是集成树 recursing-shamir 21cd90eb 的克隆**（新源参照），原来的 v0.28 产物挪到了会话临时目录，不用管。`新建工作树.sh --补齐` 在这里会失败（默认来源路径不在），别重跑，要刷新就再克隆一次集成树的 generated。
- 范围＝上面 ③ 的表。顺序：审查 42 P2-1 → 42 P3-1～3 → 43 P3-1／2 → 45 P3-3 → 41 P3-4 → 40 的 12 条；45 P3-1／2 按审查 47「raven5 已修」核实后记「早已修」。
- 每条：读原报告 → 新源复现（探针显式 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`；临时脚本放 `mv_oracle/.sandbox/`，`require('../shared/host.cjs')`，结尾 `process.exit`）→ 三选一：早已修（写提交＋覆盖测试）／现在修（测试先在旧代码上挂，原版代码错误放开关后）／不修（写理由）。
- 产出：本节下面加一张销账表（报告｜编号｜结论｜依据）。
- 小坑：node 宿主里的数组用 `length = 0`／`push` 改，别整个替换成 node 数组（`contains` 不在，会抛）；`makeCase` 吞异常，临时打点自己包 try/catch。

## DV 结论（第二棒，cc rules）

全部 20 项都定了性：**现在修 1 项**（饿狼被反射不记帧），**不修 1 项**（只在回退支），其余 18 项早已修或核过一致。另外顺手把两份渡鸦夹具在新源上重量了。

### 销账表

| 报告 | 编号 | 结论 | 依据 |
|---|---|---|---|
| 审查 42 | P2-1 三结义给死者加状态 | 早已修 | `7031eb04`（events5c，dev.339）：`mv_script.gd` 加状态前跳过带死亡状态 1 的；审查 43 甲 2 已复核。新源：generated `event_states.json`（v0.62.12）里 3 个 dead 变体（ce43×2、ce236）死者不得 708，`xiyou_event_compare` 覆盖 |
| 审查 42 | P3-1 渡鸦反射只比比例 | 早已修 | raven2（`fc6fdf63`，dev.334）：`xiyou_raven_reflect` 加逐段绝对值，edge 两例不加魔防，同参照。新源：探针在 v0.62.12 重量（见下），专项全过 |
| 审查 42 | P3-2 反射分支只补渡鸦 `applied` | **现在修** | 云裳、饿狼的 refx 八例（`86a98b04`，raven3，dev.336）只比了扣血、生命、MP、状态，用的是没招募、形态 0 的饿狼，没有进化／解析被动。这次在新源上量了形态 3、6：原版魔法拳（10259 核分裂、10261 伽马射线暴）被反射回饿狼时，apply 包装照样记帧，行动结束**对自己加解析、进化 +1**；重制反射支不调 `XGarou.applied`，进化 0、解析空。探针加 `refg.*` 八例，专项加 `_refg`：旧代码上 8 项红（4 个 reflect 例的 evolution、analysis 各一项），`battle_logic._invoke` 反射支补一行 `XGarou.applied(u, skill, u, r, true)` 后 609/609。这是照原版补漏移植，不是原版错误，没加开关。镜流、黄泉的技能全是物理（不会被魔法反射）；甚尔唯一的魔法技能 10224 伤害为 0；云裳 refx 四例已对上，没再改 |
| 审查 42 | P3-3 神话形态晚一击 | 早已修 | raven2（dev.334）查清是 krz 状态缓存时序（受伤充 TP 先消耗待刷新标记），照做；神话两例恢复进探针。新源重量后一致 |
| 审查 43 | P3-1 `act()` 开头清陈旧偏早 | 早已修 | raven4（`a07f94cd`，dev.340）改清除点，探针 `refseq.*`；新源重量后一致 |
| 审查 43 | P3-2 嵌套 apply 冲掉外层标记 | 早已修 | raven4（dev.340），探针 `refnest.*`；新源重量后一致 |
| 审查 45 | P3-1 setHp「值变了」判早了 | 早已修 | raven5（`e60d54ce`，dev.352），O-192 `STALE_REFRESH_POINTS`，探针 `refmid.*`／`refzero`；审查 47 甲 1 已销账。新源重量后一致 |
| 审查 45 | P3-2 跨行动清除点偏少 | 早已修 | 同上（raven5，dev.352；审查 47 确认） |
| 审查 45 | P3-3 回退支连升多级 | 不修 | 新源复现：战斗中一次 `gainExp` 连升两级（60→62），原版两级都回到**进战斗时缓存**的上限（1 号：5215／2031，战后上限 5375／2093；渡鸦 167：4698／1193，战后 4826／1224），连续两次 `levelUp()` 也一样。重制回退支第二级取的是 61 级的上限，会不同。**只在 O-177 回退支**（`FIX_BATTLE_LEVELUP_MAX=false`），默认支按新上限回满，玩家碰不到。将来真要切回原版时，把「旧上限」改成整条升级链开始前取一次（`gain_exp`／`change_class`／`change_level_mv` 的循环外），再按上面数字补一例 |
| 审查 41 | P3-4 `XSvPngFd.scale` 读 `skill_ids` | 早已修 | `cf248aab`（fix4，dev.331）改读 `skills()`，`xiyou_svpngfd` 的 `scale.skill_matches_skills` 覆盖。新源：v0.62.12 仍没有技能带 `<SvPngFd>`；新增了武器 4002／4003 带它，generated `svpng.json`（v0.62.12）已含这两件 |
| 审查 40 | P3-1 `xiyou_dot` 两处恒真断言 | 早已修 | nezha-fix3（dev.328）改成真比较；审查 41 甲档「通过」 |
| 审查 40 | P3-2 转换器对换行不敏感（732 等） | 早已修 | fix3：`ASI_BLOCK_HASHES`＋`AsiBlockTests`，去掉 732 跳过 |
| 审查 40 | P3-3 施加者弱引用 | 核过一致 | fix3 量过无差异（敌群战斗中不删不换），加 `lifecycle.origin_ref*` |
| 审查 40 | P3-4 `_damagedot` 生命周期 | 核过一致 | fix3：原版移除状态后也不清，加 `damagedot_survives_remove` |
| 审查 40 | P3-5 状态改变只挂在 `_tick_states` | 不修（核过） | fix3：数据里只有 1328 带标签、只靠回合倒数消失，加 3 条普查断言盯数据 |
| 审查 40 | P3-6 探针收窄靠文本引用 | 早已修 | tools62 自带 `test_no_reference_falls_back_to_converter`（`10446f95`，dev.317）盯住「没人引用就退回整组」 |
| 审查 40 | P3-7 必中被动＋防具 4998 没测试 | 不修 | 代码与原版一致（审查 40 已对 `dsPassiveSkill` 1914～1927 核）。新源全库属性反弹只有防具 4998（角色穿），必中只看出手的角色，两者同时成立只在混乱时角色打角色；覆盖缺口，不影响玩家 |
| 审查 40 | P3-8 血条显隐自证 | 早已修 | fix3：新探针 `hp_gauge_probe.cjs` 逐敌人比原版，去掉 `or e.hp <= 0` |
| 审查 40 | P3-9 `is_guard` 缺 `canMove` | 早已修 | fix3：`guarding and can_move()`，`xiyou_passive` 加 2 条 |
| 审查 40 | P3-10、P3-11、P3-12 | 早已修／无问题 | P3-10 报告自己写「无遗漏」；P3-11 头注释 fix3 已改；P3-12 报告写无问题 |

### 新源复跑（顺手）

- 两份渡鸦夹具原来是 v0.28 量的（`raven_reflect_oracle.json`、`raven_battle_oracle.json`）。在 v0.62.12 上重量：`raven_battle` 观测值逐例相同；`raven_reflect` 75 例里只有 `reffloor.*` 三例的 `rates.after` 不同（隐月 2521 每层暴击 0.2% → 2%，数据改动；专项本来就按数据库读每层值）。换成新源夹具后 `xiyou_raven_battle` 368/368、`xiyou_raven_reflect` 561/561（加 refg 前）。

### 改动

- `modes/xiyou/battle/battle_logic.gd`：`_invoke` 反射支加一行 `XGarou.applied`（**战斗核心，只加钩子行**）。
- `mv_oracle/raven_reflect_probe.cjs`：加 `refg.*` 八例；`tests/xiyou_raven_reflect.gd`：加 `_refg`、`covers_all` 10→11；两份夹具换成 v0.62.12。

### 验证

- 本地：`xiyou_raven_reflect` 609/609、`xiyou_raven_battle` 368/368；`语法检查.py` 通过。
- 选测（基准 21cd90eb）85 个场景，走云端：见下一行结果。
- `事件空绿扫描.py --check`：**红 5 项**，都是「在预设里但 event_states.json 没量」（m234e26p0#a1 等），与本分支无关：本分支没碰 `event_presets.json`，是本树 generated 从集成树克隆来的 `event_states.json` 比预设旧。总装合并时用集成树最新产物再跑一次即可。

### 变更记录草稿

## 2026-11-06 【cc·rules·未经审查】旧核查战斗项销账；饿狼魔法拳被反射回自己照样记帧（dev.待定）

- 审查 40～45 开着的 20 项战斗相关项逐条在新源 v0.62.12 上定性：18 项早已修或核过一致，45 P3-3（O-177 回退支连升多级）只在回退支、不修，42 P3-2 现在修。销账表在交付单 `cc_rules-newsrc6.md`。
- 修：饿狼（173）形态 3 起的魔法拳（核分裂、伽马射线暴）被魔法反射回自己时，原版 apply 包装照样记帧，行动结束对自己加解析、进化 +1；重制反射支补调 `XGarou.applied`。探针 `raven_reflect_probe` 加 `refg.*` 八例。
- 渡鸦反射、战斗两份夹具在 v0.62.12 重量（只差隐月每层 2%）。

## 交接板

- 用户试玩说明：饿狼的魔法拳被敌人反射回自己时，进化层数照样 +1（与原版一致）。
- 需要用户决定：无。
- 下一步：请审查线程把审查 40～45 这些项按上表销账；`重制步骤清单.md` 那行旧依据（第二单）仍请转审查线程改。

## 待交叉核查

- `battle_logic.gd` `_invoke` 反射支新加的 `XGarou.applied`：放在 `XRaven.applied` 之前，与常规路径（`_invoke` 末尾 `XGarou.applied` 在 `XRaven.applied` 前）同序；饿狼只在出手者是饿狼时记帧，别的角色被反射不受影响。
