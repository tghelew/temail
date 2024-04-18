#!/usr/bin/env ksh

set -euo pipefail



_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type=""
_syslog_conf=""
_newsyslog_conf=""

cd "${_scriptdir}"

. ../assets/scripts/global.sh

case "$1" in
    C*) # Controller
        _syslog_conf='controller_syslog.conf'
        _newsyslog_conf='controller_newsyslog.conf'
    ;;
    M*) # Mail Server
        _syslog_conf='mail_syslog.conf'
        _newsyslog_conf='mail_newsyslog.conf'
    ;;
    *) # Error
        _message 'Error' 'Unknow type of deploy command'
    ;;


esac

_run_checks "syslogd"

# syslog
_message "info" 'Initializing/Updating syslog...'
_target_syslog="/etc/syslog.conf"
_target_newsyslog="/etc/newsyslog.conf"

_message "1info" "Checking if logfile already exist"
for f in $(cat ./logfile.conf); do
    if [[ -f "$f" ]]; then
        _message '2info' "file: $f already exist skipping..."
    else
        _message '2info' "file: $f does not exist creating it..."
        $__ touch "$f"
        $__ chown root:wheel "$f"
        $__ chmod 640 "$f"
    fi
done
_message "1info" "Checking if logfile already exist done!"

if $(diff -qb "$_syslog_conf" /etc/syslog.conf >/dev/null 2>&1); then
    _message "1info" "Syslog.conf has not changed skipping"
else
    _message "1info" "Syslog.conf has changed deploying"
    $__ cp -f ./"${_syslog_conf}" /etc/syslog.conf
    $__ pkill -SIGHUP syslogd

fi

if $(diff -qb "$_newsyslog_conf" /etc/newsyslog.conf >/dev/null 2>&1); then
    _message "1info" "Newsyslog.conf has not changed skipping"
else
    _message "1info" "Newsyslog.conf has changed deploying"
    $__ cp -f ./"${_newsyslog_conf}" /etc/newsyslog.conf

fi
_message 'Info' 'SYSLOG setup completed!'

cd "${_curpwd}"
