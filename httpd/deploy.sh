#!/usr/bin/env ksh

set -euo pipefail




_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type=""
_type="Unkown"
_httpd_conf="httpd.conf"
_target_dir="/etc"
_source_dir_temp="."
_source_dir="."
_tmp=""

cd "${_scriptdir}"

. ../assets/scripts/global.sh

__deploy_errors() {

    local check=""
    _tmp=$(mktemp /tmp/temail.XXXXXXX.httpd)

    trap "$(_show_clean 3 ${_tmp})" ERR EXIT

    _target_dir="/var/www/errors"
    _source_dir="./errors"

    $__ mkdir -p "$_target_dir"

    _message "1info" 'Deploying httpd default error pages...'

    check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
    _apply_changes 1 "$check" "$_source_dir" "${_target_dir}"

    _message "2info" 'Checking httpd Configuration...'
    $__ httpd -n > "$_tmp" 2>&1
    if [ -s ${_tmp} ]; then
        _show 3 $_tmp
        grep -qi "configuration ok" $_tmp || \
           _message "3Error" "Configuration check failed!"
        rm -f "$_tmp"
    fi
    _message "2info" 'Checking httpd Configuration done!'

    _message "1info" 'Deploying httpd default error pages done!'
}

__deploy_httpd() {

    local check=""
    _tmp=$(mktemp /tmp/temail.XXXXXXX.httpd)
    trap "$(_show_clean 3 ${_tmp})" ERR EXIT


    _message "1info" 'Deploying httpd Configuration...'

    _target_dir="/etc"
    _source_dir="${1}"
    [  -d "$_source_dir" ] || \
        _message "1Error" "Source dir: ${_source_dir} cannot be found"

    check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "$_httpd_conf")
    _apply_changes 1 "$check" "$_source_dir" "${_target_dir}"

    _message "2info" 'Checking httpd Configuration...'
    $__ httpd -n > "$_tmp" 2>&1
    if [ -s ${_tmp} ]; then
        _show 3 $_tmp
        grep -qi "configuration ok" $_tmp || \
           _message "3Error" "Configuration check failed!"
        rm -f "$_tmp"
    fi
    _message "2info" 'Checking httpd Configuration done!'

    if [ "$($__ rcctl get httpd flags)" == "NO" ]; then
        _message '1info' 'Enabling httpd service'
        $__ rcctl enable httpd >/dev/null
        $__ rcctl start httpd >/dev/null
    else
        _message '1info' '(Re)Starting httpd service'
        $__ rcctl restart httpd >/dev/null
    fi

    _message "1info" 'Deploying httpd Configuration done!'
}

__deploy_php() {

    local check=""
    local php_version="$(pkg_info -a | grep -i php-[0-9] | cut -d ' ' -f1 | cut -d '-' -f2)"
    local php_version_major="$(echo $php_version | cut -d '.' -f1)"
    local php_version_minor="$(echo $php_version | cut -d '.' -f2)"
    local php_version_revision="$(echo $php_version | cut -d '.' -f3)"
    local bin_path="/usr/local/bin/php-${php_version_major}.${php_version_minor}"
    local service="php${php_version_major}${php_version_minor}_fpm"

    _target_dir="/etc"
    _source_dir="./php"

    _message "1info" 'Deploying php Configuration...'
    [ -z "$php_version" ] && _message "1error" "Unknown php version"
    [ -z "$php_version_major" ] && _message "1error" "Unknown php major version number"
    [ -z "$php_version_minor" ] && _message "1error" "Unknown php minor version number"
    _message "2info" "Linking php excutable of version $php_version..."
    [ -f "$bin_path" ] && $__ ln -sf "$bin_path" /usr/local/bin/php
    _message "2info" "Linking php excutable of version $php_version done!"


    _message "2info" "Copying php configs of version $php_version..."
    check=$(_check_diff -s "$_source_dir" -t "${_target_dir}" -f "*")
    _apply_changes 2 "$check" "$_source_dir" "${_target_dir}"
    _message "2info" "Copying php configs of version $php_version done!"

    if [ "$($__ rcctl get $service flags)" == "NO" ]; then
        _message '2info' 'Enabling php service'
        $__ rcctl enable $service >/dev/null
        $__ rcctl start $service >/dev/null
    else
        _message '2info' '(Re)Starting php service'
        $__ rcctl restart $service >/dev/null
    fi

    _message "1info" 'Deploying php Configuration done!'
}

