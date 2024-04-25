#!/usr/bin/env ksh

if type colorls 2>&1 >/dev/null; then
    export CLICOLOR=1
    # man colorls /ENVIRONMENT
    export LSCOLORS='exfxcxdxbxGxDxabagacad'
fi

if type ggrep 2>&1 >/dev/null; then
    export GREP_COLORS='mt=37;45'
fi

mkdir -p $HOME/.local/share/ksh
mkdir -p $HOME/.local/share/psql

#NOTE: This is required for tmux to work properly.
export LC_CTYPE=en_US.UTF-8

export HISTFILE=$HOME/.local/share/ksh/history
export HISTSIZE=10000
export HISTCONTROL=ignoredups:ignorespace

export TMUX_HOME=$HOME/tmux

[ -d /var/postgresql ] && export PGDATA=/var/postgresql/data
[ -d /var/postgresql ] && export PSQL_HISTORY=$HOME/.local/share/psql/history
