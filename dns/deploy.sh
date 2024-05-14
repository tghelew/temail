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

_run_checks "diff"

__handle_dynamic_zone(){
    set +e
    typeset -l mtab="$1" action="$3" zones=""
    local changed="$2"
    [ "x$changed" == "x" ] && return
    [ "x$action" == "x" ] && action="reload"

    local state="" file="" domain="" name=""
    local IFS=';'
    for c in $changed; do
        state=$(echo "$c" | cut -d @ -f 1)
        file=$(echo "$c" | cut -d @ -f 2)
        if [ "$state" == "D" ]; then
            zones="${zones}${zones:+\t}$(echo $file |\
                sed -E 's#\.?/?([[:alnum:]]+)/([[:alnum:]]+)\.zone#\2.\1#')"
        fi
    done
    unset IFS

    [ "x${zones}" != "x" ] && \
        {
            for z in $zones; do
                case $action in
                    f*)
                        _message "${mtab}info" "Freezing zone: $z ..."
                        $__ rndc freeze $z 2>1& >/dev/null
                        _message "${mtab}info" "Freezing zone: $z done!"
                        ;;
                    r*)
                        _message "${mtab}info" "Reloading zone: $z ..."
                        $__ rndc reload $z >/dev/null 2>1&
                        $__ rndc thaw $z  >/dev/null 2>1&
                        _message "${mtab}info" "Reloading zone: $z done!"
                        ;;
                    *)
                        ;;
                esac
            done
        }

    set -e
}

_deploy_common() {
    _message '1info' 'Deploying/Updating common'
    # check if file has changed:
    local source_dir="./common"
    local check=""
    _target_dir="/var/named"
    $__ mkdir -p "${_target_dir}"/{keys,etc,zones,run}

    check=$(_check_diff -s "$source_dir" -t "${_target_dir}/etc" -f "*.conf")
    _apply_changes 1 "$check" "$source_dir" "${_target_dir}/etc"

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
    _apply_changes 1 "$check" "$source_dir" "${_target_dir}/keys"

    $__ chown root:_bind "${_target_dir}"
    $__ chmod 775 "${_target_dir}"
    $__ chown -RL _bind:_bind "${_target_dir}"/*
    $__ chmod  750 "${_target_dir}"/{keys,etc}
    $__ find "${_target_dir}"/{keys,etc} -type f -exec chmod 640 {} +

    source_dir=./zones/common
    check=$(_check_diff -s "$source_dir" -t "${_target_dir}/zones" -f "*.zone")
    _apply_changes 1 "$check" "$source_dir" "${_target_dir}/zones"

    _message '2info' 'Deploying/Updating update script'

    source_dir='./scripts'
    _target_dir="/usr/local/bin"
    local target_file='update-named-root'
    check=$(_check_diff -s "$source_dir" -t "${_target_dir}" -f "$target_file*")
    _apply_changes 2 "$check" "$source_dir" "$_target_dir"
    $__ chown root:bin /usr/local/bin/"$target_file"

    # crontab
    cat <<-EOF | _update_crontab 2 'root.zone' 'root'
    #-----------------------------------root.zone Start------------------------------------
    0~10     6       1      */3       *       -ns  /usr/local/bin/update-named-root
    #-----------------------------------root.zone End--------------------------------------
EOF

    _message '2info' 'Deploying/Updating script done!'
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
    _apply_changes 1 "$check" "$source_dir" "$_target_dir"
    $__ chown root:_bind $_target_dir/$target_file
    $__ chmod 640 $_target_dir/$target_file

    rm -f "$source_dir"/"$target_file"
    _message '1info' 'Deploying/Updating custom config done!'
}

_deploy_primary() {
    _message '1info' 'Deploying/Updating primary zones'

    local source_dir="./zones/primary"
    local check=""
    _target_dir="/var/named/zones"

    check=$(_check_diff -s "$source_dir" -t "${_target_dir}" -f "*.zone")
    __handle_dynamic_zone 2 "$check" freeze
    _apply_changes 1 "$check" "$source_dir" "$_target_dir"
    __handle_dynamic_zone 2 "$check" reload

    _message '1info' 'Deploying/Updating primary zones done!'
}

