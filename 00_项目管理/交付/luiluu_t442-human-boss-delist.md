# 交付：luiluu/t442-human-boss-delist

- 车道／工作者：T442（子卡 T013-1a，含返修 R1）／小A（ag，Gemini 4 Neon + high）
- 状态：可合并

## 变更记录草稿

## 2026-11-24 【ag·小A·未经审查】T442 人族首领漏网三件下架＋12 把系别法宝归法宝线（补水风）＋CARDS 注释同步（dev.待定）

- 人族首领 EV054 漏网本体三件下架（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_trim.gd`）：`NO_SALE` 补齐 `[2, 4553]`（混元星河剑）、`[2, 4540]`（黎明—破晓）、`[0, 1981]`（技能书:免疫转换），开关 `XTianqiTrim.NO_HONGHUANG = false` 可完整回退；同步更新 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_trim.gd:187` 旧断言（经协调者批复，仅改该 1 处断言）。
- 12 把系别法宝归法宝线并补齐水/风（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_gear.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/gear_table.json`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xdb.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_save.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/help_card.gd`）：
  - 新增总开关 `XTianqiGear.ELEMENT_FABAOS := true`（设 `false` 回退）与 `gear_table.json` 的 `element_fabaos` 节；
  - 原 10 把（4543～4552）＋新增表外水系 `8101`「沧澜水剑」（模版 4545、图标 5222）、风系 `8102`「青岚风剑」（模版 4548、图标 3308；动手前全库确认 `Armors` 表 8101/8102 未被占用，暂不上 EV054 货架，留 T013-1c 统一上架）去掉原版特性 21（全属性倍率）、22（暴击/命中）、61（再动）、34（攻击次数）、11（抗性/受治疗倍率）与大额增伤/终伤/爆伤/穿透标签，只留本系或治疗 `+10%`、`FABAO_TABLE` 成长与 1 条通用法宝光环；
  - 4548 原名「御风灵剑」（元素 6 自然系）改名「森罗灵剑」避免与风系冲突；全部 12 把按 cc 文字审意见补齐同格式说明并标 `text_review: pending`（待 cc Sonnet 文字审）；
  - `XDB.rec("Armors", id)` 仅增 1 处挂点（`touches_element_fabao` → `element_fabao_rec`）；返修 R1（P2-1）同时将 `XTianqiGear.element_fabao_view` 接入 `XHelpCard.detail_rows`／`_content` 并在 `XTianqiSave.after_load` 挂接 `XTianqiGear.sync_element_fabaos(s)`，老天启篇档背包/身上/仓库已有的原版 4543～4552 实例读档后同步名字（保留 `[锁定]` 前缀与 `(+N)` 强化后缀）、说明（保留末尾法宝光环行）、备注、特性与 `yep`；西游档真存→读档零变化。
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_skills.gd` 仅同步第 17、25-26 行过期注释，说明角色卡已随 `XTianqiBase.PHASE4 := true` 开启、`CARDS := false` 仅作专项隔离钩子；`CARDS` 默认值未改。
- 数据校验与测试：`03_再刷重制_Godot/03_转换工具/天启篇数据校验.py` 补 `gear_table.json` `element_fabaos` 12 条（含 `description` 非空）规则校验；新增专项 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_element_fabaos.gd`（配 `.tscn` 与 `.gd.uid`，32/32 通过，含 `XHelpCard` 视图与 `XSave.save`→`XSave.load_slot` 真存→读档回归）。
- 玩家可见：天启篇人族首领商店不再出售漏网的混元星河剑、黎明—破晓与免疫转换书；系别法宝统一归入天启篇法宝线（本系或治疗 +10%、按法宝表成长、可带 1 条法宝光环），原自然系法宝改名「森罗灵剑」并预备水系「沧澜水剑」与风系「青岚风剑」，老存档已有法宝读档后同步新名字与说明。

## 全 12 把系别法宝文字清单（待 cc Sonnet 审）

- 通用光环行（已按 cc 文字审意见改）：`法宝等级上限随楼层提升，可带1条法宝光环`
- 12 把名字、效果词与说明（全部 `text_review: pending`，其中 4548、8101、8102 已按 cc 文字审意见改定，其余 9 把照同格式补齐）：

