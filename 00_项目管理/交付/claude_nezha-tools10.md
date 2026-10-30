# 交付：claude/nezha-tools10

- 状态：可合并
- 车道／工作者：D 检查·合并·同步工具／哪吒_10（Claude）
- 基于 claude/nezha-tools9（9bfcae6e）；交付前已合 main

## 变更记录草稿

## 2026-10-30 【Claude·哪吒_10·未经Codex检验】测试公共时钟夹具、覆盖检查认条件类型、同步 --help、进度核定 64.0% 导入（dev.待定）

- **神秘生物真实时钟公共夹具**：新增 `tests/test_main_loop.gd`（`extends SceneTree`），`并行测试.py` 对每个场景用 `-s res://tests/test_main_loop.gd` 挂上，在场景加载前把 `XPetCapture.clock` 固定为 12:15（刷新窗口外），退出时 `_finalize` 还原。要点：①`-s` 脚本编译时全局类未就绪，直接写 `XPetCapture` 会编译失败，所以运行时 `load` 脚本再 `set("clock", …)`；②必须在 `_finalize` 还原，否则静态变量里的 lambda 在退出时析构崩溃（退出码 134）。工程里没有该文件时不挂（旧工程、测试夹具兼容）。`xiyou_pet_capture`、`xiyou_book_capacity_ui` 自己的固定写法照旧生效（场景里的赋值在夹具之后）。游戏代码不改。验证：删掉 `xiyou_book_capacity_ui` 自己的固定写法后直接跑，夹具设 12:31 得到与 07:30 偶发相同的 4 条失败（bag.notices.size／.0／.1、toast.exists），设 12:15 为 85/85。另拿 `xiyou_notice_options`、`xiyou_orb_shop_ui`、`xiyou_power_books_menu`、`xiyou_race_menu` 以 12:31 跑，4 个都过（对该时钟不敏感，不算复现）。
- **内容覆盖检查认条件类型**（`内容覆盖检查.py`）：条件分支 111 的条件类型，共用核心 `_condition` 顶层 match 与宿主 `_condition_env`（地图：6 角色朝向；战斗：5 敌人）都不认的，算「未翻译|…|条件类型 N」（战斗专用公共事件按战斗宿主查）。首跑找到**新缺口：条件类型 9／10（武器／防具）7 页 9 处**——Map024/EV020/p1、Map084/EV011/p1、Map139/EV006/p1／p2、Map148/EV014/p1、Map195/EV020/p3／p7、Map213/EV002/p3（见基线）。没修；基线已更新登入。工具自测 `测试内容覆盖.py` 加 `test_condition_kinds`（4/4）。
- **同步 `--help`**：`同步正式西游.py` 参数解析挪到长任务包装之前（`build_parser`），`--help` 与参数写错直接输出，不再先打印 TASK_LOG 路径、不进新会话。
- **进度核定导入**：按沙僧 `进度核定_dev201_20261029.md` 导入进度账与 `当前状态.json`（percent 64.0、asOf dev.201，复核点 50／75 不变）。复核补充已做：事件行覆盖数字换成 6912／6910 并写入条件类型新缺口，清掉 55.1、dev.154、193 图、149 角色、444 状态块、法宝未做、下次审查 50% 等残留（含步骤清单第 5 步）；合计行写明「dev.202～220 增量未核，另记」。楼层行另记一行 Claude 初值：dev.222 切片 201 图，31＋(201−87)/231×100≈80.4%，未计入合计。`进度账.py --check --as-of dev.201` 通过。
- **工具自测偶发**：`测试合并工具.py` 的 `test_timings_record_child_user_cpu`，假 Godot 按墙钟空转 0.3 秒，机器满时 user CPU 不足 0.1 而偶发；改固定迭代数。
- 派活第 2、3 项（hostScope 说明字段、首次同步建 `.sandbox/slice`）哪吒_8 dev.219 已做，跳过。唐僧让顺手查八戒 alien-gaps 期间仍手生成接受单的原因：见下「可优化」。

## 交接板

- 下一步：「工具可优化」⑤（hostScope）已在 dev.219 做，可删；③（首次同步 ENOENT）同；⑥之外无新增。
- 需要用户决定：无。

## 进度账

- 总进度 64.0%（沙僧核定，asOf dev.201），已导入；楼层行 Claude 初值按 201 图记一行（≈80.4%），不覆盖 64.0 核定。

## 可优化（流程／工具／效率）

- 八戒 alien-gaps（dev.221 已合 main）：`04_验证/测量接受/` 里没有 alien-gaps 的接受单、其交付单也没提手生成接受单，没查到 tools8 规则漏字段的证据；alien 系列旧接受单（alien-affix 等）是 dev.219 之前的 hostScope 描述，该规则之后没再出现。
- 已做：测试公共时钟夹具（`tests/test_main_loop.gd`；回退＝删该文件，`并行测试.py` 自动不挂）。
- 建议（总装派内容车道）：条件类型 9／10（武器／防具）在 `mv_event_core.gd::_condition` 补分支（9 hasWeapon、10 hasArmor，参数 [9, 武器号, 含装备]），修后 `--update-baseline`；7 页 9 处。
- 其他测试若需要别的真实时钟/随机固定，可加进 `test_main_loop.gd`。

## 本分支提交

见 `git log claude/nezha-tools10 ^9bfcae6e`。

## 验证

- `测试合并工具.py` 195/195、`测试增量同步.py`、`测试内容覆盖.py` 4/4、`测试选测.py` 47/47 通过。
- 内容覆盖 `--check`：基线更新后无基线外新问题。
- 选测结果见下一行（本机满载，若未写则未跑完）。
