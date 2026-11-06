# 交付：cc/wukong-newsrc2

- 车道／工作者：C 规则·探针＋转换器＋同步工具／BM（cc，悟空）
- 状态：进行中（等决定，见「需要用户决定」）

## 现在到哪

新源 v0.62.12 的整套同步在本工作树跑通了（96 个探针全过，第二轮 03:14～07:20）。接受单 `04_验证/测量接受/cc_wukong-newsrc2.json` 已按「文件＋集合」整组写好理由（97 组，覆盖 33 万条单条改变、全部删除与无稳定键列表），离线对本树产物验证：带换源开关时问题全清、不带时 97 组全部不认。

**卡在 Godot 对照**：拿新源产物在云端整轮跑 431 个场景，**189 个失败**（运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42178820127 ，提交 12e11992）。失败面：`xiyou_rules*` 全部 66 个分片（切片面板与伤害，盘点期一的平衡、穿透、专武成长都没跟）、事件与楼层（`xiyou_event_compare`、`xiyou_floor_*`、`xiyou_script*`）、装备与说明卡、商店、难度、真气、玄、Boss 等。这不是「最小改动让对照不挂」能收住的量，就是盘点期一～三本身。所以没再跑最后一轮 `--accept-changes`，也没标可合并。

## 本分支做了什么（都在本树验证过）

- `battler.gd` `param_state()`：按 v0.62.05 每个状态只乘自己的层数（`counter.carry` 2420→220）；`xiyou_state_js` 注释跟上。**只在换源时成立**，旧源上会挂 counter.carry。
- `event_presets.json`：删掉 795 个挂在深渊商人旧第 3 页（`p2`）上的变体（v0.30 起深渊商人改成脚本 `CodexAbyssMerchant.openCurrent`，那一页在新源不存在；改到新脚本页只会量一句脚本调用，重制还没跟这个运行时，留给期一跟深渊商人时再加）；Map004 EV069 的 3 个变体跟到 `p1`（v0.62.12 前面插了一张空页，内容逐条相同）。同样只在换源时成立。
- 来源核验（`battle_event_contract.py`、`formula_effect_contract.py`）：敌群事件目录数、装备等级公式块数改成按冻结源版本查表（v0.28：35／47、24；v0.62.12：51／73、27），没登记的版本报错。旧源核验照旧通过。
- 同步换源工具（`同步正式西游.py`、`oracle_additions.py`、`生成接受单.py`，测试在 `测试合并工具.py`）：
  - 同步加 `--accept-source-switch <版本>`：只有本轮确实从别的版本换到这个版本时，才不要求旧输入原样存在；测量变化照旧要接受单逐条（或整组）接受。版本号对不上不生效。
  - 删掉的用例／地图／角色、没有稳定键的顶层列表字段，现在也出变化候选，但标 `switchOnly`，**只在换源时**接受单才认；平时行为不变。
  - 接受单可按「文件＋集合」整组接受（`key` 写 `*`、`fields` 写 `["*"]`，摘要取全组 [键, 摘要] 排序后的摘要，多一条、少一条、任一条不同都对不上；只在换源时认）；`生成接受单.py --grouped` 出这种草稿。换源有 33 万条单条改变，逐条写接受单要八十多 MB。整组扣问题改成按计数一次扣（逐条 `list.remove` 是平方级，33 万条要跑很久）。
- 转换器：原版有两首 bgm 的 `.ogg` 其实是 MP3（`fade to black`、`Number One`，新源切片才用到），Godot 按扩展名导入失败、同步的导入步骤会因此判失败。转换器按内容存成 `.mp3`，`XDB.audio_path` 先找 `.ogg` 再找 `.mp3`。旧源切片不引用这两首，旧产物不变。

## 需要用户决定

- **换源后 Godot 对照会挂 189 个场景，main 要不要先换？**
  - 建议：**先不换 main**。把本分支里与换源无关、旧源上也成立的部分（来源核验查表、同步换源开关与接受工具、转换器 mp3、`audio_path`）先合进 main；`param_state()`、删预设、接受单这三样留在本分支，等期一（BR）在新源产物上把 189 个场景追平后，和期一一起换源。期一车道在自己工作树里用 `XIYOU_APP` 指向新源同步就能对着新参照做。
  - 另一种：现在就换，main 上这 189 个场景挂着，期一边跟边修。缺点是这段时间所有车道的选测基准都是红的，分不清新挂旧挂。

