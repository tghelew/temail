#!/usr//bin/env ksh
set -euo pipefail

# DEBUG
# Set to anything but n to activate
DEBUG=n
[ $DEBUG != 'n' ] && set -x

__='doas -n '

_message () {
   [ $DEBUG != 'n' ] && set -x
   typeset -u mtype # all value are converted to upper case
   mtype=${1:-"Error"}
   shift
   if [[ ${mtype} == "ERROR"  ]]; then
      >&2 printf "%s: %s\n" $mtype "${@:-\"Something happends...\"}"
      exit 1
   else
       printf "%s: %s\n" $mtype "${@:-\"Something happends...\"}"
   fi
}

_run_checks () {
    [ $DEBUG != 'n' ] && set -x
    set -A  cmds $@
    set -A missing "x"

    local i=1
    for c in "${cmds[@]}"; do
        if ! type "${c}" 2>&1 >/dev/null; then
            missing[$i]="${c}"
            (( i += 1 ))
        fi
    done
    if [ ${#missing[@]} -gt 1 ]; then
        _message "Error" "Missing program(s): ${missing[@]}"
    fi
}

_add_packages () {
    if [ -f "${1}" ]; then
        _message "Info" "Installing additional package(s)..."
        $__ pkg_add -Vvl "${1}"
        _message "Info" "Done: Installing additional package(s)"
    else
        _message "Error" "file ${1} cannot be found!"
    fi
}

_update_crontab () {
    _run_checks "id sed crontab cat"

    local tmpfile=$(mktemp /tmp/temail.XXXXXXX.crontab)
    trap "[ -f $tmpfile ] && rm -f $tmpfile" ERR

    local location="$1"
    [ -z $location ] && \
        _message 'Error' "The location in the cron file cannot be empty"

    local user="${2:-root}"
      id -u $user >/dev/null 2>&1 ||  \
        _message 'Error' "The user $user does not exist"
    shift ${#@}

    $__ crontab -l > $tmpfile

    # Remove previous entries which must must be like:
    # #-$location Start---
    # #-$location End---
    sed -Ei "/^#-+$location[[:space:]]+Start/,/^#-+$location[[:space:]]+End/D" $tmpfile

    # add new cron tab
    while read -u  ctab 2>/dev/null; do
        print "$ctab"  >> $tmpfile
    done

    $__ crontab -u $user $tmpfile


    [ -f $tmpfile ] && rm -f $tmpfile

}
