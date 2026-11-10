#!/bin/zsh
# 总装 2026-11-09 列的十个旧工作树：内容都已在提交里（暂存区等于各自的 WIP 提交），
# 未入库的三个小文件已备份到 .git/tangseng/旧工作树备份_1109/。分支和提交都不删，只删工作树目录。
R=/Users/kyo/Documents/再刷项目资料库
B=$R/.claude/worktrees
df -h /Users/kyo | tail -1 | awk '{print "清理前可用",$4}'
for n in charming-chatterjee-a967ac infallible-bardeen-b4507c nostalgic-curie-5a2b2d zen-haibt-c9af58 sharp-kapitsa-ff9fc1 wukong-events3b elastic-ritchie-52f9e4 elated-chatelet-b43f1e nervous-cray-217a9d agitated-matsumoto-25d1e6; do
  if lsof -a -d cwd -Fn 2>/dev/null | grep -q "worktrees/$n"; then echo "跳过（有进程在用）: $n"; continue; fi
  git -C $R worktree remove --force $B/$n && echo "已删: $n" || echo "没删掉: $n"
done
git -C $R worktree prune
df -h /Users/kyo | tail -1 | awk '{print "清理后可用",$4}'