| 防具号 | 名字 | 系别 | 效果词 | 说明（`description`） |
| --- | --- | --- | --- | --- |
| 4543 | 勇者神剑 | 1 物理 | 物理伤害+10% | `系别法宝\n凝聚勇者之力的神剑，提升物理伤害。` |
| 4544 | 炎阳圣剑 | 2 火焰 | 火焰伤害+10% | `系别法宝\n凝聚烈阳之炎的圣剑，提升火焰伤害。` |
| 4545 | 霜华冰剑 | 3 寒冰 | 寒冰伤害+10% | `系别法宝\n凝聚极寒霜华的冰剑，提升寒冰伤害。` |
| 4546 | 厚土盾剑 | 4 大地 | 大地伤害+10% | `系别法宝\n凝聚厚土之力的盾剑，提升大地伤害。` |
| 4547 | 苍雷破穹 | 5 雷电 | 雷电伤害+10% | `系别法宝\n引动九天苍雷的灵剑，提升雷电伤害。` |
| 4548 | 森罗灵剑（改名） | 6 自然 | 自然伤害+10% | `系别法宝\n蕴含草木生机的灵剑，提升自然伤害。` |
| 4549 | 奥理星芒 | 7 奥术 | 奥术伤害+10% | `系别法宝\n凝聚奥理星辉的法器，提升奥术伤害。` |
| 4550 | 神圣权杖 | 8 神圣 | 神圣伤害+10% | `系别法宝\n蕴含圣光之力的权杖，提升神圣伤害。` |
| 4551 | 邪影魔刃 | 9 黑暗 | 黑暗伤害+10% | `系别法宝\n缠绕幽暗邪影的魔刃，提升黑暗伤害。` |
| 4552 | 凤羽神辉 | 10 治疗 | 治疗效果+10% | `系别法宝\n沐浴凤羽神辉的灵羽，提升治疗效果。` |
| 8101 | 沧澜水剑（新表外） | 14 水 | 水伤害+10% | `系别法宝\n凝聚沧澜之水的灵剑，提升水伤害。` |
| 8102 | 青岚风剑（新表外） | 15 风 | 风伤害+10% | `系别法宝\n驾驭青岚罡风的灵剑，提升风伤害。` |

## 核查留痕与后续分工

- **P2-1（已于 R1 修完）**：老天启篇档读档后原版系别法宝实例名字/说明/特性同步，已双管接入 `XTianqiSave.after_load`（`sync_element_fabaos`）与 `XHelpCard`（`element_fabao_view`），并补 `XSave.save`→`XSave.load_slot` 真存→读档回归测试（覆盖背包/身上/仓库＋锁名/强化后缀/光环保留＋西游档零变化）。
- **P2-2（另开卡，不在本单改）**：`XTianqiElements.DECK = true` 时 `map_element_id(1)` 把物理元素 1 映为 0，导致 `XDamage.calculate` 查 `elementAmplify["0"]` 读不到物理法宝 4543 的 `elementAmplify["1"]` 及角色卡 `<passiveELUP01>`，按协调口径另开卡处理，本单不碰 `damage.gd`。
- **P3 四条（留 T013-1c）**：cc Opus 初核登记的 4 条 P3 项（含 EV054 货架重整与水/风 `8101`/`8102` 统一上架等）统一留待后续子卡 T013-1c 接管 EV054 时收口。

## 交接板

- 下一步：T013-1a（T442，含返修 R1）已可合并；全 12 句法宝说明待 cc Sonnet 审；P3 四条留 T013-1c；P2-2（DECK 物理增伤）另开卡。
- 用户试玩说明：天启篇人族首领商店不再卖漏网三件；10 把原系别法宝已去超标数值改归法宝线（+10%＋成长＋1 条光环），自然系法宝改名「森罗灵剑」，老档已有法宝读档后同步新名字与说明。
- 需要用户决定：无（12 把系别法宝说明待 cc Sonnet 文字审）。

## 进度账

- 部件 9（原版养成线重做·第一期子卡 T013-1a）：人族首领漏网三件已下架、12 把系别法宝归法宝线与老档读档同步落地；部件 10 `CARDS` 注释口径已对齐 `PHASE4 := true`。

## 可优化（流程／工具／效率）

