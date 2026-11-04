# 交付：cc/nezha-tools57

- 车道／工作者：D 工具／哪吒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】O-153 钩子行收窄按审查 35 P2 收紧（dev.待定）

只改 `07_开发环境`（`选测.py`、`选测对照.json`、`测试选测.py`），不碰 Godot 工程。分支从 `cc/nezha-tools56` 切出，已合并 main。

- **P2-1 只认独立调用**：`hook_modules` 改成逐 hunk 看。先要求纯新增（删行／改行里有代码就退回）；新增的代码行必须依次拼成三种钩子块之一：① 独立调用 `XMod.fn(...)`（第一个左括号配对的右括号必须是行尾）；② `var x := XMod.fn(...)` 后紧跟同层 `if not x.is_empty():` 和更深一层 `return x`；③ `if XMod.fn(...):` 后紧跟更深一层的一行（独立调用、`return`、`return 字面量`、`return XMod.fn(...)`）。同一行带运算／赋值／分号（`var k = XFoo.f(1) * 2 + a.atk`、`hp = XFoo.f(hp) - 100`、`XFoo.go(); d.hp = 0`）、钩子后无条件 `return`／`return false`、`if` 里带 `and`、`if a:` 包着钩子，一律退回整组。原 `glue` 正则删除。
- **P2-2 白名单**：`excludeModules` 换成 `roleModules`（17 个，角色专属模块）：XRaven、XMira、XYomiJingliu、XToji、XSukuna、XGarou、XYunshang、XYunshangOrders、XGuyu、XTusu、XTusuXuan、XXuanBattle、XXuanChart、XCat、XCatDamageHooks、XQiyu、XNanoha。每一项我都对过 `core/` 下该文件的头注释（角色编号＋名字），`测试选测.py` 里 `test_real_role_whitelist_matches_code` 会再核。刻意没列：XBlackFlash（甚尔、宿傩共用）、XActorDamageHooks、XNumberBoost、XSkillProgression（多角色共用的分派／数值池）、XBinding（框架）、XHeartsteel／XHubris（成长装备，不是角色）、XAlienBattle／XRaceBattle／XZhenqi（系统）。新增角色模块要手动加进白名单；审查点名的 16 个核心设施和任何新模块默认判不是钩子。
- **测试**：`HookLineTests` 加 `test_p2_1_only_standalone_calls_narrow`（12 个反例退回、5 个正例收窄）、`test_p2_1_deleted_or_changed_lines_fall_back`、`test_p2_2_only_role_modules_are_hooks`（审查点名的 16 个设施＋XBrandNewThing／XBinding／XBlackFlash）、`test_real_role_whitelist_matches_code`；原用例的钩子模块 `XHooked` 改成真角色模块 `XToji`。`HookHistoryTests` 把 5bbccdcc（闪避公式）、f803fc1f（护盾账本）列成不该收窄，并按新选法重排其余批次。

## 历史几批收紧后的选法（不抽样，`选测.py <合并>^1 --head <合并>`）

| 合并 | 整组（关闭收窄） | 收紧后 | 结果 |
| --- | --- | --- | --- |
| 5bbccdcc wukong-reach-air2（闪避公式） | 234 | 234 | 退回整组 |
| f803fc1f bailong-tusu2（护盾账本） | 310 | 310 | 退回整组 |
| b5f3a0ce wukong-xuan3 | 373 | 373 | 退回整组 |
| c7b7f237 bajie-growth5 | 182 | 182 | 退回整组 |
| effc9fa4 wukong-xuan2 | 179 | 178 | 收窄（只差 1） |
| c1b44fa7 bajie-rules1b | 269 | 269 | 退回整组 |
| 7e7b1c71 bailong-xuan-fix1 | 7 | 7 | 退回整组 |
| 296a571a wukong-honghuang2 | 349 | 349 | 退回整组（本来就是真改核心） |

tools54 当时 dev.294～296 那批从 337／383 收到几十个的收益，在收紧后基本没有了：真实车道里的钩子大多写成 `list = XBinding.filter_targets(...)`、`value = XGuyu.hp_damage(t, value)` 这类赋值式，或夹着对原有行的修改，按审查 35 的口径本来就不该放。

## 交接板

- **建议：先别重开**（总装的 `hookLines.enabled = false` 保持）。收紧后它几乎不再省场景（上表），重开只增加误判面和维护白名单的负担。若要重开，也不会有害：所有历史批次不是持平就是只差 1。真想拿回收益，要先让车道把钩子写成独立调用（例如 `XGuyu.hp_damage(t, value)` 改成不赋值回去的形式，这本身要改游戏代码，不是工具能解决的），或者另想办法，比如按「是否碰了核心文件里非钩子的行」给战斗场景再分层。
- 用户试玩说明：无（工具改动）
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：见上。回退：`选测对照.json` 的 `hookLines.enabled = false` 或 `XIYOU_HOOKS=0`（本期没动开关，保持 true；main 上若已是 false，合并后以 main 为准）。
- 建议：钩子行收窄收益没了，选测省时间改从别处下手（见 `cc_nezha-tools56.md` 的基准建议，认本机已验的合并，约省一半云端额度）。

## 本分支提交

（见 git log）

## 验证

- `测试选测.py` 105 个全过（含新增 4 个）；`回退开关覆盖.py` 解析不了 0 行。
- 没碰 Godot 工程，不跑 Godot 选测。
