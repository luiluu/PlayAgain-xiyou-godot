# 交付：cc/t164-gem-power

- 车道／工作者：C 规则·界面／cc（T164，Sonnet＋medium，P6）
- 状态：可合并（合并顺序在 T082 分支 luiluu/cc-t082-calibrate-k 之后；本分支从它切出）

## 变更记录草稿

## 2026-11-17 【cc·T164·未经审查】光耀度（D186）：镶嵌／宝珠效果随装备等级发挥，只做显示（dev.待定）

- 概念：宝石（符文镶嵌、宝珠）的实际效果＝图鉴基础值×装备的「光耀度」；光耀度就是期四装备八项里已经在用的换算比（`XTianqiGear.flat_ratio`），**不新增数值、不改战斗结果**。
- 新增 `modes/xiyou/core/tianqi_gem_power.gd`（`XTianqiGemPower`）：光耀度文字、逐项「实际值（基础值）」、镶嵌预览；全部只认 `XTianqiBase.PHASE4` ＋ `XTianqiGear.applies`，关着每个函数返回空、界面逐字节回原样。
- `tianqi_gear.gd` 只新增只读函数 `gem_base`（镶嵌固定值＋符文之语＋宝珠固定加减的基础值八项，正是 `_compute` 里乘换算比的那三项）、`orb_slot_fixed`、`orb_lines_fixed`；现有算式一个字没动。
- 界面接线：装备详情说明卡末尾（`XHelpCard.detail_rows`）、插槽与镶嵌页（`XGearDetail.socket_rows`，新旧两套界面共用）、镶嵌图鉴状态窗一行说明、镶嵌预览（旧界面 `XHelpCard.append_rows`，新界面 `XSkinItemPage` 详情牌多一节）。
- 专项 `xiyou_tianqi_gem_power`（21 条）；相关旧专项 `xiyou_tianqi_gear_params` 19/19、`xiyou_inlay_book` 38/38 不变。
- 玩家可见：期四开着时，装备详情多「光耀度」，镶嵌图鉴多一行说明，镶嵌时能看到镶在这件装备上的实际值。

## 交接板

- 下一步：总装合并后，翻期四开关时这些显示自动出现；小A 审下面「玩家可见文字」一节。
- 用户试玩说明：期四关着（现状）画面完全不变；开着时见截图。
- 需要用户决定：无（见「我不同意的地方」，只是建议）。

## 进度账

- 无（期四显示层，不动完成度）。

## 玩家可见文字（交小A 文字审定稿）

| 位置 | 现稿 |
|---|---|
| 装备详情末尾、插槽页首行 | `光耀度：566%`（各列不同时 `310%～420%`） |
| 逐项行（详情、插槽页每个宝珠孔／镶嵌记录下） | `攻击力 +11（+2）`＝实际值（基础值）；项名用游戏术语（物理攻击等） |
| 镶嵌图鉴底部小字 | 基础值×光耀度，等级越高越盛；特效不放大 |
| 镶嵌预览首行（旧界面末尾、新界面小节「镶在这件装备上」） | `光耀度 566%（本件）`，下面同逐项行 |

## 我不同意的地方（派单要求先想）

1. **一个百分比会不会误会**：换算比按属性列（生命／物攻／物防／敏捷／幸运）各一列，同一件装备各列略不同。我的做法：只看宝石**真正加成**的那几项，各列相同给一个数、不同给范围（`310%～420%`）；没有宝石时看物攻那一列。因此头一行不会和逐项行矛盾，逐项行才是准的。
2. **只显示实际值不显示百分比？** 不建议：「等级越高越盛」要有一个数让玩家看到高级装备为什么强；所以两个都留，百分比一行、实际值逐项。
3. **名字**：Kyo 11-18 定「光耀度」（D188），已改，取代小A 定稿的「镶嵌发挥度」。
4. **图鉴说明范围**：符文之语配方里「斧额外属性+200」「伤害提高30%」这类写在备注里的 YEP 效果不走装备八项、没有换算比，**不随光耀度放大**，只有八项里的固定数值才放大。所以图鉴那句话对这类备注效果不成立，措辞请小A 把握（比如「属性数值」限定）。我没动口径。

