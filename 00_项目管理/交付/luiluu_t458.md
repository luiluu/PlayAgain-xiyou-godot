# 交付：luiluu/t458

- 车道／工作者：T458 发行出包硬门禁（排除规则不许踢掉空壳／KEEP 脚本＋出包后自动实跑进地图）／cc（Claude Opus 5.5＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-24 【cc·T458·未经审查】发行出包硬门禁：预设排除检查＋出包后实跑 mac 包进地图（dev.待定）

- 依据：Kyo 11-24「开」；起因 T424 dev.887 坏包——三个发行预设的 exclude_filter `modes/xiyou/ui/tianqi/*` 把空壳 tianqi_hall_intro.gd（XTianqiHallIntro）踢出 PCK，一开就 SCRIPT ERROR，冒烟只看退出码报了绿。
- 新工具 `03_再刷重制_Godot/07_开发环境/发行预设排除检查.py`：读 export_presets.cfg 三个发行预设（macOS／Windows／安卓 发行）的 exclude_filter，对「要进包」的文件逐个照 Godot 导出的匹配法比（跟 `res://<路径>` 和 `<路径>` 比、不分大小写、`*` 跨目录、`?` 一个字符、方括号照字面），被排除就退出码 1，逐条列「文件｜预设｜命中规则｜为什么要进包」。要进包的：空壳（发行空壳.targets）、KEEP、所有带 class_name 的 .gd、其余所有非 tests/ 的 .gd（跟 T457 在 测试导出过滤.py 加的护栏同口径）、project.godot 主场景与自动加载、进包脚本／场景里写死的 res://….gd／.tscn／.scn。png、json 等资源被排除不报。`--rev <提交>` 用 git cat-file 把那个提交的脚本、场景、预设解到临时目录再查。
- `03_再刷重制_Godot/07_开发环境/发行出包.py`：
  - 导出前（空壳树开战冒烟之后、真导出之前）对要导出的空壳树跑这项检查，有问题不导包（约 1 秒，省得白导 10 分钟）。
  - 导出、发行内容审计、存档封存检查之后强制实跑：解开 mac 包，新临时 HOME、无头、`--audio-driver Dummy`，① 新开局进地图（按键 `accept,accept,accept,down,accept,wait:120`）；② 用工程（调试版）临时脚本造一份明文旧档 save_1.json（`XSaveSeal.ENABLED=false`，等于玩家封存以前的旧档），放进发行存档目录，从标题「旧的回忆」读进地图（`wait:200,accept×4`）。输出有 SCRIPT ERROR／Parse Error／Failed to load script／Failed loading resource／Cannot open file、退出码非 0、没有 SMOKE_DONE、最后不在地图、读档那次第一下确认就进了地图（等于开了新局，没读档）都判出包失败，冒烟.md 写「出包失败（实跑没过）」和表格。
  - `--no-smoke` 不跳过实跑；只能 `--skip-run "<理由>"` 跳过，理由空白直接退出 1，理由写进 冒烟.md，旧发行目录不删。`--dry-run` 多打一行门禁说明。非 Mac 上实跑判失败并提示用 --skip-run。
- 单测 `03_再刷重制_Godot/07_开发环境/测试发行预设排除检查.py` 20 项：通配命中、目录命中、带 res:// 与 ?、不分大小写、不命中、png 和没人引用的场景命中不报、tests/ 不算、空壳／KEEP／class_name／被引用／普通脚本各自的理由、验收预设和 .options 段不算、缺发行预设报错、命令行退出码 0／1／2、dev.887（ad238e50e）真预设报出 tianqi_hall_intro.gd（本地没这个提交就跳过）；发行出包的实跑判定（五种报错行、没到地图、没 SMOKE_DONE、退出码、读档第一下就进地图）、`--skip-run` 要理由、排除检查拦在导出前、非 Mac 判失败。
- 登记：`03_再刷重制_Godot/07_开发环境/工具回归.py` GATE 加一行；`03_再刷重制_Godot/07_开发环境/检查.sh` tools 组加一行（测试工具回归.py 要求 GATE 每项都在 检查.sh 里，不加就红，见「没做／偏离」）。

## 验收逐条（卡上 5 条＋协调追加 1 条）

