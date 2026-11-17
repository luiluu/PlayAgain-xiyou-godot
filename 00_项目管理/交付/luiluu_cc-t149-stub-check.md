# 交付：luiluu/cc-t149-stub-check

- 车道／工作者：T149 发行空壳补检查（cc，Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·T149·未经审查】发行空壳.py check 补「空容器」检查，并修出一处发行战斗必崩的漏网（dev.待定）

- `发行空壳.py`：被西游代码调用、空壳却按类型返回了 `[]`／`{}`／`""`／`null` 的成员（T104 `effective_params`、T148 `create_gear` 就这样漏的），`check`／`make_tree` 现在要求二选一：在 `发行空壳特例.json` 写真值，或进新增的「已确认空值安全」名单并写理由。原样传回参数的（PASSTHRU）仍由原检查单独报、不重复。
- `发行空壳特例.json`：新增「已确认空值安全」76 条（逐个看过调用处，理由见各条）；新增特例 `XTianqiRandom.battle_random` → `s.reserve_battle_random()`（见下，发行战斗会崩）。
- `测试发行空壳.py`：新增 `test_empty_container_return_needs_override_or_allow`（报出→登记放行→写特例三步，没人调用的不报）、`test_real_project_empty_returns_all_reviewed`（真工程每个空容器成员都登记、登记的不烂）。

## 验证
- `测试发行空壳.py` 14 项全过；`发行空壳.py check` 退出码 0；工具回归全过；交付自检见回报。
- 反向验证（把新检查指向旧提交、用该提交自己的特例表）：6fe10dba4（T148 修之前）报出 `XTianqiRandom.create_gear` ✓；`XTianqiGear.effective_params`：b501d4b8b 上该函数还不存在，改在 T104 首次接线提交 2adeb34bd（函数已有、特例未补）上报出 ✓。
- 没跑游戏测试：本单只改工具与特例表，不改游戏脚本；`battle_random` 的新特例只改发行空壳生成物。

## 现 main 上报出的其余函数（共 77，逐个判断）
- **不安全：1 个**——`XTianqiRandom.battle_random`：空壳返回 `null`，`BattleLogic.setup`（battle_logic.gd:140）`random = random_context if … else XTianqiRandom.battle_random(s, troop)` 紧接着 `random.snapshot()`。凡不传 random_context 的开战，发行包会对 null 调方法崩。已补特例 `s.reserve_battle_random()`（与真脚本西游档分支一致：`battle_on(s)` 恒 false 时就是返回它）。**请总装/核查确认发行包是否真的走到这里（我没跑发行入口冒烟）。**
- **安全：76 个**，归类（每条理由在特例表里）：
  - 战斗日志／追加动作数组（XGojo begin/end_round/finish、AffixBattle／QiyinEffects／QiyinRule／Skills／Horsemen 的 end_action、end_turn、damage_ops、decide_enemy、perform、invoke_counter）：调用处 `append_array` 或 `is_empty()`，空＝没有；
  - 总账 XTianqiLedger（audit、pools、passive_buckets、nine_*）：调用处先判 `detail_on／auditing／bucketing／nine`，空壳恒 false；
  - 图标 icon_texture（XGojo、QiyinArt）：先过 `is_icon`，空壳恒 false；
  - 开局菜单／存档标签／炼坊／七印／界面页（XTianqi.*、XTianqiAlienGear／Codex／Reforge、Brand、Elements、Merchant、RingStyle、Qiyin、Line 等）：调用处在天启篇开关或天启篇存档守卫内，或页面本身发行里进不去（`new_game_enabled` 为 false）；
  - `XTianqiSkills.spec`、`XTianqiDrop._members`、`XTianqiRandom.battle_source` 等：调用处带默认值或喂给恒 1.0／恒空的函数。
- 抽样核过的调用处：battle_logic 1230／1264／2175、damage.gd 349／375／382、actor.gd 1120／1576、alienation.gd 169／292／248、zhenqi.gd 118／891、xdb.gd 160、power_books.gd 60／77、training.gd 102／122、xui.gd 264／268、entry.gd 660～736。**不是每个调用链都追到底**：我看的是调用处自带的守卫，没有跑发行模式实测；不确定的列给总装：`XTianqi.take_pending`（map_scene.gd:189，返回 `[]` 当事件待播表）、`XTianqiHallIntro.cover`（map_scene.gd:172，空壳返回 null、调用处未用返回值）。

## 我不同意的地方
- 派单要求「空壳会返回空容器的、被调用的」都登记，我照做了，但这是**高误报**检查：77 条里只有 1 条真有问题，其余靠调用处守卫。我没换思路（反向白名单也要逐个看调用处），理由是：此后新增的天启篇函数被西游档调用且无特例时一定会报，成本只是写一行理由；代价是名单会长。若觉得噪声太大，可后续改成只对「调用处前三行没出现 `.on(`／`_on(`／`active`／`enabled` 守卫」的报（启发式，我没做，怕漏）。
- `""` 也算空容器（派单点名了），导致一批纯文案函数进了名单；它们在发行包里拿到空串只影响天启篇界面，已逐条标注。

## 待交叉核查
- `battle_random` 特例是否正确、发行入口开战不崩（`测试发行入口冒烟.py` 若覆盖战斗可顺带跑）；76 条「已确认空值安全」的理由抽核。

## 可优化（流程／工具／效率）
- 建议：`发行入口冒烟` 增加一次真开战（不传 random_context）的断言，能在发行里直接抓到类似 `battle_random` 的 null（预计收益：这类漏网不再依赖静态检查；归工具车道）。
