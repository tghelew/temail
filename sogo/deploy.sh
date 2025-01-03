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
    local section="$1"
    local source="$2"
    local target="$3"
    local action="${4:-no}"

    local tmp="$(mktemp -d /tmp/temail.XXXXXXX.$section)"
    trap "$(_clean $tmp)" ERR

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
    $__ mkdir -p /etc/sogo /var/run/sogo
    $__ chown -R _sogo:_sogo /var/run/sogo
    __deploy_config_section "sogo" "$source" "/etc/sogo/"
}

_init_db() {
    _message "1info" "Maybe creating database user..."
    local tmp=$(mktemp /tmp/temail.XXXXXXX.sogo)
    trap "$(_show_clean 2 $tmp)" ERR

    psql -U _postgresql -d postgres -q  -X <<-EOF > "${tmp}" 2>&1
     DO
     \$$
        BEGIN
            IF EXISTS (
                SELECT FROM pg_catalog.pg_roles
                WHERE  rolname = 'sogo') THEN

                RAISE NOTICE 'User "sogo" already exists. Skipping.';
            ELSE
                CREATE USER sogo WITH PASSWORD NULL;
                GRANT CONNECT ON DATABASE vmail TO sogo;
            END IF;
        END
     \$$;
EOF
    _show "2" "$tmp"

    _message "1info" "Maybe creating a database user done"

    _message "1info" "Maybe creating database..."

    psql -U _postgresql -d postgres -q -X <<-EOF > "${tmp}" 2>&1
    SELECT 'CREATE DATABASE sogo WITH OWNER sogo'
      WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'sogo') \\gexec
EOF
    _show "2" "$tmp"
    _message "1info" "Maybe creating a database  done"

    [ -f $tmp ] && rm -rf "$tmp"
}

_deploy_sql() {
    _message "1info" "Deploy sql views..."
    local tmp=$(mktemp /tmp/temail.XXXXXXX.sogo)
    trap "$(_show_clean 2 $tmp)" ERR

    for file in $(find ./db -type f); do
        _message "2info" "Deploying sql views in file: $file ..."
        psql -U vmail -d vmail -q  -X -f "$file"  > "${tmp}" 2>&1
        _show 2 "$tmp"
    done
    [ -f $tmp ] && rm -rf "$tmp"
    _message "1info" "Deploy sql file done!"
}

_deploy_http() {

    _message "1info" "Deploying nginx config"
    typeset -l hname='' hpattern=''

    local _source_dir_tmp=$(mktemp -d /tmp/temail.XXXXXXX.rspamd)
    trap "$(_clean $_source_dir_tmp)" ERR EXIT

    local check=""
    local _target_dir=/etc/nginx/conf.d
    hname="www"
    hpattern="${hname}.conf"
    _source_dir="./http"

    if [[ ! -d "${_target_dir}" ]]; then
        $__ mkdir -p "${_target_dir}"
    fi

    $__ find "${_source_dir}" -type f -iname "$hpattern" -exec cat {} + >> "${_source_dir_tmp}/sogo.conf"
    check=$(_check_diff -s "$_source_dir_tmp" -t "${_target_dir}" -f "*.conf")
    _apply_changes 2 "$check" "$_source_dir_tmp" "${_target_dir}"

    _message "2info" 'Checking nginx Configuration...'
    local _tmp="${_source_dir_tmp}/check"

    set +e
    $__ nginx -t > "$_tmp" 2>&1
    if [ -s ${_tmp} ]; then
        _show 3 $_tmp
        grep -qi "ok" $_tmp || \
        _message "3Error" "Configuration check failed!"
        rm -f "$_tmp"
    fi
    _source_dir="/usr/local/lib/GNUstep/SOGo/WebServerResources"
    _target_dir="/var/www/lib/sogo/www"
    _message "2info" 'Maybe copying web resources from SoGo...'
    [[ ! -d {_target_dir} ]] && $__ mkdir -p "$_target_dir"

    check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
    _apply_changes 3 "$check" "$_source_dir_tmp" "${_target_dir}"

    _message "2info" 'Maybe copying web resources from SoGo done'

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
    if [ "$($__ rcctl get sogod flags)" == "NO" ]; then
        _message '1info' 'Enabling sogod service'
        $__ rcctl enable sogod >/dev/null
        $__ rcctl start sogod >/dev/null
    else
        _message '1info' '(Re)Starting sogo service'
        $__ rcctl restart sogod >/dev/null
    fi
    if [ "$($__ rcctl get memcached flags)" == "NO" ]; then
        _message '1info' 'Enabling memcached service'
        $__ rcctl enable memcached >/dev/null
        $__ rcctl start memcached >/dev/null
    else
        _message '1info' '(Re)Starting memcached service'
        $__ rcctl restart memcached >/dev/null
    fi

    }
# SoGo
_message "info" 'Initializing/Updating SoGo...'


_run_checks "psql"

_add_packages $_packages

case "$_type" in
    C*) # Controller
         _init_db
         _deploy_sql
        _deploy_config "./conf"
         _deploy_http
        _start_service

    ;;
    M*) # Mail
        _message 'Error' 'Mail servers does not support SoGo!'
    ;;
    *) # Error
        _message 'Error' 'Unknown type of deploy command'
    ;;

esac
_message "info" 'Initializing/Updating SoGo done!'
cd "${_curpwd}"
