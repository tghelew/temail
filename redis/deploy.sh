#!/usr/bin/env ksh

set -euo pipefail

_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type="$1"

cd "${_scriptdir}"
. ../assets/scripts/global.sh

_source_dir=""
_target_dir=""
_check=""
_packages=./packages.conf



__deploy_redis() {

    _message "1info" 'Deploying redis configuration...'
    $__ mkdir -p /var/redis/{etc,db}
    $__ chown -R _redis:_redis /var/redis/
    # Remove default etc file if any
    [ -d /etc/redis ] && $__ rm -rf /etc/redis
    _source_dir="$1"
    _target_dir=/var/redis/etc
    _check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
    _apply_changes 1 "$_check" "$_source_dir" "${_target_dir}" "chown _redis:_redis"
    _message "1info" 'Deploying redis configuration done!'
}

__deploy_redis_sentinel() {

    _message "1info" 'Deploying redis sentinel configuration...'
    local logfile=$(grep logfile sentinel.conf | cut -d' ' -f2 | tr -d '"')

    if [ -f $logfile ]; then
       local owner=$(stat -ln | cut -d ' ' -f3)
       [ "$owner" != '_redis' ] && $__ chown _redis $logfile

    else
        $__ touch $logfile && $__ chown _redis $logfile
    fi

    
    _source_dir="."
    _target_dir=/var/redis/etc
    _check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "sentinel.conf")
    _apply_changes 1 "$_check" "$_source_dir" "${_target_dir}" "chown _redis:_redis"
    _message "1info" 'Deploying redis sentinel configuration done!'

}

__deploy_service(){
    _message "1info" 'Starting/Reloading redis...'
    _source_dir=./rc
    _target_dir=/etc/rc.d
    _check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
    _apply_changes 1 "$_check" "$_source_dir" "${_target_dir}" "chown root:bin; chmod 655"

    if [ "$($__ rcctl get redis_server flags)" == NO ]; then
        $__ rcctl enable redis_server > /dev/null
        $__ rcctl start redis_server > /dev/null
    elif $(pgrep -qxf 'redis-server: /usr/local/bin/redis-server .*'); then
        $__ rcctl restart redis_server > /dev/null
    else
        $__ rcctl start redis_server > /dev/null
    fi

    if [ "$($__ rcctl get redis_sentinel flags)" == NO ]; then
        $__ rcctl enable redis_sentinel > /dev/null
        $__ rcctl start redis_sentinel > /dev/null
    elif $(pgrep -qxf 'redis-sentinel: /usr/local/bin/redis-sentinel .*'); then
        $__ rcctl restart redis_sentinel > /dev/null
    else
        $__ rcctl start redis_sentinel > /dev/null
    fi
    _message "1info" 'Starting/Reloading redis done!'
}
# redis
_message "info" 'Initializing/Updating redis...'

_run_checks ""

_add_packages $_packages

case "$_type" in
    M*) # Mail Server
        __deploy_redis ./mail
    ;;
    C*) # Controller
        __deploy_redis ./controller
    ;;
    *) # Error
        _message 'Error' 'Unknow type of deploy command'
    ;;

esac
__deploy_redis_sentinel
__deploy_service
_message "info" 'Initializing/Updating redis done!'
cd "${_curpwd}"
