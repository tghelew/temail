#!/usr/bin/env ksh

set -euo pipefail



_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type=""
_pfconf=""

cd "${_scriptdir}"

. ../assets/scripts/global.sh

case "$1" in
    C*) # Controller
        _pfconf='controller_pf.conf'
    ;;
    M*) # Mail Server
        _pfconf='mail_pf.conf'
    ;;
    *) # Error
        _message 'Error' 'Unknow type of deploy command'
    ;;


esac

_run_checks "pfctl"

# tmux
_message "info" 'Initializing/Updating pf...'
_isnew=y
_target="/etc/pf"

if [[ -d "${_target}" ]]; then
    _message 'info' 'PF is already configured, updating...'
    _isnew=n
fi
if [[ $_isnew == "n" ]]; then
    # Do not copy bruteforce nor blocked tables
    $__ cp -fpv ./pf/!(blocked|bruteforce) "${_target}/"
else
    $__ mkdir -p "${_target}"
    $__ cp -Rfpv ./pf/. "${_target}"/

fi
$__ cp -fpv ./$_pfconf /etc/pf.conf
$__ chown -RL root:wheel "${_target}" /etc/pf.conf

$__ pfctl -f /etc/pf.conf
_message 'Info' 'PF setup completed!'

cd "${_curpwd}"
