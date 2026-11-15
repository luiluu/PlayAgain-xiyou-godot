# 交付：cc/save-integrity

- 车道／工作者：C 规则·存档「存档加密＋校验」（D28，Kyo 11-15）（cc 车道，Orca task_11eb3bcf1931，返修 task_dfcee09d43bf；Opus＋medium：碰存档，甲档，交 co 核）
- 状态：可合并

## 结论（返修后）

- 新 `XSaveSeal`（`modes/xiyou/core/save_seal.gd`）：存档目录里的进度文件写成**加密＋签名**的封存格式，**用新文件名 `<名>.ksv`**；明文旧档 `<名>.json` 留在原处当备份。读到被改过、截断、坏掉的封存文件一律「存档校验失败」：**不读、不覆盖、不删**。重制版、天启篇共用存档入口，两边都生效。
- 老玩家不受影响：某个存档目录第一次被读时，把明文 `.json` 封成同名 `.ksv`（写临时文件 → **读回落盘内容解开、和原文一字不差** → 改名），`.json` 不动；全部成功后放记号 `.sealed_v1`。迁移不成（磁盘满等）那个文件照旧读 `.json`，不当成空档，下个进程再试。
- 补丁退回旧底包时，旧代码只认 `.json`、看不见 `.ksv`，**不会覆盖、删除封存档**（co 核查 P1 的代码层挡法）。剩余风险见「返修」P1。
- 密钥不再进仓库：仓库里只有公开测试密钥（号 0，开发／测试用）；发行密钥放私密设计仓，`发行出包.py` 出包时注入导出副本；发行构建没注入密钥就不封存（照旧明文），也不认测试密钥。
- **只防普通改档工具和手改数字，防不住逆向**（会拆包的人能从发行包里取出密钥）。
- 开关 `XSaveSeal.ENABLED`（O-待定-1，默认开）：关掉＝读写回到 `.json` 明文（比 `.json` 新的 `.ksv` 先解开写回，两种都读得到）。

## 存档格式（封存第 1 版，文件 `<名>.ksv`）

| 偏移 | 内容 |
|---|---|
| 0 | 魔数 `KYSV`（4 字节） |
| 4 | 版本 u8＝1 |
| 5 | 标志 u8（bit0＝先 deflate 压缩） |
| 6 | 密钥号 u8（0＝公开测试密钥，只在开发／测试构建认；发行密钥号 ≥ 1） |
| 7 | 保留 1 字节＝0 |
| 8 | 明文 UTF-8 字节数 u32（小端），上限 `MAX_PLAIN`＝128 MiB |
| 12 | IV 16 字节（每次写随机） |
| 28 | 密文：AES-256-CBC（PKCS#7 补齐），内容是压缩后的存档 JSON（与原来写的 JSON 一字不差） |
| 末尾 32 字节 | HMAC-SHA256，签前面全部字节 |

- 读：文件超过 `MAX_FILE` 不读进来 → 认密钥号 → **先验签名（常数时间比较），没过签名的字节不解密、不解压** → 解密 → 补齐**每个字节**都核 → 声明长度过上限就拒、`decompress` 最多解出声明的长度 → 长度对上。任何一步不对都算校验失败。
- 密钥：每个号由 64 位十六进制种子派生加密钥、签名钥（`sha256(种子|enc|v1)`、`sha256(种子|mac|v1)`）。密钥文件 `{"current": 号, "keys": {"号": 种子}}`：写用 current，读认所有号——以后换密钥加新号、旧号留着读老档。
- 封存管的文件（`XSaveSeal.covered`）：`save_1～30`、`save_auto`、云裳账本 `yunshang_orders_v1`、魔冠账本 `crown_progress_v1`、星级仓库 `star_warehouse`、跨存档变量 `global`（各自 `.json`／`.ksv`）。不封：设置、触屏设置、测试模式文件、瘦身日志、各种备份。

## 玩家看到什么

- **迁移**：看不到。存档文件夹里每个进度文件多一个同名 `.ksv`，原来的 `.json` 留着（是迁移那一刻的备份，之后不再更新），另有 `.sealed_v1`。
- **校验失败**：
  - 读档页：该格列表右边红字「存档校验失败」，信息窗写「存档校验失败」＋「原文件已保留，可通过游戏内反馈问卷导出存档发给我们。」；「读取」弹提示框「存档校验失败，无法读取。／原文件已保留，……」＋「确定」，不读。
  - 标题导出／导入选格：「存档 N：存档校验失败」；导出这一格报「存档校验失败」。
  - 自动存档：标题摘要「自动存档：存档校验失败」，读取弹同样的说明。
  - 云裳、魔冠账本：沿用「记录损坏」的暂停，原因写「……存档校验失败」，功能暂停、不写盘。星级仓库：不读、存取都不做，提示「仓库文件存档校验失败，暂时不能存取。……」。跨存档变量：不读、只在内存里改、不写盘。
- **原文件一直在**：游戏不删、不覆盖校验失败的文件。玩家在这一格存档、删除、**导入**时，原文件先改名成唯一的 `<文件>.failed_<时间>[_n]` 留着（任何自动清理都不碰这个名字）。反馈问卷「导出存档包」把整个存档目录原样打包，`.ksv`、`.json` 备份、`.failed_*` 都在里面。
- 坏档（闪退写一半）和被改的分不开，一样按校验失败处理、一样留原文件。
- 导出改成封存格式（`kyo-remake-save-sealed-v2`），改过的导不进；**旧版明文导出照收，导入时写成封存格式**（Kyo 11-15 D37：老玩家的备份不作废）。

## 返修（co 甲档核查 ec1064160）

