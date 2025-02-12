#!/usr/bin/env ksh

set -euo pipefail

_curpwd="${PWD}"
_scriptdir="${0%/*}"
_packages=./packages.conf
typeset -U _type=""
_tmp=$(mktemp -d /tmp/temail.XXXXXXX.backup)
cd "${_scriptdir}"

. ../assets/scripts/global.sh

trap "$(_clean $_tmp)" ERR EXIT

case "$1" in
    C*) # Controller
        cp -f './scripts/controller' "${_tmp}"/temail-backup
    ;;
    M*) # Mail Server
        if [ -f './scripts/mail' ]; then
            cp -f './scripts/mail' "${_tmp}"/temail-backup
        fi
    ;;
    *) # Error
        _message 'Error' 'Unknow type of deploy command'
    ;;
esac

_run_checks "rsync"

# pf
_message "info" 'Initializing/Updating backup...'
_add_packages $_packages

_check=""

_source_dir="$_tmp"
_target_dir="/usr/local/bin"


[ -d $_target_dir ] || $__ mkdir -p $_target_dir

_message "1info" 'Deploying script...'
_check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
_apply_changes 1 "$_check" "$_source_dir" "${_target_dir}" "chown root:bin"
_message "1info" 'Deploying scripts done!'

# crontab
cat <<-EOF | _update_crontab 1 'backup' 'root'
#----------------------------------------------backup Start------------------------------------------------------
0~30     3       *       *       *       -ns $SHELL /usr/local/bin/temail-backup
#----------------------------------------------backup End--------------------------------------------------------
EOF
_message 'Info' 'Backup setup completed!'
cd "${_curpwd}"
