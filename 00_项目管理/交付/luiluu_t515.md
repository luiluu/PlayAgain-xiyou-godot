# 交付：luiluu/t515

- 车道／工作者：T515 T013 2B 原版套装模板引擎（cc，Opus＋medium，P8）
- 状态：可合并
- 基准：本机 main `ddf0508d9`（含 github/main `10de8afd2`＝T513 已合 dev.925，另含本机已合未推的 T501）；T513（2A）已在基准里

## 变更记录草稿

## 2026-11-25 【cc·T515·未经审查】天启篇原版套装模板引擎（养成线二期 2B）（dev.待定）

- 依据：私密设计仓《天启篇_原版养成线重做方案_v0.3》第三节第 3 条「模板套」（Kyo 11-14 上午「原版套装照方案」）、第二节第 3 小节第 4 条（掉率单件不超过 +10%）；拆卡 协作交接/派单/T513_二三期拆卡.md §2B；口径 1～5 协调 11-25 回 T515（低阶取数用 A、阶取最低、件数档不累加、独占范围、五套样板）。
- 新表 `modes/xiyou/tianqi_data/suit_template.json`：件数档 2／3／5；一排 1、2、3、5、6、8、10、12、15（不出 4），四阶 5／10／15，每低一阶往前挪一格 → 2 件 1/2/3/5、3 件 5/6/8/10、5 件 8/10/12/15（**暂定，Kyo 可改，只动本表**）；八种类型（攻·伤害、攻·本系伤害、守·减承伤、守·生命、功能·技能消耗／生命回复（封顶 5）／异常抵抗、掉率（单件封顶 10））；五套样板：9 勇士（守·生命）、14 高阶火焰（攻·火系伤）、23 所有伤害板甲（攻·伤害）、143 xx套装（掉率）、188 战魂（功能·技能消耗）。
- `XTianqiSuits`（`core/tianqi_suits.gd`）加模板引擎：归了类的套装多件档不再读原效果（被动技能、状态、固定值都不再给），按「类型 × 件数档 × 阶」从表里取一条；件数档只取够到的最高一档、不累加，不超过原套最高件数，原套最低多件档没穿够不算成套（和 2A 名额同一口径）；阶＝这套身上部件最低那一阶（部件 req_level 按词条四阶分界）；1 件档、没归类的套装照原样。名字、部件、存档都不动，老存档算效果时读表。
- 接线三处（各一行）：`XEquipSuits._active_now` 经 `bonuses_of` 换档；`XTianqiAffixBattle.personal` 并入 `affix_entries`、`fold` 认直接给的数（模板效果走词条现成的池子：伤害加成池、元素增伤、承伤、属性、技能消耗、回复、异常抵抗，不新开伤害钩子）；`XTianqiDrop.sources_of` 套装那一行对模板档按表值进掉落线加成池（不再落档）。
- 回退开关 `XTianqiSuits.TEMPLATE`（O-待定）：false＝原版套装照原效果（回到本卡之前）。西游档零改动（`XTianqi.active` 不成立时 `bonuses_of` 原样返回）。
- 数据校验：`天启篇数据校验.py` 加 suit_template 一节（件数档、一排数不出 4、各档四阶取数是一排往前挪、随档不降、类型与词条键、掉率封顶 ≤10、样板号在 EquipSuits 且有多件档），`测试天启篇数据校验.py` 加 SuitTemplateT515（现表过＋八种改坏要报＋单件套不收）。
- 专项 `tests/xiyou_tianqi_suit_template`（32 项）：五套样板取值、原效果退场、阶取最低、件数档（2 件不成套／3／5／6 件按 5 件档）、不累加、掉率按表值与封顶 10、1 件档保留、没归类套装原样、和 2A 名额同台（三套只两套）、开关关回原效果、西游档原效果。
- `tests/xiyou_tianqi_nine_off` 的「套装状态 41 被九线停用」那一段借的是 9 号勇士套的原效果，9 号进了模板样板后那一段临时关 `TEMPLATE` 量原效果（其余不变）。
- 玩家可见：天启篇存档里这 5 套原版套装的效果变了（如高阶火焰 3 件从「火焰伤害 +45%」变成四阶「火焰伤害 +10%」）；装备说明卡上的套装效果文字还是原版的（见「没做」）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_suits.gd` `XTianqiSuits.TEMPLATE` | （天启篇新增）原版套装照原效果（被动技能、状态、固定值，最高到「所有伤害结果乘 2」） | 归了类的原版套装多件档按模板表 `tianqi_data/suit_template.json` 取（类型×件数档×阶，件数档不累加、阶取最低），1 件档和没归类的套装照旧；西游档零改动 | 养成线重做方案 v0.3 第三节第 3 条「模板套」（Kyo 11-14）；口径协调 11-25 回 T515 | `XTianqiSuits.TEMPLATE = false` | cc（T515） | 保留 |

## 交接板

- 下一步：2C（约 130 套归类填表，先 15 套样板给 Kyo）可接；2E 单件 49 套另开。装备说明卡（`ui/gear_info.gd` 套装段、新皮肤说明牌）对归了类的套装还显示原效果文字，建议开一张界面小单按模板显示（玩家可见文字过小A）。
- 用户试玩说明：天启篇里穿高阶火焰、所有伤害板甲、勇士、战魂、xx套装这 5 套，效果改成模板数（数值暂定）。
- 需要用户决定：低阶取数（暂定一排 1、2、3、5、6、8、10、12、15 往前挪）Kyo 可改，只动 suit_template.json。

## 进度账

- 部件 9（数值总账与养成）：拆卡稿 2B 折合 +0.20 点，交由总装按账记。

## 可优化（流程／工具／效率）

- 建议：2A 专项和本单专项都用「直接造套装件实例」的办法；以后 2C 填表铺开时，`xiyou_tianqi_nine_off`、`xiyou_tianqi_phase4_modules` 等借原版套装原效果测别的线的测试会陆续被模板换掉，可在 2C 卡里先 grep 这些测试用到的套装号（9、55、给 3609 的那套），表里要么不收、要么测试里关 `TEMPLATE`（本单已处理 9）。归 2C。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XEquipSuits._active_now`（经 `active`／`value`／`ids`／`reward`） | 非测试调用 19 处（`git grep -nE 'XEquipSuits\.(active|value|ids|reward)\(' -- '*.gd' ':!*/tests/*'`） | 调用方 19 处逐处结论：西游档、开关关、没归类的套装 `bonuses_of` 原样返回，全部不变；天启篇归了类的套装只多出一个字段齐全的合成档（数都是空的，掉率类只填 bResultPlus[2]，其余只带 tqAffix），所以 actor.gd 的 param／xparam／sparam／states／skills 读到 0 或空（原效果退场是本卡要的），tianqi_ledger 的套装状态、技能认不到原效果（同上），tianqi_money 的金钱加成读到 0，battle_logic／map_transfer／status_page 的 reward 读到模板掉率（和原版掉率套一样走 bResult），tianqi_drop.sources_of 见下行 |
| `XTianqiAffixBattle.fold` | 2 处（`git grep -nE '[^._a-z]fold\(' -- 'modes/xiyou/core/tianqi_affix_battle.gd'`） | 调用方 2 处逐处结论：personal、auras_of；只多认「条目带 value 就用 value」，装备词条条目（{key, tier, grade, extra}，见 tianqi_affix_roll.gd:292、tianqi_qiyin_equip.gd:163）都不带 value，结果不变 |
| `XTianqiAffixBattle.personal` | 3 处（`git grep -nE '[^._a-z]personal\(' -- '*.gd' ':!*/tests/*'`） | 调用方 3 处逐处结论：party_sum、view（战斗中、战斗外）；多并入 `XTianqiSuits.affix_entries`，不在天启篇或开关关时是空数组，结果不变 |
| `XTianqiDrop.sources_of` | 1 处（`git grep -nE 'sources_of\(' -- '*.gd' ':!*/tests/*'`） | 调用方 1 处逐处结论：party_bonus；只有带 tqTemplate 标记的模板档换成按表值，原版套装档照旧落档 |
| 新开关 `XTianqiSuits.TEMPLATE`（O-待定） | 新增 | 默认 true；登记见上「优化登记草稿」 |

