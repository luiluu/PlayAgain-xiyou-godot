#!/bin/zsh
# Open the canonical project when it exists.
# -n: always start a new instance; without it, `open` only activates a running Godot (e.g. the game) and drops --args.
set -e
godot_env_dir="${0:A:h}"
godot_project_dir="$godot_env_dir/../01_Godot工程"
if [[ -f "$godot_project_dir/project.godot" ]]; then
  open -n -a "$godot_env_dir/当前Godot.app" --args --editor --path "$godot_project_dir"
else
  open -n -a "$godot_env_dir/当前Godot.app" --args --project-manager
fi
