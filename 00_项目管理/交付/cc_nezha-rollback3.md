# 交付单：cc/nezha-rollback3（哪吒_12，回退支补测试 期三）

- 状态：可合并
- 执行者：cc（哪吒_12）；从 tools28 末端 a86956e9 切出，**须在 tools27、tools28 之后合**（它们又在 rollback1、rollback2 之后）。已合最新 main（749a0945，无冲突），合进来的探针有变动，补齐重跑过。
- 本期补了 7 个开关的回退支测试：O-030、O-042、O-076 的四个（GAIN_ONLY、BEFORE_REDIRECT、SAVE_NOW、FLOOR12_FIX）、O-085。`回退开关覆盖.py`：覆盖从 42 升到 49，缺口从 19 降到 12（新增缺口 0）。
- O-085 在 xstate.gd（核心存档类）。动之前查过：main 之外没有本地分支改过这个文件（`git log main..<分支>` 逐个看最近 25 个分支）。只改了一行声明（const→static var）。

## 改了哪些文件

- const 改成 static var（默认值不变；rg 全工程连 tests 一起查过，全是读取）：
  - `core/achievement.gd`：`GAIN_ONLY`、`BEFORE_REDIRECT`、`SAVE_NOW`、`FLOOR12_FIX`
  - `core/xstate.gd`：`GOLD_FLOOR_ZERO`（`GOLD_MIN_ORIGINAL` 仍是 const）
  - `core/item_marks.gd`：`LIST_ONLY_NAMES`
  - `ui/save_scene.gd`：`REAL_FILE_SIZE`
- 测试：`tests/xiyou_achievement.gd`、`xiyou_gold_cap.gd`（逐步收支对参照那段抽成 `_seqs`，两种开关各跑一遍）、`xiyou_item_marks.gd`、`xiyou_save_page.gd`。
- `07_开发环境/回退开关豁免.json` 删掉这 7 项。

## 各开关的回退断言

| 编号 | 开关 | 断言 |
| --- | --- | --- |
| O-076 | `GAIN_ONLY`、`BEFORE_REDIRECT` = false | `_gains` 本来就按开关算期望；两个都关时，期望就是 achievement_probe 参照原样（失去物品也触发，魂灯只记 112）。用全部参照例对一遍 |
| O-076 | `FLOOR12_FIX = false` | 两处十二层守层者（Map023 事件 1、Map065 事件 2）照原版给 13 |
| O-076 | `SAVE_NOW = false` | 达成后内存里有，配置文件里没有；重新读配置（相当于中途退出）就丢了，已写盘的 60 还在 |
| O-085 | `XState.GOLD_FLOOR_ZERO = false` | 金币收支各段逐步与 gold 参照原样相同（含扣成负数那段，下限 -99999999） |
| O-030 | `XItemMarks.LIST_ONLY_NAMES = false` | 锁定、置顶都直接改数据库记录的名字（「名字[锁定][置顶]」），列表显示用的就是原记录；取消后名字改回。默认只在列表副本上加标记。登记里的「跨类型套用」要改代码才能恢复，不是开关，没测 |
| O-042 | `XSaveScene.REAL_FILE_SIZE = false` | 内容 `a b"中`：实际 7 字节显示「7B」；原版算法只数要转义的字节（空格、引号、「中」），显示「5B」 |

## 留给车道（本期不碰）

- 同期一、期二：battle_logic.gd 的 O-026、O-048；map_scene.gd 的 O-010、O-011、O-012、O-015、O-036、O-117。
- O-027 `TRANSFER_FIX`、O-100 `ACTOR_IMAGE_FIX` 在事件解释器和事件核心里，属于内容车道。
- O-018 headless 测不到绘制（见 rollback2）。
- 豁免里剩的 12 项就是上面这些。

## 验证

- `语法检查.py` 通过（421 个 .gd）。
- 4 个直接专项全过：xiyou_achievement 56/56、xiyou_gold_cap 37/37、xiyou_item_marks 110/110、xiyou_save_page 42/42。
- 选测（只算本期提交的改动，`选测.py a86956e9 --head 621377b3`）：237 个场景，因为 xstate.gd 几乎被所有场景引用。全部一次通过，没有偶发，没有超过上限一半的场景（并行 2、本机负载约 5，用时 5274 秒）。

## 变更记录草稿

## 2026-10-31 【cc·哪吒·未经审查】回退支补测试期三：成就、精魂下限、物品名字标记、存档容量 7 个开关（75% 审查 G3，dev.待定）

- 7 个优化开关补了回退支测试（见交付单表）。O-076、O-085 两个直接对 mv_oracle 参照（achievement_probe、gold 参照）；O-030、O-042 按优化登记「原版行为」栏写期望。
- 4 个文件里的 7 个开关从 const 改成 static var，默认值不变。
- `回退开关豁免.json`：覆盖 42→49，缺口 19→12。
- 回退：测试是新加的段（gold_cap 抽出的 `_seqs` 逻辑没变），删掉即可；static var 改回 const 不影响调用。

## 交接板

- 「下一步」：回退支剩下的 12 项都在别的车道的文件里，等那些车道空了再派。

## 慢场景重量（tools28 第 3 项，顺手做的）

本机空闲时量的，单位是秒，括号里是 CPU 用户时间：

| 场景 | 本期选测（并行 2，负载约 5） | 单跑（--jobs 1 --full） | 之前满载时 |
| --- | --- | --- | --- |
| xiyou_map186_b | 237（110） | 239（111） | 320、373 |
| xiyou_smart_ai_b | 214（207） | 203（197） | 369 |
| xiyou_smart_ai | 209（205） | 没单跑 | 391 |
| xiyou_smart_ai_c | 198（191） | 没单跑 | 420 |
| xiyou_smart_ai_d | 189（185） | 没单跑 | 428 |

结论：五个都在上限一半（300 秒）以下，不用拆。之前超 300 是本机满载时 CPU 抢不到。smart_ai 几份基本是算力活（墙钟≈CPU），约 200 秒，离线最近，以后再加断言就该拆成八份。map186_b 墙钟 239 秒里 CPU 只有 111 秒，多半在等帧、等事件；想提速可以看看能不能用楼层流程那套 headless 快时钟，不过这是方案，场景不是我的文件，没动。

## 可优化

- 见上面 map186_b 那条（快时钟）。

## 本分支提交

- 765d1ebf、621377b3、合并 main，以及本交付提交
