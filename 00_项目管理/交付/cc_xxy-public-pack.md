# 交付：cc/xxy-public-pack

- 车道／工作者：T008 小小鱼玩家公开资料包期一（cc，Opus＋medium，P8）；核查：小o（sol）第一道、小A（Carbon）第二道
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·未经审查】小小鱼玩家资料包期一：玩家资料包.py 出「玩家看得到的」公开资料，发布补丁核过线上后自动出（dev.待定）

- 依据：私密设计仓 `协作交接/小小鱼玩家运营方案_v0.2.md` 文末契约 F1～F6、C1～C7；C5 照小A 复核第三节两处 P1 改（D89 本车道局部热修）；Kyo 已定 X1～X4。
- 新增 `07_开发环境/玩家资料包.py`（F1）：读线上 `channel.json`（Gitee、GitHub 两源，用游戏内嵌公钥验签）→ 只在发行分支／标签尖端（`cc/v<数字>`、`release/*` 分支与标签，含 origin 下同名）找 `build_info` 是 `dev.<补丁号>`、`releaseVersion` 非空、大版本与清单版本一致的唯一提交（多个、没有都失败）→ 临时 `git worktree` 检出该提交，从 HEAD 就在该提交的工作树（没有才用主工作区）`cp -c` 克隆 `generated/` 与 `.godot/` → `发行空壳.py tree --src` 出脱敏树，再照「Windows 发行」预设的 exclude_filter 删不进包的文件 → 无头 Godot 取字 → 出 `版本.json`、`数据/`八类、`事件.jsonl`、三份 md、`自检.json` → 七项自检全过才原子切 `当前`（先建临时链再 rename），留最近十版；写前比对上一版 `自检.json` 的文件哈希，被改过就报警不覆盖。参数 `--ref`、`--dry-run`、`--out`，另有 `--major`、`--from-dump`、`--inject`（反例用）、`--keep-work`、`--channel-file`（测试用，写进自检）。
- 新增 `07_开发环境/玩家资料包_取字.gd`（F2）：只拷进脱敏树跑；`ReleaseEntry.simulate_release = true` 后清 XDB 表缓存再取；技能／物品／武器／防具取 `XHelpCard.content()` 逐行（含 `<pos=APs>` 渲染行，两列排版之间留全角空格），状态取 `XPartyStatusPanel.description()`，角色取 profile，职业／敌人只取名字；版本号调 `XVersionLabel.version_text()` 与 `XUpdateCheck.version_of()`，老底包弹窗按老底包 build_info 再调一次 `version_of`（F1 不另写算法）。异化六件按 `XAlienHide.blocks_*` 标 `open_in_current_version: false`。
- 包里规则：每行 `public_id`＝`<kind>-sha256(kind|name)` 前 10 位、重名加 `-2/-3`；不出 `id`、note、damage、掉落、traits、meta；`price` 只在说明卡上有价格行时给；`params` 只给武器防具（装备面板看得到）；敌人八维不给（见「我不同意」）；数据库编辑器分组标题（「------15层副本扩充」等约 370 行）和以「测试」开头的非敌人条目不出。
- 掉率（X2，协调 11-16 定「剥」）：游戏原文里写着的掉落／产出几率「留来源、去数字」（`redact_drop`），本次 4 行（萨姆残核说明卡、改版向导对白、赌局 NPC 两句）；战斗特效几率、掉率加成效果照 X3 留。自检②顺带查「掉落／产出几率句带百分数」。
- 禁词表（C6）：每次从 main 的 `tianqi_data/*.json` 全部 name（2832 个）＋发行空壳类名（脱敏树与本仓并集 62 个）＋固定词表 11 个生成；减去正式源 v0.62.12 转换产物（generated/db、maps 原文）里本来就有的词（2547 个，原版公开名，不算天启篇新增）和单字（15 个），本次 343 条；固定词表来源：`发行内容审计.DENY`（tianqi_data、content/tianqi、content/gojo、rift_alien、ui/tianqi）、`发行空壳.SUSPECT_NAME`（tianqi、gojo、qiyin、horsem）、`SUSPECT_HEAD`（天启篇专属、只在天启篇）、`EXTRA`（XGojo＝五条悟），另加七印、四骑士、天启骑士。禁词表本身不进包；`版本.json` 的契约字段名 `tianqi_open` 不算命中。
- `发布补丁.py`（F4）：`--verify-online` 全过后跑 `玩家资料包.py`；回退开关 `PLAYER_PACK_AFTER_VERIFY = True`，单次 `--no-player-pack`；资料包失败只报警，不改线上核对的退出码；线上核对不过不出。
- `发行空壳.py`：`tree` 加 `--src <工程目录>`（克隆指定工程，空壳规则照用本脚本旁边的）；不给 `--src` 时行为不变。
- 三份 md 放 `03_再刷重制_Godot/05_发布/玩家资料包/`（`更新记录.md`、`和旧西游的不同.md`、`常见问答.md` 先放「（待补）」占位，README 写了口径），出包原样拷进去。
- 第一份产出：`~/Documents/DSH/小小鱼/game/玩家资料包/v0.02/`，`当前 → v0.02`（线上补丁 481，发行提交 `cc/v00200` 尖端 `f2f00f1bf`）。
- 验证：`测试玩家资料包.py` 35 条（自检七项各正反例、C5 定位四例、掉率剥除、事件块、出口切换／防篡改／留十版、F4 接线）全过；`测试发布补丁.py` 21 条、`测试发行空壳.py` 12 条全过；`发行空壳.py check` 通过；期一验收证据 1～6 见交付单。
- 提交：见「本分支提交」
- 未完成／已知问题：三份 md 是占位（期零）；`检查.sh` tools 组和 `工具回归.py` 门禁没登记新专项（不是本车道独占文件，见「可优化」）；少数名字带「测试」但不以它开头的条目（如「轮回模式·困难平衡测试v1」被动）留着，可不可见留给期二发行构建实跑对账。

