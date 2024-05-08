#!/usr/bin/env ksh

set -euo pipefail



_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type=""
_syslog_conf=""
_newsyslog_conf=""
_syslog_flags=""

cd "${_scriptdir}"

. ../assets/scripts/global.sh

case "$1" in
    C*) # Controller
        _syslog_conf='controller_syslog.conf'
        _newsyslog_conf='controller_newsyslog.conf'
        _syslog_flags="-S $(hostname)"
    ;;
    M*) # Mail Server
        _syslog_conf='mail_syslog.conf'
        _newsyslog_conf='mail_newsyslog.conf'
        _syslog_flags="-hn"
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
local file="" owner="" mode=""

while read -ru file owner mode; do
    [ "x$file" == "x" ] &&  continue
    [ "x$owner" == "x" ] && owner=root:wheel
    [ "x$mode" == "x" ] && mode=640

    if [[ -f "$file" ]]; then
        _message '2info' "file: $file already exist skipping..."
    else
        _message '2info' "file: $file does not exist creating it..."
        $__ touch "$file"
        $__ chown $owner "$file"
        $__ chmod $mode "$file"
    fi
done < ./logfile.conf

_message "1info" "Checking if logfiles already exist done!"

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

_message "1info" "Checking syslogd flags"
_cflags=$($__ rcctl get syslogd flags)
if [[ "$_cflags" == "$_syslog_flags" ]]; then
    _message "2info" "syslogd flags did not change skipping"
else
    _message "2info" "syslogd flags changes updating"
    $__ rcctl set syslogd flags "$_syslog_flags" >/dev/null 2>&1
    $__ rcctl restart syslogd >/dev/null 2>&1
fi


_message "1info" "Checking syslogd flags done!"
_message 'Info' 'SYSLOG setup completed!'

cd "${_curpwd}"