| 项 | 怎么改的 | 证据（专项 `xiyou_save_seal`，119/119） |
|---|---|---|
| **P1** 退回旧底包时旧代码覆盖／删除封存档 | 封存档改用新文件名 `.ksv`；所有入口经 `XSaveSeal.resolve(<名>.json)` 换名（`XSave.path`／`auto_path`、云裳／魔冠／仓库／跨存档变量的 `path()`）。旧代码只认 `.json`：它覆盖 `save_N.json`、手动存档时删 `save_auto.json`、往「空格」写 `save_N.json`，都碰不到 `.ksv`。明文 `.json` 留原处当备份。 | `rollback.ksv_untouched`、`rollback.new_reads_ksv`、`rollback.auto_still_there`、`legacy.*.json_kept` |
| P1 剩余风险（写清） | ① 退回旧底包期间：旧代码读的是迁移那一刻的 `.json`（旧进度），封存后的新进度它看不到；玩家在旧版玩出来的进度写在 `.json`，回到新版后**不读**（有记号，分不出是旧版写的还是手改的）。找回（复核后改，见「返修二」）：**先把整个存档目录备份一份，想清楚要哪一条进度**；再删掉 `.sealed_v1` 进游戏，比 `.ksv` 新的 `.json` 会重新封存，被换掉的 `.ksv` 自动先原样留成 `<名>.ksv.replaced_<时间>`（逐字节核对过才替换）；想回到原来那条就把它改回 `<名>.ksv`（`rollback.recover_by_marker`、`rollback.previous_ksv_archived`、`rollback.archive_restorable`）。② 旧版本身没有封存功能，退回期间存档照旧能被改。③ 结论不变：**随兼容整包发**（底包里就有封存读写），不走补丁（D36 协调问 Kyo）。另外，装到**没有注入密钥**的旧底包上的补丁根本不封存（发行构建没密钥＝照旧明文），所以就算误走补丁也不会写出旧代码读不了的东西。 | `keys.release_without_key_no_seal` |
| P2① 导入时坏原件被备份清理删掉 | `import_to` 不管备不备份，先把校验失败的目标改名成唯一 `.failed_<时间>[_n]`（清理只认 `.before_import_` 前缀，碰不到）；导入前备份重名加 `_2`…（同一秒两次导入不再互相覆盖） | `import.failed_original_survives_prune`（校验失败的格连续导入 5 次，原件仍在、字节一致）、`import.backups_pruned_unique`；`xiyou_save_transfer` 原 skipped 的 `import_twice_same_second_keeps_original` 现在通过 |
| P2② 解压无上限 | 文件 > `MAX_FILE` 不读进来（读档、导入都先查大小）；声明明文长度 > `MAX_PLAIN`（128 MiB）拒；`decompress` 按声明长度分配、最多解出这么多 | `crafted.oversize_rejected`（带**合法签名**的超大声明） |
| P2③ 迁移没读回落盘内容 | 所有封存写盘统一走 `XSaveSeal.write_file`：写临时文件 → **读回临时文件逐字节比、解开和原文一字不差** → 改名（存档、自动存档、账本、仓库、跨存档变量、导入、迁移都是它）。迁移不再另建 `.plain_*.bak`（`.json` 原件本身就是备份，不复用旧备份）。迁移写不进：那个文件照旧读 `.json`、不放记号、下个进程再试 | `mfail.falls_back_to_json`、`mfail.no_marker`、`mfail.retry_next_process` |
| P2④ 密钥进公开仓库 | 删掉原来的生产种子；仓库只留公开测试密钥（号 0，注释写明只给开发／测试，发行构建不认）。发行密钥在私密设计仓 `xiyou-design-docs/发行密钥/save_seal_key.json`（不进本仓库，`.gitignore` 了注入路径），`发行出包.py` 导出前复制进导出用的工程副本 `content/save_seal_key.json`、导完删；没密钥就不出包（`--no-save-key` 明知故出不封存的包）。新工具 `07_开发环境/存档密钥.py`（`--init` 生成、`--rotate` 加新号、`--check`）。原种子已在公开仓库历史里，作废不用。 | `keys.release_without_key_no_seal`、`keys.release_rejects_test_key`、`keys.release_with_key_seals`（号 3 写、号 2 读）、`keys.other_key_not_accepted`、`keys.dev_test_key_back` |
| D37（Kyo 11-15）旧明文导出要收 | `ACCEPT_PLAIN_IMPORT` 默认改成 true：旧版 `kyo-remake-save-json-v1` 导出、直接一份明文存档都照收，`import_to` 经 `write_file` 写成 `.ksv` 封存；关掉开关回到拒收 | `xfer.plain_accepted_d37`、`xfer.plain_import_sealed`、`xfer.plain_refused_when_off`；`xiyou_platform` `transfer_bare_save_ok` |
| P3 补齐只验末字节 | 每个补齐字节都核；HMAC 在解密之前（文件头注释写明） | `crafted.padding_all_bytes`（带合法签名、末字节对前面不对） |

- 反向验证（手工，改完用备份字节还原）：去掉补齐逐字节核 → `crafted.padding_all_bytes` 挂；去掉长度上限 → `crafted.oversize_rejected` 挂；去掉导入前改名 → `import.failed_original_survives_prune` 挂。
- 顺带：迁移失败时 `.ksv` 不存在会被当成「空档／空账本」再写新的（返修中发现）——改成回落读 `.json`。

### 返修二（小o 甲档复核 f6c615433 的两项 P2＋P3）

