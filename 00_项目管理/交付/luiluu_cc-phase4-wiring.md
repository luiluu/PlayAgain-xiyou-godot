# 交付：luiluu/cc-phase4-wiring

- 车道／工作者：T081 T012-b 期四暗装接线（cc，Opus＋medium，P8）
- 状态：进行中

## 变更记录草稿

## 2026-11-17 【cc·T081·未经审查】天启篇期四暗装接线：总开关 XTianqiBase.PHASE4（默认关）、单段上限 23 行拆完（dev.待定）

- 照《基础数值重构 v0.4》第七节第 2 条、第十节 T012-b：新文件 `core/tianqi_base.gd`（`XTianqiBase`），一个总开关 `PHASE4`（默认关），下面每一行只认它；**关着＝现在的行为**，西游档（`XTianqi.active` 为假）开着也走关着那一套，全部只在代码和表里、不写存档：
  - 角色卡：`XTianqiSkills.cards_flag()`＝`CARDS or PHASE4`，`CARDS` 只留给专项单独隔离卡用；
  - 角色本体：`XActor.param_base_direct` 开着读 `base_line.json`（标准线 20＋20×等级、生命魔法 ×25、职责×速度档×个人微调；表外的人照职业曲线）；
  - K「天启注视」：`combat_rules.base_damage` 改起点 **0.088**（D141 丙），乘进 `XTianqiCombat.dealt_parts`（五条悟试炼的 unit 一起乘）；按角色的乘数口子 `k_actor_mult` 现在恒 1，留给 T073-b 接烙印（没接烙印新规则）；状态页全局加成第一行、伤害详情各多一行「天启注视　伤害 ×0.088」，说明句照 D140／D146，不出现烙印的数；
  - 首领生命临时折算 U（`boss_hp_temp_unit`，四骑士本体与影子）；守层者三张表（`balance_table.guardian_phase4`，T012-c 量，缺就退回旧表并警告一次）；治疗 ×5（开着 HP／MP 回复不再乘）；
  - 绝对值清单：只接了 `abs_rescale.json` 里结构化的两类——药品固定回复（`battle_logic._apply_effect` 11／12 号效果）、常数状态持续伤害（`ext_dot`）；
  - 单段有效系数上限（`skill_rework.rules.single_hit_cap`，按名单档位）：`XTianqiSkills.formula` 兜底封顶，口径同 `天启篇数据校验.py`（卡面系数×属性权重×条件；权重 `hit_weight`：生命魔法按标准线 ×25、max_of 加 1）；
  - 九线爆伤合计封顶（`damage_ledger.phase4.nine_crit_dmg_cap` +30%，`apply_nine_cap` 新加的读处，关着不封）、秘籍格（`phase4.secret_slot`）。
- **单段上限待拆 23 行全部拆完**（T080 交来的 `single_hit_cap_pending` 清空）：新序列操作 `split_effects`（每一段原地拆成 n 段，条件块里的、大写默认序列的都拆，`yepEffects` 跟着乘），卡上系数 ÷n、合计不变、系数避开 4（10.8 拆 3 段 ×3.6，不拆 2 段 ×5.4）；每次命中都给的 TP（`tpGain`）用 `fields` 同比例分（1060 30→10、4411／4815 8→4、3645／4812 5→3，后两个多 1 点，整数分不开）；10731 后颈斩纯数据改 `keep_effects` 1→3；3631 万剑归一*灭 序列本来就是 3 段，只改系数 3.6 和说明（原卡写「1段」是错的）。脚本 `03_转换工具/天启篇单段上限拆段.py`（可重跑）。万剑归一系列照 T080 选 A 改 `xiyou_tianqi_skills` 期望值（cond_agi、xinfa_pohun、desc_lines）。角色卡默认关，**现在的游戏里看不到这些变化**。
- 修 `XTianqiSkills._seq_edit`：Godot 的 `contains("")` 为假，表里 11 条 `match: ""` 的 `drop_if`／`if_to_effects`／`if_keep` 一直没生效（3518、65、318、321、4774、4775、10701～10703、10705、2058）；改成空 match 认所有条件段。只在卡开着时有影响。
- 新专项 `xiyou_tianqi_phase4`（48 项）：默认关、关着每一行都是旧的、开着每一行都和总开关一致、开着但西游档全走旧的、单段上限开着封关着不封、开局建档不复位总开关。
- 发现：`XTianqiBase.reload()` 这种和 `Script.reload()` 同名的静态函数，用类名调会变成重新编译脚本、把静态变量全清回默认（总开关被关掉）。本单改名 `clear_cache()`；`XTianqiSkills.reload()` 有同样的问题，各专项都是先 reload 再设开关所以没暴露，没动。
- 玩家可见：无（总开关关着）。

## 交接板

- 下一步：T104（`XTianqiGear.effective_params`＋直接读装备 params 的约 50 处，含镶嵌随机值差值法）；T012-c 翻开关时要补 `balance_table.guardian_phase4` 三张表、实机标 K 和 U。
- 用户试玩说明：无（暗装，总开关关着）。
- 需要用户决定：无。

## 我不同意的地方 ／ 没照派单做的

- **镶嵌随机值差值法没做**：它属于装备八项 `effective_params`，协调已拆到 T104（本单只接了 T104 以外的行）。
- **烙印条**：本单只做了 K 那一行（名称、说明句照 D140／D146）；烙印面板那根条归 T073（烙印 v0.5 待 D159），没做。
- **绝对值清单只接两类**：`abs_rescale.json` 里只有药品、常数持续伤害的 `new` 是结构化的（`{pct_of, pct}`），护盾、技能固定回复、吸取、敌人固定底数四类 `new` 还是文字说明，要先定写法才能接；建议 T012-c 前出一张填表小单。
- **拆段的副作用**（合计伤害不变，但每次命中各自结算的东西变多）：每段各掷一次暴击、各挂一次技能效果里的状态（21 号普攻状态等）、渡鸦 10125 的施放特效按段数走；暴击期望不变，只是方差小了。需要严格保持的话，得给 `split_effects` 加「后几段不挂效果」的参数，我觉得不值。
- 10007 真·爆裂魔法的序列（whole 一段＋target 条件块里一段）和 2058 修 drop_if 之后的段数，核查时请顺便看一眼原卡意图。

## 验证

- `xiyou_tianqi_phase4` 48／48、`xiyou_tianqi_skills` 237／237（本机单跑）；`天启篇数据校验.py` 全部通过（单段上限待拆名单已空）。
- 虚拟玩家 explore（种子 1）：14／14 通过，卡死 0、脚本报错 0、violations 空。
- 虚拟玩家短帧 climb：（待填）
- `检查.sh --oracle --affected main --cloud`：（待填）

## 进度账

- 天启篇基础数值重构期四：T012-a 填表 → T012-b 接线（本单，除装备八项 T104）。

## 可优化（流程／工具／效率）

- 建议：`选测对照.json` 对 `tianqi_data/*.json` 是按文件名找引用测试的，读表的专项不写表名就会整轮；本单在专项头注释里写了读的表名。可以让选测按「哪个 core 脚本读这张表」间接找（归工具车道）。
- 建议：语法检查加一条「静态函数名不许和 Script／Resource 自带方法同名（reload、get_name 等）」，本单踩到 `reload()`（归工具车道）。

## 本分支提交

- ce190cb21 base_line 职责重判（6/8/15/21/22）、11 里德按四小强、生成脚本清冗余赋值
- e5bb47c89 WIP：期四总开关接线
- 9575a49ac 单段上限 23 行全拆、运行时单段上限按权重口径、drop_if 空匹配修、期四新专项
