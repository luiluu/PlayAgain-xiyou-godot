# 交付：cc/wukong-dead1b（cc/wukong-dead1 的接续）

- 车道／工作者：C 规则·内容／悟空（cc，派单第三批 AD 接续；总装按 Kyo 11-05 09:21 授权定：一护选 2、领域魔攻改全队）
- 状态：可合并
- 本分支从 cc/wukong-dead1（93210510）续，含 dead1 全部提交；只合本分支即可，dead1 不用单独合。dead1 的交付单 `cc_wukong-dead1.md` 照旧有效（锻造锤、领域开战、进阶界面），本单只写新增的两条。

## 变更记录草稿

## 2026-11-05 【cc·悟空·未经审查】死内容做活（续）：一护卍解按猜测重接、魔法领域魔攻给全队（两处可回退）（dev.待定）

新模块 `modes/xiyou/core/dead_content.gd`（XDeadContent）：XDB 读进地图／公共事件时就地打数据补丁（`xdb.gd` 两行接线），开关关掉后 `clear_cache()` 即回原版数据。逐条「原版怎样 → 现在怎样 → 开关」：

1. **一护卍解（Map213 住轮天外 EV2）**
   - 原版：事件引用的编号全失效——条件角色 109（现在是「牢大」）、敌群 962 无成员、奖励物品 2852 与武器 807 是空白条目，变量 1309／1311 无处写入。三页都走不到。
   - 现在（按名字和现有数据猜的重接）：
     - 招募 CE2508（伙伴号角：黑崎一护）加完 148 后置 1309＝1，同 CE1653 招绯红蔷薇置 1318 的写法。
     - 第 1 页：条件角色 109→148，不再要 1309（旧档早招了一护的也能碰到），页首补置 1309；「一护在队」判断 109→148；敌群 962→733【首领】清风；胜后物品 2852→武器 71「斩月-II」，再置 1311＝1。决心（1318，招过绯红蔷薇）不够照旧不打。
     - 第 2 页：给的武器 807→72「卍解-斩月-II」。第 3 页「简单的刷孔」判有无、重置都改成 72。
   - 敌群挑选依据：Map213 是 29 层住轮天（Map144）的副图；733 是同层另一副图 Map212 太上老君藏身处的首领清风，敌人参数（攻 900）与经验（2 万）和 29 层守层者太白金星（攻 800、经验 2.1 万）相当；敌群事件只有第 1 回合给自己加状态 44＋强制放一次技能，不开开关、没有别的副作用。死神主题的敌群 839 在深渊肝帝之地（Map185），比 29 层难得多，没选。
   - 奖励挑选依据：第 2 页原文「你还没获得斩月-II？」、第 3 页「背包没有卍解-斩月-II」，所以第 1 页给斩月-II（71）、第 2 页给卍解-斩月-II（72），都是一护专属武器（req_actors 148）。第 1 页的提示「黑崎一护学会：卍解，快去进阶吧！」照原文没改（进阶表里没有一护这一行，「学会卍解」只是文案）。
   - 开关：`XDeadContent.ICHIGO_BANKAI = false` 回原版。
2. **魔法领域魔攻（CE2478）**
   - 原版：技能 5682 说明「全员获得奈叶等级×1% 的全属性加成」，CE2478 七项给全队，魔攻 1783 只给奈叶（`313 [0,108,0,1783]`）。
   - 现在：魔攻也给全队（`[0,0,0,1783]`）。领域开战能不能触发仍由 dead1 的 `XNanoha.DOMAIN_LIVE` 管。
   - 开关：`XDeadContent.DOMAIN_ALL_MATK = false` 回原版。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 一护卍解 Map213 EV2、招募 CE2508（`modes/xiyou/core/dead_content.gd` `_patch_ichigo_event`／`patch_common_events`，`xdb.gd` 接线） | 引用角色 109、敌群 962、物品 2852、武器 807 全失效，变量 1309／1311 无处写入，玩家碰不到 | 按猜测重接：一护 148、敌群 733 清风、斩月-II 71／卍解-斩月-II 72，招募置 1309、胜后置 1311 | 原作者重排编号后没改；Kyo 11-05「死内容做活」，总装按授权选重接 | `XDeadContent.ICHIGO_BANKAI = false` | cc（悟空） | 已做 |
