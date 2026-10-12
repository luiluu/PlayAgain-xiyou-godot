#!/bin/zsh
# 【Codex·未经Claude检验】 Open the canonical project when it exists.
set -e
godot_env_dir="${0:A:h}"
godot_project_dir="$godot_env_dir/../01_Godot工程"
if [[ -f "$godot_project_dir/project.godot" ]]; then
  open -a "$godot_env_dir/当前Godot.app" --args --editor --path "$godot_project_dir"
else
  open -a "$godot_env_dir/当前Godot.app" --args --project-manager
fi
