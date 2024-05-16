#!/usr/bin/env ksh

set -euo pipefail




_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type=""
_type="Unkown"
_conf="relayd.conf"
_target_dir="/etc"
_source_dir_temp="."
_source_dir=".conf"
_hostname="$(hostname)"
_tmp=""

cd "${_scriptdir}"

. ../assets/scripts/global.sh

__deploy_relayd() {

    local check=""
    _tmp=$(mktemp /tmp/temail.XXXXXXX.relayd)
    trap "$(_show_clean 3 ${_tmp})" ERR EXIT


    _message "1info" 'Deploying relayd Configuration...'

    _target_dir="/etc"
    _source_dir="${1}"
    [  -d "$_source_dir" ] || \
        _message "1Error" "Source dir: ${_source_dir} cannot be found"

    check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "$_conf")
    _apply_changes 1 "$check" "$_source_dir" "${_target_dir}" "chown root:wheel; chmod 600"

    _message "2info" 'Checking relayd Configuration...'
    $__ relayd -n > "$_tmp" 2>&1
    if [ -s ${_tmp} ]; then
        _show 3 $_tmp
        grep -qi "configuration ok" $_tmp || \
           _message "3Error" "Configuration check failed!"
        rm -f "$_tmp"
    fi
    _message "2info" 'Checking relayd Configuration done!'

    if [ "$($__ rcctl get relayd flags)" == "NO" ]; then
        _message '1info' 'Enabling httpd service'
        $__ rcctl enable relayd >/dev/null
        $__ rcctl start relayd >/dev/null
    elif pgrep -xq relayd; then
        _message '1info' '(Re)Loading relayd configuration'
        $__ relayctl reload >/dev/null
    else
        _message '1info' '(Re)Starting relayd service'
        $__ rcctl restart relayd >/dev/null
    fi

    _message "1info" 'Deploying relayd Configuration done!'
}


# relayd
_message "info" 'Initializing/Updating realyd...'

_source_dir_temp="$(mktemp -d /tmp/temail.XXXXXXX.relayd)"
trap "$(_clean $_source_dir_temp)" ERR EXIT

case "$1" in

    C*) # Controller
        cp -Rf "./conf/"*  "${_source_dir_temp}/"
        find "$_source_dir_temp" -type f \
            -exec sed -i \
            -e "s/@tlsname@/${_hostname}/g" \
            {} +
        __deploy_relayd "${_source_dir_temp}"
    ;;
    M*) # Mail
        _message 'Error' 'Mail server type is not supported'
    ;;
    *) # Error
        _message 'Error' 'Unknown server type'
    ;;


esac
_message 'Info' 'relayd setup completed!'

cd "${_curpwd}"