## 验证

- 专项（本机）：`xiyou_tianqi_suit_template` 32/32、`xiyou_tianqi_suit_cap` 41/41、`xiyou_tianqi_nine_off` 19/19（`并行测试.py`）。
- 数据校验：`天启篇数据校验.py` 全部通过；`测试天启篇数据校验.py` 155 项 OK。
- 发行空壳：`发行空壳.py check` 退出 0（85 个脚本、833 个函数都有；`bonuses_of` 第一句「不在天启篇就原样返回」照搬成空壳）。
- 云端选测（基准 `ddf0508d9`，41 个场景、8 片）：通过，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45692219146 （`gh run watch` 前台等完退出 0）；偶发 1 个：xiyou_tianqi_gongfa_shop（并行失败、单跑通过，本卡没碰功法货架）。
- 工具回归：`工具回归.py` 全部通过。
- 截图：本卡不改界面，没有截图。

## 没做／偏离

- 装备说明卡的套装效果文字没跟模板改（不在本卡独占文件，玩家可见文字要过小A），见交接板下一步。
- 模板效果走词条通道，九线封顶（`XTianqiLedger` 的 nineCap 套装份）认不到它；稿里「两套合计 +25%」由模板表本身的数限住，九线封顶要不要把模板套也算进去，留给数值线对总账时定。

## 本分支提交

- 0aefa503b T515：原版套装模板引擎（养成线二期 2B）
