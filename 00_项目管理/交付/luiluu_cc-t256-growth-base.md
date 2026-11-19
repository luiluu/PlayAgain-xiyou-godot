# 交付：luiluu/cc-t256-growth-base

- 车道／工作者：T256 无限成长①成长底座（XTianqiGrowth＋平加＋growth.json）（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-19 【cc·T256·未经审查】天启篇无限成长底座：层价表、哪些战斗算、渡鸦奈叶层数属性平加（dev.待定）

- 依据私密设计仓 `重制设定/天启篇_无限成长_v0.4.md`（2524a5d）第二节、3.5 节、第八节卡①；Kyo 11-19「216全推荐」（Q1 甲、Q6 乙）。
- 新 `modes/xiyou/core/tianqi_growth.gd`（`XTianqiGrowth`）＋新表 `tianqi_data/growth.json`（全整数）：
  - 层价表三人共用：1～12 层每层 1 份、13～24 层 2 份（拐点，累计 36 份）、25 层 4 份、26 层起每层翻倍。`layers(计数, 基础段, 一份)`、`next_need(...)`。
  - `floor_ok(s, logic)`（Q6 乙，三人共用）：主塔、野外 地图层号 ≥ 已通主塔层−5；深渊 层号 ≥ min(已通层, 29)−5、层号 0 的深渊（天之上那几张）不算；王者难度副本、七印里副本（含七首之龙）、34～36 层终局战一律算。`floor_ok_facts` 是同一判定的纯数据版。
  - `param_flat(a, i)`：渡鸦魔法攻击、奈叶最大生命和最大魔法，按各人原有计数现算层数×表里每层的数，**实数平加**。
- `core/actor.gd`：`param_before_alien` 最后夹值之前加 `XTianqiGrowth.param_flat`（基础乘率、淬元丹、专属模块、坐骑、天启篇装备、云裳都乘完了）；`_param_now` 把种族祝福那一层包一下（`XTianqiGrowth.unrace`），退掉种族对平加那一截的放大。其余包装次序不变；计数在基础段以内时 `param_flat` 恒 0、`unrace` 原样返回，T220 现数不变。
- **开工先核（验收 2）**：种族祝福 `XRaceBattle.param` 在天启篇照常生效——人族八项 ×1.03、鬼族最大魔法、蛮族最大生命 ×(1＋q)（q 最高 0.2），会放大平加。没整个挪到它外面，改成在种族那一层把平加那一截退掉：中间还有异化词条（空壳把生命压到 1、饕餮把魔法压到 0、缄默）和敌方压属性（四骑士、饥荒线降魔法上限、疫病虚弱），挪到外面它们就压不到层数那一截了。
- 本卡不接三人计数（T257）：奈叶过 2000 次照旧原版逐次加、`floor_ok` 还没人调。每层给多少是草案（`draft: true`）：渡鸦魔攻 110（稿给 90～125）、奈叶魔法 2000／生命 700（稿给 1800～2200、生命取三分之一取整到百），等 T258 标定。
- `天启篇数据校验.py` 认 growth.json（全整数、层价分段连续不降、三人行齐全、平加项对）；`测试天启篇数据校验.py` 加 9 条（含反例）。
- 专项 `tests/xiyou_tianqi_growth` 52/52。

## 优化登记草稿

| O-待定 | `modes/xiyou/core/tianqi_growth.gd` `XTianqiGrowth.ENABLED`、`RACE_FLAT`；`core/actor.gd` `param_before_alien`／`_param_now` | 原版渡鸦灵魂只按镰刀加魔攻、奈叶适应次数走「先加后乘」被词条放大；天启篇 T220 灵魂满 15 万／20 万后无效果 | 天启篇按层价表成层，渡鸦魔攻、奈叶生命魔法每层平加实数，不吃我方百分比（含种族祝福） | 设计稿 v0.4 3.5（P1-1 修法甲）；Kyo 11-19「216全推荐」 | `XTianqiGrowth.ENABLED`、`XTianqiGrowth.RACE_FLAT` 分别设 `false`（前者整个回到 T220，后者只让种族祝福照旧放大平加） | cc | 保留 |

## 交接板

- 下一步：T257 三人计数接线（奈叶过 2000 不再 `add_param`、渡鸦没学 10136 灵魂停 15 万、流萤胜场解绑 4004、超出基础段过 `floor_ok`、跨层 `param_mark_dirty`）；T258 探针标定 growth.json 里 raven.flat.4、nanoha.flat.0／1；T260 实量场数回填三个 share。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 给 T257／T258／T260 的接口（直接用）

