# 交付单：cc/nezha-tools24（哪吒_11，工具车道）

- 状态：可合并
- 执行者：cc（哪吒_11）；自 tools23 末端 8e53634b 切，**须在 tools23 之后合**。没合 main（main 仍在合 bailong-garou2，state.json 在）。只改 `07_开发环境/选测.py`、`选测对照.json`、`测试选测.py`。验证：测试选测 58/58（新增 3）；未跑 Godot。
- 本期只交派单第 1 条（F1）；第 2、3 条（T1、T2／parse_check、指纹与戳豁免、withdraw_baseline、lsof）下一期做，第 0 步核对随下一期一起写。

## 变更记录草稿

## 2026-10-31 【cc·哪吒·未经审查】选测楼层按图号收窄不再漏选真实专项（沙僧第八期 F1／P2，dev.待定）

- **问题**（沙僧第八期 F1／P2，75% 审查二期仍开）：`选测.py` 切片 maps／keepEvents 改动时按图号收窄楼层专项，只要从脚本里按 `MAP_REF_PATTERNS` 认出一张图就当集合完整、按交集删场景。真实专项 `xiyou_floor_unknown160` 的出口图写在 `MAPS.exits` 表里、用 `_wait_map(dest[1])` 逐个走，改图 32 时被删；`xiyou_floor30_seeker` 用 `HUB := 4` 与 `_wait_map(HUB)`，改图 4 时被删。核实：tools23 末端代码里这条仍在（`map_ids` 没变），不是已修。
- **修法**：收窄时除了认出的图号求交集，再兜底两条才删：①场景脚本（连同 preload／extends 的 `tests/` 脚本，如 `xiyou_reach_check.gd`、`xiyou_map186.gd`，`Tests.scripts`）里出现改动图号的整数字面量就保留（`Tests.mentions`，只看 .gd、不看 .tscn 头的 load_steps／format）；②与 always 场景（`xiyou_floor_run*`、`xiyou_map`）共用脚本的保留（按内容数据遍历）。`map_ids` 也改成跟着 preload 的脚本找。宁可多选：坐标、次数碰上同一个数也保留。
- **代价**（真实 51 个楼层／地图专项实测，改一张图时省掉的个数 旧→新）：160 号 45→45、114 号 46→44、186 号 42→41、206 号 47→34、75 号 46→29、32 号 47→35、4 号 36→2、9 号 47→1。小图号（大厅 4、个位数）几乎不再收窄，这是对的：它们真被大量专项当常量用。
- **回退**：`选测对照.json` 的 `sliceSections.narrowFloorsByMap.anyLiteral` 改成 false 回到只按认出的图号求交集。
- 自测：`测试选测.py` 58/58（新增 3：照 F1 两个反例和 preload 辅助脚本写的夹具，改 32／4／77 时都要选上，同时 69 号专项仍被收窄掉；`anyLiteral=false` 回到旧规则；真实 `xiyou_floor_unknown160` 认得 32、`xiyou_floor30_seeker` 认得 4）。先写的用例在旧代码上 2 败 1 错，修后全过。

## 交接板

- 交接板「沙僧第六～二十一期交回」里 F1 可划掉（dev.待定），75% 审查二期的「选测按图号收窄漏选」同销。
- 工具类剩 T1、T2／parse_check、同步指纹与戳丢失豁免两项、withdraw_baseline 误删、lsof 保护：哪吒_11 下一期（tools25）做。

## 可优化

- 优化登记草稿：无。
- 建议：若嫌小图号不再收窄，可在 `选测对照.json` 加「HUB 等常量白名单」只对明确的大厅常量宽松；现在没做，正确性优先。

## 本分支提交

- bb7a95b1 选测楼层按图号收窄时字面量兜底，修沙僧第八期 F1（期一）