| 项 | 怎么改的 | 证据 |
|---|---|---|
| P2-1 出包接受运行时不认的密钥（如 current=256、空种子）还报「已注入」，包实际写明文 | 格式规则两边统一：`存档密钥.py check` 与运行时 `XSaveSeal.key_file_problem` 逐条一致（号是 1～255 的十进制、不带前导 0；种子是 64 位小写十六进制；current 是 1～255 的整数且在 keys 里；有一条不符整份不认）。运行时 `_load_keys` 改成整份校验（原来是跳过坏项）。`发行出包.py inject_save_key` 注入前调 `check`、写进副本后读回逐字节比；`verify_save_key` 导完在 mac zip 的 .pck、Windows .pck、apk 里读回密钥字节。任一不符：返回问题、`main` 打 ✗ 退出 1、不出包，不再打印「已注入」。两边共用样例 `tests/fixtures/save_key_cases.json`（21 例，含 current=256、空种子、短种子、大写、号 0、前导 0、一好一坏、current 是字符串／小数等） | Python `测试发行出包.py SaveKeyTests`（7 个：样例与运行时规则一致、注入拒 current=256 与空种子且不写文件、合格时读回、`--no-save-key`、`export_all` 在导出前就停、产物读回（缺了报两处）、`--init`／`--rotate` 产物过检查）；GDScript `keys.cases_rules`、`keys.cases_runtime_load`（同一批样例在发行模拟下逐个装载，`active_now` 与样例结论一致）。反向：把运行时上限放到 9999，两条都挂 |
| P2-2 照说明删 `.sealed_v1` 找回会无备份覆盖有效 `.ksv` | 迁移要替换已有的 `.ksv` 前先 `archive_before_replace`：原样复制成唯一的 `<名>.ksv.replaced_<时间>[_n]`，读回逐字节核对过才替换，复制不成就不替换（这个名字不归封存管、不被任何自动清理删）。开关关着把较新的 `.ksv` 解开写回 `.json` 时，被换掉的 `.json` 同样留底。交付单与 `save_seal.gd` 文件头的找回说明改成「先备份整个目录、选定要哪条，删记号后被换掉的 `.ksv` 在 `.replaced_` 里，改回名就回到原来那条」 | `rollback.previous_ksv_archived`（留底字节＝原 `.ksv`）、`rollback.archive_restorable`（改回名读到原进度 4321）、`rollback.unchanged_not_archived`（没被换的不留底）、`plainmode.json_archived`、`plainmode.reads_newer`。反向：让留底直接返回成功不复制，三条挂 |
| P3 记号写盘没读回 | `_put_marker` 写临时文件后读回逐字节比、解得开才改名 | 代码审阅（失败难造，没加断言） |

- 还没做的（复核建议的「更好的后续方案」）：检测 `.json` 在封存后被旧版更新、提示玩家有另一条进度并给受控选择。本轮只保证人工找回不丢任何一份；按 D36 整包发行范围，旧底包退回本来就少见。
- 云端（返修二＋合 main，提交 8d2450c1f，合了 main 的文字审一批所以选测成整轮 635 个）：15 个失败。其中 13 个与 **main 本身同一轮云端（cdf35cb92，整轮 634 个）失败的 13 个完全相同**（text_fix_dump、text_fix_shots、common_scripts、dungeon、enemy_book、equipment、gear_search、inlay_book、input_handled、pet_capture、rift2_canglong、troop_events_d、troop_events_half，都是文字审改字与参照对不上等，main 的事，本分支没碰）。本分支自己的 2 个：
  - `xiyou_save_transfer`：合 main 后的语义冲突——main 的文字审给 `export_text` 加了 `tianqi` 标记、专项要求天启篇导出外层格式＝明文 v1；本分支封存导出走另一分支没带标记。已修：封存导出也带 `tianqi`，专项改认 `FORMAT_SEALED`。本机 47/47（另 `xiyou_save_seal` 127/127、`xiyou_platform` 155/155）。修后没再上云（再上又是整轮 196 分钟额度，且 13 个 main 的失败照旧挂）。
  - `xiyou_step_encounter_stop`：本分支首跑与重跑都挂 `rollback_stale_target_walks`，同时带三条 `stop_fade` 已释放对象的 SCRIPT ERROR；main 同一轮这项过了。本机加临时打点实测整个专项里本分支代码只在开头跑过一次（一次迁移、一次自动存档检查点、`resolve` 不到 200 次），挂的那一段（停挂机后该不该接着走）期间没有任何存档读写。**仍判不出因果**：证据倾向无关（代码在那段不运行），但它在本分支云端挂得比 main 多，不能说已排除。请小o／总装留意。
- 步步遇敌：小o 在 main 58b657d90 上独立跑同专项，断言 7/7（`rollback_stale_target_walks` 也过），但有三条 `stop_fade` 收到已释放对象的 SCRIPT ERROR、工具判失败——**和本分支挂的不是同一种失败**，不能证明原断言是 main 已有偶发；原断言与本改动的关系仍是「没证实有关、也没证实无关」。

### 总装出包要做的（第一次）

1. 在私密设计仓生成发行密钥：`python3 03_再刷重制_Godot/07_开发环境/存档密钥.py --init`（默认写 `~/Documents/xiyou-design-docs/发行密钥/save_seal_key.json`，或 `XIYOU_SAVE_KEY=<路径>`），在设计仓提交它。**不要拷进游戏仓库。**
2. 可先 `python3 存档密钥.py --check` 查格式。出包照旧 `python3 发行出包.py`：注入前按游戏运行时的要求逐条查（号 1～255、64 位小写十六进制种子、current 在 keys 里），写进导出副本后读回比对，打印「存档密钥：已注入（号 1，不进仓库）」；**导完在三个产物（mac zip 里的 .pck、Windows .pck、apk）里读回密钥**，任一处读不到就报错不出包。缺密钥、格式不对也报错不出包。
3. 发行后**不要删旧号**（删了玩家用旧号封存的档就读不了）；要换密钥用 `--rotate`。
4. 走补丁（`发布补丁.py`）时不带密钥：装在没有密钥的旧底包上＝不封存（照旧明文）。所以封存要随整包生效。

## 逐条对应派单

