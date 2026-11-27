# 交付：luiluu/t557

- 车道／工作者：cc（claude-sonnet-5-5＋medium，P6）T557 测试模式开启全图鉴
- 状态：进行中

## 变更记录草稿

## 2026-11-27 【cc·T557·未经审查】测试模式开启全图鉴（dev.待定）

- 沿用设置页现有「测试模式」（`XTestMode`，要本机解锁文件），开着时图鉴全开：怪物图鉴全部当作已登记（名字、数值、掉落列表可看），天启篇异化图鉴全部点亮，人物图鉴里特殊角色没学会的技能不再标「未解锁」、不变灰。人物图鉴、镶嵌图鉴本来就全部列出；隐藏角色、`<book:no>` 敌人照旧不列。
- 只在读取处放行（`XTestMode.book_all`），不写存档、不写全局配置；关掉测试模式即回到原来的登记情况。
- `xiyou_test_mode` 加一组断言（未解锁／关着照旧、开着全开、掉落可打开、状态不变、关掉还原）；`xiyou_enemy_book` 隔离本机解锁文件。

## 交接板

- 下一步：无
- 需要用户决定：Kyo 这台 Mac 上没找到测试模式解锁文件（开发数据目录、发行数据目录、11-15 备份 zip 都没有），所以设置页「测试模式」现在应是灰的；要用就在 `user://modes/xiyou/test_mode_unlock` 建一个空文件（车道没有替他建）。

## 进度账

- 无变化

## 可优化（流程／工具／效率）

- 建议：别的专项没有隔离本机测试模式解锁文件，Kyo 本机开着测试模式时跑本机测试可能受影响（经验 ×10 原本就有此情况）；可由工具车道在测试环境统一指一个不存在的解锁路径。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XEnemyBook.registered` | 6 处（`git grep -n 'XEnemyBook\.registered' -- '*.gd'`，另有定义 1 处） | 调用方 6 处逐处结论：`enemy_book.gd` 目录名、状态窗隐藏（两行）、确定开掉落共 4 处，`skin_book_page.gd` 缓存键、右牌、登记计数共 3 处中的游戏代码都只管显示；战斗里 `tianqi_enemy_ai.registered` 是同名无关函数；没开测试模式时返回值与原来一致 |
| `XTianqiAlienCodex.seen` | 只经 `rows`／`progress` 给异化工坊页显示（`git grep -n 'XTianqiAlienCodex\.' -- '*.gd'`） | 只管显示；`record` 的点亮判断走 `XConfig.tianqi_alien_mark`，不经 `seen`，不受影响 |

## 验证

- 本机（并行测试）：test_mode 83/83、enemy_book 96/96、actor_book 28/28、determinism 372/372、tianqi_ending 24/24、rift_alien 150/150、ui_skin_card_p 106/106、list_pager 151/151、six_dim_book_boss 66/66、lobby_debug_npc 通过
- 语法检查：1250 个 .gd，0 个问题

## 本分支提交