## 总装合并（换源那次）在本机要做的

照[换源操作单](../../03_再刷重制_Godot/02_内容与素材/冻结正式源/换源操作单_v0.28-v0.62.12.md)，补上本分支新加的开关：

1. 没有别的同步在跑（`pgrep -fl 同步正式西游.py`）。
2. 切链接：
   ```
   cd /Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源
   chmod u+w app.nw && mkdir v0.28 && mv app.nw v0.28/app.nw && chmod a-w v0.28/app.nw
   ln -s v0.62.12/app.nw app.nw
   cat app.nw/data/ContentVersion.json
   ```
3. main 上同步：`python3 03_再刷重制_Godot/03_转换工具/同步正式西游.py --accept-additions --accept-source-switch v0.62.12 --accept-changes 03_再刷重制_Godot/04_验证/测量接受/cc_wukong-newsrc2.json`。整组摘要是对着本树当时的 main 基线算的；main 产物这期间变过，第一轮会报「接受单对不上」（探针结果已进缓存，不白跑），用本轮报告重出：`python3 03_转换工具/生成接受单.py --grouped --report <本轮同步报告.json> --out <新接受单>`，理由照抄本接受单（按文件对应），再跑一次（只比较，几分钟）。
4. `配方转换.py`、`插件备注覆盖.py`（操作单第 3 步），然后全量 `检查.sh --oracle`。
5. 来源登记：`00_项目管理/来源登记.json` 的 `legacy_xiyou_mod_kyo`：`confirmedReleaseVersion` → `v0.62.12`（同步登记时自动写）；`frozenCopy` 不变，加 `frozenCopyTarget`: `03_再刷重制_Godot/02_内容与素材/冻结正式源/v0.62.12/app.nw`、`previousFrozenCopy`: `03_再刷重制_Godot/02_内容与素材/冻结正式源/v0.28/app.nw`；`fingerprint` 换成本轮同步写的来源清单；`note` 追加一句换源说明（操作单原文）。`冻结正式源/README.md` 第一段与目录说明改写，AGENTS.md「正式源默认仍读 v0.28」那句改掉。
6. 回退：`cd …/冻结正式源 && rm app.nw && chmod u+w v0.28/app.nw && mv v0.28/app.nw app.nw && chmod a-w app.nw && rmdir v0.28`，再跑一次同步（回到 v0.28 测量）；本分支的 `param_state()` 与删预设要一起回退（`git revert` 对应两个提交）。

## 接续要点（给下一位）

- 本树 generated 现在是**新源产物**（转换＋96 个探针，第二轮同步留在 `04_验证/本地结果/自动同步/20261106_041418_537721_v0.28-v0.62.12/`）。第二轮同步核验当时没过（两条契约，已修），所以探针缓存没提交；下一轮同步仍会整轮重跑（约 3.5 小时，机器满载时更久）。
- `.sandbox/` 里 event_states 是新源 5038 个变体的结果。
- 云端快照 `refs/ci/generated/cc/wukong-newsrc2` 是新源产物。

## 可优化（流程／工具／效率）

- 已做：整组接受按计数扣问题（见上）。
- 建议：同步里某个探针失败时，已经成功的探针结果也提交进缓存（现在只有核验通过才提交，一个探针挂就要整轮 3.5 小时重跑；本车道因此白跑一轮）。归工具车道。
- 建议：event_state_probe 在同步里也走 BO 的分段并行（现在只有 `补跑事件状态探针.py` 分段；新源 5038 个变体单进程约 70 分钟）。

## 待交叉核查

- `battler.gd`（战斗核心，`param_state`）、`同步正式西游.py`／`oracle_additions.py`／`生成接受单.py`（接受边界放宽只在换源时）、两份契约、`xiyou_export.py` 音频扩展名、`xdb.gd` `audio_path`、`event_presets.json` 删 795 条。

## 验证

- `测试合并工具.py` AdditionTests／AcceptanceDraftTests／SyncRegistrationTests 全过（新加换源、删除、整组接受、`--grouped` 用例）；`工具回归.py` 全过；`语法检查.py` 0 问题；新源 Godot 导入无错误。
- 新源同步 96 个探针全部成功；离线接受单验证见上。
- 云端整轮 431 场景：242 过、189 挂（见上，是没跟的内容，不是工具问题）。

## 本分支提交

- 见 `git log main..cc/wukong-newsrc2`