| 要求 | 做了什么 | 证据（专项 `xiyou_save_seal`） |
|---|---|---|
| 接在存档统一入口；rg 所有读写路径 | 路径 `XSaveSeal.resolve`；写盘 `XSaveSeal.write_file`；读 `XSaveSeal.read`（存档页、导出导入、仓库取出事务查 whToken、瘦身记号检测都走解码读）。生产代码里直接读写这几类文件的只剩 `XSaveSeal` 自己 | `legacy.*`、`ledger.*` |
| 加密＋签名、新格式带版本号 | 见上「存档格式」 | `codec.*`、`crafted.*` |
| 旧格式先备份再迁移 | `.json` 原件留原处当备份；`.ksv` 读回核对后才落位 | `legacy.*`、`mfail.*` |
| 校验失败不读、不覆盖、不删；列表显示；读档弹提示 | 见「玩家看到什么」 | `tamper.*`、`trunc.*`、`empty.failed`、`plain_in_ksv.failed`、`auto.*`、`import.*` |
| 反馈问卷 zip 带加密存档原样 | 导出逻辑整目录原样打包，没改 | `feedback.*` |
| 开关＋O 号可回退 | `ENABLED=false`：读写 `.json` 明文，`.ksv` 解开写回、去掉记号；再打开重新迁移 | `off.*`、`on_again.*` |
| 测试不碰真实存档和设置 | 全部临时目录；密钥文件也走 `key_file_override` | — |

## 变更记录草稿

## 2026-11-15 【cc·存档封存·未经审查】存档加密＋签名，改过的存档认得出（D28）（dev.待定）

- Kyo 11-15 D28：不允许玩家修改存档。新 `XSaveSeal`：存档、自动存档、云裳／魔冠账本、星级仓库、跨存档变量写成加密＋签名格式（AES-256-CBC＋HMAC-SHA256，先压缩，带版本号和密钥号），文件名改成 `.ksv`；只防普通改档工具和手改数字，防不住逆向。
- 老存档第一次被读时自动封存成 `.ksv`（读回核对后才落位），原 `.json` 留原处当备份，老玩家不受影响；旧版本代码只认 `.json`，退回旧版时碰不到封存档。
- 校验失败（被改、截断、坏档）：不读、不覆盖、不删；读档页标红「存档校验失败」、读取弹提示（原文件已保留，可通过游戏内反馈问卷导出存档发给我们）；在这一格存档／删除／导入时原文件改名 `.failed_<时间>` 留着。账本、仓库、跨存档变量校验失败就暂停、不写盘。
- 导出改成封存格式，改过的导不进；旧版明文导出照收、导入时自动封存（D37）。
- 发行密钥不进仓库：出包时由 `发行出包.py` 从私密设计仓注入（新工具 `存档密钥.py`）；发行构建没密钥就不封存，开发／测试用公开测试密钥。
- 回退：`XSaveSeal.ENABLED = false`（读写 `.json` 明文，封存档解开写回）。
- 玩家可见：存档文件不能再用改档工具修改；改过的存档在读档页显示「存档校验失败」并保留原文件。
- 验证：专项 `xiyou_save_seal`（新，119/119）、存档相关旧专项本机通过（测试夹具改走 `XSaveSeal` 读写、`.ksv` 文件名）；co 甲档核查返修见交付单；云端选测见交付单。
- 提交：（合并时填）

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
|---|---|---|---|---|---|---|---|
| O-待定-1 | `modes/xiyou/core/save_seal.gd` `XSaveSeal.ENABLED`、`resolve`、`write_file`；`xsave.gd`、`star_warehouse.gd`、`xglobal_vars.gd`、`yunshang_orders.gd`、`demon_crown.gd` 的路径与写盘 | 存档、账本是明文 JSON，谁都能改 | 加密＋签名写成 `.ksv`，改过的认得出，旧档第一次读时迁移、`.json` 留作备份 | Kyo 11-15 D28 | `XSaveSeal.ENABLED = false`（读写 `.json` 明文，`.ksv` 解开写回） | cc | 保留 |
| O-待定-2 | `save_seal.gd` `XSaveSeal.STRICT_AFTER_MIGRATE`、`ensure_dir` | （新功能）| 目录迁移完（有 `.sealed_v1`）后不再读 `.json` | 不然改 `.json`、删 `.ksv` 就绕过 | `XSaveSeal.STRICT_AFTER_MIGRATE = false`（每次进目录都把比 `.ksv` 新的 `.json` 重新封存） | cc | 保留 |
| O-待定-3 | `save_transfer.gd` `XSaveTransfer.ACCEPT_PLAIN_IMPORT`、`parse_import`、`export_text` | 导出导入是明文 JSON | 封存开着时导出封存格式（改过的导不进）；旧版明文导出照收、导入时写成封存格式（D37） | D28＋D37（老玩家备份不作废） | `XSaveTransfer.ACCEPT_PLAIN_IMPORT = false`（封存开着时不收没签名的导出） | cc | 保留 |

## 交接板

- 下一步：小o 复核返修二；出包前总装按「总装出包要做的」生成发行密钥。
- 用户试玩说明：读档照常；存档文件夹里每个进度文件多一个 `.ksv`（新存档）和 `.sealed_v1`，原 `.json` 留作备份。改过的 `.ksv` 读档页显示「存档校验失败」。
- 需要用户决定：无。Kyo 11-15 已定：**D36** 重制版存档加密等下次整包上（不走补丁；补丁装在没有密钥的旧底包上本来也不封存）；**D37** 旧明文存档导出要收，导入时自动加密一次（已做，代价：改过的明文导出也能这样导进来——封存只管住游戏自己写的文件）。

## 进度账

- 重制版平台与存档：存档防改（D28）完成（待 co 复核）。

## 可优化（流程／工具／效率）

- 建议：守卫检查加一条 rg，禁止测试和游戏代码直接 `FileAccess.get_file_as_string(XSave.path(…))`／写 `save_*.json`（预计收益：防新代码绕过封存或一上来就崩在解析封存字节；归工具车道）。
- 建议：`xiyou_step_encounter_stop` 的 `rollback_stale_target_walks` 偶发（见「验证」，main 版本本机 16 次没挂过，原来「main 上也挂」的说法撤回）；归步步遇敌车道把等待改成确定性。
- 已做：存档相关测试夹具改走 `XSaveSeal.read_text`／`write_file`、`.ksv` 文件名。

