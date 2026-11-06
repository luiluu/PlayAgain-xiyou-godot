# 交付：cc/nezha-newsrc5

- 车道／工作者：工具／哪吒（cc）。从集成分支 cc/newsrc-switch 6e403442 切出，中途合了集成分支 58340027（优化登记一处冲突，两行都留），交回集成分支，不进 main。
- 状态：可合并
- 派单 CY 四件＋总装加派一件（⑤ 更新日志不进来源指纹）。总装先派后撤回的「集成树正式同步」没做（被权限拦下，随后撤回）。

## 结论

1. **敌人复活（revive.apply）**：原参照那 30 行**是新源的真实行为，但探针现场前后不一致**，两件事叠在一起。
   - 新源 `dsPassiveSkill.js` 加了 `invalidateBattlerStateCache`／被动缓存签名：持有者有 `_passiveCache` 时，死亡那次 `clearStates` 会触发 `ensurePassiveCacheUpToDate` 重建，krz 的 `typestates('deselectState')` 缓存随之变成 `[]` 且标成不脏；之后复活状态还在 `_states` 里，但 deselect 读到空表，不复活、不抽随机数。能力缓存脏的那一支（`dirtyWarm=true`）不受影响，照常复活。旧源没有这段，所以旧源不分脏不脏。
   - 实战里敌我开战都有被动缓存（`Scene_Battle.start` 对全部敌人 `refreshPassiveCache`），云裳运行时 `prepareAction` 也会给行动者建。原探针整段共用一场战斗：第一个状态 114 的敌人行还没缓存（复活），之后角色行里敌人当行动者、被建了缓存，于是从 252 起敌人行都「有缓存」。这就是「疑似前面用例留下的现场」的真相：现场确实串了，但串出来的那一半恰好是实战状态。
   - 改法（`state_effects_probe.cjs` revive.blocks 实战段）：每例新开一场战斗，并照 `Scene_Battle.start` 给双方 `refreshPassiveCache`。单块直调（rows）没动。
   - 新源重出：rows 552 行逐项不变；applies 136 行有 41 行变，主要是致死那一击的伤害弹字（共用战斗时累积的状态没了，各状态伤害不再都是 227），实质变化是 **114 敌人热缓存行改成不复活**（与其余状态一致），敌人热缓存不复活从 30 行变 32 行。
   - 旧源 v0.28 重跑：和 main 上的参照比，rows 不变，applies 只有 popups（41 行）／result（9 行）的致死伤害数值变，hp、死活、状态、抽数全部不变。其余 34 个用例逐项相同。
   - 本机 `xiyou_state_effects`（新参照）：revive.apply 从 173 项失败变 187 项，全是敌人热缓存行（重制都复活、新源不复活）以及 252 一类本来就对不上的行。**重制要不要照搬这个缓存行为是规则车道／Kyo 的事**：这是原版缓存失效引起的复活失灵，按「原版玩法 bug 照搬」应当照搬，但重制没有这层缓存，照搬要人为模拟「死前刚刷新过」这个条件；我没动 Godot。
2. **XNanoha.finish 回退开关**：`XNanoha.ADAPT_V062`（默认 true，跟新源 `adapt(n, 0.5)`；false 回 v0.28 固定 +10／+30、不计次数）。登优化登记 **O-待定·奈叶队友击杀**。`xiyou_nanoha` 加 `rollback.v028_fixed`（关掉后 AOE 杀两只＝+20／+60、count 为空，默认路径会是 +10／+30，所以咬得住）。`回退开关覆盖.py` 不报它。
3. **工具回归两项**（现在 `工具回归.py` 全过）：
   - 插件备注：实际是 6 个标签不是 7 个（`codexaura`、`disassemblepool`、`codexliuyingcoredrop`、`codexliuyingpassive`、`codexliuyingstate`、`codexqiyuweapon#`）。都是换源后的新功能、重制还没做，按「暂缓（已登记）」写进 `插件备注豁免.json`，依据指到 `冻结后改动盘点_v0.29-v0.62.12.md` 的对应行：
     - 流萤三个（残核掉落、被动「梦应归于何处」、萤火状态 2791）：流萤（179）整套未移植，盘点 v0.60～v0.62 标「跟」。
     - `CodexAura`：v0.30 图鉴「光环独立栏」的技能分组，只影响图鉴排版。
     - `Disassemble Pool`：IntegratedV029 内嵌新版装备备注里的分解产物池（38 件）。
     - `CodexQiyuWeapon29`：IntegratedV029 隐藏装备名单（武器 90）。
     这些是真缺口，豁免只是不让测试一直红；做掉一项就删一条。
   - death_admission 探针加 `CodexZones.ENABLED=false`。这个探针没有伤害计算，新源产物关前关后逐字节相同，旧源产物与夹具相同，夹具不用重出。
4. **15 个新状态清单**（先报不做；写法＝状态备注里的效果标签，用到＝谁加它）：

