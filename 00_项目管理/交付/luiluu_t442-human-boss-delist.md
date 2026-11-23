# 交付：luiluu/t442-human-boss-delist

- 车道／工作者：T442（子卡 T013-1a）／小A（ag，Gemini 4 Neon + high）
- 状态：可合并

## 变更记录草稿

## 2026-11-24 【ag·小A·未经审查】T442 人族首领漏网三件下架＋12 把系别法宝归法宝线（补水风）＋CARDS 注释同步（dev.待定）

- 人族首领 EV054 漏网本体三件下架（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_trim.gd`）：`NO_SALE` 补齐 `[2, 4553]`（混元星河剑）、`[2, 4540]`（黎明—破晓）、`[0, 1981]`（技能书:免疫转换），开关 `XTianqiTrim.NO_HONGHUANG = false` 可完整回退；同步更新 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_trim.gd:187` 旧断言（经协调者批复，仅改该 1 处断言）。
- 12 把系别法宝归法宝线并补齐水/风（`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_gear.gd`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/gear_table.json`、`03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xdb.gd`）：
  - 新增总开关 `XTianqiGear.ELEMENT_FABAOS := true`（设 `false` 回退）与 `gear_table.json` 的 `element_fabaos` 节；
  - 原 10 把（4543～4552）＋新增表外水系 `8101`「沧澜水剑」（模版 4545、图标 5222）、风系 `8102`「青岚风剑」（模版 4548、图标 3308；动手前全库确认 `Armors` 表 8101/8102 未被占用，暂不上 EV054 货架，留 T013-1c 统一上架）去掉原版特性 21（全属性倍率）、22（暴击/命中）、61（再动）、34（攻击次数）、11（抗性/受治疗倍率）与大额增伤/终伤/爆伤/穿透标签，只留本系或治疗 `+10%`、`FABAO_TABLE` 成长与 1 条通用法宝光环；
  - 4548 原名「御风灵剑」（元素 6 自然系）改名「森罗灵剑」避免与风系冲突；新改名字与说明均标 `text_review: pending`（待小A·文字审）；
  - `XDB.rec("Armors", id)` 仅增 1 处挂点（`touches_element_fabao` → `element_fabao_rec`），`XTianqiGear.stat_list` 同步加 `element_fabao_view` 兼容老天启篇测试档已持有的 4543～4552 旧实例；西游档零变化。
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_skills.gd` 仅同步第 17、25-26 行过期注释，说明角色卡已随 `XTianqiBase.PHASE4 := true` 开启、`CARDS := false` 仅作专项隔离钩子；`CARDS` 默认值未改。
- 数据校验与测试：`03_再刷重制_Godot/03_转换工具/天启篇数据校验.py` 补 `gear_table.json` `element_fabaos` 12 条规则校验；新增专项 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_element_fabaos.gd`（配 `.tscn` 与 `.gd.uid`，22/22 通过）。
- 玩家可见：天启篇人族首领商店不再出售漏网的混元星河剑、黎明—破晓与免疫转换书；系别法宝统一归入天启篇法宝线（本系或治疗 +10%、按法宝表成长、可带 1 条法宝光环），原自然系法宝改名「森罗灵剑」并预备水系「沧澜水剑」与风系「青岚风剑」（上述命名与说明待小A·文字审）。

## 待小A·文字审

- `Armors 4548`（自然系）：新名「森罗灵剑」；说明「系别法宝\n蕴含森罗生机的灵剑，提升自然伤害。」
- `Armors 8101`（水系，表外新号）：新名「沧澜水剑」；说明「系别法宝\n凝聚沧澜水力的灵剑，提升水属性伤害。」
- `Armors 8102`（风系，表外新号）：新名「青岚风剑」；说明「系别法宝\n御使青岚罡风的灵剑，提升风属性伤害。」
- 通用效果行（`gear_table.json` `element_fabaos.aura_line`）：「法宝成长按楼层上限与天启篇法宝表结算，可带1条法宝光环」

## 交接板

- 下一步：T013-1a（T442）已可合并；后续 T013-1b/1c/1d 按拍板推进，T013-1c 接管 EV054 时将 `8101`/`8102` 一并上架。
- 用户试玩说明：天启篇人族首领商店不再卖漏网三件；10 把原系别法宝已去超标数值改归法宝线（+10%＋成长＋1 条光环），自然系法宝暂改名「森罗灵剑」（待文字审）。
- 需要用户决定：无（水/风与 4548 命名说明待小A·文字审）。

## 进度账

- 部件 9（原版养成线重做·第一期子卡 T013-1a）：人族首领漏网三件已下架、12 把系别法宝归法宝线落地；部件 10 `CARDS` 注释口径已对齐 `PHASE4 := true`。

## 可优化（流程／工具／效率）

- 建议：`XTianqiElements.DECK = true` 时 `map_element_id(1)` 把物理元素 1 映为 0，导致 `XDamage.calculate` 查 `elementAmplify["0"]` 而读不到物理法宝 4543 的 `elementAmplify["1"]` 与角色卡 `<passiveELUP01>`（本单不碰 `damage.gd`，交后续元素/战斗核查卡统一评估是否保留物理增伤键读法）。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiTrim.NO_SALE` / `shop_goods` | 2 处（`git grep -nE '[^[:alnum:]_]NO_SALE[[:space:]]*(\(\|[^[:alnum:]_])' -- '03_再刷重制_Godot/01_Godot工程/modes/'`）；`XTianqiTrim.shop_goods` 调用方 3 处（`mv_interpreter.gd:370`、`tianqi_sect.gd:255`、`tianqi_trim.gd:158`） | 调用方 3 处逐处结论：`mv_interpreter.gd:370` 经指令 302 过滤 EV054 货单（正好按需下架 4553/4540/1981，西游档与开关关时不触发）；`tianqi_sect.gd:255` 商店不含此三件无影响；`tianqi_trim.gd:158` 牢妲兑换店只有 1060 无影响。旧测试 `tests/xiyou_tianqi_trim.gd:187` 同步更新并通过（44/44）。 |
| `XTianqiGear.stat_list` | 3 处（`git grep -n 'XTianqiGear\.stat_list(' -- '03_再刷重制_Godot/01_Godot工程/modes/'`） | 调用方 3 处逐处结论：`actor.gd:390`（`stat_equips` 算特性/伤害/被动缓存）、`actor.gd:1245`（`_param_plus` 算装备属性）、`actor.gd:1696`（开战状态），仅对天启篇存档中未带 `_tq_efabao_v` 的 4543～4552 老实例做系别法宝视图清理，其他装备与西游档零变化。 |
| `XTianqiGear.reload_table` | 1 处（`git grep -n 'XTianqiGear\.reload_table(' -- '03_再刷重制_Godot/01_Godot工程/'` 仅测试调用，工程 `modes/` 内 0 处） | 调用方 1 处逐处结论：仅额外清空 `_efabao_*` 缓存，不影响坐骑/神器表重读，`xiyou_tianqi_gear2` 46/46 通过。 |
| `XTianqiGear.clear_effective_cache` | 0 处工程调用（`git grep -n 'clear_effective_cache(' -- '03_再刷重制_Godot/01_Godot工程/modes/'`，仅测试调用） | 调用方 0 处逐处结论：仅额外清空 `_efabao_*` 缓存，无副作用。 |
| `XDB.rec` | 554 处（`git grep -n 'XDB\.rec(' -- '03_再刷重制_Godot/01_Godot工程/modes/'`） | 调用方 554 处逐处结论：新增 1 处挂点仅拦截 `name == "Armors"` 且 `XTianqiGear.touches_element_fabao(id)`（天启篇存档＋`ELEMENT_FABAOS=true`＋id 在 12 把系别法宝内），其他 550+ 处表与非目标编号零触碰、西游档零变化，云端选测 637 场景全绿。 |