1. ✓ 新工具 发行预设排除检查.py：三个发行预设 × 要进包的脚本／场景（本工作树 486 个，含空壳、KEEP、class_name、被引用），被排除退出码 1 并列出文件和规则。
2. ✓ dev.887（ad238e50e）：`python3 发行预设排除检查.py --rev ad238e50e` 退出码 1，报出 `modes/xiyou/ui/tianqi/tianqi_hall_intro.gd｜三个发行预设｜命中 modes/xiyou/ui/tianqi/*｜空壳 XTianqiHallIntro`，只此一个、没别的噪音。T457 版本：`--rev f59b1fb25`、`--rev 612aad17d`（T457 交付提交，文件已挪到 modes/xiyou/ui/）退出码 0（481 个文件）。T457 还没合进 main，合后本分支 rebase 再跑一次本机的（不带 --rev）应为 0。
3. ✓ 单测覆盖通配命中、目录命中、不命中、png 命中不报，共 20 项全过。
4. ✓ 发行出包.py 导出前强制跑排除检查、导出后强制实跑 mac 包新开局进地图＋读旧档进地图，报错行判失败；`--skip-run` 要理由。实测：
   - 端到端 `发行出包.py --out <scratch>` 在本分支（预设还是坏的）：空壳树开战冒烟通过后被排除检查拦下，退出码 1，没导包，约 50 秒（日志 `../归档/交付截图/luiluu_t458/出包_坏预设被拦.log`）。
   - 实跑 dev.887 真坏包（只读解到 scratch）：两项都失败，「47 行脚本错误，第一行：SCRIPT ERROR: Parse Error: Identifier "XTianqiHallIntro" not declared」（`dev887坏包_实跑_*.log`）。
   - 实跑修好预设的 mac 包（scratch 里空壳树去掉那条规则、注入存档封存密钥、带资源加密导出）：两项都过，新开局 6 步进地图、读旧档 9 步进地图，零脚本错误，明文旧档被发行包封存成 .ksv（`修好预设封存包_实跑_*.log`）。每次实跑约 26 秒（两项＋造旧档）。
   - rebase 到 T457 合后的 main（3e86b53df）后，三平台完整出包一轮（`--out <scratch>`）：排除检查 486 个通过 → 三平台导出 → 资源加密、内容审计、封存检查通过 → 实跑两项都过（新开局 6 步进地图；明文旧档读进地图、封存成 .ksv）→ 冒烟 Mac 14/14、Mac x86_64 14/14、Windows 15/15、安卓 14/15。安卓没过的是 apk_layout：本工作树没先编安卓后台挂机插件（要先跑 `云端导出.py android-build`），是环境问题，跟本单无关（冒烟.md 摘要 `../归档/交付截图/luiluu_t458/完整出包_冒烟.md`）。
   - 顺带发现：rebase 后工作树 `.godot` 全局类缓存还指着 T457 挪走前的旧路径，第一次完整出包被空壳树开战冒烟拦下（`Could not find script for class "XTianqiHallIntro"`）；`godot --import` 刷新后就过了。这是本地缓存问题，不是代码问题；说明挪 class_name 文件后要先刷缓存再出包。
5. ✓ 工具回归登记新增「发行预设排除检查」；`python3 工具回归.py` 全部通过（135 秒），`测试工具回归.py` 6/6；交付自检见下。
6. ✓（协调追加，T457 核 P3-1）实跑报错判定加 Failed loading resource、Cannot open file；好包两次实跑日志里这两类 0 行，没误报。

## 返修（小A Neon 核查退回，报告在私密仓 协作交接/核查报告/luiluu_t458.md）

- P1-1 ✓ `03_再刷重制_Godot/07_开发环境/发行出包.py` judge_run：「读档变新开局」防线只看真按键步，跳过 `SMOKE_KEY=wait:` 行（XKeySmoke 对 wait 也打 SMOKE_KEY，读档序列开头 wait:200 让 steps[0] 恒是标题，防线永不触发＝假绿）；一下真键都没按到也判红。单测按 RUN_LOAD_KEYS 的真实输出造样例：开头 `SMOKE_KEY=wait:200 scene=…entry.tscn`、第一下确认就进地图 → 判红；第一下停在读档页 → 判过；只有 wait 行 → 判红。在内存里用修前的 judge_run 跑同一条坏样例得 `(True, …)`，确认旧代码是假绿。用仓里两份真实实跑日志复判：封存包读旧档、新开局仍判过，dev.887 坏包仍判红。
- P2-1 ✓ `03_再刷重制_Godot/07_开发环境/发行预设排除检查.py` extract_rev 的 `git ls-tree` 加 `-c core.quotepath=false`。修前在 `core.quotepath=true` 环境下 `--rev ad238e50e` 报「里没有 export_presets.cfg」，修后照常报出 tianqi_hall_intro.gd；单测 dev.887 那条改在 quotepath=true 环境里跑。
- P3-1 ✓ must_ship 的引用只从已确定要进包的文件（空壳、KEEP、全部非 tests 脚本、project.godot 引用）往外扩（队列），被排除目录里没人用的场景互相引用不再误报；被进包脚本引用到的场景及其下游照报。补单测。本工作树结果不变（481 个，0 命中）。
- P3-2 ① ✓ make_old_save 起 Godot 时用临时 HOME，自动加载的 user:// 不落到真实开发数据目录；实测照样 7 秒造出 save_1.json、0 行脚本错误。
- P3-2 ② 没改（排除检查挪到空壳树开战冒烟之前）：`测试发行出包.py` 里三个现有用例（开战冒烟失败拦导出、加密问题拦导出、密钥格式不对）的假工程没有 export_presets.cfg，挪到前面它们会先撞排除检查而变红；那个测试文件不在本单名单。现在排在开战冒烟后、真导出前，仍是导出前拦，只是晚 40 秒。要挪的话连那三个用例的假工程一起补预设，可另派。
- 核查意见「检查.sh 那一行放行」照办；「挪过 class_name 文件后类缓存过期」改按核查建议记进可优化：只在检出缓存过期时对克隆空壳树 `--import`，不在出包开头无条件对工程 `--import`（本单没做）。