| 编号 | 名字 | 写法 | 用到 |
|---|---|---|---|
| 2720 | 舍身剑·燃血 | Custom Remove／Leave Effect | 技能 10458 |
| 2721 | 凝气成罡 | Custom Confirm Effect | 技能 10461 |
| 2723 | 用剑终伤+150% | Custom Confirm Effect | 技能 10464 |
| 2724 | 诛仙剑主 | Custom Confirm Effect | 技能 10466 |
| 2747 | 全知全能 | Permanent、Custom React、ClaudeShuangSource | 技能 10525、公共事件 839／840 |
| 2748 | 全知全能 -1 | Custom Leave、ClaudeShuangSource | 状态 2747 |
| 2750 | 全知全能-2 | Permanent、Custom React、ClaudeShuangSource | 技能 1216／1220、物品 138、敌人 526、公共事件 9028 |
| 2751 | 全知全能-3 | Permanent、Custom React、ClaudeShuangSource | 公共事件 9029 |
| 2771～2773 | 超赛1～3 | Custom Apply／Remove／Passive Condition／Confirm | 技能 10563～10565，三者互相引用 |
| 2774 | 超蓝 | 同上 | 技能 2398、2401、2402、2773、5187、7178 等 12 处 |
| 2775 | 自在极意功 | Custom React Effect | 技能 10567 |
| 2776 | 自我极意功 | Custom React Effect | 技能 10568 |
| 2777 | 自我终伤 | Custom Confirm Effect | 技能 10568 |

   场景：2771～2774 是 `xiyou_state_effects_tp` 的 `inventory.costume_0`／`untranslated_46` 两项失败的来源；其余的切片可达性没查。脚本 `mv_oracle/.sandbox/cy_states.cjs`（不入库）。
5. **更新日志不进来源指纹**（总装定「都不算」）：`xiyou_export.py` 的 `read(rel, record=True)`，`export_changelog` 读 `data/PlayerChangelog/*.json` 时 `record=False`；`data/ContentVersion.json` 在 data 顶层，照旧记（探针 `source_identity.cjs` 也算它）。新源转换后 manifest.inputs 3418 份，PlayerChangelog 0 份；`验证西游来源.py` issues 为空。测试 `测试转换器写入.py` `ChangelogIdentityTests`（把 record=False 去掉就挂，反向试过）。100 多份参照身份能不能对上要等集成树同步，我这里没跑同步。

## 验证（本机，`XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`）

| 场景 | 结果 | 说明 |
|---|---|---|
| state_effects 探针（新源／旧源） | 两边 35 例无错 | 新源参照已拷进本树 generated/oracle（不入 Git） |
| xiyou_state_effects | 29942/30131 | revive.apply 187、action.counter.sequence 1、rest.costume 1，见上 |
| xiyou_nanoha | 全过 | 含新回退断言 |
| 测试转换器写入.py | OK | — |
| 工具回归.py | 全部通过 | — |
| 语法检查.py | 通过 | — |

- `事件空绿扫描.py --check` 没跑：本单没碰事件，event_states 产物过期归八戒（派单说明）。
- 注意：我中途有几次跑探针时环境变量没带上，实际跑的是旧源。上面记的结果都是带 XIYOU_APP 重跑过的。

## 改了哪些文件

- `03_转换工具/mv_oracle/state_effects_probe.cjs`（revive.blocks 实战段每例新战斗＋被动缓存）
- `03_转换工具/mv_oracle/death_admission_probe.cjs`（关五乘区）
- `03_转换工具/xiyou_export.py`（read 的 record 参数、更新日志不记指纹）
- `01_Godot工程/modes/xiyou/core/nanoha.gd`（ADAPT_V062）、`tests/xiyou_nanoha.gd`
- `07_开发环境/插件备注豁免.json`、`07_开发环境/测试转换器写入.py`
- `00_设计/优化登记.md`（O-待定·奈叶队友击杀）
- 产物：集成树要重跑 state_effects 探针（或同步）才会拿到新参照。

## 变更记录草稿

## 2026-11-06 【cc·哪吒·未经审查】敌人复活参照改每例独立现场；奈叶队友击杀回退开关；更新日志不进来源指纹（dev.待定）

查清新源敌人热缓存不复活是 dsPassiveSkill 缓存失效引起的原版行为，revive 探针改成每例新战斗并建被动缓存，新旧源重跑；XNanoha.ADAPT_V062（O-待定·奈叶队友击杀）；插件备注 6 个新源标签登记暂缓、death_admission 关五乘区；转换器读更新日志不记进 manifest.inputs。核查：待审查（改了 nanoha.gd、转换器）。

## 交接板

- 下一步：集成树重出 state_effects 参照；规则车道（或 Kyo）定重制要不要照搬「敌人热缓存不复活」；15 个新状态待派。
- 需要用户决定：敌人热缓存不复活要不要照搬（原版缓存 bug；照搬的话要在重制里模拟这个条件）。默认先不动，测试里这批行照旧挂着。

## 可优化（流程／工具／效率）

- Bash 每次调用不保留环境变量，`export XIYOU_APP` 下一条命令就丢了，探针悄悄退回默认的旧源（我在这上面白跑了几轮）。建议探针或 `shared/host.cjs` 在没设 XIYOU_APP 时打一行「用的是默认来源 v0.28」，或者 `新建工作树.sh --补齐` 把来源写进工作树的一个文件、host 优先读它（工具，小）。
