#!/usr/bin/env ksh

# Max depth of dir prompt
# After only the first letter of the directories are shown.
export PROMPT_DIR_DEPTH=5

function _color {
    local -l name=$1
    shift
    local color=""
    case $name in
        "red") color='\033[1;31m' ;;
        "green") color='\033[1;32m' ;;
        "yellow") color='\033[1;33m' ;;
        "blue") color='\033[1;34m' ;;
        "magenta") color='\033[1;35m' ;;
        "cyan") color='\033[1;36m' ;;
        "white") color='\033[1;37m' ;;
        "default") color='\033[1;39m' ;;
        *);;
    esac
    print -n "${color}${@}\033[0m"
}

function _prompt_chars {
    local error=$1
    local uid=$(id -u)
    local output=""
    local char='❯'
    [[ $error -gt 0 ]] && char='❮'
    output=$(_color 'yellow' $char;_color 'blue' $char;_color 'green' $char; )
    if [[ $uid -eq 0 ]]; then
        output=$(_color 'red' "$char$char$char")
    fi
    print -n "$output"
}

function _prompt_pwd {
   local pwd="${PWD##$HOME}"
   local output=""
   [[ ${#pwd} != ${#PWD} ]] && pwd="~$pwd"
   set -A cdir $(echo $pwd | tr '/' ' ' )
   if [[ ${#cdir[*]} -ge $PROMPT_DIR_DEPTH ]]; then
       output=$(echo "${cdir[0]}" | cut -b -1)
       for i in $(seq 1 $(( ${#cdir[*]} - 1 ))); do
           if [[ $i -le $(( $PROMPT_DIR_DEPTH - 3 )) ]]; then
                output="${output}/$(echo "${cdir[$i]}" | cut -b -1)"
           else
               output="${output}/${cdir[$i]}"
           fi
       done
   else
       output="${pwd}"
   fi
   unset cdir
   _color 'blue' "$output"
}

function _prompt_show {
    case "${TERM:-dumb}" in
        xterm*|screen*|eterm*|rxvt*)
            print $(_color 'blue' "\u")$(_color 'default' "  ")$(_prompt_pwd)"\n"$(_prompt_chars $1)" "
        ;;
        *)
            print '\w \$ '
        ;;
    esac
}

PS1="\$(_prompt_show \$?)"
