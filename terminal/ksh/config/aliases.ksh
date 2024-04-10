#!/usr/bin/env ksh

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias q=exit
alias c=clear
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -pv'
alias get='ftp -Cnm '

# alias path='echo -e ${PATH//:/\\n}'
# alias ports='netstat -tulanp'
alias shutdown='doas shutdown'
alias reboot='doas reboot'


alias _='doas'
# I want to retain my prompt and functions
alias _r="doas -u root $SHELL -l"


if type colorls 2>&1 >/dev/null; then
  alias ls=colorls
fi

alias l='ls -1A'         # Lists in one column, hidden files.
alias ll='ls -lh'        # Lists human readable sizes.
alias lr='ll -R'         # Lists human readable sizes, recursively.
alias la='ll -A'         # Lists human readable sizes, hidden files.
alias lm='la | "$PAGER"' # Lists human readable sizes, hidden files through pager.
alias lk='ll -Sr'        # Lists sorted by size, largest last.
alias lt='ll -tr'        # Lists sorted by date, most recent last.
alias lc='lt -c'         # Lists sorted by date, most recent last, shows change time.
alias lu='lt -u'         # Lists sorted by date, most recent last, shows access time.
alias sl='ls'            # I often screw this up.

if type ggrep 2>&1 >/dev/null; then
  alias grep='ggrep --color=auto '
fi


alias pkga='pkg_add'
alias pkgd='pkg_delete'
alias pkgi='pkg_info'

# Resource Usage
alias df='df -kh'
alias du='du -kh'
alias dud='du -d 1'

alias topc='top -o cpu'
alias topm='top -o vsize'

# History

# Makes a directory and changes to it.
function mkdcd {
  [[ -n "$1" ]] && mkdir -p "$1" && builtin cd "$1"
}


function kman {
  PAGER="less -g -I -s '+/^       "$1"'" man ksh;
}

function alval {
  set -o noglob
  query="${@}"
  alias | grep -Ei "$query"
}
