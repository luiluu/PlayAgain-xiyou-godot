# 交付：claude/bajie-skillshare

- 车道／工作者：B 界面·养成／八戒（Claude，重制_八戒_69）
- 状态：可合并
- 期一：进阶次数读取（已完成，可合并）；期二：技能共享／羁绊／领袖技能范围与参照（进行中）

## 变更记录草稿

## 2026-10-24 【Claude·八戒·未经Codex检验】读进阶次数三处改读 XAdvance（dev.待定）

- 角色进阶（dev.168）留下的三处读点接上 `XAdvance.rank`：
  - 小猫 178 `XCat.advanced()`：照原版 `advanced(a)`＝本角色、35 级起、`_AdvancedNum≥1`、学会 10444。进阶后成长 `growth()` 换成 35／50／60／70／81 级插值 0.30～0.875 的曲线（不低于 0.5，81 级起 0.875）；「进阶后…」三条说明文字随之变成「效果：…」。伤害钩子 `cat_damage_hooks` 原本就经 `advanced()` 读，不用改。
  - 甚尔／宿傩进阶石 `XDungeon.roll_advance_stone`：甚尔进阶过（≥1）不再掷；宿傩还差 `3−进阶次数` 枚，≤0 或背包够数不掷（不掷时不耗随机数，同原版短路顺序）。
  - 角色图鉴「最大进阶次数」`XActorBook.advance_max`：按当前进阶次数取行（`XAdvance.max_text`），已满显示当前次数；渡鸦 167 照运行时补登的 5 条：未满 5，满后显示次数。
- 参照：新探针 `03_转换工具/mv_oracle/advance_reads_probe.cjs`（冻结 v0.28 新游戏、Math.random 0.5；掷石头的「中」用例临时改 0），产物复制为 `tests/fixtures/advance_reads_oracle.json`：小猫 60 例（10 个等级 × 进阶 0～2 × 是否学会 10444）、进阶石 52 例、图鉴 732 例（进阶表每个角色次数 0～最大＋1，另加 167、1）。没进同步脚本 PROBES（固定参照随测试提交，同 actor_advanced_oracle）。
- 专项 `tests/xiyou_advance_reads`（8 项）。
- 未接（写进 cat.gd 文件头）：进阶后额外行动（原版 makeActionTimes＋1，在 battler，沙僧独占）、进阶后终技帮助改品质 10（helpItem）。小猫进阶要的「小猫进阶石」与进阶表行本来就在 XAdvance 表里，奉神老妪界面已可进阶。
- 验证：并行测试 `xiyou_advance_reads`（8/8）、`xiyou_cat`（992/992）、`xiyou_actor_advanced`（33/33）、`xiyou_actor_book`（22/22）、`xiyou_actor_book_review`（6/6）、`xiyou_dungeon`（6954/6954）、`xiyou_random_streams`（484/484）、`xiyou_module_hooks`（1310/1310）；必跑 `xiyou_event_compare`（5/5）、`xiyou_rules.tscn xiyou_rules_d1b xiyou_rules_d1c xiyou_rules_d1d`（101600／101542／101385／101422 全过）。
- 提交：f6b131b9

## 交接板

- 下一步：八戒_69 继续期二（技能共享／羁绊／领袖技能范围清单）与期三（先做技能共享）。
- 用户试玩说明：小猫进阶后剑技成长曲线与说明文字变化；图鉴「最大进阶次数」按当前阶显示；甚尔、宿傩进阶后不再掉多余的进阶石。
- 需要用户决定：无

## 进度账

- 养成：角色进阶读点补齐，完成度小幅上升（总装按账面口径定）

## 本分支提交

- f6b131b9 进阶次数读取三处改读 XAdvance；参照 advance_reads_probe、专项 xiyou_advance_reads
