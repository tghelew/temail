#!/usr/bin/env ksh

set -euo pipefail

_curpwd="${PWD}"
_scriptdir="${0%/*}"
_hostname_full=$(hostname)
_hostname=$(hostname -s)
typeset -U _type="$1"

cd "${_scriptdir}"
. ../assets/scripts/global.sh

_source_dir=""
_target_dir=""
_check=""
_packages=./packages.conf

__deploy_config_section() {
    local tmp="$(mktemp -d /tmp/temail.XXXXXXX.smtp)"
    trap "$(_clean $tmp)" ERR

    local section="$1"
    local source="$2"
    local target="$3"
    local action="${4:-no}"
    _message "1Info" "Deploying $section configuration..."

    [ "$(ls -1A "${source}")" ] || \
        {
            _message "1Warning" "Source: $source is empty skipping!"
             return
        }

    cp -Rf "${source}"/*  "${tmp}/"

    _message "2info" "Replacing templates in configuration files..."
    find "$tmp" -type f \
        -exec sed -i \
        -e "s/@hostname@/${_hostname_full}/g" \
        -e "s/@host@/${_hostname}/g" \
        {} +
    _message "2info" "Replacing templates in configuration files done!"

    check=$(_check_diff -s "$tmp" -t "${target}" -f "*")
    _apply_changes 1 "$check" "$tmp" "${target}" "${action##no*}"
    _message "1Info" "Deploying $section configuration done!"

    [ -d $tmp ] && rm -rf $tmp

}

_deploy_config() {
    local source="$1"
    __deploy_config_section "smtpd common" "./common" "/etc/mail"
    __deploy_config_section "smtpd" "$source" "/etc/mail"
}

_deploy_sql() {
    _message "1info" "Deploy sql views..."
    local tmp=$(mktemp /tmp/temail.XXXXXXX.smtpd)
    trap "$(_show_clean 2 $tmp)" ERR

    for file in $(find ./db -type f); do
        _message "2info" "Deploying sql views in file: $file ..."
        psql -U vmail -d vmail -q  -X -f "$file"  > "${tmp}" 2>&1
        _show 2 "$tmp"
    done
    [ -f $tmp ] && rm -rf "$tmp"
    _message "1info" "Deploy sql file done!"
}

_start_service() {
    _message "1info" "Checking Configuration"

    local tmp=$(mktemp /tmp/temail.XXXXXXX.smtpd)

    set +e
     $__ newaliases > ${tmp} 2>&1
     $__ smtpd -n >${tmp} 2>&1
    set -e

    if  ! grep -q 'configuration OK' ${tmp}; then
        _show 1 $tmp
        rm -f $tmp
        _message "1Error" "Wrong Smtpd Configuration!"
    fi

    [ -f $tmp ] && rm -f $tmp

    if [ "$($__ rcctl get smtpd flags)" == NO ]; then
        _message "1info" "Enabling & Starting smtpd..."
        $__ rcctl enable smtpd > /dev/null
        $__ rcctl start smtpd > /dev/null
        _message "1info" "Enabling & Starting smtpd done!"
    elif $(pgrep -q 'smtpd'); then
        _message "1info" "Re-Starting smtpd..."
        $__ rcctl restart smtpd > /dev/null
        _message "1info" "Re-Starting smtpd done!"
    else
        _message "1info" "Starting smtpd..."
        $__ rcctl start smtpd > /dev/null
        _message "1info" "Starting smtpd done!"
    fi
}

# smtpd
_message "info" 'Initializing/Updating smtpd...'


_run_checks "smtpd smtpctl"

case "$_type" in
    M*) # Mail Server
        _add_packages $_packages
        _deploy_config "./mail"
        _start_service

    ;;
    C*) # Controller
        _deploy_config "./controller"
        _deploy_sql
        _start_service
    ;;
    *) # Error
        _message 'Error' 'Unknow type of deploy command'
    ;;

esac
_message "info" 'Initializing/Updating smtpd done!'
cd "${_curpwd}"
