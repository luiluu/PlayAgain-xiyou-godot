# 交付：claude/project-thread-ksjqul

- 车道／工作者：安卓战斗提速（v0.01 实机反馈续）／cc（云端，项目线程「优化安卓战斗提速」）
- 状态：进行中
- 车道路径：无（云端容器，没有 Mac 工作树；本分支不改切片、转换器、探针，不用同步）

## 变更记录草稿

## 2026-11-12 【cc·云端·未经审查】安卓战斗提速：选技能、行动结算、进战斗各段少做重复计算（dev.待定）
- 起因：Kyo 11-12 安卓实机「进去战斗、选技能、逃跑都有卡顿，商店卡顿」，上一条车道（dev.476）修了每帧重画，留下「行动结算本身耗时、进战斗停顿」没处理；Kyo「让协调开 fable 线优化提速」。本轮只减少重复计算，不改任何规则：同一种子的同一场战斗，开关两态的整份日志、随机数位置、双方资源逐项相同。
- 逐段计时找到的几处（云端容器上的数，手机约慢 5 倍，没有实机）：
  - 说明卡每画一张都把近 1 MB 的 `CodexDamageElements.json` 重读两三遍（一张约 85 毫秒 → 1.5 毫秒），是选技能、翻商店时一格一顿的主因。本分支也查到并改了，与反馈修复线撞车；那边先合并（O-341，`XHelpCard.ELEMENT_DATA_CACHE`），本分支以它为准，不重复登记，专项里保留一项开关两态内容相同的检查。
  - O-待定-1 `core/actor.gd` 只读窗口缓存：一次行动里角色的技能表被重算 100～300 遍（每读一次能力值都要过专属模块包装链，链上各模块各自再问一遍「会不会某技能」）。现在在几段确定只读的计算外面开「只读窗口」（全员快照 `views`／`view_of`、列可用技能 `usable_skills`、可行动标记 `move_flags`、伤害乘区 `XDamage.calculate` 公式值算完之后那段、资源快照、侧栏一格、技能列表各行），窗口内同一名角色的技能表、特性表与索引、被动值、能力值、生效套装只算一遍；窗口里遇到任何写入（学／忘技能、换装备、加减状态、hp／mp／tp 写入、公式帧进出、能力值脏标记）当场作废，窗口一关整份丢掉，不跨写入留存；三处重入护栏（云裳万法同裳、璇共宿、屠苏盾相补底：取对方那项时不再套自己）开着时算出的值另存一份。试过跨写入留存的版本：只多省两成，而且升级后立刻读到旧值，弃用。
  - O-待定-2 `core/module_registry.gd`：每次算伤害都把整条技能记录（备注、行动序列、公式语法树）逐项深拷贝一遍交给乘区钩子；现在同一条记录只拷一次（冻结成只读，记录对象换了就重拷）。
  - O-待定-3 `core/appearance.gd` `kept_load`：战斗背景、角色与敌人图、光标、影子、连击数字、战斗音乐原先每场 `load()`，上一场放掉后要重新读包、解码、传显存；现在按路径留住最近 160 个。
  - 零碎：道法标签按技能编号记住（备注文字变了重取，`XZhenqi.DAOFA_TAG_CACHE`）；`equip_list` 改成循环。
- 量到的数（云端容器，多次取最小；括号里是手机按 5 倍的估计，未实测）：
  - 说明卡 85 → 1.5 毫秒一张（约 400 → 8）。
  - 一场 6 次行动的战斗，行动结算合计 275 → 158 毫秒；10 次行动的 387 → 252。全员快照 4.7 → 1.9，列可用技能 9～21 → 1.2～3.4，自动选招合计 113 → 85，开战结算 32 → 21。
  - 进战斗画面（结算准备＋场景搭建＋两帧）约 117 → 47 毫秒（第二场起；第一场还要读各张表，见「可优化」）。
- 试过没留：正则只编译一次（动 90 多个文件，量不出差别，已整批撤回）。
- 新专项 `tests/xiyou_battle_speed`（34 项）：说明卡开关两态内容相同、技能记录拷贝逐项相同且只读、贴图留存有上限、窗口规则（写入作废、关窗清空、克隆体不沾）、敌群 2 与 3 的整场自动战斗开关两态签名相同、全程比对无不一致、各开关各自单关。环境变量 `XIYOU_READ_VERIFY=1` 时每次命中缓存都重算一遍比对，不一致当场崩溃，可套在任何测试上跑。
- 玩家可见：安卓上选技能、翻商店和背包时说明卡不再一格一顿；放技能后的结算停顿、进战斗的停顿缩短。
- 未完成／已知问题：没有实机数据；行动结算剩下的耗时分散在脚本各处，没有单一大头了。进战斗截地图画面、回地图刷新事件、每次开游戏第一场战斗读表这三处没动（见「可优化」）。

