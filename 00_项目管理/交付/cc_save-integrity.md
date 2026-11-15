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
- 导出改成封存格式（`kyo-remake-save-sealed-v2`），改过的导不进；旧版明文导出默认不收。

## 返修（co 甲档核查 ec1064160）

| 项 | 怎么改的 | 证据（专项 `xiyou_save_seal`，119/119） |
|---|---|---|
| **P1** 退回旧底包时旧代码覆盖／删除封存档 | 封存档改用新文件名 `.ksv`；所有入口经 `XSaveSeal.resolve(<名>.json)` 换名（`XSave.path`／`auto_path`、云裳／魔冠／仓库／跨存档变量的 `path()`）。旧代码只认 `.json`：它覆盖 `save_N.json`、手动存档时删 `save_auto.json`、往「空格」写 `save_N.json`，都碰不到 `.ksv`。明文 `.json` 留原处当备份。 | `rollback.ksv_untouched`、`rollback.new_reads_ksv`、`rollback.auto_still_there`、`legacy.*.json_kept` |
| P1 剩余风险（写清） | ① 退回旧底包期间：旧代码读的是迁移那一刻的 `.json`（旧进度），封存后的新进度它看不到；玩家在旧版玩出来的进度写在 `.json`，回到新版后**不读**（有记号，分不出是旧版写的还是手改的）。找回：删掉存档目录里的 `.sealed_v1` 再进游戏，比 `.ksv` 新的 `.json` 会重新封存（`rollback.recover_by_marker`）。② 旧版本身没有封存功能，退回期间存档照旧能被改。③ 结论不变：**随兼容整包发**（底包里就有封存读写），不走补丁（D36 协调问 Kyo）。另外，装到**没有注入密钥**的旧底包上的补丁根本不封存（发行构建没密钥＝照旧明文），所以就算误走补丁也不会写出旧代码读不了的东西。 | `keys.release_without_key_no_seal` |
| P2① 导入时坏原件被备份清理删掉 | `import_to` 不管备不备份，先把校验失败的目标改名成唯一 `.failed_<时间>[_n]`（清理只认 `.before_import_` 前缀，碰不到）；导入前备份重名加 `_2`…（同一秒两次导入不再互相覆盖） | `import.failed_original_survives_prune`（校验失败的格连续导入 5 次，原件仍在、字节一致）、`import.backups_pruned_unique`；`xiyou_save_transfer` 原 skipped 的 `import_twice_same_second_keeps_original` 现在通过 |
| P2② 解压无上限 | 文件 > `MAX_FILE` 不读进来（读档、导入都先查大小）；声明明文长度 > `MAX_PLAIN`（128 MiB）拒；`decompress` 按声明长度分配、最多解出这么多 | `crafted.oversize_rejected`（带**合法签名**的超大声明） |
| P2③ 迁移没读回落盘内容 | 所有封存写盘统一走 `XSaveSeal.write_file`：写临时文件 → **读回临时文件逐字节比、解开和原文一字不差** → 改名（存档、自动存档、账本、仓库、跨存档变量、导入、迁移都是它）。迁移不再另建 `.plain_*.bak`（`.json` 原件本身就是备份，不复用旧备份）。迁移写不进：那个文件照旧读 `.json`、不放记号、下个进程再试 | `mfail.falls_back_to_json`、`mfail.no_marker`、`mfail.retry_next_process` |
| P2④ 密钥进公开仓库 | 删掉原来的生产种子；仓库只留公开测试密钥（号 0，注释写明只给开发／测试，发行构建不认）。发行密钥在私密设计仓 `xiyou-design-docs/发行密钥/save_seal_key.json`（不进本仓库，`.gitignore` 了注入路径），`发行出包.py` 导出前复制进导出用的工程副本 `content/save_seal_key.json`、导完删；没密钥就不出包（`--no-save-key` 明知故出不封存的包）。新工具 `07_开发环境/存档密钥.py`（`--init` 生成、`--rotate` 加新号、`--check`）。原种子已在公开仓库历史里，作废不用。 | `keys.release_without_key_no_seal`、`keys.release_rejects_test_key`、`keys.release_with_key_seals`（号 3 写、号 2 读）、`keys.other_key_not_accepted`、`keys.dev_test_key_back` |
| P3 补齐只验末字节 | 每个补齐字节都核；HMAC 在解密之前（文件头注释写明） | `crafted.padding_all_bytes`（带合法签名、末字节对前面不对） |

- 反向验证（手工，改完用备份字节还原）：去掉补齐逐字节核 → `crafted.padding_all_bytes` 挂；去掉长度上限 → `crafted.oversize_rejected` 挂；去掉导入前改名 → `import.failed_original_survives_prune` 挂。
- 顺带：迁移失败时 `.ksv` 不存在会被当成「空档／空账本」再写新的（返修中发现）——改成回落读 `.json`。

### 总装出包要做的（第一次）

