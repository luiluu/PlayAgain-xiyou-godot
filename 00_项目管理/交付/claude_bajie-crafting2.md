# 交付：claude/bajie-crafting2

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_55）
- 状态：可合并

## 规模估算（开工时写）

原版 hc.js（Recipe Crafting，44KB）＋ data/Recipes.txt。读码要点：插件在 plugins.js 里叫 `hc`，代码却读 `PluginManager.parameters('RecipeCrafting')`，参数一项都取不到（参照里读出 0 项），全部走代码缺省（类别「炼金术、打造、加工、珠宝」、经验公式 50×等级、可批量、显示金币／玩家等级／类别等级、玩家等级图标 1045、成功提示 `制作成功!`、失败 `Crafting failed!`、满级 `MAX LEVEL`）；材料的 `cons:false` 原版不认（读的是 consumed），一律消耗；配方都没写成功率，成功率恒 100。

| 部分 | 规模 | 期 |
| --- | --- | --- |
| 配方转数据：458 条，全部 known:false（打造 217、加工 142、炼金术 69、珠宝 30；结果 98% 是武器防具） | 小：新脚本 `03_转换工具/配方转换.py`，产物 `modes/xiyou/recipes.json` 入 Git（正式源冻结，不改转换器） | 本期 |
| 运行时：已知配方、四类别等级与经验（新存档字段）、材料计数（物品按数量、武器防具按背包实例）、可制作数、制作一件／多件（扣材料与金币、得结果、类别经验升级、玩家经验 pxp） | 中 | 本期 |
| `crafting learn N`：193 个公共事件（190 张「设计图」物品使用）＋ Map006 一处；解释器插件指令只加 `crafting` 识别一处（learn／forget） | 小 | 本期 |
| 制作界面 Scene_Crafting：帮助窗、类别横排、配方列表（x可做数）、详情（等级需求、材料拥有/需要、费用）、数量确认（←→ ±1、↑↓ ±10）、金币窗、类别等级经验条、结果弹窗；主菜单开放「制作」 | 中大 | 本期 |
| 鼠标用的 ButtonSet 五个按钮（数量 −10／−1／+1／+10、确定） | 小 | 可砍（放最后） |
| `crafting call 类别`（Scene_CraftingSpecific）：正式数据里没有事件用 | — | 不做 |

合计约一期半，本期全做；ButtonSet 按钮做不完就砍并写明。

## 变更记录草稿

## 2026-10-23 【Claude·八戒_55·未经Codex检验】制作系统第一期（dev.待定）

- **配方数据**：新脚本 `03_转换工具/配方转换.py` 照 hc.js 的读法把冻结正式源 `data/Recipes.txt` 转成 `modes/xiyou/recipes.json`（458 条，入 Git；`--check` 核对产物与源一致）。没改转换器。
- **规则**（新 `core/crafting.gd` XCrafting）：已知配方、四类别（炼金术、打造、加工、珠宝）等级与经验（新存档字段 `XState.crafting`，旧档读入为初始值）；材料计数（物品按持有数、武器防具按背包实例）；可做数；制作一件／多件（扣材料与费用、得结果——武器防具走独立装备 `gain_gear`、类别经验 xp，经验 ≥ 50×等级升级）。照原版：插件参数一项都没读到（插件名 hc 与代码里的 RecipeCrafting 不符），全部用代码缺省；材料的 `cons:false` 不认，一律消耗；配方没写成功率，恒 100；Codex 宝珠稀有化（installNativeOrbRuntime）把产出宝珠的配方当作未学会，列表不显示（参照里珠宝类学会的 6 条全是宝珠配方，列表为空）。
- **学会配方**：设计图物品的公共事件（193 个）与三层训练场 Map006 的插件指令 `crafting learn N`；解释器插件指令只加 `crafting` 一处（learn／forget），写法同 EnemyBook／ShopInventory。
- **界面**（新 `ui/crafting.gd` XCraftingScene，照 hc.js Scene_Crafting）：帮助窗、类别横排、配方列表（x可做数，做不了半透明）、详情（等级需求、材料持有/需要、费用）、数量确认（←→ ±1、↑↓ ±10）、金币窗（原版内容层没随窗口变宽重建，金额挤在左边，照画）、类别等级经验条、结果弹窗（「3x 狼神爪 制作成功!」）。主菜单「制作」开放（Scene_Menu.commandRecipe，从菜单进可以制作）。
- **砍掉**：确认数量时鼠标用的 ButtonSet 五个按钮（−10／−1／+1／+10／确定）没做，键盘与点窗口照常可用；`crafting call 类别`（Scene_CraftingSpecific）正式数据没有事件用，不做。
- **参照与测试**：`tests/fixtures/crafting_oracle.json`（冻结 v0.28 浏览器参照：新局学会 26 条配方、配方 1 材料 ×3、金币 150000；窗口几何、类别窗、四类列表、每条配方的详情与确认窗、类别等级窗、金币窗，配方 1 做 3 件前后的数量、经验、弹窗、列表与详情）；新专项 `xiyou_crafting` 43 项。`xiyou_panels` 灰显名单 5→4 项。
- **改到的非独占文件**：`core/mv_event_core.gd`（插件指令加 `crafting` 一处，3 行）、`core/xstate.gd`（存档字段）、`ui/menu.gd`（指令开关行与「crafting」分支）。

## 交接板

- 下一步：制作的鼠标 ButtonSet 按钮（可做可不做）；主菜单其余灰显按盘点顺序：种族祝福菜单（随种族规则）→ 异化工坊 → 宠物。
- 用户试玩说明：主菜单「制作」可以用了。用「设计图」学会配方后，在制作页选类别、选配方，看材料够不够，确定后用左右键（±1）、上下键（±10）选数量再确定，做出的装备进背包，类别等级随经验提升。产出宝珠的配方照原版稀有化不显示。

## 进度账

- 养成与周边系统：15% → 17%，制作系统第一期（458 条配方、学会、制作、类别等级）接入（八戒估，待沙僧复核）

## 本分支提交

- 6c5e425e 配方转换脚本与 recipes.json（唐僧_15 代存）
- a7b5fa84 制作系统规则、界面、学会配方、主菜单入口、参照与专项
- （本提交）交付单

## 验证

- 相关专项（`并行测试.py`，8 个全过）：`xiyou_crafting` 43/43（新）、`xiyou_panels` 35/35、`xiyou_interp_review` 13/13、`xiyou_event_compare` 5/5、`xiyou_enemy_book` 41/41、`xiyou_save_page` 40/40、`xiyou_battleback_save` 5/5、`xiyou_review135` 84/84。分支已含最新 main（dev.141 之后 main 没再前进）。`配方转换.py --check` 一致。
- 截图对照：`xiyou_crafting -- --out=<目录>` 窗口模式存列表、确认 x3、弹窗三张，与原版截图版面一致（原版参照截图的帮助窗是空的，是取参照时直接调了 commandOk、类别窗没停用所致；正常操作时帮助窗显示结果说明，重制同）。
