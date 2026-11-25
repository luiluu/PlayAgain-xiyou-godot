# 交付：luiluu/t509

- 车道／工作者：T509 洪荒首证不隐藏、写明首证人（Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-25 【cc·T509·未经审查】洪荒首证对所有人显示名字并写明首证人（dev.待定）

- 依据：Kyo 11-25「先别出包，洪荒首证不要隐藏，要写明首证人之类的」「首证人：大手子」。
- 52 洪荒首证没解锁时不再显示 ???，称号列表照名字和图标（曙光流光图标 6427）列出，后面接说明；样式、选了不变的做法与 53 洪荒·阿夜一致（`XHonghuangTitles.VISIBLE_LOCKED` 多一项）。51 洪荒证道照旧 ???。
- 只有兑过码的本机能佩戴：`XDesignation.apply_choice` 对未解锁项不变，T508 本机解锁逻辑一行没动。
- 只西游档；天启篇存档、回退开关关着都不列，天启篇零改动。
- Kyo 11-25 改定写法（取代原说明句和我加的「：」）：照洪荒·阿夜那行，名字后直接接全角括号：「洪荒首证（首位证道洪荒者的荣誉，首证人：大手子，不可获得）」。

## 玩家可见文字（Kyo 11-25 逐字定稿；待小A 审）

| 位置 | 文字 |
| --- | --- |
| 更换称号列表，52 未获得 | 洪荒首证（首位证道洪荒者的荣誉，首证人：大手子，不可获得） |

## 截图

- 无（本机 Godot 起不了图形页，未截图；列表为选项文字，测试里逐字断言）。

## 测试

- 本机：语法检查 0 问题；本机直接跑 Godot 专项因工作树未补齐转换产物编译失败，没测。
- 专项 `xiyou_honghuang_titles` 改断言（52 显示名字＋说明；选 52 未获得不变），云端选测 6 个场景（xiyou_designation、xiyou_event_compare 四片、xiyou_honghuang_titles）2 片全过：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45644265094 （提交 b5b31326c，等到跑完）。

- 改写法后复跑：云端选测 6 个场景全过（含 xiyou_honghuang_titles）：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45647309032 （提交 72143d0da，gh run watch 前台等完）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处 | 逐处结论 |
| --- | --- | --- |
| `XHonghuangTitles.VISIBLE_LOCKED`／`locked_choice` | 1 处（`git grep -n 'locked_choice' -- '*.gd' ':!*/tests/*'`：designation.gd `_locked_choice`） | 只多一个 id，别的号不变 |

## 优化登记草稿

- 无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 交接板

- 下一步：小A 审文字。需要用户决定：无。
