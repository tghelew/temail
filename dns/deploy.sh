#!/usr/bin/env ksh

set -euo pipefail



_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type="$1"

cd "${_scriptdir}"

. ../assets/scripts/global.sh


# dns BIND
_message "info" 'Initializing/Updating DNS...'
_isnew=y
_target_dir="/var/named"
_target_script="/usr/local/bin/named-adblock"

_run_checks "diff"


__apply_changes() {

    local check="${1}"
    local source="${2}"
    local target="${3}"

    local state=""
    local file=""
    local bck=$IFS
    local target_file

    local IFS=';'
    for c in $check; do
        state=$(echo "$c" | cut -d @ -f 1)
        file=$(echo "$c" | cut -d @ -f 2)
        case $state in
            S) _message "2info" "file: $file has not changed... skipping"
            ;;
            D) _message "2info" "file: $file has changed... deploying"
               IFS=$bck
               target_file="${target}/$file"
               $__ mkdir -p "${target_file%/*}"
               $__ cp -Rf "$file" "$target_file"
            ;;
            E) _message "2info" "file: $file is suspicious double checking!"
               if [ -f "$source/${file}" ]; then
                   _message "3info" "file: $file exist locally copying it!"
                   IFS=$bck
                   target_file="${target}/$file"
                   $__ mkdir -p "${target_file%/*}"
                   $__ cp -Rf "$source/$file" "$target_file"
               else
                   _message "3info" "file: $file doesn't exist locally skipping"
               fi
            ;;
            X) _message "2Warnig" "Unable to read dir: $file check that it exists or is readable."
            ;;
            *) _message "2Warnig" "Something happen during parsing of the command."
            ;;
        esac
    done
}

_deploy_common() {
    _message '1info' 'Deploying/Updating common'
    # check if file has changed:
    local source_dir="./common"
    local check=""
    _target_dir="/var/named"
    $__ mkdir -p "${_target_dir}"/{keys,etc,zones}

    check=$(_check_diff -s "$source_dir" -t "${_target_dir}/etc" -f "*.conf")
    __apply_changes "$check" "$source_dir" "$_target_dir/etc"

    $__ ln -sf "${_target_dir}/etc/rndc.conf" /etc/rndc.conf

    source_dir=./keys
    check=$(_check_diff -s "$source_dir" -t "${_target_dir}/keys" -f "*.key")
    __apply_changes "$check" "$source_dir" "$_target_dir/keys"

    $__ chown -RL root:_bind "${_target_dir}"/*
    $__ chmod  750 "${_target_dir}"/{keys,etc}
    $__ chmod -R 640 "${_target_dir}"/{keys,etc}/

    source_dir=./zones/common
    check=$(_check_diff -s "$source_dir" -t "${_target_dir}/zones" -f "*.zone")
    __apply_changes "$check" "$source_dir" "$_target_dir/zones"


    _message '1info' 'Deploying/Updating common done!'
}
_deploy_adzone() {
    _message '1info' 'Deploying/Updating adzone'

    local source_dir="./zones/virtual"
    local check=""
    _target_dir="/var/named/zones"

    check=$(_check_diff -s "$source_dir" -t "${_target_dir}" -f "*.zone")
    __apply_changes "$check" "$source_dir" "$_target_dir"

    _message '1info' 'Deploying/Updating adzone done!'
}

_deploy_adzone() {
    _message '1info' 'Deploying/Updating adzone'

    local source_dir="./zones/virtual"
    local check=""
    _target_dir="/var/named/zones"

    check=$(_check_diff -s "$source_dir" -t "${_target_dir}" -f "*.zone")
    __apply_changes "$check" "$source_dir" "$_target_dir"

    _message '2info' 'Deploying/Updating update script'

    source_dir='./scripts'
    _target_dir="/usr/local/bin"
    check=$(_check_diff -s "$source_dir" -t "${_target_dir}" -f "update-adblock*")

    _message '2info' 'Deploying/Updating script done!'

    _message '1info' 'Deploying/Updating adzone done!'
}

_add_packages ./packages.conf

# $__ rcctl stop named > /dev/null

case $_type in
    C*)
        _deploy_common
        _deploy_adzone
    ;;
    M*)
        _deploy_common
    ;;
    *)
        _message 'Error' 'Unknown deployment type.'
    ;;
esac
# $__ rcctl start named >/dev/null
_message 'Info' 'DNS setup completed!'

cd "${_curpwd}"
