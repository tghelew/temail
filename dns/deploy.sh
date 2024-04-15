#!/usr/bin/env ksh

set -euo pipefail



_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type="$1"

cd "${_scriptdir}"

. ../assets/scripts/global.sh


# dns BIND
_message "info" 'Initializing/Updating DNS...'
_isnew=y
_target_conf=""
_target_script=""

_run_checks "diff"


_deploy_common() {
    _message 'info' '\tDeploying/Updating common'

    _message 'info' '\tDeploying/Updating common done!'
}
_deploy_adzone() {
    _message 'info' '\tDeploying/Updating adzone'

    _message 'info' '\tDeploying/Updating adzone done!'
}

_add_packages ./packages.conf
case $_type in
    C*)
        _deploy_common
        _deploy_adzone
    ;;
    M*)
        _deploy_common
    ;;
    *)
        _message 'Error' 'Unknown deployment type.'
    ;;
esac
_message 'Info' 'DNS setup completed!'

cd "${_curpwd}"
