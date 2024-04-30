#!/usr/bin/env ksh

set -euo pipefail



_curpwd="${PWD}"
_scriptdir="${0%/*}"
_source_dir=""
_target_dir=""
_check=""
_packages=./packages.conf

cd "${_scriptdir}"

. ../assets/scripts/global.sh


_run_checks "bash mkdir cd rm"

# tmux
_message "info" 'Initializing/Updating terminal...'
_add_packages "${_packages}"
_message "1info" 'Initializing/Updating tmux...'
mkdir -p ~/.local/share/tmux
_source_dir="./tmux"
_target_dir="$HOME/tmux"

check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
_apply_changes 1 "$check" "$_source_dir" "${_target_dir}"

ln -sf "${_target_dir}/tmux.conf" ~/.tmux.conf

_message '1Info' 'Tmux setup completed!'


# ksh
_message "1info" 'Initializing/Updating ksh...'
$__ mkdir -p /etc/ksh

_target_dir=/etc/ksh
_source_dir="./ksh/config"
check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
_apply_changes 1 "$check" "$_source_dir" "${_target_dir}"
$__ chown -RL root:wheel "${_target_dir}"

_target_dir=/etc
_source_dir="./ksh"
check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "ksh.kshrc")
_apply_changes 1 "$check" "$_source_dir" "${_target_dir}"
$__ chown -RL root:wheel "${_target_dir}/ksh.kshrc"

_target_dir=/root
_source_dir="./ksh"
check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "rprofile")
_apply_changes 1 "$check" "$_source_dir" "${_target_dir}"
$__ chown root:wheel "${_target_dir}/rprofile"
$__ test  -f "${_target_dir}/.profile" && $__ rm -f "${_target_dir}/.profile"
$__ test  -h "${_target_dir}/.profile"  || $__ ln -f "${_target_dir}/rprofile" "${_target_dir}/.profile"

_target_dir=$HOME
_source_dir="./ksh"
check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "profile")
_apply_changes 1 "$check" "$_source_dir" "${_target_dir}"

$__ chown  $USER:$USER "${_target_dir}/profile"
[ -f "${_target_dir}/.profile" ] && rm -f "${_target_dir}/.profile"
[ -h "${_target_dir}/.profile" ] || ln -f "${_target_dir}/profile" "${_target_dir}/.profile"

_message "1info" 'ksh setup completed!'

_message "info" 'Initializing/Updating terminal done!'

cd "${_curpwd}"