## 交接板

- 下一步：Kyo 安卓实机看选技能、放技能、进战斗、逃跑、商店是否顺了；还卡就按「可优化」里三处在实机上计时（要在安卓包里打逐段耗时日志）。
- 用户试玩说明：安卓上进战斗、选技能上下翻、放技能、逃跑；商店和背包上下翻看说明卡。战斗结果应与之前完全一样。
- 需要用户决定：是否作为热更推给玩家（Kyo 另说）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `modes/xiyou/core/actor.gd` `XActor.READ_MEMO`（`read_begin`／`read_end`／`read_touch`）；窗口在 `battle/battle_logic.gd`、`core/damage.gd`、`core/resource_context.gd`、`battle/side_status.gd`、`battle/battle_scene.gd`；作废点在 `core/battler.gd`、`core/alien_battle.gd`、`core/hubris.gd`、`core/number_boost.gd`；`core/equip_suits.gd`；`core/zhenqi.gd` `XZhenqi.DAOFA_TAG_CACHE`；`tests/xiyou_battle_speed.gd` | 原版每次读能力值都现算（MV 引擎快，不成问题）；重制照做，一次行动里技能表重算 100～300 遍 | 只读窗口内同一名角色的技能表、特性表、被动值、能力值、套装只算一遍；写入当场作废，关窗丢弃 | Kyo 11-12 安卓放技能卡；行动结算省四成上下，结果逐项相同 | `XActor.READ_MEMO = false`（`XIYOU_READ_VERIFY=1` 可全程比对）；道法标签 `XZhenqi.DAOFA_TAG_CACHE = false` | cc（云端） | 保留 |
| O-待定-2 | `modes/xiyou/core/module_registry.gd` `XModuleRegistry.ITEM_COPY_CACHE`；`tests/xiyou_battle_speed.gd` | 重制原先：每次算伤害把整条技能记录深拷贝一遍给乘区钩子 | 同一条记录只拷一次，拷贝只读 | 同上 | `XModuleRegistry.ITEM_COPY_CACHE = false` | cc（云端） | 保留 |
| O-待定-3 | `modes/xiyou/core/appearance.gd` `XAppearance.KEEP`、`KEEP_MAX`、`kept_load`；`battle/battle_scene.gd`、`battle/battler_sprite.gd`、`battle/combo_counter.gd`；`tests/xiyou_battle_speed.gd` | 原版图片载入后留在 ImageManager 缓存；重制原先每场战斗重新 `load()` | 按路径留住最近 160 个贴图／音乐 | Kyo 11-12 安卓进战斗卡 | `XAppearance.KEEP = false` | cc（云端） | 保留 |

## 进度账

- 无（不改完成度；安卓扩展账「战斗流畅度」待实机确认后再记）。

## 可优化（流程／工具／效率）

- 建议（要实机计时，无画面的云端量不到）：进战斗时截地图画面当转场底图（`_snapshot` 要从显卡读回整屏，手机上可能几十到上百毫秒）；逃跑或打完回地图时 `refresh_events` 整张地图事件重刷；每次开游戏第一场战斗要现读十几张表（电脑约 150 毫秒），可以挪到读档或标题画面空闲时预读。归界面／地图车道。
- 建议：安卓包加一个隐藏的逐段耗时日志开关（进战斗、行动结算、回地图各段毫秒数写到日志文件），Kyo 实机跑一场发回来就能定位，不用再猜。
- 已做：`XIYOU_READ_VERIFY=1` 全程比对开关（不设就没有开销）；`tests/xiyou_battle_speed` 末尾打印各段耗时（PERF 行），以后量战斗耗时直接跑它。
- 备注：行动结算剩下的 150～250 毫秒（电脑）分散在专属模块包装链、日志记录、公式求值各处，再往下省要动结构（比如能力值跨写入缓存），风险与收益不成比例，建议先看实机再定。

## 验证

（待写）

## 待交叉核查

- 甲档：`core/actor.gd`（只读窗口缓存本体）、`core/battler.gd`（作废点、hp／mp／tp 写入）、`battle/battle_logic.gd`（窗口位置）、`core/damage.gd`（乘区窗口只在公式值已算完时开）、`core/resource_context.gd`、`core/module_registry.gd`（拷贝缓存只读性）。核查要点：窗口内有没有漏掉的写入路径（漏了就会读到旧值；`XIYOU_READ_VERIFY=1` 跑相关专项可查）。
- 乙档：`core/appearance.gd`、`ui/help_card.gd`、`core/equip_suits.gd`、`core/zhenqi.gd`、`core/alien_battle.gd`、`core/hubris.gd`、`core/number_boost.gd`、`battle/side_status.gd`、`battle/battle_scene.gd`、`battle/battler_sprite.gd`、`battle/combo_counter.gd`、测试。

## 本分支提交

（待写）