## 期一验收证据

证据原文件在本机 `03_再刷重制_Godot/04_验证/本地结果/玩家资料包_T008证据/`（主工作区与本工作树各一份，不入 Git：仓库公开，掉率原文对照不该进去）。

### 1. `--dry-run` 与真实运行

两次都退出码 0，七项全 ✓（`证据1_dry-run.log`、`证据1_真实运行.log`）。真实运行末尾 `自检.json` 全文（DSH `当前/自检.json`）：

```json
{
 "ok": true,
 "checks": {
  "①字段白名单": {"ok": true, "problems": [], "problem_count": 0},
  "②禁词零命中": {"ok": true, "problems": [], "problem_count": 0},
  "③内部数字编号零命中": {"ok": true, "problems": [], "problem_count": 0},
  "④版本对得上": {"ok": true, "problems": [], "problem_count": 0},
  "⑤条数不掉一成": {"ok": true, "problems": [], "problem_count": 0},
  "⑥public_id类内唯一": {"ok": true, "problems": [], "problem_count": 0},
  "⑦写入路径在出口内": {"ok": true, "problems": [], "problem_count": 0}
 },
 "counts": {"Actors": 167, "Classes": 39, "Skills": 6787, "Items": 2308, "Weapons": 1056, "Armors": 2228, "States": 1963, "Enemies": 877, "事件": 1716},
 "excluded": {"Actors": 12, "Classes": 138, "Skills": 3846, "Items": 755, "Weapons": 2948, "Armors": 5772, "States": 828, "Enemies": 1150},
 "forbidden": {"tianqi_data_files": 29, "tianqi_data_names": 2832, "dropped_in_original": 2547, "dropped_single_char": 15, "stub_classes": 62, "fixed_words": 11, "fixed_dropped_in_original": [], "total": 343,
  "from": "天启篇数值表（main）全部 name；发行空壳替换的类名；玩家资料包.py 固定词表（来源见交付单）"},
 "source_commit": "f2f00f1bf4af6a49409a5b698871d6d567b5de3b",
 "source_refs": ["refs/heads/cc/v00200"],
 "used_ref": null, "from_dump": null, "injected": null,
 "channel_source": "https://gitee.com/kyoluu/play-again_-xiyou_-kyo/raw/main/godot",
 "channel_sha256": "ef7580482687b256fe9d9d5b97700b1d80b15cce2dae56021db72eed6b056203",
 "generated_from": "同提交工作树",
 "major_basis": "上一版 v0.02",
 "release_gate": {"alien_hidden": true, "is_release": true},
 "dry_run": false,
 "drop_rate_lines_redacted": 4,
 "generated_at": "2026-11-16 03:24:27",
 "files": {"事件.jsonl": "ae50dfcb…", "和旧西游的不同.md": "7c904a1c…", "常见问答.md": "ec39de60…", "数据/Actors.json": "8d616560…", "数据/Armors.json": "eecf6480…", "数据/Classes.json": "a7c5dc03…", "数据/Enemies.json": "ba622065…", "数据/Items.json": "5e1a9f9c…", "数据/Skills.json": "dba83a3a…", "数据/States.json": "fe91e0a7…", "数据/Weapons.json": "01afc29b…", "更新记录.md": "a7a75133…", "版本.json": "55dd278e…"}
}
```

