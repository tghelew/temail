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
_target_dir="/var/named"
_target_script="/usr/local/bin/named-adblock"

_run_checks "diff named named-checkconf rndc"


__apply_changes() {

    local mtab="${1:-1}"
    local check="${2}"
    local source="${3}"
    local target="${4}"

    local state=""
    local file=""
    local bck=$IFS
    local target_file

    local IFS=';'
    for c in $check; do
        state=$(echo "$c" | cut -d @ -f 1)
        file=$(echo "$c" | cut -d @ -f 2)
        IFS=$bck
        case $state in
            S) _message "$(($mtab+ 1))info" "file: $file has not changed... skipping"
            ;;
            D) _message "$(($mtab+ 1))info" "file: $file has changed... deploying"
               target_file="${target}/$file"
               $__ mkdir -p "${target_file%/*}"
               $__ cp -Rf "$source/$file" "$target_file"
            ;;
            E) _message "$(($mtab+ 1))info" "file: $file is suspicious double checking!"
               if [ -f "$source/${file}" ]; then
                   _message "$(($mtab+ 2))info" "file: $file exist locally copying it!"
                   target_file="${target}/$file"
                   $__ mkdir -p "${target_file%/*}"
                   $__ cp -Rf "$source/$file" "$target_file"
               else
                   _message "$(($mtab+ 2))info" "file: $file doesn't exist locally skipping"
               fi
            ;;
            X) _message "$(($mtab+ 1))Warnig" "Unable to read dir: $file check that it exists or is readable."
            ;;
            *) _message "$(($mtab+ 1))Warnig" "Something happen during parsing of the command."
            ;;
        esac
    done
}

_deploy_common() {
    _message '1info' 'Deploying/Updating common'
    # check if file has changed:
    local source_dir="./common"
    local check=""
    _target_dir="/var/named"
    $__ mkdir -p "${_target_dir}"/{keys,etc,zones,run}

    check=$(_check_diff -s "$source_dir" -t "${_target_dir}/etc" -f "*.conf")
    __apply_changes 1 "$check" "$source_dir" "${_target_dir}/etc"

    _message '2info' 'Checking rndc.conf...'
    local _rndc_target_conf=/etc/rndc.conf
    [ -h $_rndc_target_conf ] && $__ rm -f $_rndc_target_conf
    $__ touch $_rndc_target_conf

    if [[ "$($__ cat $_rndc_target_conf)" != "*include*" ]]; then
        _message '3info' 'Updating rndc.conf. '
        $__ tee "$_rndc_target_conf" >/dev/null <<EOF
        include "/var/named/etc/rndc.conf";
EOF
    fi
    $__ chown root:_bind "$_rndc_target_conf"
    $__ chmod 640 "$_rndc_target_conf"
    _message '2info' 'Checks of rndc.conf done'


    source_dir=./keys
    check=$(_check_diff -s "$source_dir" -t "${_target_dir}/keys" -f "*.key")
    __apply_changes 1 "$check" "$source_dir" "${_target_dir}/keys"

    $__ chown root:_bind "${_target_dir}"
    $__ chmod 775 "${_target_dir}"
    $__ chown -RL _bind:_bind "${_target_dir}"/*
    $__ chmod  750 "${_target_dir}"/{keys,etc}
    $__ find "${_target_dir}"/{keys,etc} -type f -exec chmod 640 {} +

    source_dir=./zones/common
    check=$(_check_diff -s "$source_dir" -t "${_target_dir}/zones" -f "*.zone")
    __apply_changes 1 "$check" "$source_dir" "${_target_dir}/zones"


    _message '1info' 'Deploying/Updating common done!'
}

_deploy_custom() {
    _message '1info' 'Deploying/Updating custom config'

    local source_dir="."
    local check=""
    _target_dir="/var/named/etc"
    local custom_file="${1}"
    local target_file="custom.conf"
    [ "x$custom_file" == "x" ] && _message "2error" "Custom file must be provided."
    trap "[ -f $source_dir/$target_file ] && rm -f $source_dir/$target_file" ERR
    cp -f "$source_dir"/"$custom_file" "$source_dir"/"$target_file"

    check=$(_check_diff -s "$source_dir" -t "${_target_dir}" -f "$target_file")
    __apply_changes 1 "$check" "$source_dir" "$_target_dir"
    $__ chown root:_bind $_target_dir/$target_file
    $__ chmod 640 $_target_dir/$target_file

    rm -f "$source_dir"/"$target_file"
    _message '1info' 'Deploying/Updating custom config done!'
}

_deploy_adzone() {
    _message '1info' 'Deploying/Updating adzone'

    local source_dir="./zones/virtual"
    local check=""
    _target_dir="/var/named/zones"

    check=$(_check_diff -s "$source_dir" -t "${_target_dir}" -f "*.zone")
    __apply_changes 1 "$check" "$source_dir" "$_target_dir"

    _message '2info' 'Deploying/Updating update script'

    source_dir='./scripts'
    _target_dir="/usr/local/bin"
    local target_file='update-named-adblock'
    check=$(_check_diff -s "$source_dir" -t "${_target_dir}" -f "$target_file*")
    __apply_changes 2 "$check" "$source_dir" "$_target_dir"
    $__ chown root:bin /usr/local/bin/"$target_file"

    # crontab
    cat <<-EOF | _update_crontab 'adblock' 'root'
    #-----------------------------------adblock Start------------------------------------
    0~10     3       *       *       *       -ns  /usr/local/bin/update-named-adblock
    #-----------------------------------adblock End--------------------------------------
EOF
    _message '2info' 'Deploying/Updating script done!'

    _message '1info' 'Deploying/Updating adzone done!'
}

_deploy_checkconf() {
    local _tmp=$(mktemp /tmp/temail.XXXXXXX.dns)
    local l=""
    local _clean=$(cat <<-EOF
if [ -f ${_tmp} ]; then
  while read -ru l ; do
    printf "\t\t%s\n" "$l"
  done < ${_tmp}
  rm -f ${_tmp}
fi
EOF
                   )

    trap "$_clean" ERR EXIT

    _message "1Info" "Checking installed configuration..."
     $__ named-checkconf -t /var/named etc/named.conf > "${_tmp}" 2>&1
     while read -ru l ; do
         printf "\t\t%s\n" "$l"
     done < ${_tmp}
    _message "1Info" "Checking installed configuration done"
    [ -f ${_tmp} ] && rm -f ${_tmp}
}

_add_packages ./packages.conf

local service=isc_named

case $_type in
    C*)
        _deploy_common
        _deploy_custom "controller.conf"
        _deploy_adzone
        _deploy_checkconf
    ;;
    M*)
        _deploy_common
        _deploy_custom "mail.conf"
        _deploy_checkconf
    ;;
    *)
        _message 'Error' 'Unknown deployment type.'
    ;;
esac
_message '1Info' 'Initializing/Restarting named services'
if $($__ rndc -q status >/dev/null 2>&1); then
    _message '2info' 'Named service already configured, reloading'
    $__ rndc -q reload >/dev/null 2>&1
else
    _message '2info' 'Initializing named services...'
    $__ update-named-adblock
    $__ rcctl enable $service > /dev/null
    $__ rcctl set $service flags -t /var/named -c etc/named.conf -u _bind > /dev/null
    $__ rcctl start $service > /dev/null
fi
_message '1Info' 'Done initializing/reloading named services!'
_message 'Info' 'DNS setup completed!'

cd "${_curpwd}"
