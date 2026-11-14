# 交付：cc/release-stub-gojo

- 车道／工作者：发行防泄漏（cc，Orca 车道；本单配 Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【cc·未经审查】发行空壳补漏：五条悟、守层者重算换空壳；名单不再只靠类名前缀，审包解开脚本核空壳；号卷消耗空壳修好（dev.待定）

- 起因：架构分析车道报 `发行空壳.py` 只按类名前缀（XTianqi*、XRiftAlien）认天启篇脚本，`XGojo`（modes/xiyou/core/gojo.gd，天启篇专属角色 180 的技能、台词、数值）不在名单里，main 上出包会带真脚本。
- 已发版本核实（只读本机发版仓库历史和 05_发布 里的包）：**没有一个已发版本带出 gojo.gd 或 guardian_rework.gd**。
  - v0.01.07 底包（dev477，mac zip、Windows pck、安卓 apk 三个都看了）、v0.01.08 补丁（patch_477_478，发版仓库里推过的 9 个版本全看了）、v0.01.09 补丁（patch_477_479，现在线上这一个）：文件名单里都没有 gojo／guardian_rework。这几个都从 477 补丁线出包，补丁线是 11-12 五条悟并入 main 之前切出的（`7dd03657e`、`966c578f4` 的树里没有 gojo.gd）。
  - 这些包里有的天启篇脚本（tianqi、tianqi_combat、tianqi_gear 等 6 个、rift_alien）按体积和字符串常量看都是空壳（tianqi_affix_table 编译后 122 字节、没有字符串常量；rift_alien 和手写空壳一样）。这些包早于本单的标记，新审计会把它们报成「不是空壳」，所以旧包是逐个手查的，没用新审计的结论。
  - 更早的 0.470～0.476 就是 11-13 已经处理过的那次外泄（rift_alien.json 等），五条悟那时还没进 main，这次没有新发现。
- 盘点（main 上全部 .gd 按文件名、头注释、`XTianqi.active` 引用、指向 DENY 的 res:// 路径扫一遍；数据和美术按路径对照 DENY）：
  - 漏网 2 个：`XGojo`（gojo.gd）、`XGuardianRework`（guardian_rework.gd，守层者按新成长重算，只管天启篇存档）。已补。
  - 数据和美术：没有漏网。tianqi_data、content/tianqi、content/gojo、ui/tianqi、rift_alien.json 都在 DENY 里；content/intro（启动动画）和标题画面本来就要发行。
  - 不算漏网：`XFabaoFeed`、`XLotteryRework`（法宝与积分重构）对所有存档生效，不是天启篇专属；宿傩（XSukuna、XSukunaFx、content/sukuna）是本体已经发过的内容。
  - 混合文件（XTraining、XItemMarks、XBonds、XEquipScene、XBattleScene、XMapScene 等）里有天启篇的接线代码。数值都在 XTianqi* 里（会换空壳），注释导出时会去掉；包里会留下函数名、开关名这类结构信息，没有设计数值和文字。没动。
- `07_开发环境/发行空壳.py`：
  - 名单改成「前缀 ＋ 显式 `EXTRA`」：XGojo、XGuardianRework。
  - 新增 `suspects()`：脚本文件名带 tianqi／gojo／qiyin／horsem，或头注释说只在／只管／只进天启篇、天启篇专属，或代码里有指向 DENY 的 res:// 路径，又没进空壳名单也没进 `MIXED_OK`（写了理由的西游真脚本：标题画面、XDB）的，`check` 和 `make_tree` 直接失败（检查.sh 守卫项跟着生效）。
  - 空壳多编进一个字符串常量 `const _RELEASE_STUB := "xiyou-release-stub-v1"`（注释导出时会去掉，字符串常量会留下），手写空壳 XRiftAlien 也加了这一行，缺了就报缺成员；`is_stub_tree` 两样都要有。
  - 特例表里写到的成员也进空壳（西游测试会读 `XGojo.ENABLED`）。
  - 新守卫：函数返回 Dictionary／Array、真脚本会原样传回同类型参数（`… else c`），空壳却按类型给空值的，要写特例（规则同「返回数字要写特例」）。
