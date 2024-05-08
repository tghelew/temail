#!/usr/bin/env ksh

set -euo pipefail

_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type=""
_tmp=$(mktemp -d /tmp/temail.XXXXXXX.pf)
cd "${_scriptdir}"

. ../assets/scripts/global.sh

trap "$(_clean $_tmp)" ERR EXIT

case "$1" in
    C*) # Controller
        cp -f './controller_pf.conf' "${_tmp}"/pf.conf
    ;;
    M*) # Mail Server
        cp -f './mail_pf.conf' "${_tmp}"/pf.conf
    ;;
    *) # Error
        _message 'Error' 'Unknow type of deploy command'
    ;;


esac

_run_checks "pfctl"

# pf
_message "info" 'Initializing/Updating pf...'
_check=""
_source_dir="./pf"
_target_dir="/etc/pf"

_message "1info" 'Deploying tables, anchors, and scripts...'
_check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
_apply_changes 1 "$_check" "$_source_dir" "${_target_dir}" "chown root:wheel"
[ ! -f "${_target_dir}/t_bruteforce" ] && $__ touch "${_target_dir}/t_bruteforce"
[ ! -f "${_target_dir}/t_blocked" ] && $__ touch "${_target_dir}/t_blocked"
_message "1info" 'Deploying tables, anchors, and scripts done!'

_message "1info" 'Deploying pf configuration...'
_source_dir="${_tmp}"
_target_dir="/etc"
_check=$(_check_diff -s "${_source_dir}" -t "${_target_dir}" -f "*")
_apply_changes 1 "$_check" "${_source_dir}" "${_target_dir}" "chown root:wheel;pfctl -f"
_message "1info" 'Deploying pf configuration done!'

# crontab
cat <<-EOF | _update_crontab 1 'pf' 'root'
#----------------------------------------------pf Start------------------------------------------------------
0~7     6       *       *       *       -ns $SHELL /etc/pf/x_expire_table 86400 blocked bruteforce
*/10    *       *       *       *       -ns $SHELL /etc/pf/x_manage_table
#----------------------------------------------pf End--------------------------------------------------------
EOF
_message 'Info' 'PF setup completed!'

cd "${_curpwd}"