## 验证

- 专项 `xiyou_save_seal` 127/127（新；返修二后）：编码往返；改任一段一字节／截断／追加／空；带合法签名的超大声明、坏补齐；明文旧档迁移（七个文件 `.ksv` 解开＝原文、`.json` 原件不动、记号）；旧底包退回模拟；新档往返、改字节、截断、明文写进 `.ksv`、迁移后丢进来的 `.json`、存到失败格改名留着、删除改名；自动存档；多槽；账本、仓库、跨存档变量改过不读不写；开关关闭／再打开；导出导入；导入保留失败原件；反馈 zip 原样；发行模拟冷启动读旧档；迁移写不进回落 `.json`；发行密钥（无密钥不封存、不认测试密钥、号轮换、21 例格式样例与出包工具一致）；找回时被换掉的 `.ksv`／`.json` 先留底。
- 本机直跑（`test_main_loop`，本机测试槽被别的车道占着）：save_corrupt 53/53、save_cat_slots 15/15、save_slim 126/126、save_page 42/42、save_events 31/31、save_transfer 39/39（原 skipped 一项现在通过）、star_warehouse 99/99、global_vars 17/17、demon_crown 106/106、demon_crown_compact 48/48、autosave 10/10、pause_save 46/46、save_cold_load 27/27、splash_autosave 74/74、feedback_v001 32/32、yunshang_shop 436/436、yunshang_gear_load 137/137、platform 155/155、percent_pills 65/65、review_regressions 29/29、random_streams 490/490、floor30_gifts 30/30、tianqi_affix_seed 23/23、tianqi_opening 44/44、tianqi_seed_fix 77/77、lottery_seed 12/12、tianqi_save 82/82、battleback_save 5/5、newgame_back 68/68、entry_release 16/16。
- 工具快速回归全部通过（98 秒）；语法检查通过。
- 云端选测（返修＋D37 后，提交 7bd3bb794，基准 main fa0562032，254 个场景）：**全部通过**。
- `xiyou_step_encounter_stop`：返修中途那次云端（dc6b231d1）又挂了 `rollback_stale_target_walks`，本机前后几轮里本分支也挂过几次，main 版本没挂过（16/16）；最后一轮本机交替跑 main 版本与本分支版本各 8 次全过，最终云端也过。失败那一段（挂机前留下目的地、停挂机后该接着走）不经过任何存档读写（挂机存档要整点＋固定档位，测试新局都没有），封存每次存档只多约 0.4 毫秒，`XSave.path` 每次约 40 微秒。**结论：没证实和本改动有关，也没证实无关**，看着是负载相关的偶发；请 co 复核时留意，总装合并时它若再挂就单跑重试并把日志附上。
- 真发行包实机冷启动、Windows／安卓文件替换、真磁盘满／断电没做（要出包或实机）。
- 合并建议：`合并车道.sh … --finish --affected --cloud`。

## 待交叉核查

- co 甲档复核：`save_seal.gd`（重写）、`xsave.gd`、`save_transfer.gd`、`star_warehouse.gd`、`xglobal_vars.gd`、`yunshang_orders.gd`、`demon_crown.gd`、`save_slim.gd`、`ui/save_scene.gd`、`entry.gd`、`07_开发环境/发行出包.py`、`07_开发环境/存档密钥.py`（新）、`.gitignore`；测试夹具改动。

## 本分支提交

- 6b696d2a6 存档封存 XSaveSeal 接入
- 81d3f31d2 专项 xiyou_save_seal；旧存档专项改走 XSaveSeal 读写
- abe3b2397 交付单
- 返修：封存档改 .ksv、发行密钥出包注入、上限、读回核对、补齐逐字节、导入保留失败原件；测试改 .ksv；迁移失败回落 .json；D37 旧明文导出照收、导入时封存（7bd3bb794 云端 254 个全过）

## co 甲档核查

- 核查者：co（派单 gpt-6.1-sol＋medium），2026-11-15；对象 abe3b2397（主体 6b696d2a6、81d3f31d2）。**结论：不通过，需返工后复核；没有改游戏代码。** 专项通过不代表下面边界已满足。

### 发现与分级

1. **P1（补丁发行阻断）：退回旧底包会失去读档能力，且旧代码能够真正覆盖／删除封存原件。** 代码审阅：主体父提交的 `xsave.gd` 按 JSON 解析，全部封存手动档／自动档均无法读；旧 `_write` 直接 rename 替换目标，`remove` 直接删，手动保存还会 `remove_auto` 无条件删除自动档。旧 global／仓库也不认识封存格式。迁移备份只覆盖迁移时刻，不包含此后玩家的新进度，所以不能称“文件不丢，只需人工找回”。**建议只随整包发行，且底包本身含封存读写保护；若一定走补丁，先发布兼容底包／阻止退回不兼容版本并完成回退实测。** 本项是旧代码审阅推导，未安装真实旧包。
2. **P2：导入会绕过失败原件的永久保留。** `save_transfer.gd:135–144` 默认 BACKUP_BEFORE_IMPORT=true，只复制成 `.before_import_*` 后覆盖目标；随后 `prune_import_backups` 会删旧备份，同秒还存在同名覆盖问题（现有专项明确 skipped `import_twice_same_second_keeps_original`）。**临时目录实测**：坏封存原件导入时复制字节相同，但补足后续导入备份并调用真实 prune 后，该坏原件备份已被删除（`initial_bad_preserved=true bad_survives_prune=false`）。应在所有导入模式下先把失败目标移到唯一 `.failed_*`，排除自动清理，普通导入备份另行处理。
3. **P2：解压没有硬上限。** `save_seal.gd:125–137` 验 MAC 后直接把 u32 plain_len 交给 decompress，没有最大明文／密文／导入文件大小限制。篡改长度而不重签会先被 MAC 拦住，这点正确；但源码密钥公开时可构造有效 MAC 的超大声明或压缩炸弹，使读档／导入内存耗尽。建议在分配／解压前限制长度并对导入文件限制大小，增加有效 MAC 的越界专项。只看代码，没有实际分配巨量内存。
4. **P2：迁移落盘验证弱于交付承诺。** `_migrate` 先对内存 sealed 解开核对，再 `_put` 写盘；`_put` 只检查 flush 错误和长度，未读回临时封存字节解密比对，因而不是“写盘后解开核对无误才替换”。备份首次创建确有逐字节核对，但同秒已存在的备份直接复用不核对。建议对实际临时文件 unseal 与原文字节核对，并用唯一备份名／复用前逐字节确认。未做介质故障注入。
5. **P2（项目边界）：公开源码包含生产密钥种子，与《天启篇三方协作》第一节“公开游戏仓绝不放……任何密钥”冲突。** 不赞成“等仓库转私有前再做”；应发行前私密注入并从公开源码移除真实种子，明确目前种子已暴露，首发前选定最终版本化密钥。编进客户端仍只能防普通改档，不能提供服务端权威保证；发布后不要简单改 SECRET 作废玩家档，需保留旧版本读取／迁移策略。本报告不复制种子。

