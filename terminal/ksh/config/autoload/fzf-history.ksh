#!/usr/bin/env ksh
set -euo pipefail

fzf-history-widget () {
	local selected num
	selected="$(fc -rl 1 | awk '{ cmd=$0; sub(/^[ \t]*[0-9]+\**[ \t]+/, "", cmd); if (!seen[cmd]++) print $0 }' |
    FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} ${FZF_DEFAULT_OPTS-} -n2..,.. --scheme=history --bind=ctrl-r:toggle-sort,ctrl-z:ignore ${FZF_CTRL_R_OPTS-} +m" fzf)"
	local ret=$?
    if [ -n "$selected" ]; then
        num=$(echo "$selected" | awk '{print $1}')
        fc $num
    fi
	return $ret
}