- 建议（同 P2-2，另开卡）：`XTianqiElements.DECK = true` 时 `map_element_id(1)→0` 使 `XDamage.calculate` 查不到物理增伤键 1，建议单开战斗/元素核查卡统一处理。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiTrim.NO_SALE` / `shop_goods` | 3 处（`git grep -n 'XTianqiTrim\.shop_goods(' -- '03_再刷重制_Godot/01_Godot工程/modes/'`：`mv_interpreter.gd:370`、`tianqi_sect.gd:255`、`tianqi_trim.gd:158`） | 调用方 3 处逐处结论：`mv_interpreter.gd:370` 经指令 302 过滤 EV054 货单（按需下架 4553/4540/1981，西游档与开关关时不触发）；`tianqi_sect.gd:255` 与 `tianqi_trim.gd:158` 不含此三件无影响。旧测试 `tests/xiyou_tianqi_trim.gd:187` 同步更新并通过（44/44）。 |
| `XTianqiGear.stat_list` | 3 处（`git grep -n 'XTianqiGear\.stat_list(' -- '03_再刷重制_Godot/01_Godot工程/modes/'`） | 调用方 3 处逐处结论：`actor.gd:390`（`stat_equips`）、`actor.gd:1245`（`_param_plus`）、`actor.gd:1696`（开战状态），仅对天启篇存档中未到 `EFABAO_VER` 的系别法宝实例做视图清理，其他装备与西游档零变化。 |
| `XTianqiGear.reload_table` | 1 处（`git grep -n 'XTianqiGear\.reload_table(' -- '03_再刷重制_Godot/01_Godot工程/'`，仅测试调用） | 调用方 1 处逐处结论：仅额外清空 `_efabao_*` 缓存，`xiyou_tianqi_gear2` 46/46 通过。 |
| `XTianqiGear.clear_effective_cache` | 0 处工程调用（`git grep -n 'clear_effective_cache(' -- '03_再刷重制_Godot/01_Godot工程/modes/'`） | 调用方 0 处逐处结论：仅额外清空 `_efabao_*` 缓存，无副作用。 |
| `XDB.rec` | 554 处（`git grep -n 'XDB\.rec(' -- '03_再刷重制_Godot/01_Godot工程/modes/'`） | 调用方 554 处逐处结论：新增 1 处挂点仅拦截 `name == "Armors"` 且 `XTianqiGear.touches_element_fabao(id)`（天启篇存档＋`ELEMENT_FABAOS=true`＋12 把系别法宝），其他表与西游档零触碰。 |
| `XTianqiSave.after_load` | 1 处（`git grep -n 'XTianqiSave\.after_load(' -- '03_再刷重制_Godot/01_Godot工程/modes/'`：`xstate.gd:1111`） | 调用方 1 处逐处结论：`xstate.gd:1111` 在读档末尾调用，追加的 `XTianqiGear.sync_element_fabaos(s)` 仅在天启篇存档且 `ELEMENT_FABAOS=true` 时幂等同步系别法宝实例，西游档与关开关直接返回；`xiyou_tianqi_save` 82/82、`xiyou_tianqi_element_fabaos` 32/32 通过。 |
| `XHelpCard.detail_rows` / `_content` | 3 处（`git grep -n 'XHelpCard\.detail_rows(' -- '03_再刷重制_Godot/01_Godot工程/modes/'`：`gear_detail.gd:120`、`skin_gear_detail.gd:79`、`skin_item_page.gd:292`） | 调用方 3 处逐处结论：仅在入口对天启篇系别法宝老实例走 `XTianqiGear.element_fabao_view(obj)`，非系别法宝与西游档原样返回（发行空壳规则 2 照搬 `return item`），R1 云端选测 64 场景全绿。 |

## 验证

- **R1 云端选测**（提交 `277db38691`，`ci/luiluu/t442-human-boss-delist`，基准 `b751799ee5`）：64 个场景／2 片全部通过，最长一片 8.5 分钟，已 `gh run watch 45290060879 --exit-status` 前台等完：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45290060879
- **初版云端选测**（提交 `8cf5221c7a`，基准 `faf1e13a07`）：637 个场景／16 片全部通过，最长一片 17.5 分钟：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45284706618
- **本机专项（前台单跑，全部 `--audio-driver Dummy`）**：
  - `xiyou_tianqi_element_fabaos.tscn`（R1 含 `XHelpCard` 视图＋真存→读档回归）：32/32 通过
  - `xiyou_tianqi_save.tscn`：82/82 通过
  - `xiyou_tianqi_gear2.tscn`：46/46 通过
  - `xiyou_tianqi_trim.tscn`（R0）：44/44 通过
  - `xiyou_tianqi_gear.tscn`（R0）：36/36 通过
  - `xiyou_tianqi_phase4.tscn`（R0，含 `CARDS` 隔离断言）：176/176 通过
  - `xiyou_tianqi_skills.tscn`（R0，含 `CARDS` 隔离断言）：245/245 通过
  - `xiyou_tianqi_skill_debt.tscn`（R0，含 `CARDS` 隔离断言）：31/31 通过
- **M5 前虚拟玩家 DoD（R0，`--audio-driver Dummy`）**：
  - `explore`（`xiyou_virtual_player.tscn`，seed 20261113）：16/16 通过，`aborted=""`、`stuck=[]`、`violations=[]`
  - 短帧 `climb`（`--vp-mode=climb --vp-ff --vp-seed=1 --vp-ticks=3000`）：11/11 通过，连过 1～4 层至第 5 层（3023 步 / 12331 帧），`defeats=0`、`aborted=""`、`stuck=[]`、`violations=[]`
- **静态与门禁检查（R1 重跑全过）**：
  - `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：退出码 0（含 `gear_table.json` `element_fabaos` 12 把 `description` 校验）
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：退出码 0（81 脚本，785 函数全齐）
  - `python3 03_再刷重制_Godot/07_开发环境/天启篇存档登记.py`：退出码 0
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：退出码 0（1195 个 `.gd` 零错误）
  - `python3 03_再刷重制_Godot/07_开发环境/工具回归.py`（R0）：退出码 0（23/23 全部通过）

## 本分支提交

- `8cf5221c7` T442 人族首领漏网三件下架＋12 把系别法宝归法宝线（补水风）＋CARDS 注释同步
- `b751799ee` T442 交付单入仓（含云端选测 45284706618 与虚拟玩家 DoD 结果）
- `277db3869` T442 返修 R1：老档读档同步与说明卡视图（P2-1）＋12 把系别法宝文字统一
