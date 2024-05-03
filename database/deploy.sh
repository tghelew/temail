#!/usr/bin/env ksh

set -euo pipefail



_curpwd="${PWD}"
_scriptdir="${0%/*}"
_packages=./packages.conf

_source_dir=""
_custom_dir=""
_target_dir=/var/postgresql
_hostname=$(hostname -s)
_tmp=""
_check=""

cd "${_scriptdir}"

. ../assets/scripts/global.sh

__deploy_initdb() {

    _run_checks "pg_ctl"
    _tmp=$(mktemp /tmp/temail.XXXXXXX.database)
    _target_dir=/var/postgresql/data
    trap "$(_show_clean 3 ${_tmp})" ERR

    _message "1info" 'Maybe initializing database cluster...'

    if [ -d "${_target_dir}" ]; then
        _message "2info" "Database cluster is already initialized"
    else
        _message "2info" "Database cluster is not initialized..."
        $__ -u _postgresql pg_ctl -D "${_target_dir}" initdb > ${_tmp} 2>&1

    fi
    [ -f ${_tmp} ] && \
        {
            _show 3 $_tmp
            rm -f "$_tmp"
        }

    _message "1info" 'Maybe initializing database done!'
}

__deploy_standby() {

    _run_checks "pg_basebackup"
    _tmp=$(mktemp /tmp/temail.XXXXXXX.database)
    _target_dir=/var/postgresql/data
    trap "$(_show_clean 3 ${_tmp})" ERR

    _message "1info" 'Maybe initializing standby database...'

    if [ -d "${_target_dir}" ]; then
        _message "2info" "Standby Database is already initialized"
    else
        _message "2info" "Standby Database  is not initialized..."
        $__ -u _postgresql \
        pg_basebackup -h eshua.ghelew.ch -U replicator -S "${_hostname}_slot" -D "${_target_dir}" \
            -w -Fp -Xs -P -R > ${_tmp} 2>&1
    fi
    [ -f ${_tmp} ] && \
        {
            _show 3 $_tmp
            rm -f "$_tmp"
        }

    _message "1info" 'Maybe initializing standby database done!'
}

__deploy_common() {

    _target_dir=/etc/postgresql
    _source_dir=./common

    $__ mkdir -p "${_target_dir}"

    _message "1info" 'Deploying common configurations...'
    check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
    _apply_changes 1 "$check" "$_source_dir" "${_target_dir}"

    _message "1info" 'Deploying common configurations done!'
}

__deploy_custom() {

    _target_dir=/var/postgresql/data

    _message "1info" 'Deploying custom configurations...'
    check=$(_check_diff -s "$_custom_dir" -t "${_target_dir}" -f "*")
    _apply_changes 1 "$check" "$_custom_dir" "${_target_dir}"

    $__ sed -i "s/@name@/$_hostname/" "${_target_dir}/postgresql.conf"
    $__ chown -R _postgresql:_postgresql "${_target_dir}"

    _message "1info" 'Deploying custom configurations done!'
}

_message "info" 'Initializing/Updating Postgresql ...'

_add_packages "${_packages}"

case "$1" in
    C*) # Controller
        __deploy_common
        __deploy_initdb
        _custom_dir=./controller
        __deploy_custom
    ;;
    M*) # Mail Server
        __deploy_common
        _custom_dir=./mail
        __deploy_standby
    ;;
    *) # Error
        _message 'Error' 'Unknow type of deploy command'
    ;;

esac


if [ "$($__ rcctl get postgresql flags)" == "NO" ]; then
    _message '1info' 'Enabling postgresql service'
    $__ rcctl enable postgresql >/dev/null
    $__ rcctl start postgresql >/dev/null
else
    _message '1info' '(Re)Starting postgresql service'
    $__ rcctl restart postgresql >/dev/null
fi

_message "info" 'Initializing/Updating Postgresql done!'
_message "info" 'If needed prepare stand by mode as described in the ./databasde/README.org'


cd "${_curpwd}"