### 已核路径（代码审阅）

- 迁移按文件备份→临时文件→同目录 rename；半途退出时已替换文件仍可解，未替换仍是明文，没有记号时可混合读；下进程跳过已封存文件继续迁移。磁盘满在 backup／temp／marker 的写入错误处不替换旧文件；部分失败本进程 `_tried` 阻止重扫，下一进程才重试。未做真实断电／磁盘满实测，flush 并不等于完整断电持久化承诺。
- STRICT_AFTER_MIGRATE 确实拒绝一切晚到的明文（包括合法旧版本写入、回滚补丁、手工恢复的旧备份），不是仅识别“作弊”。当前工程搜索覆盖的生产入口都接入封存，未找到仍明文写这几类进度文件的模块；未来或旧模块仍有此兼容性风险。ENABLED=false 写入会清 marker，旧底包不会做这一步。
- HMAC 在 AES 解密前，使用 constant_time_compare；IV 每次 Crypto 随机生成，长度字段包含在 MAC 中。PKCS#7 只检查末字节，未检查全部 padding 字节（P3 防御完善项；有 MAC 前提下普通篡改已拦）。
- 全工程 rg FileAccess.open／store_buffer／store_string 并排除测试，逐项看生产写入口：进度写盘集中于 xsave、save_seal、star_warehouse、xglobal_vars；云裳／魔冠经 write_text_safely 再检查原文件。其它写入是 options／触屏设置、更新状态和补丁解包、测试模式、XDB 缓存、导出文件，不属于所列进度。账本校验失败拒写，仓库与 global 初读失败后暂停写；手动档／自动档删除和重存走 quarantine。未对“读入内存后外部再改磁盘”的并发情况作保证。
- 导入拒明文提示明确“请用当前版本重新导出”；这意味着仅持有旧导出文件的玩家不能直接迁移，需受控恢复路径。反馈 zip 在封存专项实际验证原样字节。测试 XSave.dir_override、账本 path_override 随临时目录；没有修改真实存档或 options。

### 实测与未核到

- 本轮用并行测试工具串行抽跑四项（退出 0，25 秒）：`xiyou_save_seal` **97/97**、`xiyou_save_corrupt` **53/53**、`xiyou_save_transfer` **38/38**（另有上述 skipped 项）、`xiyou_global_vars` **17/17**。日志：`03_再刷重制_Godot/04_验证/本地结果/并行测试/20261115_184256_bzwuzrat/`。
- 额外坏档导入／备份裁剪实验在临时目录完成并清理；最初使用 SceneTree 脚本因 GameApp 自动加载编译不可见而失败，改成临时 Node 场景后成功复现，不涉及游戏源码修改。
- `xiyou_step_encounter_stop` 与 main 的测试代码没有差异，但**本轮没有在 main 独立重跑**，也没重跑云端 416 项；所以“main 上也挂、已有偶发”仅为执行方记录，不能当成本轮已证实结论。建议总装取 main 隔离复跑及原失败日志再销账。
- 未核到：真实整包启动／补丁回退、Windows／安卓文件替换行为、真实磁盘满／断电、全部专项与 oracle；本轮是只读代码甲审加四个专项及一个临时复现，不能把这些边界记为通过。P1/P2 修复后需重点复核。

## 小o 甲档复核

- 复核者：co（派单 gpt-6.1-sol＋medium），2026-11-15；对象 **885e875d8** 及其返修提交、D37。**结论：不通过，剩余两项 P2；原 P1 已关闭，无新增 P1，原 P3 已关闭。** 本轮仅改本交付单，没有改游戏代码。

### 逐项销账与剩余问题

