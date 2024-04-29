#!/usr//bin/env ksh
set -euo pipefail

# DEBUG
# Set to anything but n to activate
DEBUG=n
[ $DEBUG != 'n' ] && set -x

__='doas -n '

_message () {
   [ $DEBUG != 'n' ] && set -x
   typeset -u mtype # all value are converted to upper case
   local mpattern="%s: %s\n"
   local mtab=""
   mtype=${1:-"Error"}
   typeset -i numtab=${mtype%%[a-zA-Z]*}
   shift

   case $numtab in
       [1-9])
           for _ in $(seq -s" " ${numtab}); do
               mtab="\t$mtab"
           done
           ;;

   esac
   mpattern="$mtab$mpattern"
   mtype="${mtype#[0-9]}"

   if [[ ${mtype} == "ERROR"  ]]; then
      >&2 printf "$mpattern" $mtype "${@:-\"Something happends...\"}"
      exit 1
   else
       printf "$mpattern" $mtype "${@:-\"Something happends...\"}"
   fi
}

_run_checks () {
    [ $DEBUG != 'n' ] && set -x
    set -A  cmds $@
    set -A missing "x"

    local i=1
    for c in "${cmds[@]}"; do
        if ! type "${c}" 2>&1 >/dev/null; then
            missing[$i]="${c}"
            (( i += 1 ))
        fi
    done
    if [ ${#missing[@]} -gt 1 ]; then
        _message "Error" "Missing program(s): ${missing[@]}"
    fi
}

_add_packages () {
    if [ -f "${1}" ]; then
        local _tmp=$(mktemp /tmp/temail.XXXXXXX.package)
        trap "$(_show_clean 2 $_tmp)" ERR EXIT

        _message "1Info" "Installing additional package(s)..."
         $__ pkg_add -Vvl "${1}" > "${_tmp}" 2>&1
         [ -f ${_tmp} ] && {
             while read -ru l ; do
                 printf "\t\t%s\n" "$l"
             done < ${_tmp}
             rm -f ${_tmp}
         }

        _message "1Info" "Done: Installing additional package(s)"


    else
        _message "1Error" "file ${1} cannot be found!"
    fi
}

_update_crontab () {
    _run_checks "id sed crontab cat"

    local tmpfile=$(mktemp /tmp/temail.XXXXXXX.crontab)
    trap "[ -f $tmpfile ] && rm -f $tmpfile" ERR

    local location="$1"
    [ -z $location ] && \
        _message 'Error' "The location in the cron file cannot be empty"

    local user="${2:-root}"
      id -u $user >/dev/null 2>&1 ||  \
        _message 'Error' "The user $user does not exist"
    shift ${#@}

    $__ crontab -l > $tmpfile

    # Remove previous entries which must must be like:
    # #-$location Start---
    # #-$location End---
    sed -Ei "/^#-+$location[[:space:]]+Start/,/^#-+$location[[:space:]]+End/D" $tmpfile

    # add new cron tab
    while read -u  ctab 2>/dev/null; do
        print "$ctab"  >> $tmpfile
    done

    $__ crontab -u $user $tmpfile


    [ -f $tmpfile ] && rm -f $tmpfile

}

# Check diff of files in a given folder
# parameters:
#   -s source directory
#   -f filename pattern (file globbing only)
#   -t target directory
#   -i ignore pattern: pattern to ignore in the diff
# output: (D|S|E)@f;... | X@d;...
#  - D: source and target file are Different
#  - S: source and target file are the Same
#  - E: error was not able to process file f
#  - X: unalble to read Directory d
#  - f: fullpath of source filename
_check_diff() {
    local output="";
    local source="";
    local target="";
    local files="";
    local regex="";
    local filter="";
    local usage=$(cat <<-EOF
        Usage: _check_diff -s DIR -t DIR -f pattern [-i regex] ...
          Perform a diff of Source files with Target files,
          Ignoring regex found in files.
          Pattern support glob(7)
          Regex support re_format(7)
EOF
          );

    trap "print \"$usage\"" ERR

    while getopts s:t:f:i: p; do
        case $p in
            s) source=$OPTARG
               ;;
            t) target=$OPTARG
               ;;
            f) files=$OPTARG
               ;;
            i) regex="$OPTARG${regex:+ }${regex}"
               ;;
            *) print "$usage"
               return 1
               ;;
        esac
    done
    shift $(($OPTIND - 1))
    # Validation of input
    if [[ "x$source" == "x" || "x$target" == "x" || "x$files" == "x" ]]; then
        return 1
    elif [[ ! -d "$source" ]]; then
        output="X@$source${output:+;}${output}"
    elif $__ test ! -d "$target"; then
        output="X@$target${output:+;}${output}"
    fi
    [[ "x$output" != "x" ]] && { print "$output"; return 0; }
    _run_checks "find diff"
    # Done
    files=$(cd "$source";find . -type f -iname "$files")
    for r in $regex; do
        filter="-I '$r' ${filter}"
    done
    for f in $files; do
        f="${f#*/}"
        if [[ ! -f "$source/$f" ]]; then
            output="E@$f${output:+;}${output}"
            continue
        elif $__ test ! -f "$target/$f"; then
            output="E@$f${output:+;}${output}"
            continue
        fi
        if $($__ diff -qb $filter "$source/$f" "$target/$f" >/dev/null 2>&1); then
            # file did not change
            output="S@$f${output:+;}${output}"
        else
            # file did change
            output="D@$f${output:+;}${output}"
        fi
    done

    # show the answer
    print "$output"

}

