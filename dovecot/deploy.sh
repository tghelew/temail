#!/usr/bin/env ksh

set -euo pipefail



_curpwd="${PWD}"
_scriptdir="${0%/*}"

cd "${_scriptdir}"

. ../assets/scripts/global.sh

typeset -U _type=""
_type="Unkown"
_target_dir="/etc"
_source_dir_temp="."
_source_dir="."
_tmp=""
_hostname="$(hostname -s)"
_replica="$(grep -Ev "${_hostname}|#.*" mail.conf | head -n 1)"

# dovecot
_source_dir_temp="$(mktemp -d /tmp/temail.XXXXXXX.dovecot)"
trap "$(_clean $_source_dir_temp)" ERR EXIT

__deploy_login_conf() {
   _message '1info' 'Deploying login.conf.d ...'
   local source_dir="./login.conf.d" target_dir="/etc/login.conf.d" check=""
    check=$(_check_diff -s "$source_dir" -t "${target_dir}" -f "*")
    _apply_changes 1 "$check" "$source_dir" "${target_dir}"
   _message '1info' 'Deploying login.conf.d done!'
}

__deploy_group_membership() {
    local group="vmail"
   _message '1info' "Adding group $group to dovecot user ..."
    group info -e $group || _message "2Error" "Group: $group does not exitst!"
    if $(grep -q "${group}.*dovecot" /etc/group); then
        _message "2info" "dovecot user is already memeber of group: $group"
    else
        $__ user mod -S $group _dovecot
    fi
   _message '1info' "Adding group $group to dovecot user done!"

}

__deploy_scripts() {
   _message '1info' "Deploying bin scripts..."
   _source_dir=./bin
   _target_dir=/usr/local/bin

    check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
    _apply_changes 1 "$check" "$_source_dir" "${_target_dir}" "chmod +x;chown root:bin"

   _message '1info' "Deploying bin scripts done!"

   _message '1info' "Deploying sieve scripts..."
   _source_dir=./sieve
   _target_dir=/usr/local/lib/dovecot/sieve

    check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
    _apply_changes 1 "$check" "$_source_dir" "${_target_dir}" "sievec;chown root:bin"

   _message '1info' "Deploying sieve scripts done!"


}

__deploy_config() {

    _source_dir="./conf"
    _target_dir="/etc/dovecot"
    local check=""
    local marker_file=".temail"

    _tmp=$(mktemp /tmp/temail.XXXXXXX.dovecot)
    trap "$(_show_clean 3 $_tmp)" ERR EXIT

   _message '1info' "Deploying configuration..."
   cat <<-EOF > "${_source_dir_temp}/$marker_file"
## DO NOT DELETE!! ########################################################################################
This is a marker file to detect changes in configuration.
$(find "$_source_dir" -type f)
###########################################################################################################
EOF
   cp -Rf "${_source_dir}"/*  "${_source_dir_temp}/"

   _message "2info" "Replacing templates in configuration files..."
   find "$_source_dir_temp" -type f \
       -exec sed -i \
                 -e "s/@hostname@/${_hostname}/g" \
                 -e "s/@replica@/${_replica}/g" {} +
   _message "2info" "Replacing templates in configuration files done!"

   # Remove default & huge configuration.
   [ -f "${_target_dir}"/.temail ] || {
       _message "2info" "Removing default configuration..."
       $__ rm -rf "${_target_dir}/"
       $__ mkdir -p "$_target_dir"
       _message "2info" "Removing default configuration done!"
   }
    check=$(_check_diff -s "$_source_dir_temp" -t "${_target_dir}" -f "*")
    _apply_changes 1 "$check" "$_source_dir_temp" "${_target_dir}"

    _message "2info" "checking configuration..."
    doveconf -n 2> "$_tmp" >/dev/null
    _message "2info" "checking configuration done!"

   _message '1info' "Deploying configuration done!"

}

_message "info" 'Initializing/Updating dovecot...'
_run_checks "dovecot doveadm doveconf"

_add_packages ./packages.conf

case "$1" in

    M*) # mail
        _type="mail"
        __deploy_login_conf
        __deploy_group_membership
        __deploy_config
        __deploy_scripts
    ;;
    C*) # Controller
        _message 'Error' 'Dovecot not supported on controller!'
    ;;
    *) # Error
        _message 'Error' 'Unknown server type'
    ;;
esac

if [ "$($__ rcctl get dovecot flags)" == "NO" ]; then
    _message '1info' 'Enabling dovecot service'
    $__ rcctl enable dovecot >/dev/null
fi
if $($__ rcctl ls started | grep -q dovecot); then
    _message '1info' 'Reloading dovecot configuration'
    $__ doveadm reload
else
    _message '1info' 'Starting dovecot service'
    $__ rcctl start dovecot
fi
_message "info" 'Initializing/Updating dovecot done!'

cd "${_curpwd}"
