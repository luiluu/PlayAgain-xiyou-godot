# 交付：cc/nezha-tools63

- 车道／工作者：D 工具／哪吒（cc，Sonnet／medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】插件备注覆盖扫描工具（dev.待定）

只读新工具 `03_再刷重制_Godot/07_开发环境/插件备注覆盖.py`：专抓 YEP_X_ExtDoT 那类「按插件名对照查不出」的缺口（标签是 meta 键，不是代码字面量）。
- **抽取**：冻结 `plugins.js` 启用的 165 个插件＋`codex/modules.json` 启用的运行时，从代码（去注释）抽正则／字符串里的 `<标签…>`（`(?:A|B)` 展开、`(\d+)`→`#`、其它捕获组→`*`）、`meta.xxx`／`meta['xxx']`、帮助文档里的标签（`Item x Cost`→`item#cost`）、插件命令名。共 832 个标签、若干命令。
- **用量**：扫冻结 `data/*.json` 的 note、事件注释(108/408)、插件命令(356/357)，数条数、数据类、举 3 个 id。
- **重制有没有读**：工程 `.gd`（不含 tests）＋转换器（不含 mv_oracle、预检、ui_reference）按标签名词边界匹配（大小写／空格／下划线归一）→「已读」；只在测试／探针里出现、只有子串命中、标签过短→「拿不准」；都没有→「没读」。另外**收割重制代码里带 `>` 的正则字符串**，拿数据里的标签原文去试匹配，命中就算「已读（通用正则）」——专门防 `Custom X Effect`（转换器 `EFFECT_RE`）、`<CUSTOM (.*) MASTERY FORMULA>`、`<NO (.*) MASTERY EFFECT>` 这种「重制读了、但名字不是字面量」的误报。
- 输出 markdown（数据用量>0 的先列，没读>拿不准>已读）、`--json`、`--all`（含数据没用到的）、`--no-generated`；还报「生成数据」里该标签保留的条数。整份约 6 秒。
- 测试 `测试插件备注覆盖.py`（12 项，约 15 秒）：抽取单元＋已知例——DoT／Regen Formula 必须「没读」，Custom Target Eval、Item n Cost、SC自动解除必须「已读」，Custom React Effect 必须靠通用正则判「已读」。已接进 `检查.sh` 的工具回归。

## 交接板

- 下一步：见下方「数据用量>0 且没读」清单，由总装按影响派活。
- 用户试玩说明：无（只读工具，没碰游戏代码）。
- 需要用户决定：无。

## 进度账

- 无。

## 数据用量>0 且「没读」的结果（2026-11-04，main 含 gaps6 之后）

总数：数据里有用量的标签／命令 240 个——已读 199、没读 29、拿不准 12。以下 29 条按玩家影响粗排；「确认」＝我读了代码或数据抽查过，「疑似」＝没细查。

**确认是真缺**
1. `HP Life Steal`／`* Life Steal`（YEP_LifeSteal）——**112 个技能**（如 Skills#182 `<HP Life Steal: 30%>`）；`.gd`、转换器里完全没有吸血实现（`gear_query.gd` 里的「吸血」只是装备词条分类关键字）。**影响最大**。
2. `DoT Formula`／`Regen Formula`／`DoT Animation`／`Regen Animation`（YEP_X_ExtDoT）——33＋10＋33＋9 个状态；已知（gaps6），另有 `Custom DoT Formula`（States#1386）、`Custom Regen Formula`（States#2038）各 1。
3. `Hide HP Gauge`／`Show HP Gauge`（YEP_X_VisualHpGauge）——546＋277 个敌人。重制有 12px 敌人血条（`battle_scene.gd`），但逐敌人「隐藏／强制显示」没读，所有敌人都按默认规则出血条。玩家直接看得到。
4. `Max State Floor`（CP_StateFloor）——6 个状态（States#1323 起，如隐月1 `<Max State Floor: 0>` 加 `<State Can Added Floor>`）；重制只读了插件参数 `State Added Type`（`battler.gd:483`），状态层数上限没读。
5. `Multi-Element Rule`（YEP_ElementCore）——16 个技能（Skills#7006 起，`<Multiple Elements: 2,3,5>` 配 `<Multi-Element Rule: Add>`）；工程里无「多属性取法」规则，多属性技能是不是按插件默认（取最高）算，需有人看 `damage.gd` 的属性段确认。
6. `Element Reflect n`（YEP_ElementCore）——1 件防具（Armors#4998）。

**确认是「名字匹配不到」但其实读了（已被工具的通用正则识别，不在 29 条里）**
- `Custom Apply／Remove／React／Establish／…Effect`（YEP_BuffsStatesCore，约 500 个状态）：转换器 `xiyou_export.py:175 EFFECT_RE` 通用读。
- `Custom EXP Mastery Formula`、`No Damage Mastery Effect`：`skill_mastery.gd:73-84` 通用正则。
- `Equip LevelUp Trait Armor`、`Codex Bind`、`ici`、`* Plus`、`* Rate` 等同类。

**还在 29 条里的疑似（没细查）**
- `Breathing Speed`／`Sideview Weapon`／`Sideview No Collapse`／`Sideview Show Shadow`（YEP_X_AnimatedSVEnemies，各 195 个敌人）：重制只有固定呼吸（`battler_sprite.gd:47`，注释写「Breathing Y Rate 0.02」），逐敌人速度、武器、不倒下、影子没读；影响偏观感。
- `passiveASUP`／`passivePREE`／`passiveGUARD`／`passiveXPBST*`（dsPassiveSkill）：插件按 metaName 变量取，抽样 `passiveXPBST` 在 `passive_books.gd` 有对应，**多半是名字匹配不到**，建议有人对着 `dsPassiveSkill.js` 的 `iteratePassiveSkill(…)` 调用点逐个核。
- `SvPngFd`（10）、`pSTCatName_X`（152，PKD_SimpleSkillsTree 分类名，帮助文档示例名）、`Anchor X`（2）、`State Animation`（YEP_X_VisualStateFX，1）、`not independent item`（11，YEP_ItemCore；`mv_script.gd` 有 cleanupIndependentItems 空操作，可能等价）、`SkillKillGoon`（11，Olivia OTB）、`CodexRandomWeakAura`／`CodexWeakNewGame`／`Codex Guide v1`（各 1）。

## 可优化（流程／工具／效率）

- 已做：本工具本身；`--all` 之外不查数据没用到的标签，整份 6 秒。
- 建议：总装合并后每天全量里跑一次 `插件备注覆盖.py` 并和上次的「没读」条数比，新增就报（现在只有回归测试，没有基线）——预计收益小，可挂到哪吒下一期。
- 建议：同样的思路可扩到「插件命令的用量」（本期只做到 356 的首词匹配，对多词命令只做前缀匹配）和事件脚本 355／655 里的 `$gameSystem.xxx` 调用，抓脚本里直接调用插件函数的缺口；归哪吒。
- 已知局限：重制若用字符串拼接动态拼标签名（如 `"SC" + tagName`）、或标签名拆在两个常量里，工具会判「没读」或「拿不准」；通用正则试匹配只用每个标签的第一条样本。

## 本分支提交

- 见 git log（分支 cc/nezha-tools63）
