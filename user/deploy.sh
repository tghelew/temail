#!/usr/bin/env ksh

set -euo pipefail



_curpwd="${PWD}"
_scriptdir="${0%/*}"
typeset -U _type=""
_userconf=""
_userfile=$(mktemp /tmp/temail.XXXXXXX.user)
_doasfile=$(mktemp /tmp/temail.XXXXXXX.user)
_folderfile=$(mktemp /tmp/temail.XXXXXXX.user)
_sshfile=$(mktemp /tmp/temail.XXXXXXX.user)
_sshknown=$(mktemp /tmp/temail.XXXXXXX.user)
_clean=$(cat <<-EOF
  [ -f $_userfile ] && rm -f $_userfile
  [ -f $_doasfile ] && rm -f $_doasfile
  [ -f $_folderfile ] && rm -f $_folderfile
  [ -f $_sshfile ] && rm -f $_sshfile
  [ -f $_sshknown ] && rm -f $_sshknown
EOF
)

trap "$_clean" ERR EXIT

cd "${_scriptdir}"


. ../assets/scripts/global.sh

case "$1" in
    C*) # Controller
        _userconf='controller_user.conf'
    ;;
    M*) # Mail Server
        _userconf='mail_user.conf'
    ;;
    *) # Error
        _message 'Error' 'Unknow type of deploy command'
    ;;
esac

_run_checks "user group ssh-keyscan"

__deploy_doas() {
   _message '1info' 'Deploying doas config'
   [ ! -s $_doasfile ] && _message '2info' 'doas configuration is empty skipping' && return 0

   # Add header/footer to file
   sed -i -e '1 i\
#-----------------------------------User Start------------------------------------
'   \
           -e '$ a\
#-----------------------------------User End--------------------------------------
'   $_doasfile

   # Update doas
   [ -f /etc/doas.conf ] || $__ touch /etc/doas.conf
   $__ sed -Ei "/^#-+User[[:space:]]+Start/,/^#-+User[[:space:]]+End/D" /etc/doas.conf
   $__ tee -a /etc/doas.conf >/dev/null  < $_doasfile
   $__ doas -C /etc/doas.conf
   _message '1info' 'Deploying doas config done'
}

__deploy_folder() {
   _message '1info' 'Deploying folder config'
   [ ! -s $_folderfile ] && _message '2info' 'folder configuration is empty skipping' && return 0
   _message '1info' 'Deploying folder config done'
}

