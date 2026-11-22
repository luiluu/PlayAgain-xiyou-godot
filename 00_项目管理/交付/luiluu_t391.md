# 交付：luiluu/t391

- 车道／工作者：T391 数据校验补齐 6 份天启篇 JSON（K5）／cc（Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-22 【cc·T391·未经审查】数据校验补齐六份天启篇 JSON：drop_table、gojo_trials、money_table、ring_styles、trumpet、weak_affix_table（dev.待定）

- 依据：启封缺口 K5（账本部件 16）。先确认：`天启篇数据校验.py` 里这六份表原先没有任何规则（按文件名和规则函数都查过）。
- `03_转换工具/天启篇数据校验.py` 新增六个规则函数＋六个检查函数，登记进 `CHECKS`：
  - `drop_table_rules`：generic 层段／件数／品质权重／等级窗口，guardian、dungeon_up（四档不降）、bonus（档位两列递增、top 不小于末档）、signature 的范围；`ignore_skills` 不重复。
  - `gojo_trials_rules`：troop、shell_enemy、tint、试炼号从 1 连续、key 不重复、各项数值范围、`ratio` 在 (0,1]、`domain` 三键齐、`phase4_dmg_pct` 1～100。
  - `money_table_rules`：`by_floor` 个数＝`floor_max`、五档价格倍数齐且不降、卖价七档不降、重铸阶系数四档、进阶逐阶变贵、修炼级数×每级层数不超 36 层、天平范围。
  - `ring_styles_rules`：七印色、样式层名／优先级／颜色／动效、图片文件存在（`content/tianqi/ring_style/` 与 `circle` 的 res:// 路径）、`rules` 展开 `{seal}`／`{line}` 后的样式都在 styles 里、`when` 键只认已知的、`dots.min_pieces`。
  - `trumpet_rules`：七卷序号／key／物品号／技能号不重复、段号在 `drop.segments` 内、段区间首尾相接、难度键合法、可学上限越强越少、百分数是整数且在范围内、退役物品不与七卷重号。
  - `weak_affix_rules`：词条键＝`w<no>`、角色号不重复且在 `six_dim.json` 的 actors 里、`proj` 键只用已知字段、各子块（settle／thunder／mark／pass／invite／ward）的技能号与百分数、`guidable_skills` 不重复。
- 引用号存在性：物品、技能、状态、遭遇组、敌人对 `generated/db` 查。`generated/db` 不进仓库且常比表旧（本机那份 11-07 的，缺 10707、10830 这些新源号），所以**只抓库里号段范围内的空洞，比库里最大号还大的不判**；没有库（云端）就整段跳过。这是取舍：能抓手滑改错的号，抓不到「新号写错成另一个新号」。
- `测试天启篇数据校验.py` 加 `K5SixTables`：正例（真表全过、六张都登记进 CHECKS）＋六份共 40 余条反例（每份 6～8 条，含引用空洞、重号、断档、越界、缺键），另有「表不在就跳过」「文件读坏算不过」。

## 验收逐条

1. ✓：六份各有形状、取值范围、引用 ID 存在的校验（引用见上，数据库部分是范围内空洞）；确认过原先真没校验。
2. ✓：每份至少一条反例（`K5SixTables` 六个 test，每份多条）。
3. ✓：对 main 现数据 `天启篇数据校验.py` 退出码 0；`测试天启篇数据校验.py` 130 项全过。
4. ✓：只改了校验脚本和测试，数据没动，没发现数据有错。
5. ✓：本交付单；自检结论见回执。

## 量数（规则覆盖，入仓代替量数表）

| 表 | 规则函数 | 形状/范围/引用/关系 | 反例用例 |
| --- | --- | --- | --- |
| drop_table | `drop_table_rules` | 约 35 项 | 8 组 |
| gojo_trials | `gojo_trials_rules` | 约 25 项（每试炼） | 6 组 |
| money_table | `money_table_rules` | 约 35 项 | 7 组 |
| ring_styles | `ring_styles_rules` | 约 25 项＋逐样式/规则 | 7 组 |
| trumpet | `trumpet_rules` | 约 30 项＋逐卷 | 8 组 |
| weak_affix_table | `weak_affix_rules` | 约 25 项＋逐词条 | 8 组 |

（「约」＝按代码里 check 条数粗数，没逐条计。）

## 发现

- `weak_affix_table.json` 的 `proj` 里的技能（如 4507）不在 `guidable_skills` 里——不是错（proj 是改本人看到的那份，guidable 是可引导标记），所以没加这条关系。
- `ring_styles.json` 的 `orb_tier` 没有 art，靠 `tint_by: quality` 程序画；规则按此放行。

## 可优化（流程／工具／效率）

- 建议：把 `generated/db` 的新旧比对纳入检查前置（比如读 `build_info`），这样引用检查在新库上能查到号段尾部。小活，归工具车道。

## 本分支提交

- 见 git log（校验脚本＋测试＋本交付单）