__deploy_apps() {

    # Move application from source to target /usr/local/share
    # and then create symlink to web root
    ___move_app() {

        typeset -l move="${1:-y}" link="${2:-y}"
        if [ "$move" == "y" ]; then
            $__ chown -R root:wheel "${_source_dir_temp}/$app_folder"
            $__ mkdir -p "${_target_dir}"
            $__ mv -f "${_source_dir_temp}/$app_folder" "${_target_dir}/$name"
        fi
        if [ "$link" == "y" ]; then
            $__ mkdir -p "$www"
            local dir="${_target_dir}/${name}"
            if [ "$target" != "no" ]; then
                [ -d "$dir/${target}" ] || _message "3Error" "Folder: ${dir}/${target} does not exist!"
                dir="${dir}/${target}"
            fi
            $__ ln -sf "../${dir##$_root_dir}" "${www}/$name"
            $__ chown  root:wheel "${www}/$name"
        fi

    }

    ___deploy_config() {
        local hash=$(cat )
        typeset -l cname='' cfolder='' cpattern='' chash=''
        local check=""
        while read -ru cname cfolder cpattern; do
            [ "x$cname" == "x" ] && _message "3Error" "Name cannot be empty!"
            [ "$cname" == "$name" ] || continue

            [ "x$cfolder" == "x" ] && _message "3Error" "Folder cannot be empty!"
            [ "x$cpattern" == "x" ] && _message "3Error" "Pattern cannot be empty!"

            _source_dir="./${cfolder}"
            check=$(_check_diff -s "$_source_dir" -t "${_target_dir}/${name}" -f "$cpattern")
            _apply_changes 2 "$check" "$_source_dir" "${_target_dir}/${name}"
        done < "${apps_config}"

    }

    ___deploy_httpd() {
        typeset -l hname='' hfolder='' hpattern=''
        local check=""
        while read -ru hname hfolder hpattern; do
            [ "x$hname" == "x" ] && _message "3Error" "Name cannot be empty!"
            [ "$hname" == "$name" ] || continue

            [ "x$hfolder" == "x" ] && _message "3Error" "Folder cannot be empty!"
            [ "x$hpattern" == "x" ] && _message "3Error" "Pattern cannot be empty!"

            _source_dir="./${hfolder}"
            $__ find "${_source_dir}" -type f -iname "$hpattern" -exec cat {} + >> "${_source_dir_temp}/$_httpd_conf"

        done < "${apps_httpd}"

    }

    ___run_init() {
        typeset -l rname='' rscript='' rparams=''
        while read -ru rname rscript rparams; do
            [ "x$rname" == "x" ] && _message "3Error" "Name cannot be empty!"
            [ "$rname" == "$name" ] || continue

            [ "x$rscript" == "x" ] && _message "3Error" "Script cannot be empty!"
            [ "x$rparams" == "x" ] && _message "3Error" "Parameters cannot be empty!"

            [ -f "./${rscript}" ] || _message "3Error" "Script cannot be found!"

            [ "$rparams" == "no" ] && rparams=""

            _message "3Info" "Executing initialization script: ./$rscript"
             . "./${rscript}" 3 "${_curpwd}" $rparams

        done < "${apps_init}"

    }

    _message "1info" 'Deploying Web apps...'
    _run_checks "sha256 ftp tar sed"
    # Get list of apps to deploy
    local _root_dir=/var/www
    _target_dir="$_root_dir"/apps
    local apps_download=$_source_dir_temp/apps_download.conf
    local apps_config=$_source_dir_temp/apps_config.conf
    local apps_httpd=$_source_dir_temp/apps_httpd.conf
    local apps_init=$_source_dir_temp/apps_init.conf

    _read_conf "./apps/${_type}.conf" "$apps_download" 'Download'
    [ -s "$apps_download" ] || _message "2info" "No apps configured for deployment skipping..."

    _read_conf "./apps/${_type}.conf" "$apps_config" 'Config'
    [ -s "$apps_config" ] || _message "2info" "No apps configuration for deployment skipping..."

    _read_conf "./apps/${_type}.conf" "$apps_httpd" 'HTTPD'
    [ -s "$apps_httpd" ] || _message "2info" "No apps web configuraton for deployment skipping..."

    _read_conf "./apps/${_type}.conf" "$apps_init" 'Init'
    [ -s "$apps_init" ] || _message "2info" "No apps configured for deployment skipping..."

    typeset -l name="" target="" www="" url=""
    #    For each application:
    while read -ru name target www url; do
        [ "x$name" == "x" ] && _message "2Error" "Name cannot be empty!"
        [ "x$target" == "x" ] && _message "2Error" "Target cannot be empty!"
        [ "x$www" == "x" ] && _message "2Error" "www cannot be empty!"
        [ "x$url" == "x" ] && _message "2Error" "Url cannot be empty!"
    #        Fetch the application and untar it.
        _message "2Info" "Fetching app: $name from url..."
        ftp -MVo "$_source_dir_temp/$name.tar.gz" "$url"
        local app_folder="$(tar -zt -f "${_source_dir_temp}/$name.tar.gz" "${name}*" | head -n1)"
        tar -zx -C ${_source_dir_temp} -f "${_source_dir_temp}/$name.tar.gz"
        sha256 -b "${_source_dir_temp}/$name.tar.gz" | cut -d '=' -f2 > "${_source_dir_temp}/$app_folder/sha256.txt"
        echo "$target;${www}/$name" > "${_source_dir_temp}/$app_folder/links.txt"
        _message "2Info" "Fetching app: $name from url done!"

    #        Create necessary symlink to web root
        _message "2Info" "Moving app to destination and creating web link..."
        if [ -f "${_target_dir}/$name/sha256.txt" ]; then
            # app already exist checking signature
            _message "3Info" "App in ${_target_dir}/$name already exits checking signature..."
            local path="$(cat "${_target_dir}/$name/links.txt" | cut -d ';' -f2)"
            if [ "$(cat "${_target_dir}/$name/sha256.txt")" != \
                 "$(cat "${_source_dir_temp}/$app_folder/sha256.txt")" ]; then

                if [ "$(cat "${_target_dir}/$name/links.txt")" != \
                    "$(cat "${_source_dir_temp}/$app_folder/links.txt")" ]; then
                    _message "3Info" "New application to be installed and links to be updated..."
                    [ -h "$path" ] && $__ rm -f "$path"
                    ___move_app "y" "y"
                else
                    _message "3Info" "New application to be installed..."
                    ___move_app "y" "n"
                fi

            else
                if [ "$(cat "${_target_dir}/$name/links.txt")" != \
                    "$(cat "${_source_dir_temp}/$app_folder/links.txt")" ]; then
                    _message "3Info" "Application already exist updating links..."
                    # update link file
                    echo "$target;${www}/$name" | $__ tee  "${_target_dir}/$name/links.txt" > /dev/null
                    [ -h "$path" ] && $__ rm -f "$path"
                    ___move_app "n" "y"
                else
                    _message "3Info" "Application already exist skipping..."
                    ___move_app "n" "n"
                fi
            fi
        else
            _message "3Info" "App in ${_target_dir}/$name does not exits creating ..."
            ___move_app "y" "y"

        fi
        _message "2Info" "Moving app to destination and creating web link done!"

    #        Get list of local configurations and add it to target
        _message "2Info" "Adding local conf for $name ..."
        ___deploy_config
        _message "2Info" "Adding local conf for $name done!"

    #        Get section of httpd config and add it
        _message "2Info" "Adding httpd config for $name ..."
        ___deploy_httpd
        _message "2Info" "Adding httpd config for $name done!"
    #        Initialize Application
        _message "2Info" "Running initialization script for $name ..."
        ___run_init
        _message "2Info" "Running initialization script for $name done!"
    done < "$apps_download"

    _message "1info" 'Deploying Web apps done!'
}


# httpd
_message "info" 'Initializing/Updating httpd...'

_add_packages ./packages.conf

_source_dir_temp="$(mktemp -d /tmp/temail.XXXXXXX.httpd)"
trap "$(_clean $_source_dir_temp)" ERR EXIT

case "$1" in

    C*) # Controller
        _type="controller"
        cat "./$_type/httpd.conf" > "${_source_dir_temp}/$_httpd_conf"
        __deploy_httpd "${_source_dir_temp}"
        __deploy_errors
        __deploy_php
        __deploy_apps
    ;;
    M*) # Mail
        _type="mail"
        cat './mail/httpd.conf' > "${_source_dir_temp}/$_httpd_conf"
    ;;
    *) # Error
        _message 'Error' 'Unknown server type'
    ;;


esac
_message 'Info' 'httpd setup completed!'

cd "${_curpwd}"