__deploy_user() {
    _message '1info' 'Deploying user config'
    [ ! -s $_userfile ] && _message '2info' 'user configuration is empty skipping' && return 0

    if [ -s $_sshfile ]; then
        _message '2info' 'Generating known hosts from config'
        ssh-keyscan -p 2203 -f $_sshfile 2>/dev/null | tee "$_sshknown" > /dev/null
        sed -i '/^#/d' "$_sshknown"
    fi

    typeset -l  name=""  uid=""  gid="" agroup="" group=""  shell=""  home="" ssh=""
    local comment=""
   while read -ru name uid gid group shell home ssh comment; do
       [ "x$name" == "x"  ]       && _message '2error' "User's name cannot be empty"
       [ "x$uid" == "x"   ]       && _message '2error' "User's uid cannot be empty"
       [ "x$gid" == "x"   ]       && _message '2error' "User's gid cannot be empty"
       [ "x$group" == "x" ]       && _message '2error' "User's group cannot be empty"
       [ "x$shell" == "x" ]       && _message '2error' "User's shell cannot be empty"
       [ "x$home" == "x"  ]       && _message '2error' "User's home cannot be empty"
       [ "x$ssh" == "x"   ]       && _message '2error' "User's ssh cannot be empty"
       $(type $shell > /dev/null) || _message '2error' "User's shell must be a valid command"

       agroup=""
       for g in $(echo "$group" | tr ',' ' '); do
           if $(group info -e $g); then
               agroup="$g${agroup:+,}$agroup"
           else
               [ $g != 'no' ] && _message '2info' "Group: $g does not exist... Skipping it"
           fi
       done

       if $(user info -e $name); then
           _message '2info' "User: $name already exists... Checking setting"

           local cuserinfo="$(grep $name /etc/passwd | cut -d ':' -f5,7)"
           local cagroup="$(id -Gn $name | tr ' ' '\n' | grep -v $(id -gn $name) | tr '\n' ',')"
           local nuserinfo="$comment:$shell"

           if [[ "$cuserinfo" != "$nuserinfo" || "$agroup${agroup:+,}" != "$cagroup" ]] then
               # echo "agroup:$agroup${agroup:+,}; cuserinfo: $cuserinfo"
               # echo "cagroup:$cagroup; nuserinfo: $nuserinfo"
               _message '3info' "User's setting has changed updating only: group, shell, and comment"
               $__ user mod -s $shell -c "$comment" -S $agroup -- $name
           else
               _message '3info' "User's setting has not changed: group, shell, or comment"
           fi
       else
           _message '2info' "User: $name does not exists... Creating"
          $(group info -e $gid) || $__ group add -g $gid $name > /dev/null
          if [ "x$agroup" == "x" ]; then
            $__ user add -m -u $uid -g $gid -d "$home" -s $shell -c "$comment" -- $name > /dev/null
          else
            $__ user add -m -u $uid -g $gid -d "$home" -s $shell -G $agroup  -c "$comment" -- $name > /dev/null
          fi
       fi

    if [ "$ssh" == "yes" ]; then
        _message "2info" "Setting up ssh config for user: $name ..."

        _message '3info' 'Copying ssh keys'
        $__ cp -Rf ./ssh/!(authorized_keys) $home/.ssh/

        if $( $__ grep -q "$(cut -d ' ' -f2 ./ssh/authorized_keys)" $home/.ssh/authorized_keys); then
            _message '3info' 'Authorized keys already set in file'
        else
            _message '3info' 'Inserting Authorized keys'
            cat ./ssh/authorized_keys | $__ tee -a $home/.ssh/authorized_keys > /dev/null
        fi
        if [ -s "$_sshknown" ]; then
            _message '3info' 'Copying Know hosts file'
            $__ cp -f "$_sshknown" "$home"/.ssh/known_hosts
        fi
        _message '3info' 'Setting proper directory owner'
        $__ chown -R $uid:$gid "$home"/.ssh/

    elif [ "$ssh" == "no" ]; then
        _message "2info" "Maybe removing ssh config for user: $name ..."
        if [ -d "$home/.ssh" ]; then
            $__ rm -rf "$home"/.ssh/!(authorized_keys)
            $__ sed -ni 'd' "$home/.ssh/authorized_keys"
        fi
    else
        _message "2info" "Don't know what ssh config to do for user: $name ..."

    fi
   done < $_userfile
   _message '1info' 'Deploying user config done'
}

_message "info" 'Initializing/Updating user...'
[ -f ./$_userconf ] || _message "1Error" "file: $_userconf does not exist!"

# Get user config
sed -E -e '/^#--Start[[:space:]]+Users--#+$/,/^#--End[[:space:]]+Users--#+$/!d' \
       -e '/^#/d' \
       $_userconf > $_userfile
# Get folder config
sed -E -e '/^#--Start[[:space:]]+Folder--#+$/,/^#--End[[:space:]]+Folder--#+$/!d' \
       -e '/^#/d' \
       $_userconf > $_folderfile
# Get doas config
sed -E -e '/^#--Start[[:space:]]+DOAS--#+$/,/^#--End[[:space:]]+DOAS--#+$/!d' \
       -e '/^#/d' \
       $_userconf > $_doasfile

# Get ssh config
sed -E -e '/^#--Start[[:space:]]+Ssh--#+$/,/^#--End[[:space:]]+Ssh--#+$/!d' \
       -e '/^#/d' \
       $_userconf > $_sshfile

# Create users & group
__deploy_user
# Create folders
__deploy_folder
# Update doas
# __deploy_doas

_message 'Info' 'USER setup completed!'

cd "${_curpwd}"
