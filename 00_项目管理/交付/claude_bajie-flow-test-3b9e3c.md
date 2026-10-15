# 交付：claude/bajie-flow-test-3b9e3c（第二轮）

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_3）
- 位置：worktree `.claude/worktrees/bajie-flow-test-3b9e3c`，分支 `claude/bajie-flow-test-3b9e3c`
- 状态：可合并

## 任务

一键出售（含「出售锁定」）与道具置顶，照正式版做（唐僧 2026-10-15 派）。

## 独占文件

- 新增 `01_Godot工程/modes/xiyou/core/item_marks.gd`（XItemMarks：锁定/置顶状态、列表标记与排序、卖价、一键出售规则）
- 改 `01_Godot工程/modes/xiyou/ui/shop.gd`（一键出售窗口、出售列表标记、锁定拒卖）、`ui/item_scene.gd`（操作菜单「道具置顶」「出售锁定」）
- 新增测试 `01_Godot工程/tests/xiyou_item_marks.{gd,tscn}`
- 文档：`00_设计/优化登记.md`（O-030）、`00_设计/界面风格.md`（商店一节，含一处 `dev.待定`）
- 没改共用组件；存档结构不变（物品锁定/置顶存在已有的 `XState.flags`）。

## 变更记录草稿

```
## 2026-10-15 【Claude·八戒·未经Codex检验】一键出售、出售锁定、道具置顶（dev.待定）

- 照正式版做（只读参照：app.nw/js/plugins/Star_ShopOnekey.js、Star_ItemTop.js、js/codex/runtime/installUnifiedQualityRuntime.js；插件顺序 ShopOnekey 92、ItemTop 123；「一键出售」指令由 YEP_ShopMenuCore 加，购买限定时灰显）。
- 一键出售：商店指令「一键出售」打开 Window_OnekeySellCommand (350,150,240,行数×36+内边距×2)，七档「出售普通品质」…「出售神话品质」左对齐（每档都含旧档 0～14，故七行）。确定：背包（不含身上）里备注品质属于该档旧档 0～14、名字不带「[锁定]」的装备逐件卖出，卖价按 YEP sellingPrice（<Sell Price> 优先，否则半价向下取整），0 价也卖（原版现行代码不查价格），无确认；之后关窗回到指令窗（取消同）。旧档 15（混沌 Mod）不在一键出售里（原版只到 14）。
- 出售锁定：物品页操作「出售锁定」——物品记入 ItemSpLock（无提示），装备实例名字加/去「[锁定]」并提示「锁定完成」「取消锁定」；商店出售列表选中锁定的提示「已锁定 无法出售」并留在列表；挂机自动卖出、一键出售都跳过名字带「[锁定]」的装备。
- 道具置顶：物品页操作「道具置顶」（只对物品）——记入 TopItem，提示「置顶完成」「取消置顶」；物品列表与商店出售列表把置顶物品按出现先后逐个移到最前（后出现的更前），名字加「[置顶]」。做完都留在操作菜单。
- ItemSpLock / TopItem 存在 XState.flags（随存档，存档结构不变）。
- 优化 O-030：物品的「[锁定]」「[置顶]」只画在物品列表里，不像原版那样改 $dataItems 的名字（原版会漏到购买列表、提示等处）；`XItemMarks.LIST_ONLY_NAMES` 设 false 恢复。
- 验证：新测试 xiyou_item_marks 26/26（一键出售规则与窗口、锁定/置顶切换与提示、列表顺序与标记、锁定拒卖、购买限定灰显、存档往返）；检查.sh 全部通过；合并 main 后重跑转换器，相关专项（xiyou_item_marks、xiyou_floor_run 到六层 95/95、xiyou_flow、xiyou_gear_ui）全部通过。界面属标准级，**未做正式版截图对照**（窗口矩形按代码：x/y 来自插件、宽为 Window_Command 默认 240、高为 fittingHeight），待有条件时用 ui_reference 补。
- 提交：见交付单「本分支提交」
- 未完成／已知问题：战斗物品窗口（Window_BattleItem 也继承 makeItemList，原版战斗里同样置顶/标记）Godot 还没有，做时接 `XItemMarks.apply_list`。
```

## 交接板

- 下一步：第 6 项「逐页复现原版界面」里删去「一键出售与出售锁定；道具置顶」；补一句「战斗物品窗口做时接 XItemMarks.apply_list」。一键出售窗口待正式版截图对照（标准级，可与下批界面一起截）。
- 用户试玩说明：商店「一键出售」可用（按品质批量卖背包装备，锁定的不卖）；物品页可「出售锁定」与「道具置顶」。
- 需要用户决定：O-030（物品锁定/置顶标记只显示在列表里）。

## 进度账

- 界面部分：一键出售、出售锁定、道具置顶三项完成（完成度由沙僧复核）。

## 发现的问题

- 无新 bug。原版两处行为照做未改（如需改再登记）：一键出售没有确认、0 价装备也卖。
- 工具（给唐僧）：车道 `git merge main` 后转换产物（generated，不入 Git）不会更新，worktree 里的 `检查.sh` 仍按旧切片跑（本轮第一次检查只测到五层）。要在合并 main 后再跑一次 `新建工作树.sh --补齐 <路径>`（约 20 秒）。可考虑让检查.sh 在切片比转换产物新时提示。

## 本分支提交

- 0b89468 第二轮开工：交付单
- 2a85046 一键出售、出售锁定、道具置顶＋测试＋O-030
- 9064676 合并 main
- （本提交）交付单可合并