| O-待定 | 魔法领域魔攻 CE2478（`modes/xiyou/core/dead_content.gd` `patch_common_events`） | 说明写全员全属性，魔攻 1783 只给奈叶 | 魔攻也给全队 | 照说明；像作者笔误 | `XDeadContent.DOMAIN_ALL_MATK = false` | cc（悟空） | 已做 |

## 交接板

- 下一步：无（dead1 四条加本续两条都交了）。
- 用户试玩说明：一护在队时去住轮天外（29 层副图）找雕像，已招过绯红蔷薇就能挑战首领清风，赢了给斩月-II，再对话给卍解-斩月-II；奈叶的魔法领域开战后队友也有魔攻加成。都能用开关回原版。
- 需要用户决定：无（总装已按授权定；Kyo 觉得重接得不对可以关开关）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 坑（已在 `dead_content.gd` 头注释写明）：GDScript 里给类加静态函数别叫 `reload()`——`XFoo.reload()` 调到的是 `Script.reload()`，会把类的静态变量全重置回默认值，测试里关开关会悄悄失效。本期第一次就踩了，改叫 `clear_cache()`。建议 `语法检查.py` 加一条：`static func (reload|new|get|set|call)\(` 报警。归工具车道，小改。
- 改了 `xdb.gd`（两行），`选测.py main --list` 因此选中 303 个场景（全工程都读 XDB）。补丁只碰 Map213、CE2508、CE2478 三处数据，我在本机跑了读这几处的场景加 dead1 的 36 个选测（见验证）；整套 303 个留给总装合并时按影响面走云端（派单说车道不跑付费云端）。

## 验证

- 专项：`xiyou_floor_odds`（原版那支关开关比；做活那支：没决心不打、1309 页首置上、打敌群 733 胜、斩月-II＋1311、第 2 页卍解-斩月-II、第 3 页刷孔；CE2508 招募后置 1309）、`xiyou_nanoha`（`domain.all_matk`：队友与奈叶都带 1783；dead1 的 domain.* 改成关这个开关比 CE 原样）本机通过。`xiyou_event_compare` 开头关掉两个开关对原版。`语法检查.py` 通过。
- 选测（本机 `并行测试.py`，合 main 后）：dead1 的 36 个选测里的战斗核心（xiyou_determinism、xiyou_battle、xiyou_combat、xiyou_battle_common_event*、xiyou_battle_events、xiyou_battle_start_event 等）、xiyou_rules 三段抽样，加读 Map213／CE2508／CE2478 或 XDB 地图的 xiyou_floor_odds、xiyou_floor_run／_b／_c、xiyou_event_compare、xiyou_json_cache、xiyou_map、xiyou_script／_gaps／_census、xiyou_dungeon、xiyou_troop_events、xiyou_state_effects_tp、xiyou_actor_advanced 等共 39 个，全部通过（987 秒），无偶发。`工具回归.py` 通过。整套 303 个没跑（见「可优化」第 2 条）。
- 没跑全量 `检查.sh`（车道规则）。

## 待交叉核查

- `xdb.gd`（XDB.table／XDB.map 读进后打补丁）：补丁只认原数据（Map213 EV2 第 1 页角色仍是 109、CE2508 有 129 [148]、CE2478 有 313 [0,108,0,1783]）才动，数据变了就不改。
- `dead_content.gd` `_patch_ichigo_event` 倒序遍历第 1 页、在 126 处换成 127 并在其后插 122（1311）。

## 本分支提交

- dead1：9fbf80e2、a4855362、93210510（见 cc_wukong-dead1.md）
- 6eccdf07 一护卍解重接、领域魔攻全队（XDeadContent，O-待定）
- 841ed9ab 合并 main
