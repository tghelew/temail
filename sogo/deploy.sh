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

_start_service() {
    _message "1info" "Checking Configuration"
}

# smtpd
_message "info" 'Initializing/Updating sogo...'


_run_checks "psql"

case "$_type" in
    C*) # Controller
        _add_packages $_packages
        _init_db
        _deploy_sql
        _deploy_config "./conf"

    ;;
    M*) # Mail
        _message 'Error' 'Mail servers does not support SoGo!'
    ;;
    *) # Error
        _message 'Error' 'Unknown type of deploy command'
    ;;

esac
_message "info" 'Initializing/Updating sogo done!'
cd "${_curpwd}"
