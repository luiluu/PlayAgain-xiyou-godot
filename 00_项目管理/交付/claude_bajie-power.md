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

### 独占文件

- 新 `01_Godot工程/modes/xiyou/core/power.gd`（XPower）、`tests/xiyou_power.gd/.tscn`、`03_转换工具/mv_oracle/power_probe.cjs`（加进 同步正式西游.py PROBES，输出 power.json，约 5 秒）
- `ui/help_card.gd` 装备战力行（tests/xiyou_help_card 改为连战力行一起比）、`ui/options_scene.gd` 战力项、`core/xconfig.gd` 加 codexPowerEnabled 默认值

### 已完成

- 装备评分 XPower.equipment：照 installCombatPowerRuntime v2 equipment()——基础属性（数据库记录按 YEP_CoreEngine 备注覆盖 params）、特性 11/13/14/21/22/23/32/33/34/61/62/64、战力相关备注（终伤、暴伤、元素增幅/放大、武器类型、穿透、PBST/XPBST/SPBST、再行动、额外释放、独立乘区）、被动状态（<Passive State>，状态的特性、G_ShuXing、备注）、法宝成长（初始等级×每级属性）、三档参照伤害增益（CodexDamage reference 预演：攻防 100、公式 1e6、物理一半＋13 元素均分、固定减伤 25000×终伤倍率在取整后扣）、finish 分配三项。power_probe 按特性/备注种类自动取 72 件（含 12 件法宝）：总分、三项、逐行明细全部一致（xiyou_power）。
- 说明卡「装备战力：N」行（名字后，18 号、rgba(255,211,115,1)）：help_cards 参照 389/389，含 126 行战力。参照里每类第一件真装备（水果刀、学徒斗篷）没有这行——参照引擎首次 setItem 的现象，测试对这几张去掉 Godot 的战力行比较。
- 设置页「战力显示与估算」：ON/OFF，确定取反、左右开关，切换清缓存；状态与正式版选项参照一致（默认 ON，存成 false 才关）。
- 未移植：渡鸦／米拉／甚尔／狂妄／心钢专属装备加成（角色未接入）；法宝升级（等级取初始等级）。

### 未做（下一段）

- 角色战力 CodexCombatPower.actor：孤立角色＋中性敌人（防御 100／1 万／100 万三档）、10 回合技能循环（冷却、预热、费用、再生、额外行动、重复次数）、爆发/持续、有效生命、辅助治疗，curve 折分；自身（裸装）与装备差。参照已试：切片 10 个角色各 2～3 个可计入技能，单次约 0.6 秒。
- 界面：装备页／技能页状态窗「战力 N」（现「战力 …」）、主菜单「战力见状态」→ 有缓存时「战斗力 N」、装备变更后的战力提示。

## 停在哪里

- ①② 已提交；全量检查只差正式源 v0.25 的登记（见上面「验证」），已告诉唐僧。
- ③ 装备评分、说明卡、设置页已完成（26f1221、36ff923、3e5fba2）；下一段是角色战力与装备/技能页、主菜单显示。

## 本分支提交

- 4aba769 开工交付单
- f5a5680 新建工作树.sh --补齐 刷新旧参照、bash 调用提示
- f24e85e 商店数量窗卖出报酬列与装备数量光标
- c6f9fe6 交付单：①② 检查结果
- 26f1221 WIP 装备评分＋探针；36ff923 WIP 说明卡战力行＋法宝成长；3e5fba2 WIP 设置页战力项