# Following the execution of `_check_diff` apply changes
# mtab: the number of tab to apply to messages
# check: the output of the execution of check diff
# source: the source directory
# target: the target directory
_apply_changes() {

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

# Return a string command that cleanup a file or folder
# files: the files to show and clean up
_clean () {
    local files="$@"
    local output=""
    [ -z "$files" ] && return 0
    for f in $files; do
        [[ ! -f "$f" && ! -d "$f" ]] && continue
        output="${output}${output:+;}"$(cat <<-EOF
[[ -f $f  || -d $f ]] && rm -rf $f
EOF
              )
    done
    echo "$output"
}

# Display content of files with appropriate tabs
# mtab: the number of tab to apply to messages
# files: the files to show and clean up
_show () {
    typeset -i  mtab=${1:-1}
    shift
    local files="$@"
    local l=""
    local pattern="\t%s\n"
    [ -z "$files" ] && return 0
    if [[ $mtab > 1 ]] ; then
        mtab=$(( $mtab - 1 ))
        for _ in $(seq 1 $mtab); do
            pattern="\t$pattern"
        done
    fi
    for f in $files; do
        [ ! -f "$f" ] && continue
        while read -ru l; do
            printf "$pattern" "$l"
        done < $f
    done
}

# Return a string command that cleanup display and cleanup a file
# mtab: the number of tab to apply to messages
# files: the files to show and clean up
_show_clean () {
    typeset -i  mtab=${1:-1}
    shift
    local files="$@"
    local output=""
    local l=""
    local pattern="\t%s\n"
    [ -z "$files" ] && return 0
    if [[ $mtab > 1 ]] ; then
        mtab=$(( $mtab - 1 ))
        for _ in $(seq 1 $mtab); do
            pattern="\t$pattern"
        done
    fi
    for f in $files; do
        [ ! -f "$f" ] && continue
        output="${output}${output:+;}"$(cat <<-EOF
if [ -f $f ]; then
    while read -ru l; do
        printf "$pattern" "$l"
    done < $f
    rm -f $f
fi
EOF
                                        )
    done
    echo "$output"
}


# Read a space/tab separated configuration section from file
# conf: configuration file
# destination: path to file where configuration section sould be saved
# Section: the name of the section
#  Section are enclosed by:
#   #--Start <section>--#[...]#
#   #--End <section>--#[...]#
_read_conf() {
    local conf="$1" dest="$2"
    shift 2
    local section="$@"
    [ -f $conf ] || _message "1Error" "file: $conf does not exist!"

    sed -E -e '/^#--Start[[:space:]]+'"$section"'--#+$/,/^#--End[[:space:]]+'"$section"'--#+$/!d' \
        -e '/#/d' \
        $conf > $dest
}
