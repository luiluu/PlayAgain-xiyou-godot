#!/bin/zsh
# 默认准备合并；唐僧手改交接板/进度账后加 --finish 收尾；--dry-run 只读。
exec python3 "${0:A:h}/合并车道.py" "$@"