1. 在私密设计仓生成发行密钥：`python3 03_再刷重制_Godot/07_开发环境/存档密钥.py --init`（默认写 `~/Documents/xiyou-design-docs/发行密钥/save_seal_key.json`，或 `XIYOU_SAVE_KEY=<路径>`），在设计仓提交它。**不要拷进游戏仓库。**
2. 出包照旧 `python3 发行出包.py`：它自动注入（打印「存档密钥：已注入（号 1，不进仓库）」）；缺密钥会报错不出包。
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
- 导出改成封存格式，改过的导不进；旧版明文导出默认不收。
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
| O-待定-3 | `save_transfer.gd` `XSaveTransfer.ACCEPT_PLAIN_IMPORT`、`parse_import` | 导出导入是明文 JSON | 封存开着时导出封存格式；没签名的明文导出不收 | 不然改明文导出再导入就绕过 | `XSaveTransfer.ACCEPT_PLAIN_IMPORT = true`（照旧收明文导出，导入后写成封存格式） | cc | 保留 |

## 交接板

- 下一步：co 复核返修；出包前总装按「总装出包要做的」生成发行密钥。
- 用户试玩说明：读档照常；存档文件夹里每个进度文件多一个 `.ksv`（新存档）和 `.sealed_v1`，原 `.json` 留作备份。改过的 `.ksv` 读档页显示「存档校验失败」。
- 需要用户决定：
  1. **发行方式（D36，协调问 Kyo）**：推荐随兼容整包发。补丁装在没有密钥的旧底包上不会封存（安全但等于没上）；整包带密钥才生效。
  2. **旧版明文导出文件还收不收**：默认不收（否则改明文再导入就绕过）。若有玩家只有旧版导出文件要换设备，可临时打开 `ACCEPT_PLAIN_IMPORT`。推荐：不收。

## 进度账

- 重制版平台与存档：存档防改（D28）完成（待 co 复核）。

## 可优化（流程／工具／效率）

- 建议：守卫检查加一条 rg，禁止测试和游戏代码直接 `FileAccess.get_file_as_string(XSave.path(…))`／写 `save_*.json`（预计收益：防新代码绕过封存或一上来就崩在解析封存字节；归工具车道）。
- 建议：`xiyou_step_encounter_stop` 的 `rollback_stale_target_walks` 偶发（第一轮云端挂过，封存关掉本机也挂过一次），归步步遇敌车道改成确定性；co 提醒「main 上也挂」尚未在 main 隔离复跑证实。
- 已做：存档相关测试夹具改走 `XSaveSeal.read_text`／`write_file`、`.ksv` 文件名。

## 验证

- 专项 `xiyou_save_seal` 119/119（新）：编码往返；改任一段一字节／截断／追加／空；带合法签名的超大声明、坏补齐；明文旧档迁移（七个文件 `.ksv` 解开＝原文、`.json` 原件不动、记号）；旧底包退回模拟；新档往返、改字节、截断、明文写进 `.ksv`、迁移后丢进来的 `.json`、存到失败格改名留着、删除改名；自动存档；多槽；账本、仓库、跨存档变量改过不读不写；开关关闭／再打开；导出导入；导入保留失败原件；反馈 zip 原样；发行模拟冷启动读旧档；迁移写不进回落 `.json`；发行密钥（无密钥不封存、不认测试密钥、号轮换）。
- 本机直跑（`test_main_loop`，本机测试槽被别的车道占着）：save_corrupt 53/53、save_cat_slots 15/15、save_slim 126/126、save_page 42/42、save_events 31/31、save_transfer 39/39（原 skipped 一项现在通过）、star_warehouse 99/99、global_vars 17/17、demon_crown 106/106、demon_crown_compact 48/48、autosave 10/10、pause_save 46/46、save_cold_load 27/27、splash_autosave 74/74、feedback_v001 32/32、yunshang_shop 436/436、yunshang_gear_load 137/137、platform 155/155、percent_pills 65/65、review_regressions 29/29、random_streams 490/490、floor30_gifts 30/30、tianqi_affix_seed 23/23、tianqi_opening 44/44、tianqi_seed_fix 77/77、lottery_seed 12/12、tianqi_save 82/82、battleback_save 5/5、newgame_back 68/68、entry_release 16/16。
- 工具快速回归全部通过（98 秒）；语法检查通过。
- 云端选测：CLOUD_RESULT
- 真发行包实机冷启动、Windows／安卓文件替换、真磁盘满／断电没做（要出包或实机）。
- 合并建议：`合并车道.sh … --finish --affected --cloud`。

## 待交叉核查

- co 甲档复核：`save_seal.gd`（重写）、`xsave.gd`、`save_transfer.gd`、`star_warehouse.gd`、`xglobal_vars.gd`、`yunshang_orders.gd`、`demon_crown.gd`、`save_slim.gd`、`ui/save_scene.gd`、`entry.gd`、`07_开发环境/发行出包.py`、`07_开发环境/存档密钥.py`（新）、`.gitignore`；测试夹具改动。

## 本分支提交

- 6b696d2a6 存档封存 XSaveSeal 接入
- 81d3f31d2 专项 xiyou_save_seal；旧存档专项改走 XSaveSeal 读写
- abe3b2397 交付单
- 返修：封存档改 .ksv、发行密钥出包注入、上限、读回核对、补齐逐字节、导入保留失败原件；测试改 .ksv；迁移失败回落 .json

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
