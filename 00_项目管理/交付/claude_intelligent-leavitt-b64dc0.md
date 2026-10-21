# 交付：claude/intelligent-leavitt-b64dc0

- 车道／工作者：核查／八戒（Claude，重制_八戒_38，只读）
- 状态：可合并

## 变更记录草稿

## 2026-10-21 【Claude·八戒】核查 d35bc08、4870e4e、cb5d85f、dbaf70c、8e231d8、ef8f133、8701ab0（合并提交 ef52235）

沙僧同步提速第一期逐行审完（以 `ef52235^1..ef52235` 的代码差异为准，含 `incremental_sync.py`、`同步正式西游.py` 的 `run_probes`、`hboot.cjs`、`manual_sandbox.cjs`、`oracle_shard_merge.cjs`、`新建工作树.sh`）。**结论：通过，无 P0／P1**；留 P2 一项、P3 四项，均不影响产物正确性。复跑 `测试增量同步.py` 46 项、`测试角色同步提速.py` 24 项均通过；未重跑全量同步。

逐项：

- **缓存键覆盖输入**：通过。公共键去掉了 generated 的绝对路径（换工作树能命中），读转换产物的探针仍按 maps／db／manifest／slice.json 内容入键；全部探针实际读 generated 的只有 event、formula_program、formula_equipment，读的都在这四类之内（已逐个 grep 核）。app 路径仍在键里，工作树的冻结源是指向主工作区的符号链接，resolve 后相同。`plan` 改为由 `explain` 判定：除「只有单元变化」外的任何原因（键、产物声明、产物 SHA）一律整体重跑，比原来多核了产物声明，更保守。
- **手动探针种子隔离**：通过。未设 `XIYOU_ORACLE_SANDBOX` 时 `hboot` 在 `.sandbox/manual/probe-*` 克隆 save／macport 并以它为沙盒，同一进程多次 boot 共用一份；守卫对沙盒外的 save 路径仍按 protectedPath 拦写（测试有覆盖），种子与 manual 目录拒绝符号链接。同步自己设环境变量，不走这条路。种子键只算 save／macport，不含 manual。
- **六难度共享并发池**：通过。切片拆成 6 条 `slice_probe.cjs <d>` 进同一线程池，各难度独立种子目录（`run/slice_probe-d<N>`）、独立产物文件；增量时每难度各自按 `units['slice_probe.cjs']` 合并自己的那份。任一条失败（退出码或产物缺失、新错误）都在发布前抛出，缓存已先作废，`generated/oracle` 不被改写；日志与发布按 PROBES 顺序写，不受完成先后影响。slice_probe 每个难度本来就各自 boot，拆进程与原单进程等价（八戒_36 已逐字节对照）。
- **未知产物依赖保守处理**：通过。分片探针的任何依赖含 generated 标记且不在 `GENERATED_SHARD_AUDITS`（或 SHA 对不上）就不分片、退回整份产物键；8e231d8 去掉注释剥离后连注释里的标记也算，更保守。已核 event_probe 当前 SHA 与审视值一致，且它只读 manifest 的 `slice.commonEvents` 与切片地图的 `MapNNN.json`（单元键即地图文件 SHA，公共事件内容来自冻结源，由 source 键覆盖）。
- **V2→V3 升级**：通过。版本不同即整表作废、记 `cache-version`，首次全跑；主工作区旧 V2 缓存被携带到新工作树也只会全跑。
- **缓存携带**：通过。只在目标不存在时复制，先查两边符号链接再复制；携带的条目命中时仍逐文件核产物 SHA，种子不同则 seedFiles 不同而全跑。

问题：

- P2　`测试角色同步提速.py`（24 项：携带、未命中原因、审视哈希、六难度分命令、角色分片合并、手动种子隔离）没有接进 `检查.sh`，也不由 `测试合并工具.py` 带跑（只带了 `测试增量同步.py`），日常收工检查不看守这批新行为。建议在 `检查.sh` 工具回归段加一行。
- P3　`.sandbox/manual/probe-*` 每次手动跑探针新建一份种子副本（save 约 11 MB，APFS 克隆实占小），从不清理；主工作区已有 2 份。建议同步开跑时或 `新建工作树.sh --补齐` 时删旧副本，或在文档写明可随时删。
- P3　`GENERATED_SHARD_AUDITS` 写死 event_probe.cjs 全文 SHA：以后改 event_probe（连注释）都会让它退回整份产物键、失去按地图分片（结果仍正确，只是慢），`CACHE_MISS` 原因里也看不出是审视失效。`长任务与增量同步.md` 应写明「改 event_probe 后复核读取范围并更新审视哈希」。
- P3　`oracle_shard_merge.cjs` 的 `slice-actors` 合并类型没有调用方（第二期按单元复用用户已定不做），但它在 TOOLING 里，改它会让三个分片探针整体重跑。建议删掉，或注明为第二期保留。
- P3　`长任务与增量同步.md` 没写缓存携带、手动探针种子隔离、切片六难度分命令、`CACHE_MISS` 原因与同步报告 `missReasons`／`commands`，仍是 V2 时的描述。

## 交接板

- 待交叉核查：把「合并 codex/sync-actor-speedup-p1」一行的核查者改为已核（八戒_38 通过，见本条）；本分支提交加进待交叉核查（核查：待Codex）。
- 下一步：P2「测试角色同步提速.py 接进 检查.sh」可交下一条规则车道顺手做（一行）；P3 四项可攒批。

## 本分支提交

- 本交付单（核查沙僧同步提速第一期）