## 验证

- **云端选测**（提交 `8cf5221c7a`，`ci/luiluu/t442-human-boss-delist`，基准 `faf1e13a07`）：637 个场景／16 片全部通过，最长一片 17.5 分钟，已 `gh run watch 45284706618 --exit-status` 前台等完：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45284706618
- **本机专项（前台单跑，全部 `--audio-driver Dummy`）**：
  - `xiyou_tianqi_element_fabaos.tscn`：22/22 通过
  - `xiyou_tianqi_trim.tscn`：44/44 通过
  - `xiyou_tianqi_gear.tscn`：36/36 通过
  - `xiyou_tianqi_gear2.tscn`：46/46 通过
  - `xiyou_tianqi_phase4.tscn`：176/176 通过（含 `CARDS` 隔离断言）
  - `xiyou_tianqi_skills.tscn`：245/245 通过（含 `CARDS` 隔离断言）
  - `xiyou_tianqi_skill_debt.tscn`：31/31 通过（含 `CARDS` 隔离断言）
- **M5 前虚拟玩家 DoD（`--audio-driver Dummy`）**：
  - `explore`（`xiyou_virtual_player.tscn`，seed 20261113）：16/16 通过，`aborted=""`、`stuck=[]`、`violations=[]`
  - 短帧 `climb`（`--vp-mode=climb --vp-ff --vp-seed=1 --vp-ticks=3000`）：11/11 通过，连过 1～4 层至第 5 层（3023 步 / 12331 帧），`defeats=0`、`aborted=""`、`stuck=[]`、`violations=[]`，零卡死／零脚本错／零负值
- **静态与门禁检查**：
  - `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`：退出码 0（含 `gear_table.json` `element_fabaos`）
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：退出码 0（81 脚本，784 函数全齐）
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：退出码 0（1195 个 `.gd` 零错误）
  - `python3 03_再刷重制_Godot/07_开发环境/工具回归.py`：退出码 0（23/23 全部通过）

## 本分支提交

- `8cf5221c7` T442 人族首领漏网三件下架＋12 把系别法宝归法宝线（补水风）＋CARDS 注释同步
