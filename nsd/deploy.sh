#!/usr/bin/env ksh

set -euo pipefail



_curpwd="${PWD}"
_scriptdir="${0%/*}"
cd "${_scriptdir}"

. ../assets/scripts/global.sh


# pf
_message "info" 'Initializing/Updating NSD...'
_isnew=y
_target="/var/nsd"

_run_checks "nsd nsd-control-setup nsd-control openssl "

_tsig=$(openssl rand -base64 16)
if [[ -f "${_target}/zones/.temail" ]]; then
    _message 'info' 'NSD is already configured, updating...'
    _isnew=n
fi
if [[ $_isnew == "n" ]]; then
    # Extract generated tsig and replace new-line by '@'
    _tsig="$($__ sed -nE '/#+-tsig[[:space:]]+Start/,/#+-tsig[[:space:]]+End/p' ${_target}/etc/nsd.conf |\
        tr '\n' '@')"

    $__ cp -fpv ./nsd.conf "${_target}/etc/"
    # Replace tsig with the existing secret
    $__ sed -Ei "/#+-tsig[[:space:]]+Start/,/#+-tsig[[:space:]]+End/c\\
${_tsig}" "${_target}/etc/nsd.conf"

    $__ cat "${_target}/etc/nsd.conf" | tr '@' '\n' | $__ tee  "${_target}/etc/nsd.conf"

else
    $__ mkdir -p "${_target}/zones/master/"
    $__ cp -fpv ./nsd.conf "${_target}/etc/"

    # update tsig
    $__  sed -Ei "/#+-tsig[[:space:]]+Start/,/#+-tsig[[:space:]]+End/s:X+:$_tsig:"  "${_target}/etc/nsd.conf"

    $__ nsd-control-setup
    echo "!! DO NOT DELETE !!\nThis file is a marker made by temail scripts." | $__ tee "${_target}/zones/.temail"
    $__ rcctl enable nsd
    $__ rcctl start nsd
fi

$__ cp -Rfpv ./zones/. "${_target}"/zones/master/
$__ chown -RL root:wheel "${_target}/zones/master/" "${_target}/zones/.temail"
$__ chown root:_nsd "${_target}/etc/nsd.conf"


$__ nsd-control reconfig
$__ nsd-control reload

_message 'Info' 'NSD setup completed!'

cd "${_curpwd}"
