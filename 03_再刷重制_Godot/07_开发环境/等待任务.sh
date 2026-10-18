#!/bin/zsh
set -eu
exec python3 "${0:A:h}/长任务.py" wait "$@"
