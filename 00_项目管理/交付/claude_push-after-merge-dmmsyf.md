# 交付：claude/push-after-merge-dmmsyf

- 车道／工作者：工具／Claude（云端会话，架构审查后续：合并后推送 GitHub）
- 状态：可合并

## 变更记录草稿

## 2026-10-18 【Claude·云端·未经Codex检验】合并后自动推送 main 到 GitHub

- 用户方向：2026-10-18 用户同意每次合并后把 main 推到 GitHub，取代原来的「GitHub 重制完成再推」；云端分支由唐僧在 Mac 上像车道一样合并，不用 GitHub 的合并按钮，Mac main 仍是唯一原件。
- `合并车道.py --finish` 在提交、清理全部完成后调用 `push_github()`：有名为 `github` 的远端时先 `ls-remote`／`fetch` 它的 main；GitHub 有本地 main 没有的提交就列出并跳过，从不强推；否则 `git push github main`。远端不通、认证失败或超时（120 秒，`GIT_TERMINAL_PROMPT=0` 不卡在密码提示）只打印一行警告，合并照样退出 0，下次合并补推。没有 `github` 远端就跳过。
- `测试合并工具.py` 加 3 项（临时裸库作远端）：推送成功、远端不通只警告、远端领先时不推且远端提交不动；`合并提速工具.md` 补第 5 步说明。
- 验证：云端补装 zsh 后 `测试合并工具.py` 52/52（原 49 项＋新增 3 项）。没跑 `检查.sh --oracle`（只改合并工具与文档，云端无冻结正式源）。
- 与 PR #4（`claude/review-codex-changes-7swxg0`，改 `draft()` 并在测试文件前部加 `DraftTests`）改的是同两个文件的不同位置，两边先后合并都不会冲突；都合并后测试应为 54 项。

## 交接板

- 唐僧行：删掉第④项「GitHub 重制完成再推」，改为「每次合并 --finish 后自动推 main 到 `github` 远端，失败只警告」。
- 合并前请确认 Mac 主工作区指向 GitHub 的远端名叫 `github`（`git remote -v`）。若叫 `origin`，执行 `git remote rename origin github`，或 `git remote add github https://github.com/luiluu/PlayAgain-xiyou-godot`；否则工具会打印「无 github 远端，跳过推送」。
- AGENTS.md「多会话并行」流程第 4 步（合并）末尾建议加一句：「`--finish` 最后把 main 推到 GitHub（`github` 远端；GitHub 有本地没有的提交时不推，人工核对）。云端分支也由总装在 Mac 上照车道合并，不用 GitHub 合并按钮。」本分支未改 AGENTS.md，由唐僧决定措辞并写入。
- 用户试玩说明：无（只改合并工具）。

## 进度账

- 不变。

## 本分支提交

- 合并车道 --finish 后推送 GitHub、三项回归、文档、本交付单。