## 验证

- 专项 `xiyou_tianqi_gem_power`（开关关：显示函数全空、图鉴无说明行、`gem_base` 全 0；开：光耀度＝换算比、逐项＝换算比×基础值、与 `effective_params` 宝石那份相差 ≤1、图鉴数字区与关着逐项相同只多一行、八项不被显示函数改动、再关回原样）21/21；`xiyou_tianqi_gear_params`、`xiyou_inlay_book` 通过；`语法检查.py` 0 问题。
- 截图（开／关）：`00_项目管理/交付/T164_截图/{on,off}_detail_mode0.png`（装备详情）、`{on,off}_detail_mode2.png`（插槽与镶嵌）、`{on,off}_inlay_book.png`（镶嵌图鉴）。工具 `tests/t164_gem_shots.gd`（不是专项）。
- **没验的**：镶嵌预览（旧说明卡追加行、新界面详情牌小节）只有逻辑专项（`preview_rows` 数值）、没截图——需要在物品页选装备→升级／宝珠列表里实操才能出图；PHASE4 开着的真实存档没试。
- 没跑 `选测.py main --list` 里的战斗核心类（`xiyou_determinism` 等）：本单只加只读函数和界面行，没碰战斗路径；改动里 `help_card.gd`、`item_scene.gd` 是共享界面文件，建议总装合并后按影响面选测界面类专项。

## 返修（小A 核查 3 P1＋3 P2，Sonnet＋medium）

专项 `xiyou_tianqi_gem_power` 29/29、`xiyou_tianqi_gear_params` 38/38、`xiyou_inlay_book` 19/19（headless，`--audio-driver Dummy`）。

| 条 | 改了什么 | 对应测试 |
|---|---|---|
| P1① 预览头行读错列 | `power_text(item, base)` 新增 base 参数，预览按待镶材料／宝珠自己加成的列算，不再读已镶宝石 | `preview_stone`、`preview_head_uses_preview_column`（已镶物攻的装备预览只加物防的基础值，头行取物防列且≠本件头行）、`multi_col_range` |
| P1② 皮肤详情牌拆节 | `skin_template_page.gd` `help_sections`：以「光耀度」开头的头行不进「自带」，与逐项行同留「说明」 | `skin_head_and_lines_same_section`、`dress_card_section` |
| P1③ 专项空转 | 删掉自比；真起战斗（`XBattleLogic`，固定随机 0.5，1 号位戴这件普攻敌人）量物攻＋命中伤害，调一遍全部显示函数后再量，开／关两态各一遍必须相同；顺手去掉无意义的 `replace`；补宝珠预览、dress_card、皮肤分节 | `damage_unchanged_by_display_on`、`damage_unchanged_by_display_off`、`params_unchanged`、`augment_preview_runs` |
| P2① 定稿文字 | `NAME`＝光耀度；范围加「（各项不同）」（新增 `head_text`）；预览首行 `光耀度：X%（本件）`／`（本件，各项不同）`；图鉴 `NOTE`＝基础值×光耀度，等级越高越盛；特效不放大 | `detail_has_power_and_line`、`socket_has_power_and_line`、`book_note_added`、`multi_col_range` |
| P2② 空槽跳变 | 空槽看五列 `[0,2,3,6,7]`（`EMPTY_COLS`），不再单取物攻 | `empty_slot_five_columns` |
| P2③ 图鉴开关 | `inlay_book.gd` 改认 `XTianqiBase.on()`（原版存档不再出说明行） | `book_note_added`（天启档）、`off_book_no_note` |

