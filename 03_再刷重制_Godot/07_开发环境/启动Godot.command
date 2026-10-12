#!/bin/zsh
# 【Codex·未经Claude检验】 Open the installed project manager.
set -e
godot_env_dir="${0:A:h}"
open -a "$godot_env_dir/当前Godot.app" --args --project-manager
