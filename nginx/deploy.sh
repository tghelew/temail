#!/usr/bin/env ksh

set -euo pipefail




_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type=""
_type="Unkown"
_conf="nginx.conf"
_target_dir="/etc/nginx"
_conf_dir="conf.d"
_source_dir_temp="."
_source_dir="."
_tmp=""

cd "${_scriptdir}"

. ../assets/scripts/global.sh

__deploy_errors() {

    local check=""
    _tmp=$(mktemp /tmp/temail.XXXXXXX.nginx)

    trap "$(_show_clean 3 ${_tmp})" ERR EXIT

    _target_dir="/var/www/errors"
    _source_dir="./errors"

    $__ mkdir -p "$_target_dir"

    _message "1info" 'Deploying nginx default error pages...'

    check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
    _apply_changes 1 "$check" "$_source_dir" "${_target_dir}" "chown www:www"

    _message "1info" 'Deploying nginx default error pages done!'
}

__deploy_nginx() {

    local logs=/var/log/nginx
    local check=""
    _tmp=$(mktemp /tmp/temail.XXXXXXX.nginx)
    trap "$(_show_clean 3 ${_tmp})" ERR EXIT

    _message "1info" 'Deploying nginx main Configuration...'

    _target_dir="/etc/nginx"
    _source_dir="."
    [  -d "$_source_dir" ] || \
        _message "1Error" "Source dir: ${_source_dir} cannot be found"
    [ -d "$_target_dir/conf.d" ] || \
        $__ mkdir -p "$_target_dir/conf.d"

    if [ ! -d "$logs" ]; then
        $__ mkdir -p "$logs"
        $__ touch $logs/errors.log
        $__ touch $logs/access.log
        $__ chown -R www:www "$logs"
    fi

    check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "$_conf")
    _apply_changes 1 "$check" "$_source_dir" "${_target_dir}"

    _message "2info" 'Checking nginx Configuration...'
    $__ nginx -t > "$_tmp" 2>&1
    if [ -s ${_tmp} ]; then
        _show 3 $_tmp
        grep -qi "ok" $_tmp || \
           _message "3Error" "Configuration check failed!"
        rm -f "$_tmp"
    fi
    _message "2info" 'Checking nginx Configuration done!'


    if [ "$($__ rcctl get nginx flags)" == "NO" ]; then
        _message '1info' 'Enabling nginx service'
        $__ rcctl enable nginx >/dev/null
        $__ rcctl start nginx >/dev/null
    else
        _message '1info' '(Re)Starting nginx service'
        $__ rcctl restart nginx >/dev/null
    fi

    _message "1info" 'Deploying nginx Configuration done!'
}

_message "info" 'Initializing/Updating nginx...'

_add_packages ./packages.conf

_source_dir_temp="$(mktemp -d /tmp/temail.XXXXXXX.nginx)"
trap "$(_clean $_source_dir_temp)" ERR EXIT

case "$1" in

    C*) # Controller
        _type="controller"
        __deploy_nginx
        __deploy_errors
        _message "Info" "Deploying Nginx"
    ;;
    *) # Error
        _message 'Error' 'Unknown server type'
    ;;


esac
_message 'Info' 'Nginx setup completed!'

cd "${_curpwd}"