- **原 P1（旧底包覆盖／删除封存档）：关闭。** 代码审阅旧代码固定读取／保存／删除 `.json`，新版统一 resolve 到 `.ksv`，两者隔离；封存专项实测旧代码行为模拟覆盖手动 `.json`、删除自动 `.json` 后 `.ksv` 可继续读。不是安装真实底包的端到端回退实测。D36 已决定随整包发行，本轮接受此发行范围；仍不建议部署到不带密钥的旧底包补丁。
- **原 P2①（失败原件被导入备份裁剪）：关闭。** import_to 在任何备份开关前先 quarantine_if_failed，唯一 `.failed_*` 不匹配导入备份清理；普通导入备份 unique_name 加序号。实测 seal 120/120 覆盖失败原件导入保护，transfer 39/39，原来的同秒 skipped 项现已实际执行通过。
- **原 P2②（解压炸弹）：关闭。** 文件读取前 MAX_FILE、验 MAC 后解密前 MAX_PLAIN=128 MiB、decompress 的输出缓冲有界，超长声明的有效签名测试通过；导入读文件也限制大小。并未实测在低内存安卓上同时分配多份 128 MiB 缓冲的峰值，128 MiB 是上限而非内存占用承诺。
- **原 P2③（写盘未读回验证）：关闭。** write_file 的 `_verify` 实际读回临时文件，与预期 bytes 比较，再 unseal 对照原文，通过后才 rename；xsave／账本／仓库／global 已走该入口。迁移失败且没有 `.ksv` 时 resolve 回落原 `.json`，原件不被替换。marker 自身 `_put_marker` 仍是 flush 后 rename、没有 `_verify`，但 marker 损坏会导致下次重试迁移，不把它当作进度文件验证通过，记为 P3 完善项。
- **原 P2④（公开发行种子）：主体已修，出包守卫仍有 P2，见下。** HEAD 的 gd／py／json 中精确检索旧种子已不存在，旧号 0 派生密钥已换成明确公开测试串，发行模拟不装载号 0；注入文件路径被 gitignore，git ls-files 未见发行密钥文件。未读取私密真实密钥，也不声称清除了 Git 历史中的旧种子。旧封存格式从未面向玩家发行是本次淘汰的前提；已有内部测试档不能当作正式玩家档直接读。
- **原 P3（PKCS#7 只验最后一字节）：关闭。** 现逐字节核对所有 padding，专项包含有效签名的坏补齐。
- **D37：按用户决定接受。** ACCEPT_PLAIN_IMPORT 默认 true，旧明文导出按原格式校验后导入写 `.ksv`；因此用户可编辑旧明文后导入，这是已知授权取舍，不再作为本轮防改阻断。

### 剩余 P2（返工后复核）

1. **发行密钥校验与运行时不一致，可无报错导出一个实际上不封存的包。** `发行出包.py:245` 只要求 current≥1、keys 有对应项，没有验证 current≤255、种子是足够长度的字符串等；运行时 `_load_keys` 则拒绝号>255或长度<32。本轮临时目录实测：缺文件正常被拒绝；但 `{current:256, keys:{"256":"x"}}` 被 inject_save_key 返回成功并打印“已注入”，同一配置在 simulate_template 下 active_now=false，游戏回到明文。即使 current=1，空串也能穿过工具的注入检查。`存档密钥.py --check` 的约束更严，但出包未调用。**修复建议：共享严格格式验证（1..255、完整字符串种子格式、current 必须可加载），出包前调用；增加发行模式加载注入副本后 active_now=true 的守卫。** --no-save-key 是明确的手动回退开关，可保留；不能把无效密钥误报为正常注入。此项测试只调用真实 inject 函数与运行时模拟，没有实际导出三个发行包。
2. **恢复分叉进度的推荐流程会永久覆盖另一条有效进度，缺少恢复前快照。** marker 存在时新版优先 `.ksv`，旧底包后来写的 `.json` 完整保留但不读、不提示；所以严格讲是“回退期间进度被静默忽略”，不是两个版本自动接续。本轮临时目录复现：新版进度 `.ksv`、随后旧版进度 `.json` 并存，有 marker 时读新版；按交付单删除 marker 后，比 `.ksv` 新的 `.json` 直接覆盖有效 `.ksv`，目录内没有此前封存字节的副本（`marker_recovery_overwrote_ksv=true previous_ksv_archived=false`）。**修复建议：迁移需替换已有有效 `.ksv` 时，先保存唯一、经核对的恢复备份；并把“先备份整个目录、明确选择哪条时间线”写入恢复说明。** 更好的后续方案是检测 `.json` 在封存后被更新，提示存在另一条进度并提供受控恢复选择，不能只按 mtime 自动决定。D36 整包范围下无需把所有分叉自动合并，但不能让推荐找回流程无备份地抹掉另一份玩家进度。

### 本轮实测、步步遇敌与未核范围

- 专项工具串行抽跑：`xiyou_save_seal` **120/120**、`xiyou_save_transfer` **39/39**（skipped=[]），退出 0、14 秒；日志 `03_再刷重制_Godot/04_验证/本地结果/并行测试/20261115_200650_alt3f92e/`。确认实际是 120 而非交付单验证栏遗留的 119。
- `xiyou_step_encounter_stop` 本分支 **7/7**、工具退出 0（64 秒），日志 `03_再刷重制_Godot/04_验证/本地结果/并行测试/20261115_200713_puk2j8ex/`。独立在 main 工作区 **58b657d90** 跑同专项，断言 **7/7**（rollback_stale_target_walks 也 PASS），但出现三条 `stop_fade` 传入 previously freed 对象的 SCRIPT ERROR，工具判失败（退出 1，54 秒），日志 `/tmp/co_seal_main_step/xiyou_step_encounter_stop.log`。这是**不同失败类型**，不能拿它证明原 rollback_stale_target_walks 断言是 main 已有偶发；当前对原断言与本改动的因果关系仍无法判定，保留执行方“未证实有关／无关”的修订结论。无存档读写的局部路径支持相关性较低的推断，但不是排除时序影响的证据。
- 临时 Python／Godot 实验仅使用自建临时目录，生成的测试数据已清理，不碰真实存档／options／私密发行密钥；公开仓没有此次注入实验产物。未重跑云端 254 项，未实际出包检查 PCK 内密钥、未做真实旧底包回退、Windows／安卓、磁盘满／断电或历史 Git 秘密清理。以上未核项不能标通过；两项剩余 P2 修后只需针对性复核。

## 小o 甲档复核二

- 复核者 co（派单 gpt-6.1-sol＋medium），2026-11-15；对象 **df0e71aba**（返修主体 b5c17de81，合并 main 后导出修复 df0e71aba）。**结论：本次存档甲档通过，上轮两项 P2 与 marker P3 关闭，无剩余存档 P1／P2／P3 阻断。** 步步遇敌另定位到 main 本身可复现的 P2 测试计数时序缺陷，需工具／专项车道修，不能把当前整轮 CI 称为全绿。本轮未改游戏代码，只追加本节。

