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
_serviceconf=./services.conf
_servicefile=$(mktemp /tmp/temail.XXXXXXX.spamd)

trap "$(_clean $_servicefile)" ERR EXIT

__deploy_spamd(){
_message "1info" 'Deploying spamd configuration...'
_source_dir=./conf
_target_dir=/etc/mail
_check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
_apply_changes 1 "$_check" "$_source_dir" "${_target_dir}" "chown root:wheel"

_source_dir=./db
_target_dir=/var/db/

_check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
_apply_changes 1 "$_check" "$_source_dir" "${_target_dir}" "chown root:wheel"

_message "2info" "Running initial spamdb script..."
$__ sh /etc/mail/x_spamd_update_allowed_domain
_message "2info" "Running initial spamdb script done!"

_source_dir=./pf
_target_dir=/etc/pf

_check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
_apply_changes 1 "$_check" "$_source_dir" "${_target_dir}" "chown root:wheel;pfctl -a spamd -f"


_message "1info" 'Deploying spamd configuration done!'
}

__deploy_scripts(){
_message "1info" 'Deploying Scripts...'
_source_dir="./scripts"
_target_dir="/usr/local/bin"

_check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
_apply_changes 1 "$_check" "$_source_dir" "${_target_dir}" "chmod +x"

_message "1info" 'Deploying Scripts done!'
}

__deploy_crontab(){
cat <<-EOF | _update_crontab 1 'spamd' 'root'
#----------------------------------------------spamd Start------------------------------------------------------
~       *       *       *       *       /usr/libexec/spamd-setup
~       */4     *       *       *       -ns $SHELL /etc/mail/x_spamd_update_allowed_domain
#----------------------------------------------spamd End--------------------------------------------------------
EOF
}

__start_service(){
_message "1info" 'Starting/Reloading services...'

_read_conf $_serviceconf $_servicefile 'Service'
typeset -l name cert_file cert_key interface target hostname
local sflags="" lflags=""
hostname=$(hostname -s)
while read -u name interface target cert_file cert_key; do
    [ "$name" != "$hostname" ] && continue
    [ "x$name"      == "x"  ] && _message "1Error" "Name cannot be empty"
    [ "x$interface" == "x"  ] && _message "1Error" "Interface cannot be empty"
    [ "x$target"    == "x"  ] && _message "1Error" "Target cannot be empty"
    [ "x$cert_file" == "x"  ] && _message "1Error" "Certificate cannot be empty"
    [ "x$cert_key"  == "x"  ] && _message "1Error" "Certificate Key cannot be empty"

    [ "$interface" != no ] && sflags=$sflags${sflags:+ }"-y $interface"
    [ "$target" != no ] && \
        {
        sflags=$sflags${sflags:+ }"-Y $target"
        lflags=$lflags${lflags:+ }"-Y $target"
        }
    [ "$cert_file" != no ] && sflags=$sflags${sflags:+ }"-C $cert_file"
    [ "$cert_key" != no ] && sflags=$sflags${sflags:+ }"-K $cert_key"
done < "$_servicefile"

local curflags=$($__ rcctl get spamd flags)
if [ "$curflags" != "$sflags" ]; then
    _message '2info' 'Enabling/Updaging spamd service'
    $__ rcctl enable spamd >/dev/null
    $__ rcctl set spamd flags "$sflags" >/dev/null

    if $(pgrep -q spamd); then
        _message '2info' 'Re-starting spamd configuration'
        $__ rcctl restart spamd >/dev/null
    else
        _message '2info' 'Starting spamd service'
        $__ rcctl start spamd >/dev/null
    fi
fi

curflags=$($__ rcctl get spamlogd flags)
if [ "$curflags" != "$lflags" ]; then
    _message '2info' 'Enabling/Updating spamlogd service'
    $__ rcctl enable spamlogd >/dev/null
    $__ rcctl set spamlogd flags "$lflags" >/dev/null

    if $(pgrep -q spamlogd); then
        _message '2info' 'Re-starting spamlogd configuration'
        $__ rcctl restart spamlogd >/dev/null
    else
        _message '2info' 'Starting spamlogd service'
        $__ rcctl start spamlogd >/dev/null
    fi
fi
_message "1info" 'Starting/Reloading services done!'
}

# spamd
_message "info" 'Initializing/Updating spamd...'
_run_checks "pfctl hostname"

case "$_type" in
    M*) # Mail Server
        __deploy_scripts
        __deploy_spamd
        __deploy_crontab
        __start_service
    ;;
    C*) # Controller
        _message 'Error' 'Spamd cannot be deployed on Controller'
    ;;
    *) # Error
        _message 'Error' 'Unknow type of deploy command'
    ;;

esac
_message "info" 'Initializing/Updating spamd done!'
cd "${_curpwd}"
