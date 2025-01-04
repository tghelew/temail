#!/usr/bin/env ksh

set -euo pipefail

_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type=""
_tmp=$(mktemp -d /tmp/temail.XXXXXXX.pf)
cd "${_scriptdir}"

_deploy_anchor=""

. ../assets/scripts/global.sh

trap "$(_clean $_tmp)" ERR EXIT

case "$1" in
    C*) # Controller
        cp -f './controller_pf.conf' "${_tmp}"/pf.conf
    ;;
    M*) # Mail Server
        cp -f './mail_pf.conf' "${_tmp}"/pf.conf
        _deploy_anchor="yes"
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
_anchor_dir="/etc/pf/anchors"


[ -d $_target_dir ] || $__ mkdir -p $_target_dir
[ -d $_anchor_dir ] || $__ mkdir -p $_anchor_dir

_message "1info" 'Deploying tables and scripts...'
_check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
_apply_changes 1 "$_check" "$_source_dir" "${_target_dir}" "chown root:wheel"

[ ! -f "${_target_dir}/t_bruteforce" ] && $__ touch "${_target_dir}/t_bruteforce"
[ ! -f "${_target_dir}/t_blocked" ] && $__ touch "${_target_dir}/t_blocked"
_message "1info" 'Deploying tables and scripts done!'

_message "1info" 'Deploying pf configuration...'
_source_dir="${_tmp}"
_target_dir="/etc"
_check=$(_check_diff -s "${_source_dir}" -t "${_target_dir}" -f "*")
_apply_changes 1 "$_check" "$_source_dir" "${_target_dir}" "chown root:wheel; pfctl -f"
if [[ -n "$_deploy_anchor" ]]; then
    _message "2info" 'Deploying anchors...'
    _source_dir="./anchors"
    _target_dir="$_anchor_dir"
    _check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
    _apply_changes 2 "$_check" "$_source_dir" "${_target_dir}" "chown root:wheel"

    /bin/sh /etc/pf/x_manage_anchor -D -f -d "$_target_dir"
    _message "2info" 'Deploying anchors done'
fi

_message "1info" 'Deploying pf configuration done!'


# crontab
cat <<-EOF | _update_crontab 1 'pf' 'root'
#----------------------------------------------pf Start------------------------------------------------------
0~7     6       *       *       *       -ns $SHELL /etc/pf/x_expire_table 86400 blocked bruteforce
*/10    *       *       *       *       -ns $SHELL /etc/pf/x_manage_table
0~20    4       */2     *       *       -ns $SHELL /etc/pf/x_manage_anchor -d /etc/pf/anchors
#----------------------------------------------pf End--------------------------------------------------------
EOF
_message 'Info' 'PF setup completed!'
cd "${_curpwd}"
