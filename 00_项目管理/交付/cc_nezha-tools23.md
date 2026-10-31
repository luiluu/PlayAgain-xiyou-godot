# 交付单：cc/nezha-tools23（哪吒_11，工具车道）

- 状态：可合并
- 执行者：cc（哪吒_11）；自 tools22 末端 1942993d 切（用 `新建工作树.sh --补齐 --branch cc/nezha-tools23 --from cc/nezha-tools22`，新参数实测可用）。没合 main：交付时 main 正在合 bailong-garou2（c03226dd，state.json 在），合进来万一 bailong 被 --abort 会把它带进本分支；main 这期间只动了文档与 garou 探针，`git merge-tree` 试合无冲突。只改工具与工具说明。验证：测试增量同步 66/66、测试合并工具 223/223、测试提交守卫 16/16、测试参照批次、测试公式程序 12/12；未跑 Godot。

## 变更记录草稿

## 2026-10-31 【cc·哪吒·未经审查】同步测量按用例键对齐、车道基线自动取主工作区 oracle（dev.待定）

- **按用例键对齐（期一①）**：先查清了「插在中间被当成改动」在哪一层——放行判定（`oracle_additions.compare_file`）对 KEYS 登记的参照一直按稳定键比，实测 alien_affix 抽掉中间一条再比只算 1 条新增；按下标比的是同步报告里给人看的 `measurementChanges`（`diff_paths`），插一条就列出一串 `/cases[N]/…`，看着像整段改了。现在：①`diff_paths` 给了参照文件名时，顶层带稳定键的列表按键列 `/cases[id=x] 新增`／`删除`／`/cases[id=x]/字段`，其余列表照旧按下标；②KEYS 没登记的 `cases`（alien_battle、shield、review135、stage50_review、achievement_badges 等）两边每条都有 `id`（都没有就看 `key`）且各自不重号时自动按它对齐（`oracle_additions.field_keys`），新增键＝新增用例（照旧要 `--accept-additions`）、少了键＝删除（拒收）、同键内容变＝改动（可用接受单，键 `[["id",…]]`，与 `生成接受单.py` 照抄的 changeCandidates 同口径）；`current_digest`、撤图裁基线（`withdraw_baseline`）、已知错误放行同用这套键。缺键、重号或别的字段照旧整段比。**这是放宽**：原来未登记的 cases 改一点就整段拒收，现在按条认；`AUTO_KEY_FIELDS = ()` 即回退。
- **车道同步不用再手拷主工作区 generated/oracle（期一②）**：查到的原因（读码推出，没在真车道复现）：合 main 后 `--补齐` 的 `refresh_oracle` 按修改时间刷新，车道同步过的参照文件是同步时写的、比主工作区那份新，不被刷新；车道又没有待用的基线时，比较基线取车道这份旧的，main 在此期间接受过的改变就显示成车道的改变、被拒收。dev.223 的 `main_baseline_files` 只管「补齐后手拷、main 没前进」那一半。现在 `同步正式西游.py` 在车道已合进当前 main（主工作区在 main 上、`.git/lane-merge/state.json` 不在、其提交是车道 HEAD 的祖先，`merged_main`）时，比较基线里主工作区有的参照整份取主工作区的，车道独有的仍取本树的，并在基线里记下 main 提交（`main.json`）；拒收后留下的基线若取自别的 main（或车道自己的产物），合进新 main 后自动重取。车道没合进当前 main 时照旧取本树的，提示改成「先 git merge main 再同步」。**回退**：`comparison_baseline` 里 `head = …` 那行改成 `head = None`。
- **注意**：`同步正式西游.py` 在 tools_digest 里，合进 main 后，之前在旧工具下同步过、还没合并的车道产物指纹对不上，合并时要在 main 完整同步一次（`oracle_additions.py` 不在指纹里）。
- **期二**：`新建工作树.sh --补齐 --branch` 切完后，原分支没有自己的提交（都已在 main 里，如 app 起的 `cc/<随机名>`）时提示 `git branch -d <原分支>`，只提示不删。
- 自测：`测试增量同步.py` 66/66（新增 4：未登记 cases 插中间／重排／删一条／改一条走接受单的端到端、缺键与重号仍整段比、车道合 main 后基线取主工作区并按 main 提交重取、`merged_main` 的祖先／合并中／不在 main 判断）；`测试合并工具.py` 223/223（新增 1：未登记 cases 按 id 认，原「未知集合拒收」改用非 cases 字段）；`测试提交守卫.py` 16/16（补齐切分支用例加空分支提示与有提交不提示）；`测试参照批次.py`、`测试公式程序.py` 通过。

## 交接板

- 可删「工具可优化（八戒 dev.208）」里「同步在车道工作树里应固定拿主工作区 oracle 当基线」这半句：车道已合当前 main 时已是如此。
- 车道交代里「同步前先把主工作区的 generated/oracle 拷回来」不用再写；改成「同步前先 git merge main」。

## 可优化

- 优化登记草稿：无。
- 建议：`--补齐` 的 `refresh_oracle` 仍按修改时间刷新，车道合 main 后 `generated/oracle` 里可能还是旧参照（只影响 Godot 专项读到的参照，同步基线已不受影响）；要彻底可改成「车道已合当前 main 时按内容对齐主工作区，车道本期同步过的另行保留」，需要记下车道哪些参照是自己同步出来的，归工具车道。

## 本分支提交

- 3bd6a2e6 同步测量差异按用例键对齐，未登记的 cases 按 id/key 认（期一①）
- 144628c9 车道合进当前 main 时同步基线整份取主工作区 oracle；--branch 切完提示可删空分支（期一②、期二）