### 两项 P2 与 P3 复核

- **P2-1 关闭（代码＋实测）**：inject_save_key 注入前调用存档密钥.py check；current=256、空种子两个旧复现配置本轮均被真实 inject 函数拒绝，目标文件均未生成。Python SaveKeyTests **7/7**，包含无效配置拒绝、导出前停止、有效配置读回、三类模拟产物漏密钥检测；运行时在 seal 专项共享样例中逐个加载验证。代码审阅确认导出前读回副本逐字节核对，导出后 verify_save_key 检查 Mac zip 的 pck、Windows pck、apk，问题沿 export_all 返回并使出包失败。包后验证是查找注入原始字节，不是实际启动包读取资源；本轮未实际出三个包，产物内检查实测来自工具的模拟产物测试。
- **P2-2 关闭（代码＋实测）**：迁移替换现有 `.ksv` 前 archive_before_replace 复制到唯一 `.replaced_*`，读回 bytes 相等才 rename 成备份，备份失败阻止覆盖；回退明文 `.json` 同样留底，备份不匹配封存／导入清理。重跑上轮同一个临时恢复探针：有 marker 仍优先 `.ksv`；删 marker 恢复较新 `.json` 后，**previous_ksv_archived 从 false 变成 true**，旧有效封存字节在目录内可找到。seal 专项的 previous_ksv_archived／archive_restorable／plainmode.json_archived 等也通过。跨版本分叉仍不自动接续，但 D36 整包与人工恢复范围内，两条进度均可保留，已满足本轮修复要求。
- **P3 关闭（代码审阅）**：_put_marker 写临时文件后读回与预期字节相等，并确认预期字节 unseal 成功后才 rename；因读回字节已相同，等价于解开读回文件。未做介质错误注入。
- 本轮专项实测（工具退出 0，77 秒）：**xiyou_save_seal 127/127、xiyou_save_transfer 47/47（skipped=[]）、xiyou_step_encounter_stop 7/7**；日志 `03_再刷重制_Godot/04_验证/本地结果/并行测试/20261115_205203_e1vpc__q/`。导出合 main 修复正确：封存分支返回值增加外侧 `tianqi` 元信息，不改封存内容；普通／天启篇命名、封存往返、旧明文导入加载等 47 项通过，未发现需再次全量云端验证的专属差异。

### 步步遇敌：已定位独立于存档的测试时序缺陷

- 读取云端 run **43751580029**（8d2450c1f）失败日志，确认为 rollback_stale_target_walks，walking／started／stopped 都 true，但 battles_after=0、from=now、touch_target=(-1,-1)，6/7；不是把此前的 stop_fade 错误混为同一失败。原始日志摘取在 `/tmp/co_seal_cloud_failed.log`。
- main 基准 **cdf35cb92** 与本分支的原始专项和 map／移动实现无差异。临时复制原测试到 `/tmp`，仅增加 before_stop、after_stop、baseline 打点，在 main 与本分支各跑完整原逻辑，两边均 **7/7**（日志 `/tmp/co_step_main_diag.log`、`/tmp/co_step_branch_diag.log`）。本轮不能复述“本分支稳定挂”，但云端首跑／重跑失败事实保留。
- **根因证据**：测试在设置旧目的地后 `await tap(button_at())`，tap 按下／松开间会等待数个 process_frame，期间游戏继续跑物理帧；测试却在 tap 完成、重新打开 yd100、再等移动完成**之后**才采集 b0／g0。旧目的地可在采集前已经走完并清空，采集后自然没走、没新战斗，导致“旧坏表现没有出现”的假阴性。它实际测的是“采样后还走没走”，漏掉了“点击停挂机期间已经继续走”。
- **main 独立复现相同断言，不含任何存档分支代码**：使用完整原测试临时副本，唯一调度调整是在回退开关臂设 Engine.max_fps=15（模拟低渲染帧率下多物理帧批次），main 得到 **6/7，rollback_stale_target_walks FAIL**，日志 `/tmp/co_step_main_slow.log`。打点为 before_stop grid=(15,16)、target=(14,16)，after_stop grid=(13,15)、target=(-1,-1)，baseline 已在(13,15)，最终 from=now、battles_after=0——**人物确实在 tap 等待期走了，断言漏记**。再用同一 stale_target_hangup 函数的缩小探针在 main 连跑三次，**3/3 同型假阴性**，其中一次 (17,12)→(17,11) 已走回旧目标，baseline 后仍被判没有走；日志 `/tmp/co_step_main_probe.log`。这些是临时测试副本／调度实验，不修改仓库测试或生产逻辑。
- **判断**：已有实测证明该断言失败无需本分支即可触发，归为 **P2：原专项采样时机依赖渲染／物理帧调度**，不是存档功能回归；封存初始化增加的耗时可以改变运行调度和触发概率，不等于封存破坏移动行为。不能声称逐帧证明了那一轮云端的唯一原因，但云端同型失败已有 main 可复现机制，足以撤销“本分支独有逻辑错误”的阻断判断。建议专项车道在点击前采集基线并记录实际 stepped／位置变化，或把点击期间也纳入观察，固定该段时钟；修复应保留 MV_CLEAR_DEST=true 停住、false 继续走的双向断言，禁止靠重跑通过销账。stop_fade 已释放对象错误另行修，不是此断言的根因证据。

### 未核到与交接

- 未重跑整轮云端或那 13 个 main 文字审失败；未验证真实发行包中的资源路径加载、三平台实机、真实旧底包回退、磁盘满／断电。密钥实测均为公开测试样例和临时文件，不读取私密发行密钥、不触真实存档／options；临时存档实验已清理。真实出包仍需总装跑默认密钥守卫与冒烟，步步遇敌独立 P2 请登记专项车道修复；存档分支本轮无需再返修。
