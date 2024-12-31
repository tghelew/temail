#!/usr/bin/env ksh
set -euo pipefail

typeset -i _mtab=$1
_rootdir="${2}"
_target_app_dir="${3}"

[ -d "$_rootdir" ] || \
    {
        echo "Error folder: $_rootdir cannot be found!" >&2
        exit 1
    }

. "${_rootdir}"/assets/scripts/global.sh

_tmp=$(mktemp /tmp/temail.XXXXXXX.pfadmin)
trap "$(_show_clean $(( $_mtab + 1 )) $_tmp)" ERR

_run_checks "psql"
_message "${_mtab}info" "Maybe creating a database user..."

psql -U _postgresql -d postgres -q  -X <<-EOF > "${_tmp}" 2>&1
     DO
     \$$
        BEGIN
            IF EXISTS (
                SELECT FROM pg_catalog.pg_roles
                WHERE  rolname = 'vmail') THEN

                RAISE NOTICE 'User "vmail" already exists. Skipping.';
            ELSE
                CREATE USER vmail WITH PASSWORD NULL;
            END IF;
        END
     \$$;
EOF
_show "$(( $_mtab + 1))" "$_tmp"

_message "${_mtab}info" "Maybe creating a database... "

psql -U _postgresql -d postgres -q -X <<-EOF > "${_tmp}" 2>&1
    SELECT 'CREATE DATABASE vmail WITH OWNER vmail'
      WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vmail') \\gexec
EOF
_show "$(( $_mtab + 1))" "$_tmp"

_message "${_mtab}info" "Maybe creating a database done!"

[ -f $_tmp ] && rm -rf "$_tmp"

_message "${_mtab}info" "Maybe creating template folder..."
[ -d "${_target_app_dir}" ] || _messages "${_mtab}Error" "Folder: ${_target_app_dir} doesn't exist!"
$__ mkdir -p "${_target_app_dir}"/templates_c
$__ chown -R www "${_target_app_dir}"/templates_c
_message "${_mtab}info" "Maybe creating template folder done!"