| 接口 | 说明 |
| --- | --- |
| `XTianqiGrowth.on(s = null)` | 开关开、天启篇存档、表在 |
| `layers(count, base, share) -> int`／`next_need(count, base, share) -> float` | 纯层价表；`next_need` 是到下一层还差的计数（没过基础段时含基础段剩下的） |
| `price(n)`／`cumulative(n)` | 第 n 层几份／累计几份 |
| `actor_row("raven"|"nanoha"|"liuying") -> Dictionary` | 表里一行 |
| `count_of(key, a)`／`layers_of(key, a)`／`next_need_of(key, a)` | 读原有计数：渡鸦 `XRaven.soul`（没学 need_skill 记 0）、奈叶 `flags.codexNanohaAdapt[str(id)]`、流萤 `state_data._codexLbEmberWins`；`layers_of` 不在天启篇为 0 |
| `param_flat(a, i)` | 平加（已接 actor.gd，T257 不用再接属性；计数变了要调 `a.param_mark_dirty()`） |
| `unrace(a, i, before, after)` | 只给 actor.gd 用 |
| `floor_ok(s, logic = null) -> bool`／`facts(s, logic)`／`floor_ok_facts(dict)` | Q6 乙；只管超出基础段的那部分，基础段由调用方不判。logic 给 null 时只按地图和副本档位判（七印、终局要 logic） |
| `ember_bonus(n)`／`dmg_pct_of(n)` | 流萤：层数给的余烬（不含前 3000）、伤害百分数（每满 dmg_step 层 +dmg_pct） |

growth.json 字段：`price.segments[{from,to,shares}]`、`price.grow`（之后每层倍数）、`price.turn`（拐点层）、`price.max_layer`（循环保险）；`floor_rule.window／abyss_cap／abyss_prefix／king_tier`；`actors.<键>.actor／base／share`，渡鸦 `need_skill`、`flat{"4"}`，奈叶 `flat{"0","1"}`，流萤 `ember／ember_cap／dmg_step／dmg_pct`（不走平加，没有 flat）。下划线开头的键是注释。标定只改数，不改字段；加字段同步改 `03_转换工具/天启篇数据校验.py` 的 `growth_rules`。

## 发现

1. 验收逐条：
   1. XTianqiGrowth：层价表、layers、next_need、floor_ok、param_flat、回退开关都有（接口见上）。
   2. 种族祝福会放大平加（结论与做法见变更记录草稿）。
   3. actor.gd：`param_before_alien` 末尾一项平加；`_param_now` 多拆一行包住种族祝福（验收 2 要求的「挪到外侧」的等效做法）。专项断言：穿脱带百分比的魔攻／最大魔法／最大生命词条装备、有无能力强化（buffs +2 档）、鬼族／蛮族／人族种族祝福下，层数带来的面板增量都**正好等于** growth.json 的数×层数。
   4. growth.json 全整数；数据校验全部通过。
   5. 只天启篇：西游档 `param_flat` 0、`on()` false；`ENABLED=false` 回到原数（专项比过面板）；计数在基础段以内 param_flat 恒 0。
   6. 专项：层价表 12/13、24/25/26 边界、next_need、平加两条断言（＋种族）、floor_ok 用例（主塔 33 层打 28 涨 27 不涨、妄语／无为深渊涨、13 层深渊不涨、天之上深渊层号 0 不涨、王者副本涨，真存档地图再跑一遍）、存读档后层数与面板不变、没加存档字段。
   7. 虚拟玩家（种子 7，`--headless --audio-driver Dummy`）：explore 14/14、退出码 0；短帧 climb（`--vp-frames=60000`）9/9、退出码 0：卡死 0、脚本报错 0、硬性违规（负血负钱）0；中途全灭回标题、读档后接着打赢，存读档正常。只爬到第 1 层、阵容里没有渡鸦奈叶，覆盖不到成长本身，那部分靠专项。
2. 已知没顾到的一处：天启篇饥荒遗物（`XTianqiRewards.actor_param`，战斗内按层数叠的全属性 %）在种族之内、平加之外，会放大层数那一截（战斗中才有，最多约 +9%）。稿 3.5 没点名它；要堵可以照 unrace 的办法再包一层，留给 T257／T258 看标定时要不要管。
3. 发行空壳：`发行空壳.py check` 通过，空壳里 `param_flat` 返回 0.0、`unrace` 原样返回 after。
4. 公共规矩读的是 v1.6。

## 验证

- `xiyou_tianqi_growth` 52/52（单跑）。
- 并行选测 29 个场景全部通过（并行 2，445 秒）：xiyou_tianqi_growth、actor_modules、alien_affix、alien_battle、determinism、json_cache、liuying、nanoha、param_cache、param_max、param_states、race_battle、raven_artifact、raven_battle、raven_soul、three_growth、tianqi_affix_battle、tianqi_balance、tianqi_brand、tianqi_ledger、tianqi_ledger_p3、tianqi_money、tianqi_phase4、tianqi_phase4_modules、tianqi_rewards、tianqi_save、virtual_player、yunshang_wraps、text_batch23。
- 没跑：`选测.py` 因 actor.gd 归战斗核心列出 421 个场景（xiyou_rules 全段、事件对照等），车道只跑了上面直接相关的 29 个；改动对计数在基础段以内的角色是恒等（param_flat 0、unrace 原样返回），整轮请总装合并时按影响面选测或云端跑。
- `天启篇数据校验.py` 全部通过；`测试天启篇数据校验.py` 91 条 OK；`语法检查.py` 0 问题；`发行空壳.py check` 通过。

## 本分支提交

- aa7d42f95 XTianqiGrowth、growth.json、actor.gd 平加、数据校验、专项
- 715b9f2ca 合并 main（测试天启篇数据校验.py 两边各加一个类，都留）