## 测试

- `测试发行预设排除检查.py` 22/22（返修后）；`测试发行出包.py` 33/33（没改它，确认没被我改坏）；`测试工具回归.py` 6/6；`工具回归.py` 全过。
- 云端选测：选测 0 个 Godot 场景（只改了 07_开发环境 工具），照样跑了：rebase 前 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45423716739 ；rebase 后（47e416bf8，基准 3e86b53df）https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45426076942 ，返修后（9ca9bfa4f）https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45429374410 ；都用 `gh run watch` 前台等完，success。
- 没起 Godot 截图（实跑全是无头），没有截图；实跑日志已提交在 `../归档/交付截图/luiluu_t458/`。

## 没做／偏离

- 改了独占名单外的 `检查.sh`（tools 组加一行调新单测）：工具回归.py 的规矩是「GATE 里每一项都必须同时被 检查.sh 的 tools 组调用」，测试工具回归.py 会核，只改 工具回归.py 会红。
- 「出完包后强制跑这项检查」改成导出前跑：查的是要导出的同一棵空壳树，结果一样，早跑省 10 分钟白导。
- 「读一个旧档」：仓里没有玩家旧版本的存档夹具，现做法是每次出包用工程现造一份明文旧档（玩家封存以前的格式），走发行包里明文→封存迁移再读档的路。要换成固定的历史版本存档夹具，得另放一个文件进仓（不在本单独占名单），可另派。
- 发行出包.py 新增部分的单测放在 测试发行预设排除检查.py 里（测试发行出包.py 不在独占名单）。

## 交接板

- 下一步：已 rebase 到 T457 合后的 main，本机 `发行预设排除检查.py` 退出码 0（481 个）；三平台完整出包已在 scratch 全程跑过一轮，门禁串得起来。
- 用户试玩说明：无（只改出包工具，游戏不变）。
- 需要用户决定：无。

## 进度账

- 无（工具链门禁，不动游戏进度）。

## 可优化（流程／工具／效率）

- 建议：T457 在 测试导出过滤.py 里加的「发行预设不许踢空壳／KEEP／非测试脚本」护栏和本工具同口径（本工具是超集：另含被引用的场景、Godot 匹配法）。两边都合后，由小A 或总装把那段改成调 `发行预设排除检查.check()`，只留一套规则（预计省一处维护；归小A 车道，几分钟）。
- 建议（按 T458 核查意见改）：发行出包.py 克隆空壳树后，用 Python 比一下 `.godot/global_script_class_cache.cfg` 和工程里 `.gd` 的 class_name 路径（不到 0.1 秒），只在过期时对克隆的空壳树跑 `godot --headless --import`；不对工程本身 `--import`（会改写工作区的 .uid／.import）。本单没做，归下一单出包工具。
- 建议：实跑现在只跑 Mac 原生架构；Windows／安卓仍靠 发行入口冒烟.py 的替身。要更严可以给 x86_64 切片也跑一次（多约 30 秒）。

## 动了的共用函数和开关

无（没动 `core/`、`battle/`、`skin/`；新增的都是 07_开发环境 的工具函数）。

## 本分支提交

- bf808402c WIP: T458 发行预设排除检查.py 与单测
- 5f92d1f01 WIP: T458 发行出包接排除检查与出包后实跑进地图门禁、--skip-run 要理由
- （见 git log）T458：出包实跑判定加 Failed loading resource／Cannot open file（T457 核 P3-1）
- （见 git log）T458 交付单与实跑日志
- （见 git log）单测门禁豁免、rebase 到 main、补完整出包结果
- （见 git log）T458 返修：读档判定跳过 wait 步、ls-tree 不转义中文、引用只从要进包的文件扩、造旧档用临时 HOME
