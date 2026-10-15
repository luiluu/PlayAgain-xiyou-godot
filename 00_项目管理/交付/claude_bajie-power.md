# 交付：claude/bajie-power

- 车道／工作者：B 规则·界面／八戒（Claude，重制_八戒_4，沿用）
- 位置：worktree `.claude/worktrees/bajie-flow-test-3b9e3c`，分支 `claude/bajie-power`
- 状态：进行中（①② 功能完成，等 main 登记正式源 v0.25 后复检；③ 进行中）
- 任务（唐僧 2026-10-15 09:55 派）：①`新建工作树.sh --补齐` 刷新过旧的 generated/oracle 与转换产物；②商店数量窗卖出报酬行（YEP_X_MoreCurrencies Window_ShopNumber）；③战力估算（installCombatPowerRuntime），数值用 mv_oracle 参照。
- 预分配编号：O-031～O-033（①② 未用）

## 第一批：①② 

### 独占文件

- `03_再刷重制_Godot/07_开发环境/新建工作树.sh`
- `01_Godot工程/modes/xiyou/ui/shop.gd`（数量窗）、`core/item_marks.gd`（卖出报酬解析加买入价标记 `buy`、`draws_gold`）
- `01_Godot工程/tests/xiyou_item_marks.gd`

### 变更记录草稿

```
## 2026-10-15 【Claude·八戒·未经Codex检验】补齐脚本刷新旧参照；商店数量窗卖出报酬列（dev.待定）

- 新建工作树.sh --补齐：已有 generated 时，把主工作区 generated/oracle 里较新的文件克隆进来（按修改时间；本分支独有或比主工作区新的文件保留，并打印保留了哪些），然后照旧按本分支重跑转换器与导入。之前合并 main 后旧参照不刷新，worktree 检查会误报（八戒连续两轮碰到）。脚本是 zsh，用 bash/sh 调用时开头就报「本脚本是 zsh 脚本」并退出 64（原来报 `A: unbound variable`）。
- 商店数量窗（YEP_X_MoreCurrencies Window_ShopNumber）：卖出时在金币列左边接着画报酬列，每个变量／物品一列，三行是现有、「+数量×单价」（不分组）、结算；变量列是「数值 图标 变量名（系统色）」，物品列是「数值 图标」；按备注行倒序从右往左排，列间隔 5，金币列宽按 getCoreGoldWidth(max×100)。
- isDrawGoldCurrency：物品有 <Variable/Item x Buy Price> 且基础价为 0 时，数量窗不画金币三行（如武器 961「哈耳庇厄之爪」卖出只显示不朽碎片与物品 180）。
- 数量光标宽度：本 MOD 装备是独立物品，maxItems 为 1，光标按 1 位字宽（原来按 9999，装备的光标偏宽、「×」偏左）。
- 标准级参照：在 ui_reference 浏览器里跑正式版，记录 Window_ShopNumber 的 drawText／drawIcon 调用（w961×2、物品 10×3、w73×1 三例）；xiyou_item_marks 逐项比对文字、颜色、字号、对齐、y，x 差 3 像素以内（字宽累积），另比对光标位置。截图对照：`03_再刷重制_Godot/04_验证/本地结果/出售报酬数量窗/`（正式版_961.png、Godot_961.png，数量窗部分一致）。
- 验证：合并 main（2b9545f，已是最新）后 `检查.sh --oracle`：37 个 Godot 测试全部通过（xiyou_item_marks 88/88、xiyou_rules 20468/20468、xiyou_event_compare 5/5 等），参照守卫与 MV 参照引擎通过；唯一失败是「西游来源/转换/参照不一致」——正式应用 10:23 更新到 v0.25（package.json、Actors/Classes/Skills/Armors/CommonEvents/Map004 与若干 runtime 指纹变了），晚于本 worktree 10:20 的补齐。不是代码问题；要等 main 跑 同步正式西游.py 登记 v0.25，本分支再 merge main、--补齐、复检。
- 发现（范围外，给唐僧）：大厅 Map004 的商店有 208 件商品在正式版用变量／物品买入（<Variable x Buy Price>／<Item x Buy Price>，如防具 4279、4375、4540…），Godot 商店购买只扣金币，这些商品基础价多为 0，等于免费。属严格级规则缺口，建议另派（买入的变量/物品扣除、列表价格列、数量窗买入行、能否买）。
```

### 交接板

- 下一步：新增「商店买入的 MoreCurrencies 变量／物品价格（大厅 208 件商品）」——见上面发现。
- 用户试玩说明：商店卖出有报酬的物品时，数量窗会像正式版一样列出将得到的不朽碎片、不朽灵魂、物品等。

## 第二批：③ 战力估算

（未开始）

## 停在哪里

- ①② 已提交；全量检查只差正式源 v0.25 的登记（见上面「验证」），已告诉唐僧。
- ③ 开始：读完 installCombatPowerRuntime.js；mv_oracle/power_probe.cjs 草稿能取装备评分（未提交）。

## 本分支提交

- 4aba769 开工交付单
- f5a5680 新建工作树.sh --补齐 刷新旧参照、bash 调用提示
- f24e85e 商店数量窗卖出报酬列与装备数量光标
