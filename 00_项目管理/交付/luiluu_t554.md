# 交付：luiluu/t554

- 车道／工作者：cc（claude-opus-5-5＋medium，P8；小A 周额度用完改派）T554 人物图鉴页优化
- 状态：进行中

## 变更记录草稿

## 2026-11-27 【cc·T554·未经审查】天启篇人物图鉴牌头：立绘不出圈、角色属性上色、武器防具分行对齐（dev.待定）

- 依据 Kyo 11-27 反馈（私密仓 协作交接/附图/20261127_图鉴/4～6.png）与事项 84（图鉴改版只改天启篇，西游档不动）。只改新界面图鉴 `XSkinBookPage`；西游档、原版界面风格的旧图鉴页一行不变。
- 立绘出圈：法阵里的侧视图按「看得见的部分」量（原生图取站立三格不透明像素的外接框，新角色用外观档案框），超出法阵外接方框才缩到 0.86 以内并居中；本来放得下的位置大小不变。全员 163 位扫过，缩的只有小铃兰（帧 256）和奈叶（帧 128）。开关 `XSkinBookPage.FIT_SPRITE`。
- 牌头改三行「角色属性／武器／防具」：标签同宽一列，值从同一竖线起；类型名整个换行不拆字（原来「副／手」被拆），续行对齐值列；掌握特性重复的去重（小铃兰两个「法杖」，35 个职业有重复号）；一类全会写「全部」。角色属性按元素上色，没有写灰字「无」。
- 「属性」与「角色属性」合并：天启篇牌头不再画原版「属性」（人物属性，旧克制用），只留「角色属性」。依据天启篇元素重做 v0.7「旧克制停用，我方挨打也不看克制」，两行并列只会让人以为是一回事。开关 `XSkinBookPage.HEAD_ROWS`（关＝回到改前一段折行＋白字角色属性）。
- 「矢」：查实防具类型 13「矢」有一件装备 4541 花与鸟之矢（神器专武，天启篇大厅「强者证明的奖励」能领），167～179 号 12 位能装，所以照列（协调 11-27 定 A）；备好开关 `XSkinBookPage.HIDE_ARMOR_TYPES`（默认空，设 `[13]` 只藏图鉴显示、不动数据），等 Kyo 定。
- 新专项 `xiyou_tianqi_actor_book_head`（全员立绘扫描、牌头三行数据、去重与「全部」、不拆字、开关关回改前、西游档 actor_info 与改前逐项相等且立绘不缩）。
- 玩家可见：天启篇人物图鉴头像不再出圈；属性一栏只剩带颜色的「角色属性」；武器、防具各占一行排整齐，全会的显示「全部」。

## 交接板

- 下一步：另开卡——代码里我方挨打仍按旧克制算（`modes/xiyou/core/damage.gd:378` `tq_elem` 只在目标是敌人时成立，第 403 行我方受击仍乘 `matchup(e, affinity(b))`），与元素重做 v0.7「我方挨打也不看克制」不一致；本单没改（协调 11-27 同意另开卡）。
- 用户试玩说明：天启篇 → 图鉴 → 人物图鉴，看小铃兰、奈叶、宿傩。
- 需要用户决定：图鉴可装备列表里「矢」要不要藏（只有一件花与鸟之矢；A 照列＝现状，B 只藏显示＝把 `HIDE_ARMOR_TYPES` 设 `[13]`）。「全部」这个写法与牌头文字待小A 文字审。

## 进度账

- 无变化

## 可优化（流程／工具／效率）

- 已做：无
- 建议：旧图鉴页 `XActorBook.status_ops`（天启篇选「原版」界面风格时用）也照列重复的掌握类型（如「法杖、法杖」），量小，可归下一张图鉴卡顺手改。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XSkinBookPage.actor_info`（加字段 `head_rows`、`weapons_all`、`armors_all`、`nature_parts`；天启篇掌握去重） | 调用方 14 处（`git grep -n 'actor_info(' -- '*.gd'`，不含定义）：游戏代码只有 `skin_book_page.gd` 同步右牌 1 处，其余 13 处在测试 `xiyou_ui_skin_card_p`（3）、`xiyou_tianqi_actor_notes`（4）、`xiyou_tianqi_actor_book_head`（6） | 原有字段含义不变，只多字段；去重只在天启篇（`head_rows_on`），西游档专项断言与开关全关时逐项相等；`xiyou_ui_skin_card_p` 的旧页文字可达对照照过 106/106 |
| `XSkinBookPage._draw_actor`（拆出 `_draw_actor_body`；立绘改走 `sprite_place`） | 1 处（`git grep -n '_draw_actor(' -- '*.gd'`） | 只在本页 `_draw` 调；改前牌头分支照旧走，牌头以下逻辑原样搬进 `_draw_actor_body` |
| `XTianqiNature.line_of_actor_id`（改为调新函数 `natures_of_actor_id`，结果不变） | 调用方 4 处（`git grep -n 'line_of_actor_id' -- '*.gd'`，不含定义）：`actor_book.gd` 1、`skin_book_page.gd` 1、测试 `xiyou_tianqi_element_effects` 2 | 返回值不变；新函数已登记发行空壳「已确认空值安全」 |

## 验证

- 本机（并行测试）：tianqi_actor_book_head 36/36、ui_skin_card_p 106/106、tianqi_element_effects 101/101、list_pager 151/151、test_mode 83/83、ui_sel_scale 90/90、ui_t366 35/35、tianqi_actor_notes 14/14、actor_book 28/28、actor_book_compare 1/1（工具场景跳过）
- 带窗口截图跑（`--audio-driver Dummy`）：48/48
- 语法检查：1251 个 .gd，0 个问题
- 发行空壳.py check：0（新函数 `natures_of_actor_id` 登记进 `07_开发环境/发行空壳特例.json`「已确认空值安全」）
- 工具回归.py：全部通过
- 云端选测：（待填）
- 选测.py 列出的 `xiyou_event_compare*` 四个交云端跑

## 截图（1280×720 原尺寸；20x9 为 1600×720 窗口）

改前 → 改后：

- 小铃兰：`../归档/交付截图/luiluu_t554/t554_before_127_16x9.png` → `../归档/交付截图/luiluu_t554/t554_after_127_16x9.png`（20x9 同名）
- 宿傩（矢照列、防具「全部」、角色属性「无」）：`../归档/交付截图/luiluu_t554/t554_before_172_16x9.png` → `../归档/交付截图/luiluu_t554/t554_after_172_16x9.png`（20x9 同名）
- 奈叶（第二个出圈的）：`../归档/交付截图/luiluu_t554/t554_before_108_16x9.png` → `../归档/交付截图/luiluu_t554/t554_after_108_16x9.png`
- 1 号狗逍遥（本来放得下，立绘不变）：`../归档/交付截图/luiluu_t554/t554_before_1_16x9.png` → `../归档/交付截图/luiluu_t554/t554_after_1_16x9.png`

## 本分支提交

- 02350cf5b WIP：天启篇人物图鉴牌头＋专项
- （交付提交见 git log）
