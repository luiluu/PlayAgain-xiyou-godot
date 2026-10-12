#!/bin/zsh
# 直接试玩本库的 Godot 重制版；新建自己的游戏窗口，不关闭现有编辑器或游戏。
set -e
godot_env_dir="${0:A:h}"
godot_project_dir="$godot_env_dir/../01_Godot工程"
open -n -a "$godot_env_dir/当前Godot.app" --args --path "$godot_project_dir"
