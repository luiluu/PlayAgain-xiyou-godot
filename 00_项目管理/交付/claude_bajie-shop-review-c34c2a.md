# 交付：claude/bajie-shop-review-c34c2a

- 车道／工作者：B 界面／八戒_76（Claude），八戒接手（分支由 claude/bajie-attr-points 合入，旧交付单名 claude_bajie-attr-points.md 已删）
- 状态：可合并（期一：商店钩子收尾）

## 变更记录草稿

## 2026-10-26 【Claude·八戒·未经Codex检验】商店测试用自动关闭钩子（dev.待定）

- 起因：悟空_60 交付单「可优化」：`XMessageBox.auto`／`auto_answers` 不管商店，楼层专项走到「购买物品」会卡到 600 秒超时。
- 做了什么：`XShop` 加 `static var auto_close := false` 与 `auto_log`。为真时商店一打开就把 `{goods, purchase_only, stock_group}` 记进 `auto_log`，下一帧发 `closed`（等 `open_shop` 接上 await），事件接着往下走。默认关，正式游戏不受影响；只在测试里设，用完设回 false。
- 新专项 `tests/xiyou_shop_auto_close`（10 项）：恰兰吉尔战争利器武器店 Map072 EV2，选「离开」不开店；选「购买物品」商店即开即关、记下 1240～1251 号武器各 200000、事件走完（后面的公共事件 249 照跑）、商店节点已释放、地图空闲；默认值为关。
- 楼层专项要用时：`XShop.auto_close = true`，跑完查 `XShop.auto_log` 的商品表即可，不必再在专项里删掉商店步骤。reach069 的飞艇公司商店还在悟空分支上（main 没有 Map069），所以示例用的是 main 已有的 Map072；悟空合并 Map069 后可在 reach069 里直接用。
- 原派单期一的修炼点数界面：重制已有（dev.155 `XTraining`／`XTrainingScene`，mv_script 已接 `Star.ActorAttributePlusPoints.XiuLian = [...]` 与 `SceneManager.push(Scene_ActorAttributePlusPoints)`，带分号也认）。北丑居 Map090 只有南贤 EV4 一个事件调用（命脉强化表项 49～56，每项 3 级、每级 15 亿精魂），切片接入后无需界面改动。唐僧_13 调整后本车道不接 Map090。

## 交接板

- 下一步：楼层专项遇到商店事件时用 `XShop.auto_close`；Map090 北丑居可由内容车道直接接（修炼界面已有）。
- 用户试玩说明：无（只加测试钩子）。
- 需要用户决定：无

## 进度账

- 无变化（测试基础设施）

## 验证

- 八戒_76：`并行测试.py … xiyou_shop_auto_close xiyou_flow`：先红（钩子未加时解析失败），加钩子后 10/10、48/48。
- 八戒接手（2026-10-27，合入 main 99ac357d 后）：`并行测试.py … xiyou_shop_auto_close xiyou_flow xiyou_event_compare`：10/10、48/48、5/5，168 秒。
- 再合 main（只带进白龙交付登记）后 `检查.sh --affected main`（长任务.py 启动）：选测 15 个场景全过（event_compare 5、flow 48、gear_ui 47、gold_cap 30、item_list 38、item_marks 108、legion_tech 1178、magic_level 7、orb_ui 39、review_fixes 16、shop_auto_close 10、shop_buy 10373、shop_stock 46、system_evidence 15、window_rects 9），文档登记、访问守卫、导出排除通过，53 秒。
- 临时输出只在会话草稿目录，未写进工作树；已清理。

## 可优化（流程／工具／效率）

- 已做：`XShop.auto_close` 测试钩子（回退：删掉 shop.gd 里两处 auto_close 代码和新专项）。
- 建议：测试用例写错（解析失败）时 Godot 不退出，并行测试要等 600 秒超时才报。可在并行测试里看到 `SCRIPT ERROR: Parse Error` 就提前结束该场景（省 10 分钟／次，归哪吒车道）。

## 本分支提交

- f2f97d07 商店测试用自动关闭钩子＋专项 xiyou_shop_auto_close
- 51abd1ea WIP：交付单草稿与 .uid（总装代存）
- 1e5fc5f4 交付单改名（八戒接手）