- 截图已重出（开／关）：`T164_截图/{on,off}_{detail_mode0,detail_mode2,preview,inlay_book}.png`，新增镶嵌预览（`*_preview.png`，旧界面说明卡追加行；新界面详情牌小节只有专项、没截图）。
- 没验：「预览首行读错列」没有真实「已镶防御宝石的装备」做端到端，用 `power_text(g, 基础值)` 直接断言列选择；伤害对比的显示函数与 `PHASE4` 是同一个开关，所以是「调显示前后伤害不变」，开／关两态的伤害差异本来就来自期四换算（不是本单改的）。
- P3：①图鉴底部左右文字在 130% 字体缩放会挤，`NOTE` 保持 26 字未加长；②`tianqi_gear.gd` 原算式未动（小A 已核）；③镶嵌预览截图已补。
- 我不同意的地方：无。

## 可优化（流程／工具／效率）

- 无。

## 待交叉核查

- 改了共享界面文件：`help_card.gd`（`detail_rows` 末尾加行、新增 `append_rows`）、`item_scene.gd`（`_update_help` 两行）、`skin_item_page.gd`（一处）、`gear_detail.gd`（`socket_rows` 三处）、`inlay_book.gd`（`status_ops` 末尾一行）。关着时都是空数组／不进分支，请核「关着逐字节不变」。
- 无核心战斗文件改动。

## 本分支提交

- 见 `git log cc/t164-gem-power`（WIP 提交＋本交付单提交）

## 改名：镶嵌发挥度 → 光耀度（D188，Kyo 11-18；Sonnet＋medium）

全部改动文字（原文→改后）：

| 位置 | 原文 | 改后 |
|---|---|---|
| `XTianqiGemPower.NAME` | 镶嵌发挥度 | 光耀度 |
| 详情／插槽页头行 | `镶嵌发挥度：566%`（范围加`（各项不同）`） | `光耀度：566%`（范围同样加`（各项不同）`） |
| 镶嵌预览首行 | `镶嵌发挥度：X%（本件）`／`（本件，各项不同）` | `光耀度：X%（本件）`／`（本件，各项不同）` |
| 图鉴说明行 `NOTE` | 仅基础属性＝基础值×发挥度（等级越高越多），特效不放大 | **基础值×光耀度，等级越高越盛；特效不放大** |
| 代码注释、测试名、截图工具注释、`skin_template_page.gd` 注释等 | 发挥度／宝石发挥度 | 光耀度 |

- 搭不上、已改顺的地方：①「等级越高越多」→「越盛」（光耀越盛）；②`NOTE` 压到 20 字：旧稿 26 字在 130% 字号下与右侧「镶嵌顺序为从左到右显示」重叠（小A P3 预言的），新稿 130% 实测不挤（`on_130_inlay_book.png`）；「仅基础属性」四字删了，因为「基础值×」已表达，且特效不放大单独交代。
- 复核 P2 测试已补（`xiyou_tianqi_gem_power` 37/37）：宝珠预览（有效孔出行、孔无类型／孔号越界／空 rec 短路）`augment_*`；符文之语模板八项进 `gem_base` 与逐项行 `runeword_*`；总开关开着但存档非天启档时图鉴无说明行 `nontianqi_book_no_note`。
- 验证：`xiyou_tianqi_gem_power` 37/37、`xiyou_tianqi_gear_params` 38/38、`xiyou_inlay_book` 19/19（headless，`--audio-driver Dummy`）。
- 截图（`T164_截图/`，截图工具新增）：`skin_{100,130}_tab{0,2}.png`＝新皮肤详情牌（装备详情／插槽与镶嵌）100%与130%字号；`on_130_detail_mode0.png`＝旧界面详情 130%；`on_130_inlay_book.png`＝图鉴 130%。其余 `{on,off}_*` 已按新名重出。图鉴 130% 下其它行（符文之语备注行等）本来就有重叠，是原界面的老毛病，不是本单引入，没动。
- 没验：新界面「镶在这件装备上」小节（`dress_card`）仍只有专项、没截图（需物品页实操）。