（`files` 哈希这里截前 8 位，全文在 DSH 的 `自检.json`。`major_basis` 是「上一版 v0.02」，因为验收时同一版跑了好几次；第一次出包时没有上一版，按默认 false。）

`版本.json`：`version` v0.02、`patch` 481、`release_base` 477、`legacy_popup_version` 0.01.11、`published_at` 2026-11-15 17:32（更新仓清单提交时间）、`major_content` false、`tianqi_open` false、`highlights` 取线上清单 7 条说明、`source_commit` f2f00f1bf…。

### 2. C5 定位日志

```
✓ 线上清单 https://gitee.com/kyoluu/play-again_-xiyou_-kyo/raw/main/godot：验签通过，最新 0.481（481）
✓ 线上清单 https://raw.githubusercontent.com/luiluu/zaishuayiba-updates/main/godot：验签通过，最新 0.481（481）
481 → 提交 f2f00f1bf4af6a49409a5b698871d6d567b5de3b（refs/heads/cc/v00200）build_info {"developmentVersion": "dev.481", "releaseVersion": "0.02", "releaseBase": 481, …}
脱敏树 …/04_验证/本地结果/玩家资料包/<时间>/tree（generated 来自 同提交工作树 …/cc-v00110/03_再刷重制_Godot/01_Godot工程；空壳 6 个；按发行预设删 123 个文件）
右下角 v0.02；补丁号算出 v0.02；老底包弹窗 0.01.11；发行门 {'alien_hidden': True, 'is_release': True}
```

看过的发行尖端：`cc/v00110`（dev.480）、`cc/v00200`（dev.481 ← 唯一命中）、`release/v0.01`（dev.480）、`release/v0.01.03／.06／.07／.08` 标签（dev.473／476／477／478）。main 线上 `22056d4bd`、`cc/v00200` 的升版提交 `96984fa8f` 不是尖端，不看（小A 复核半边 A）。临时 worktree 跑完 `git worktree remove --force`，`git worktree list` 里不留。

### 3. 抽 20 条说明对照

`证据3_抽样对照.md`：技能 8（其中 166～179 自制角色技能 4：黑羽淬魂、亡者盛宴、破限成长、游云）、装备 6（带 `<pos=APs>` 3：《字典》、亚特兰蒂斯秘力头饰、寒霜之杖）、物品 3、状态 3，左栏数据库原文（description＋渲染用备注标签），右栏包里的 description。对照的是脱敏树里 `XHelpCard.content()`／状态详情的输出（发行构建画卡用的同一个函数，去了控制符），**不是真机截图**；真机实跑抽样对账在期二（契约 2.1 期二本来就有）。抽到的 3 条「其他装备」原本是编辑器分组标题，已据此加规则剔除，表是剔除后重抽的。

### 4. 反例（`证据4_反例.log`）

都在真实模式（写 DSH 出口）跑，用 `--from-dump` 复用同一份取字结果：

| 反例 | 注入 | 拦住它的项 | 退出码 | 「当前」 |
|---|---|---|---|---|
| 禁词 | `数据/Items.json` 加一行名为「一力降十会」（天启篇数值表里的名字） | ②禁词零命中 | 1 | 仍 → v0.02，`v0.02` 全目录哈希前后都是 `0d348eda…`，待检目录已删 |
| 数字 id | `数据/Skills.json` 第 0 行加 `"id": 123` | ①字段白名单、③内部数字编号 | 1 | 同上 |
| 空目录 | `数据/` 清空 | ①（缺八个文件）、⑤（八类 0 条且比上一版掉一成以上） | 1 | 同上 |

### 5. 全文检索（`证据5_rg.log`，查 DSH `当前/`）

