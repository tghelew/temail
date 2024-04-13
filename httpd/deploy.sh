#!/usr/bin/env ksh

set -euo pipefail




_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type=""
_httpd_conf=""

cd "${_scriptdir}"

. ../assets/scripts/global.sh

case "$1" in
    C*) # Controller
        _httpd_conf='controller_httpd.conf'
    ;;
    M*) # Mail
        _httpd_conf='mail_httpd.conf'
    ;;
    *) # Error
        _message 'Error' 'Unknown server type'
    ;;


esac

_run_checks "httpd"

# httpd
_message "info" 'Initializing/Updating httpd...'
_isnew=y
_target="/etc/httpd.conf"

if [[ -f "${_target}" ]]; then
    _message 'info' 'httpd is already configured, updating...'
    _isnew=n
fi
if [[ $_isnew == "n" ]]; then
    if $(diff -qb ./${_httpd_conf} /etc/httpd.conf >/dev/null 2>&1); then
        _message 'info' 'httpd.conf has not changed skipping copy...'
    else
        _isnew=y
        $__ cp -fpv ./${_httpd_conf} "${_target}"
    fi
else
    $__ cp -fpv ./${_httpd_conf} "${_target}"
fi

[ -f ./packages.conf ] && $__ pkg_add -l ./packages.conf

[ $_isnew == 'y' ] && $__ chown  root:wheel "${_target}"

[ $_isnew == 'y' ] && $__ httpd -n

# enable and start service
[ $_isnew == 'y' ] && $__ rcctl enable httpd
[ $_isnew == 'y' ] && $__ rcctl start httpd
_message 'Info' 'httpd setup completed!'

cd "${_curpwd}"
