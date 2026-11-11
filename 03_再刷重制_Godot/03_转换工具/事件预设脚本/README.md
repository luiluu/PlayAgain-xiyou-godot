# 事件预设脚本（cc 分段甲五期）

给「事件写法覆盖 --missed 没执行到的簇」出 event_presets 变体的小脚本。工作目录用环境变量 `SA_WORK` 指定（放 `tried.json`、写 `targets_<tag>.json`），不写进本库别处；只有带 `--write` 时改 `event_presets.json`。

| 脚本 | 做什么 |
| --- | --- |
| `bonly.py [generated 目录]` | 列出只在战斗里跑的公共事件（调用方全是 occasion＝战斗的技能／物品、敌群页、或这类公共事件）。地图对照走不到它们，`--missed` 里这些不用追（五期时 1595 个里占 716）。 |
| `nb.py cov.json missed.json tag [--skip-ce bonly.json] [--write]` | 门头（111／411）已被某个用例执行到：拿那个用例的预设当底，叠上开门预设（经 `事件祖先预设.trace_var` 倒推）。 |
| `nb2.py …` | 门变量在门前被 122 随机赋值时，沿供体路径用 `sim.py` 数随机数位置，解出 random_seq。 |
| `nb3.py …` | 在供体预设上换门变量的初值（门值附近一批候选），用 `sim.py` 模拟，挑第一个让目标执行到的。 |
| `sim.py` | 小模拟器：只认 122、111（开关、变量、物品）、411／412、117（递归进公共事件）、118／119、115、121；别的条件当真。只用来估路径，变体对不对以探针＋对照为准。 |
| `战斗公共事件盘点/盘点.py [--run run.json]` | bonly 名单逐个归类（原版无效／没翻译／重制已覆盖／到得了未覆盖）：调用方可达（职业、特性、敌人行动、技能树、角色进阶插件、技能替换、状态备注、引擎写死的预约等）＋ Godot 实跑（`battle_ce_run.gd`，整跑＋逐条单跑，经 占槽.py，约 40 秒）＋ 写法覆盖，产物在 `04_验证/战斗公共事件盘点/`。 |
| `greedy.py cov.json 前缀,前缀 [--write]` | 本轮新变体按「新增执行指令」贪心留，其余删（比 `事件祖先预设 --prune` 省）。 |

`tried.json`：event_presets.json 在 git 里全部历史版本出现过的 (页, 预设)，生成时避开（四期 tried.py 的做法）。
一轮：生成 → `补跑事件状态探针.py`（XIYOU_STATE_SHARDS=2）→ `xiyou_event_compare --coverage=…`（外包 占槽.py）→ `事件写法覆盖 --missed` → `greedy.py --write`。