- `<Prefixes`、`<Custom`、`formula`、`dropItems`、「（ID」：**零命中**。
- `%`：Skills 3788 行、Armors 1881、Weapons 900、Items 567、States 920、事件 8。全部是说明卡／状态详情／对白原文里的效果数值（「暴击率+10%」「普通攻击50%的几率触发…」「受到攻击的概率+1000%」「物品掉落率+5%」「精魂和爆率增加10%」等难度说明），X3 照留。
- 掉落／产出几率句带百分数：剥后只剩 1 行命中检索式，是赌局 NPC 对白另一句「可以消耗…肝帝积分，提升10%遇到肝帝积分赌局的概率」——花积分买的加成幅度，不是掉率，按效果留；请小A 判。
- 剥掉的 4 行原文→出包文：`掉率剥除_原文到出包文.json`（本机，不入 Git）。出包文是：
  1. 萨姆残核说明卡：「…第15、17、19、21、27层深渊「未知存在」有概率掉落；不受掉落率加成影响。」（原文冒号后三档百分数和「21、27层至少（百分数）」整段去掉）
  2. 改版向导对白：「…的首领会掉落，概率随难度；不受掉落率加成影响。」（同上）
  3. 赌局 NPC：「(开启后通过深渊位置存在有概率可以触发肝帝积分赌局(可以拒绝))」（原文「有（百分数）的概率」）
  4. 赌局 NPC：「(开启后，每次完成赌场二阶段有概率产出星神命途系列装备)」（同上）

### 6. 她的索引逻辑读新数据（`证据6_索引.log`）

把 `dsh-pet/lib/` 的 `kb-index.cjs`、`game-kb.cjs`、`jsonfile.cjs` 拷到 scratchpad（与原文件逐字 diff 一致），`DSH_PET_GAME_DATA` 指 `当前/数据/`，在临时工作区 `build({force:true})`，不碰她的索引：

| 副本 | 块数 | `by_id` 去重后 | 含「（ID」 | 纯数字块 ID |
|---|---|---|---|---|
| 原样 | 15425 | **8**（id 全回退 0，互相覆盖） | 15425 | 15425 |
| 按 S5 改 | 15425 | **15425**（两数相等） | 0 | 0 |

S5 副本改了四处（diff 在日志末尾）：`loadKind` 带上 `public_id`；块 ID 用 `public_id`、没有就跳过计数；`formatRow` 去「（ID…）」；**敌人那条映射 `{ id, name, description: enemyNote(note), params }` 也要带上 `public_id`**——不加的话 877 个敌人整批被跳过（契约 S5 没写到这一处，给她的信要补一句）。

## 交接板

- 下一步：小o（sol）第一道核 F1～F4 代码与证据 1、2、4、6；小A（Carbon）第二道核外泄红线（证据 3、5、禁词来源）；两道过后项目经理cc 投信给小小鱼（信里第 5 步补一句「敌人那条映射也带上 public_id」）；期零补三份 md。
- 用户试玩说明：无（不改游戏）。
- 需要用户决定：无（掉率口径协调 11-16 已按 X2 定「剥」）。

## 进度账

- 无（工具与运营资料，不改游戏进度）。

## 我不同意的地方

1. **掉率剥了，玩家截图对不上**：萨姆残核说明卡、改版向导对白在游戏里原样写着掉率，小小鱼手里那句没数字，玩家拿截图问时她答不全。照协调按 X2 剥了；请 Kyo 后续考虑「游戏里已写明的掉率可以照原文答」。
2. **敌人八维默认不出**：发行版图鉴打过登记后确实显示八维（`ui/enemy_book.gd` 画 `e.param(i)`），但那是运行时随难度变的值，数据库原值和玩家看到的不同，出了会让她答错；期一按「默认剥」不出，要放回得先定按哪个难度出。
3. **「发行构建游戏内说明卡」对照不是真机**：证据 3 对照的是脱敏树里同一个画卡函数的输出；真正的「装进发行包、点开截图」对账放期二。
4. **`major_content` 第一版算法**：没有上一版时按默认 false（这次 v0.02 已在 11-15 上线，加班窗口基本过了）；以后按上一版资料包的版本号中间段比。
5. **C5 补一条约定**：`cc/v*` 只认 `cc/v` 后面跟数字的分支，免得 `cc/vp-paths` 这类车道分支被当成发行线。

## 可优化（流程／工具／效率）

- 建议：把 `测试玩家资料包.py` 登记进 `检查.sh` 的 tools 组和 `工具回归.py` 的门禁（几秒、不连网、不跑 Godot；两处都不是本车道独占文件，交总装顺手加）。
- 建议：期二「发行构建实跑抽样对账」可复用 `发行入口冒烟.py` 起发行包，在真机说明卡上截图比对证据 3 那 20 条。
- 已做：`玩家资料包.py --from-dump` 复用上次取字结果，反例和改规则后的复跑不用重建树、不跑 Godot（几秒）；回退＝不用这个参数。

## 本分支提交

- adf356159 WIP: T008 期一主体（玩家资料包.py＋无头取字＋专项＋发布补丁接线＋发行空壳 --src）
- （本提交）掉率剥除、编辑器分组标题与测试条目剔除、禁词来源去路径、交付单