- **顺手修的发行隐患**：`XTianqiTrumpet.cost`（号卷，11-14 新加）真脚本是「不是六号第 1 回合就原样返回 c」，空壳给了 `{}`，`_skill_cost` 拿到的消耗表没有 mp／tp，每个技能都报错（一场测试上千次 SCRIPT ERROR）。照这个空壳出的发行包战斗会坏。特例写成 `c`。没发过（号卷是 11-14 才进 main 的）。
- `发行空壳特例.json`：XGojo.formula＝0.0、hidden／locked＝id == ACTOR（真脚本在天启篇外就是这个结果）、ENABLED＝false（空壳不往数据库补 180 那一行，跟「没启用」一致）；XTianqiTrumpet.cost＝c。
- `07_开发环境/发行内容审计.py`：审包时把空壳名单里的脚本从包里取出来（pck、exe 内嵌、apk、mac zip 都能读），.gdc 用 zstd 解开（Python 3.14 自带 `compression.zstd`），找空壳标记；找不到就报「不是发行空壳（天启篇真脚本进包了）」，审计失败。新增 `--tree <工程>`：出包前查源工程里的空壳都换上了、没有没归类的。
- `发行出包.py`、`发布补丁.py`：审计也查空壳；回退开关（`--real-scripts`／`REAL_SCRIPTS`）开着时只查 DENY，不然回退就没法用。
- 测试：`测试发行空壳.py` 加 5 项（标记、EXTRA、迹象检测、原样传参、真工程五条悟和守层者都在名单里、没有没归类的）；`测试导出过滤.py` 加带内容的假 pck（真脚本要报；带标记的空壳不管压不压缩、文本还是 .gdc 都放过）和名单必含项。反向验证：把 XGojo 从 EXTRA 去掉，`check`、`测试导出过滤`、`测试发行空壳` 三处都会失败。
- 实测：从空壳工程实导「Windows 发行」pck（没推）：审计通过，56 个空壳都在包里、都带标记；从真工程导出同一个预设，审计报 56 处真脚本。发行模式（simulate_release 改 true）下真脚本工程和空壳工程各跑 8 个场景（sukuna_battle、battle、combat、determinism、actor_book、item_marks、hidden_actors、actor_advanced）：都通过，PASS/FAIL 行逐行一致。
- 回退：`发行空壳.EXTRA` 清空（XGojo、XGuardianRework 回到真脚本）；删掉特例表里新加的 5 条（XTianqiTrumpet.cost 别删）；`发行内容审计.audit(包, [])` 跳过空壳检查。

## 交接板

- 下一步：下一次出包或出补丁（从 main）照常跑 发行出包.py／发布补丁.py，审计现在会解开脚本核空壳。发行验收（真脚本对空壳整轮比对）要在发行模式下跑；`xiyou_fabao_rework` 读 XGuardianRework 的内部常量，在空壳工程里会解析失败，跟天启篇测试一起排除。
- 用户试玩说明：无（玩家看不到变化）
- 需要用户决定：无。已发版本都没带出五条悟和守层者重算的脚本，不用补发空壳补丁。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：未归类的天启篇专属脚本 `check` 直接失败，新加专属模块不会再靠「记得起名带前缀」（回退：清空 `suspects` 的判据）。
- 已做：空壳原样传参守卫（同上，删 `PASSTHRU` 判断即回退）。
- 建议：XTianqiAlienGear、XTianqiReforge 的几个操作（dismantle、reroll、reforge 等）真脚本关着时返回 `{"error": …}`，空壳给 `{}`。只有天启篇界面会调，发行版走不到，没改；以后发行版如果开放异化或重铸，调用方又只看 `has("error")`，空壳会被当成成功。收益小，归天启篇车道顺手补特例。
- 建议：开发模式下空壳工程的 xiyou_sukuna_battle 有 10 条伤害差 1.2 倍（不换 gojo 空壳的对照组也一样；发行模式下没有）。这是天启篇开着时两边本来就不同，验收别用开发模式比。

## 本分支提交

- f6bdc91af 发行空壳补漏：XGojo、XGuardianRework 换空壳；名单改前缀＋显式 EXTRA，未归类的天启篇专属脚本 check 直接失败；空壳编进标记，发行内容审计解包核空壳
- 580c0e026 发行空壳：XTianqiTrumpet.cost 原样返回消耗表；原样传回参数的函数也要写特例；特例表写到的成员进空壳（XGojo.ENABLED=false）
