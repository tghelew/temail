#!/usr/bin/env ksh

set -euo pipefail




_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type="$1"

cd "${_scriptdir}"

. ../assets/scripts/global.sh

local _source_dir=""
local _target_dir=""


# certbot
function _deploy_certbot {

    _run_checks "certbot"
    _message 'info' 'Starting Certbot setup'
    # create folders
    _target_dir=/var/certbot
    local _target_log_dir=/var/log/certbot
    _message '1info' 'Creating required folders...'
    $__ mkdir -p $_target_dir/{etc,db}
    $__ mkdir -p $_target_log_dir
    $__ chmod -R 755  $_target_dir $_target_log_dir
    _message '1info' 'Creating required folders done!'

    _message '1info' 'Copying files...'
    local check=""
    _source_dir=.
    _target_dir="/var/certbot/etc"
    check=$(_check_diff -s "$_source_dir" -t "$_target_dir" -f "*.ini")
    _apply_changes 1 "$check" "$_source_dir" "${_target_dir}"
    _message '1info' 'Copying files done!'

    _message '1info' 'Copying scripts...'
    local check=""
    _source_dir=./scripts/controller/
    _target_dir="/usr/local/bin"
    check=$(_check_diff -s "$_source_dir" -t "$_target_dir" -f "*")
    _apply_changes 1 "$check" "$_source_dir" "${_target_dir}"
    _message '1info' 'Copying scripts done!'

    # setup cronjob
    _message '1info' 'Updating crontab...'

    cat <<-EOF | _update_crontab 'certbot' 'root'
    #-----------------------------------certbot Start------------------------------------------------------------
    0~30     4      */5       *       *       -ns  /usr/loca/bin/certbot renew -c /var/certbot/etc/cli.ini -q
    #-----------------------------------certbot End--------------------------------------------------------------
EOF

    _message '1info' 'Updating crontab done!'
    _message 'info' 'Certbot setup completed make sure to generate your certificate(s)!'

}

function _deploy_sync_script {

    _run_checks "cp"
    _message 'info' 'Starting sync script deploymenet'
    _message '1info' 'Copying scripts...'
    local check=""
    _source_dir=./scripts/common/
    _target_dir="/usr/local/bin"
    check=$(_check_diff -s "$_source_dir" -t "$_target_dir" -f "*")
    _apply_changes 1 "$check" "$_source_dir" "${_target_dir}"
    _message '1info' 'Copying scripts done!'
    _message 'info' 'Starting sync script deploymenet done!'

}


_message "info" 'Initializing/Updating Certificate...'
case $_type in
    C*)
        _add_packages ./packages.conf
        _deploy_certbot
        _deploy_sync_script
    ;;
    M*)
        _deploy_sync_script
    ;;
    *)
        _message '1Error' 'Unknown deployment type.'
    ;;
esac
_message 'Info' 'Certificate Setup completed!'

cd "${_curpwd}"
