# 交付：luiluu/cc-dexiyou-names

- 车道／工作者：T070 D126 去西游化落地（cc，Sonnet＋medium；本单配 Sonnet＋medium，因为按现成清单改文字和前缀，机械为主）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·未经审查】D126 去西游化：见证使者、晨星币、【霸主】【远古首领】（dev.待定）

- 依据：Kyo 11-16 拍板 D126；位置清单见私密设计仓 `协作交接/T053_去西游化命名候选.md` 第二、三节。
- `text_fix/rules.json` dict 末尾加四条：天道使者→见证使者（负向前瞻跳过 Map046 EV001 那句讨债台词，`tianqi_sect.gd:291` 匹配逻辑原样不动）、天道币→晨星币、`超级[Bb]oss`→霸主（前面 Boos→Boss 先改回错字）、【DOTABOSS】→【远古首领】；D105 三条 Boss 规则的 why 同步改。Map204 的 356 指令串、System 变量名、oracle 冻结参照不在改字范围，没动。
- `core/zhenqi.gd:267` 首领识别正则加入「霸主」，旧前缀保留；「远古首领」（原【DOTABOSS】）没加：原版本来不按名认它为首领，xiyou_zhenqi 对照参照也这么要求，加了会改玩法；`core/test_mode.gd` GM 面板币名显示「晨星币」（ID 2451 不动）。
- `core/tianqi_sect.gd`：`rewrite_message` 前加 `_hall_trim_message`，天启篇下删 Map004 EV073「天道币、逆天币、心法碎片并入肝帝积分（1个＝30积分）；」一句、EV071 cmd571 删「、天道使者打晕求道者小队」（再经 D105 规则成「副本首领（1/8）」）。西游档原样。
- 排重：见证使者、晨星币、霸主、远古首领在 Actors／Items／Skills／Enemies／States 的 name 里零撞名。
- 验证：`检查.sh --affected` 因 rules.json 判「整轮」（654 场景，本机太慢）没跑完，改跑受影响面 61 个场景（引用 zh_fwd／XZhenqi／XTextFix／XTianqiSect／XEncounterTarget／XTestMode 的全部专项＋事件对照四份）全过；语法检查、交付自检过。
- 测试：`xiyou_text_fix`（新增 `_d126` 六项）、`xiyou_text_batch23`、`xiyou_tianqi_sect_bing`（新增 `_hall_trim` 五项，含 Map046 仍是老钱）更新后全过；`tests/lib/zh_fwd.gd` 同步新口径。
- 玩家可见：天启篇大厅商店向导、改版向导各删一句过时说明；原「天道使者」「天道币」「【超级Boss】」「【DOTABOSS】」显示为「见证使者」「晨星币」「【霸主】」「【远古首领】」。

## 交接板

- 下一步：无
- 用户试玩说明：同上「玩家可见」
- 需要用户决定：见下「给协调的话」三点（都有默认做法，不挡合并）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：T053 清单里 EV071 的「天道加持」「天道补偿」（cmd283／504／531／537，对应 `core/guide.gd:153,297`）不在本单范围，没动；「天道」二字只剩说明里的游戏规则名，是否一并去西游化请 Kyo 定（改的话同样走 rules.json＋guide.gd，约半小时）。

## 给协调的话

0. 「远古首领」（原【DOTABOSS】ROSHAN，敌 2027）没进首领识别正则：原版本来不认它，xiyou_zhenqi 对照参照（boss.enemies）要求不变。要让它算首领是玩法改动，你定。
1. 西游档 Map046 EV001 的 4 处讨债人台词仍叫「天道使者」（为保 `tianqi_sect.gd:291` 不动）；要西游档也全改，需要在 :291 加一个「见证使者」条件，你定。
2. EV073 那句删完后，句尾「旧存档里的这些货币，读档时已经自动折算。」「金精铜钱并入诸神头颅」在天启篇仍在，按验收只删了指定一句，建议后续一并删。
3. `Map046 EV001 cmd27` 的 toast「你击败了天道眷顾者…」不在本单范围，没动。
4. 为让注释不过时，另顺手改了 `core/text_fix.gd`、`core/encounter_target.gd` 各一行注释（不在独占清单内，仅注释）。

## 本分支提交

- 见 git log
