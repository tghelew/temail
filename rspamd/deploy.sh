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
_packages=./packages.conf



# rspamd
_message "info" 'Initializing/Updating rspamd...'

_run_checks ""

_add_packages $_packages

case "$_type" in
    M*) # Mail Server
    ;;
    C*) # Controller
        _message 'Error' 'Not supported on Controller!'
    ;;
    *) # Error
        _message 'Error' 'Unknow type of deploy command'
    ;;

esac
_message "info" 'Initializing/Updating rspamd done!'
cd "${_curpwd}"
