#!/usr/bin/env ksh

set -euo pipefail



_curpwd="${PWD}"
_scriptdir="${0%/*}"
_packages=./packages.conf

cd "${_scriptdir}"

. ../assets/scripts/global.sh

_add_packages "${_packages}"

_run_checks "bash mkdir cd rm"

# tmux
_message "info" 'Initializing/Updating tmux...'
_isnew=y
_target="$HOME/tmux"


mkdir -p ~/.local/share/tmux

if [[ -d "${_target}" ]]; then
    _message 'info' 'Tmux is already configured, updating...'
    _isnew=n
fi
if [[ $_isnew == "n" ]]; then
    rm -rf "${_target}/"
    cp -Rfv ./tmux/. "${_target}"/
else
    mkdir -p "${_target}"
    cp -Rfpv ./tmux/. "${_target}"/
fi
ln -sf "${_target}/tmux.conf" ~/.tmux.conf

_message 'Info' 'Tmux setup completed!'


# ksh
_message "info" 'Initializing/Updating ksh...'

_target=~/
cp -fpv ksh/profile $_target/.profile

_message "info" 'ksh setup completed!'


cd "${_curpwd}"
