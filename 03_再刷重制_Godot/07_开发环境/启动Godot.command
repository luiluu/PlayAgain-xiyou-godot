#!/bin/zsh
# Open the installed project manager.
# -n: always start a new instance; without it, `open` only activates a running Godot (e.g. the game) and drops --args.
set -e
godot_env_dir="${0:A:h}"
open -n -a "$godot_env_dir/当前Godot.app" --args --project-manager
