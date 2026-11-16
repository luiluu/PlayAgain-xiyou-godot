# 交付：luiluu/cc-dexiyou-names

- 车道／工作者：T070 D126 去西游化落地（cc，Sonnet＋medium；本单配 Sonnet＋medium，因为按现成清单改文字和前缀，机械为主）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·未经审查】D126 去西游化：见证使者、晨星币、【霸主】【远古首领】，只在天启篇存档套用（dev.待定）

- 依据：Kyo 11-16 拍板 D126；位置清单见私密设计仓 `协作交接/T053_去西游化命名候选.md`；小A 核查 P1-1（西游档不能被改）返修收口。
- **模式隔离**：四条（天道使者→见证使者［负向前瞻跳过 Map046 EV001 讨债台词，`tianqi_sect.gd:291` 不动］、天道币→晨星币、`超级[Bb]oss`→霸主、【DOTABOSS】→【远古首领】）放进 `text_fix/rules.json` 独立字段 `tianqi_dict`，`XTextFix.fix` 只在 `XTextFix.tq_on()`（当前存档是天启篇）时套用；西游档 1:1 原貌，不再出现「见证使者」与 Map046「天道使者」自相矛盾。
- **缓存隔离**：`_signature()` 编入模式位（磁盘 `#textfix` 缓存按档隔离）；`XTextFix.sync_mode()` 在换档（`XState._become_current`）、天启篇开局建档（`XTianqi.start_new_game`）时清表与地图缓存，同进程切档不串。收口方案比报告多一点：报告写「切档时清缓存」，实现为「模式变了才清」，避免每次读档白清。
- `core/zhenqi.gd:267` 首领正则加入「霸主」，旧前缀保留；「远古首领」没加（原版本来不认 ROSHAN 为首领，xiyou_zhenqi 对照参照要求不变）。
- `core/test_mode.gd`：`RESOURCES` 保留「天道币」，新增 `resource_name(s, r)`，天启篇显示「晨星币」，西游档原名（测试模式界面 `ui/test_mode_scene.gd` 一行同步）。
- `core/tianqi_sect.gd`：`_hall_trim_message` 天启篇下删 Map004 EV073「天道币、逆天币、心法碎片并入肝帝积分（1个＝30积分）；」一句及句尾「旧存档里的这些货币，读档时已经自动折算。」（P3-1），EV071 cmd571 删「、天道使者打晕求道者小队」。西游档原样。
- 测试：`xiyou_text_fix` `_d126` 分两态（天启篇套用＋西游档原貌＋换档清缓存来回切＋DICT 开关）；`xiyou_tianqi_sect_bing` 西游档 `orig`／`plain` 恢复「天道使者」原断言，向导句两态各验，Map046 四页都验老钱；`xiyou_text_batch23`、`tests/lib/zh_fwd.gd`（D126 四条只在 `tq_on()` 时转）同步；`tests/lib/tq_save_kit.gd` 建档后调 `sync_mode`。
- 玩家可见：天启篇大厅商店向导、改版向导各删一句过时说明；天启篇里原「天道使者」「天道币」「【超级Boss】」「【DOTABOSS】」显示为「见证使者」「晨星币」「【霸主】」「【远古首领】」；西游档不变。

- 验证：`检查.sh --affected` 因 rules.json 判整轮（654 场景，本机太慢）没跑；改跑受影响面 136 个场景（引用 XTextFix／XZhenqi／XTianqiSect／XTianqi／XTestMode／zh_fwd／tq_save_kit 的全部专项＋事件对照四份）全过；语法检查、交付自检过。

## 交接板

- 下一步：无
- 用户试玩说明：同上「玩家可见」
- 需要用户决定：见下「给协调的话」（都有默认做法，不挡合并）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：T053 清单里 EV071 的「天道加持」「天道补偿」（cmd283／504／531／537，对应 `core/guide.gd:153,297`）不在本单范围，没动；「天道」二字只剩说明里的游戏规则名，是否一并去西游化请 Kyo 定（改的话同样走 rules.json＋guide.gd，约半小时）。

## 给协调的话

0. 「远古首领」（原【DOTABOSS】ROSHAN，敌 2027）没进首领识别正则：原版本来不认它，xiyou_zhenqi 对照参照（boss.enemies）要求不变。要让它算首领是玩法改动，你定。
1. 西游档 Map046 的「天道使者」现在是 1:1 原貌（讨债人与敌名都叫天道使者，不再矛盾），无需处理。
2. 「金精铜钱并入诸神头颅」一句在天启篇仍在，属另一种旧货币说明，没动，要删另说。
3. `Map046 EV001 cmd27` 的 toast「天道眷顾者」、EV071 的「天道加持／补偿」（P3-2）由协调另开卡，没动。
4. 为让注释不过时，另顺手动了独占清单外的：`core/text_fix.gd`（模式隔离本体，返修所需）、`core/xstate.gd`／`core/tianqi.gd` 各一行 `sync_mode` 调用、`ui/test_mode_scene.gd` 一行币名、`tests/lib/tq_save_kit.gd` 一行；`encounter_target.gd` 一行注释。

- 截图：只放本工作树 `03_再刷重制_Godot/04_验证/本地结果/t070/`（返修后重拍两张）；主工作区根目录的 `T070截图/` 已删（只删了这个目录，别的没碰）。

## 本分支提交

- 见 git log