_deploy_adzone() {
    _message '1info' 'Deploying/Updating adzone'

    local source_dir="./zones/virtual"
    local source_file="adblock.zone"
    local check=""
    _target_dir="/var/named/zones"
    typeset -i source_serial=$(sed -nE 's/^[[:space:]]+([0-9]+).*;serial/\1/p' "${source_dir}/${source_file}" )
    typeset -i target_serial=$(sed -nE 's/^[[:space:]]+([0-9]+).*;serial/\1/p' "${_target_dir}/${source_file}" )

    if [[ $target_serial > $source_serial ]]; then

        check=$(_check_diff -s "$source_dir" -t "${_target_dir}" -f "$source_file")
        _apply_changes 1 "$check" "$source_dir" "$_target_dir"
    else
        local mes="Target file is serial: $target_serial"
        mes=$mes" is newer than Source serial: $source_serial skipping..."
        _message '2warning' "$mes"
    fi

    _message '2info' 'Deploying/Updating update script'

    source_dir='./scripts'
    _target_dir="/usr/local/bin"
    local target_file='update-named-adblock'
    check=$(_check_diff -s "$source_dir" -t "${_target_dir}" -f "$target_file*")
    _apply_changes 2 "$check" "$source_dir" "$_target_dir"
    $__ chown root:bin /usr/local/bin/"$target_file"

    # crontab
    cat <<-EOF | _update_crontab 2 'adblock' 'root'
    #-----------------------------------adblock Start------------------------------------
    0~10     3       *       *       *       -ns  /usr/local/bin/update-named-adblock
    #-----------------------------------adblock End--------------------------------------
EOF
    _message '2info' 'Deploying/Updating script done!'

    _message '1info' 'Deploying/Updating adzone done!'
}

_deploy_resolv() {
    _message '1info' 'Deploying/Updating resolv'
    # check if file has changed:
    local source_dir="./resolv"
    local check=""
    _target_dir="/etc"

    check=$(_check_diff -s "$source_dir" -t "${_target_dir}" -f "*")
    _apply_changes 1 "$check" "$source_dir" "${_target_dir}" "chown root:wheel; chmod 644"

    $__ rcctl stop resolvd
    $__ rcctl disable resolvd

    _message '1info' 'Deploying/Updating resolv done!'
}

_deploy_checkconf() {
    local _tmp=$(mktemp /tmp/temail.XXXXXXX.dns)
    trap "$(_show_clean 2 $_tmp)" ERR EXIT

    _message "1Info" "Checking installed configuration..."
     $__ named-checkconf -t /var/named etc/named.conf > "${_tmp}" 2>&1
     [ -f ${_tmp} ] && {
         while read -ru l ; do
             printf "\t\t%s\n" "$l"
         done < ${_tmp}
         rm -f ${_tmp}
     }
    _message "1Info" "Checking installed configuration done"
}

_add_packages ./packages.conf

local service="isc_named"
case $_type in
    C*)
        _deploy_common
        _deploy_primary
        _deploy_custom "controller.conf"
        _deploy_adzone
        _deploy_checkconf
        _deploy_resolv
    ;;
    M*)
        _deploy_common
        _deploy_custom "mail.conf"
        _deploy_checkconf
        _deploy_resolv
    ;;
    *)
        _message 'Error' 'Unknown deployment type.'
    ;;
esac
_message '1Info' 'Initializing/Restarting named services'
if [[ $($__ rcctl ls on | grep -i "$service") == "$service" ]]; then
    _message '2info' 'Named service already configured, reloading'
    $__ rndc -q reload >/dev/null 2>&1
else
    _message '2info' 'Initializing named services...'
    [[ "$_type" == "C*" ]] && $__ update-named-adblock
    $__ rcctl enable $service > /dev/null
    $__ rcctl set $service flags -t /var/named -c etc/named.conf -u _bind > /dev/null
    $__ rcctl start $service > /dev/null
fi
_message '1Info' 'Done initializing/reloading named services!'
_message 'Info' 'DNS setup completed!'

cd "${_curpwd}"
