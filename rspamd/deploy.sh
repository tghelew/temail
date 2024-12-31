#!/usr/bin/env ksh

set -euo pipefail

_curpwd="${PWD}"
_scriptdir="${0%/*}"
_hostname_full=$(hostname)
_hostname=$(hostname -s)
_domain=${_hostname_full#*.}
_twin=$([[ "$_hostname" == eshub ]] && echo "eshuc.$_domain" || echo "eshub.$_domain")

typeset -U _type="$1"

cd "${_scriptdir}"
. ../assets/scripts/global.sh

_source_dir=""
_target_dir=""
_check=""
_packages=./packages.conf

__deploy_config_section() {
    local tmp="$(mktemp -d /tmp/temail.XXXXXXX.rspamd)"
    trap "$(_clean $tmp)" ERR
    #FIXME: there's a bug where when apply_changes is called with an action
    #       the whole folder is deleted without an indication of any issue
    #       maybe nested trap ?

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
        -e "s/@twin@/${_twin}/g" \
        {} +
    _message "2info" "Replacing templates in configuration files done!"

    check=$(_check_diff -s "$tmp" -t "${target}" -f "*")
    _apply_changes 1 "$check" "$tmp" "${target}" "${action##no*}"
    _message "1Info" "Deploying $section configuration done!"

    [ -d $tmp ] && rm -rf $tmp

}

_deploy_config() {
    __deploy_config_section "local" "./local" "/etc/rspamd/local.d"

    __deploy_config_section "override" "./override" "/etc/rspamd/override.d"

    $__ mkdir -p /etc/rspamd/local.d/maps.d
    __deploy_config_section "local maps" "./maps" "/etc/rspamd/local.d/maps.d"

    $__ -u _rspamd mkdir -p /var/rspamd/keys
    __deploy_config_section "private keys" "./keys" "/var/rspamd/keys" "chown _rspamd:_rspamd"


    cat <<-EOF | _update_crontab 1 'rspamd' 'root'
    #-----------------------------------rspamd Start---------------------------------------
    ~       23       *      *        *       -ns  /usr/local/bin/rspamadm dmarc_report
    #-----------------------------------rspamd End-----------------------------------------
EOF
    _message "1info" "Checking Configuration"

}

_deploy_http() {

    typeset -l hname='' hpattern=''

    local _source_dir_tmp=$(mktemp -d /tmp/temail.XXXXXXX.rspamd)
    trap "$(_clean $_source_dir_tmp)" ERR EXIT

    local check=""
    local _target_dir=/etc/nginx/conf.d
    hname="www"
    hpattern="${hname}.conf"
    _source_dir="."

    if [[ ! -d "${_target_dir}" ]]; then
        $__ mkdir -p "${_target_dir}"
    fi

    $__ find "${_source_dir}" -type f -iname "$hpattern" -exec cat {} + >> "${_source_dir_tmp}/rspam.conf"
    check=$(_check_diff -s "$_source_dir_tmp" -t "${_target_dir}" -f "*.conf")
    _apply_changes 2 "$check" "$_source_dir_tmp" "${_target_dir}"

    _message "2info" 'Checking nginx Configuration...'
    local _tmp="${_source_dir_tmp}/check"

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

_start_service() {
    local tmp=$(mktemp /tmp/temail.XXXXXXX.rspamd)

    rspamadm configdump 1>/dev/null 2>${tmp}

    if  [ -s $tmp ]; then
        _show 1 $tmp
        rm -f $tmp
        _message "1Error" "Wrong Rspamd Configuration!"
    fi

    [ -f $tmp ] && rm -f $tmp

    if [ "$($__ rcctl get rspamd flags)" == NO ]; then
        _message "1info" "Enabling & Starting rspamd..."
        $__ rcctl enable rspamd > /dev/null
        $__ rcctl start rspamd > /dev/null
        _message "1info" "Enabling & Starting rspamd done!"
    elif $(pgrep -q 'rspamd'); then
        _message "1info" "Re-Starting rspamd..."
        $__ rcctl restart rspamd > /dev/null
        _message "1info" "Re-Starting rspamd done!"
    else
        _message "1info" "Starting rspamd..."
        $__ rcctl start rspamd > /dev/null
        _message "1info" "Starting rspamd done!"
    fi

}

# rspamd
_message "info" 'Initializing/Updating rspamd...'

case "$_type" in
    M*) # Mail Server
        _run_checks "rspamd rspamc rspamadm"
        _add_packages $_packages
        _deploy_config
        _start_service
    ;;
    C*) # Controller
        _run_checks "nginx"
        _deploy_http
    ;;
    *) # Error
        _message 'Error' 'Unknow type of deploy command'
    ;;

esac
_message "info" 'Initializing/Updating rspamd done!'
cd "${_curpwd}"
