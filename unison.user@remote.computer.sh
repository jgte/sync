#!/bin/bash -u

# This script connects to the computer specified in the filename and synchronizes
# the current directory with the corresponding remote current directory.
#
# The remote computer name and the user on that computer is identified in the
# filename of this script as:
#
#   unison.<username>@<remote computer>.sh
#
# If there is no '@' character, then the current username is used.
#
# The current directory is synchronized with the remote directory, relative to $HOME
# (this cannot be changed):
#
#   <username>@<remote computer>:$PWD
#
# All input arguments are passed as additional unison arguments.
#
# https://github.com/jgte/bash


function machine_is
{
  OS=`uname -v`
  [[ ! "${OS//$1/}" == "$OS" ]] && return 0 || return 1
}

function file_ends_with_newline() {
    [[ "$(tail -c1 "$1")" == "" ]]
    # if machine_is Darwin
    # then
    #     [[ "$(tail -n1 "$1")" == "" ]]
    # else
    #     [[ "$(tail -c1 "$1")" == "" ]]
    # fi
}

# ------------- unison executable -------------

UNISON="$(which unison)"
if [ -z "$UNISON" ]
then
    for i in / /usr /usr/local $HOME
    do
        for j in bin sbin
        do
            [ -e "$i$j/unison" ] && UNISON="$i$j/unison"
            [ ! -z "$UNISON" ] && break
        done
        [ ! -z "$UNISON" ] && break
    done
fi
if [ -z "$UNISON" ]
then
    echo ERROR: cannot find unison binary
    exit 3
fi

# ------------- Finding where I am -------------

LOCAL=$(cd $(dirname $0); pwd)

#default flags
DEFAULT_FLAGS=(-auto)
DEFAULT_FLAGS+=(-times)
DEFAULT_FLAGS+=(-fastcheck true)
# DEFAULT_FLAGS+=(-perms 0)
# DEFAULT_FLAGS+=(-dontchmod)
DEFAULT_FLAGS+=(-rsrc false)
DEFAULT_FLAGS+=(-prefer newer)
DEFAULT_FLAGS+=(-links false)

#default files to ignore
IGNORE_FLAGS=()
IGNORE_FLAGS+=(-ignore 'Name *-blx.bib')
IGNORE_FLAGS+=(-ignore 'Name *.!sync')
IGNORE_FLAGS+=(-ignore 'Name *.a')
IGNORE_FLAGS+=(-ignore 'Name *.aux')
IGNORE_FLAGS+=(-ignore 'Name *.bbl')
IGNORE_FLAGS+=(-ignore 'Name *.blg')
IGNORE_FLAGS+=(-ignore 'Name *cache*')
IGNORE_FLAGS+=(-ignore 'Path *cache*')
IGNORE_FLAGS+=(-ignore 'Name *.exe')
IGNORE_FLAGS+=(-ignore 'Name *.fdb_latexmk')
IGNORE_FLAGS+=(-ignore 'Name *.fls')
IGNORE_FLAGS+=(-ignore 'Name *.lof')
IGNORE_FLAGS+=(-ignore 'Name *.log')
IGNORE_FLAGS+=(-ignore 'Name .*.log')
IGNORE_FLAGS+=(-ignore 'Name *.lot')
IGNORE_FLAGS+=(-ignore 'Name *.nav')
IGNORE_FLAGS+=(-ignore 'Name *.o')
IGNORE_FLAGS+=(-ignore 'Name *.out')
IGNORE_FLAGS+=(-ignore 'Name *.run.xml')
IGNORE_FLAGS+=(-ignore 'Name *.snm')
IGNORE_FLAGS+=(-ignore 'Name *.swp')
IGNORE_FLAGS+=(-ignore 'Name *.synctex.gz')
IGNORE_FLAGS+=(-ignore 'Name *.toc')
IGNORE_FLAGS+=(-ignore 'Name *.vrb')
IGNORE_FLAGS+=(-ignore 'Path__pycache__')
IGNORE_FLAGS+=(-ignore 'Name *conflicted*')
IGNORE_FLAGS+=(-ignore 'Name *to-delete*')
IGNORE_FLAGS+=(-ignore 'Name *~')
IGNORE_FLAGS+=(-ignore 'Name .*.swp')
IGNORE_FLAGS+=(-ignore 'Name ._*')
IGNORE_FLAGS+=(-ignore 'Path .DocumentRevisions*')
IGNORE_FLAGS+=(-ignore 'Name .dropbox*')
IGNORE_FLAGS+=(-ignore 'Name .DS_Store')
IGNORE_FLAGS+=(-ignore 'Path .fseventsd*')
IGNORE_FLAGS+=(-ignore 'Name .fuse_hidden*')
IGNORE_FLAGS+=(-ignore 'Name .gmt*')
IGNORE_FLAGS+=(-ignore 'Name .HFS+*')
IGNORE_FLAGS+=(-ignore 'Name .journal*')
IGNORE_FLAGS+=(-ignore 'Name .metadata*')
IGNORE_FLAGS+=(-ignore 'Path .Spotlight*')
IGNORE_FLAGS+=(-ignore 'Name .swo')
IGNORE_FLAGS+=(-ignore 'Name .swp')
IGNORE_FLAGS+=(-ignore 'Name .sync*')
IGNORE_FLAGS+=(-ignore 'Path .sync')
IGNORE_FLAGS+=(-ignore 'Name .SyncArchive')
IGNORE_FLAGS+=(-ignore 'Name .SyncID')
IGNORE_FLAGS+=(-ignore 'Name .SyncIgnore')
IGNORE_FLAGS+=(-ignore 'Path .TemporaryItems')
IGNORE_FLAGS+=(-ignore 'Path .Trash*')
IGNORE_FLAGS+=(-ignore 'Name .unison*')
IGNORE_FLAGS+=(-ignore 'Name .~*')
IGNORE_FLAGS+=(-ignore 'Path $RECYCLE.BIN')
IGNORE_FLAGS+=(-ignore 'Name Icon*')
IGNORE_FLAGS+=(-ignore 'Path lost+found')
IGNORE_FLAGS+=(-ignore 'Name nohup.out')
IGNORE_FLAGS+=(-ignore 'Name screenlog.*')
IGNORE_FLAGS+=(-ignore 'Name Thumbs.db')
IGNORE_FLAGS+=(-ignore 'Path *to-delete*')
IGNORE_FLAGS+=(-ignore 'Path .dropbox*')
IGNORE_FLAGS+=(-ignore 'Path .unison')

# ------------- remote computer name -------------

COMPUTER_REMOTE=`basename $0`
COMPUTER_REMOTE=${COMPUTER_REMOTE%.sh}
COMPUTER_REMOTE=${COMPUTER_REMOTE#unison.}

# ------------- remote username -------------

#strip user form the remote computer name
USER_REMOTE=${COMPUTER_REMOTE%@*}
#handling user in the computer name
if [ "$USER_REMOTE" == "$COMPUTER_REMOTE" ]
then
    #if the user is the same of the computer, then no user was given
    USER_REMOTE=$USER
else
    #if there's a user, then remove it form the computer name
    COMPUTER_REMOTE=${COMPUTER_REMOTE#*@}
fi

# ------------- keyfile -------------

SSH_KEY_FILE=$HOME/.ssh/$USER_REMOTE@${COMPUTER_REMOTE%%.*}
echo "Looking for key file $SSH_KEY_FILE"
if [ ! -e "$SSH_KEY_FILE" ]
then
    SSH_KEY_FILE=none
    SSH_ARGS="-C"
    echo "Not using a keyfile (file $SSH_KEY_FILE does not exist)."
else
    SSH_ARGS="-C -i $SSH_KEY_FILE"
    echo "Using keyfile $SSH_KEY_FILE"
fi

# ------------- exclude file -------------

EXCLUDE=()
for FILE_NOW in "$LOCAL/unison.ignore" "$LOCAL/unison.$COMPUTER_REMOTE.ignore"
do
    if [ -e "$FILE_NOW" ]
    then
        file_ends_with_newline "$FILE_NOW" || {
            echo "ERROR: file $FILE_NOW needs to end with a newline."
            exit 3
        }
        while read i
        do
            EXCLUDE+=(-ignore "$i")
        done < "$FILE_NOW"
        echo "Using exclude file $FILE_NOW: ${EXCLUDE[@]}"
    else
        echo "Not using exclude file $(basename $FILE_NOW)."
    fi
done

# ------------- include file -------------

INCLUDE=()
for FILE_NOW in "$LOCAL/unison.ignorenot" "$LOCAL/unison.$COMPUTER_REMOTE.ignorenot"
do
    if [ -e "$FILE_NOW" ]
    then
        file_ends_with_newline "$FILE_NOW" || {
            echo "ERROR: file $FILE_NOW needs to end with a newline."
            exit 3
        }
        while read i
        do
            INCLUDE+=(-ignorenot "$i")
        done < "$FILE_NOW"
        echo "Using include file $FILE_NOW: ${INCLUDE[@]}"
    else
        echo "Not using include file $(basename $FILE_NOW)."
    fi
done

# ------------- argument file -------------

FILE_FLAGS=()
for FILE_NOW in "$LOCAL/unison.arguments" "$LOCAL/unison.$COMPUTER_REMOTE.arguments"
do
    if [ -e "$FILE_NOW" ]
    then
        file_ends_with_newline "$FILE_NOW" || {
            echo "ERROR: file $FILE_NOW needs to end with a newline."
            exit 3
        }
        while read -r i
        do
            echo "Added to FILE_FLAGS the argument '$i'"
            FILE_FLAGS+=("$i")
        done <<< "$(xargs < "$FILE_NOW" printf '%s\n')"
        echo "Using arguments file $FILE_NOW"
    else
        echo "Not using arguments file $(basename $FILE_NOW)."
    fi
done

# ------------- more arguments in the command line -------------

ADDITIONAL_FLAGS="$@"

# ------------- debug -------------

if [[ ! "${ADDITIONAL_FLAGS/-debug/}" == "$ADDITIONAL_FLAGS" ]]; then
    UNISON="echo $UNISON"
    ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS/-debug/}"
fi

# ------------- dirs -------------

for ((i = 0 ; i < ${#FILE_FLAGS[@]} ; i++))
do
    echo "FILE_FLAGS1[$i]=${FILE_FLAGS[$i]}"
done

if [ ${#FILE_FLAGS[@]} -gt 0 ] && [[ ! "${FILE_FLAGS[@]//--remote-dir=/}" == "${FILE_FLAGS[@]}" ]]
then
    count=0
    for ((i = 0 ; i < ${#FILE_FLAGS[@]} ; i++))
    do
        echo "FILE_FLAGS[$i]=${FILE_FLAGS[$i]}"
        if [[ ! "${FILE_FLAGS[$i]//--remote-dir=/}" == "${FILE_FLAGS[$i]}" ]]
        then
            DIR_REMOTE="${FILE_FLAGS[$i]/--remote-dir=/}"
            echo "DIR_REMOTE1=$DIR_REMOTE"
            FILE_FLAGS[$i]=""
            break
        fi
    done
elif [[ ! "${ADDITIONAL_FLAGS//--remote-dir=/}" == "${ADDITIONAL_FLAGS}" ]]
then
    for i in $ADDITIONAL_FLAGS
    do
        if [[ ! "${i//--remote-dir=/}" == "$i" ]]
        then
            DIR_REMOTE="${i/--remote-dir=/}"
            ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS//--remote-dir=$DIR_REMOTE/}"
            break
        fi
    done
else
    #editing the remote dir
    DIR_REMOTE="${LOCAL/\/home\/$USER\//\/home\/$USER_REMOTE\/}"
    DIR_REMOTE="${LOCAL/"/Users/$USER/"/"/Users/$USER_REMOTE/"}"
fi

for ((i = 0 ; i < ${#FILE_FLAGS[@]} ; i++))
do
    echo "FILE_FLAGS2[$i]=${FILE_FLAGS[$i]}"
done

echo "DIR_REMOTE=$DIR_REMOTE"

# ------------- remote location -------------

REMOTE="ssh://$USER_REMOTE@$COMPUTER_REMOTE/$DIR_REMOTE"

# ------------- force flags -------------

if [[ ! "${ADDITIONAL_FLAGS/-force-here/}" == "$ADDITIONAL_FLAGS" ]]; then
    FORCELOCAL_FLAGS="-force $LOCAL"
      FORCEDIR_FLAGS=
    ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS/-force-here/}"
elif [[ ! "${ADDITIONAL_FLAGS/-force-there/}" == "$ADDITIONAL_FLAGS" ]]; then
    FORCELOCAL_FLAGS=
      FORCEDIR_FLAGS="-force $REMOTE"
    ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS/-force-there/}"
else
    FORCELOCAL_FLAGS=
      FORCEDIR_FLAGS=
fi

# ------------- no deletion flags -------------

if [[ ! "${ADDITIONAL_FLAGS/--nodeletion-here/}" == "$ADDITIONAL_FLAGS" ]]; then
    NODELETIONLOCAL_FLAGS="-nodeletion $LOCAL"
      NODELETIONDIR_FLAGS=
    ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS/-nodeletion-here/}"
elif [[ ! "${ADDITIONAL_FLAGS/-nodeletion-there/}" == "$@" ]]; then
    NODELETIONLOCAL_FLAGS=
      NODELETIONDIR_FLAGS="-nodeletion $REMOTE"
    ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS/-nodeletion-there/}"
else
    NODELETIONLOCAL_FLAGS=
      NODELETIONDIR_FLAGS=
fi

# ------------- syncing -------------
#need to fix freaky blank messing up the unison call below
ADDITIONAL_FLAGS="$(echo $ADDITIONAL_FLAGS |  sed 's/ *$//' | sed 's/^ *//')"

# ------------- pinging remote host -------------

# ping -c 1 $COMPUTER_REMOTE || (
#     echo "Continue anyway [Y/n]?"
#     read ANSWER
#     [ "$ANSWER" == "n" ] || [ "$ANSWER" == "N" ] && exit 3
# )

    [ ! -d "$LOCAL" ] && echo "ERROR: cannot find $LOCAL" && exit 3

# ------------- simplemode -------------

echo "====================================================================="
echo "Default flags        : ${DEFAULT_FLAGS[@]}"
echo "Default ignore flags : ${IGNORE_FLAGS[@]}"
echo "Command-line flags   : $ADDITIONAL_FLAGS $FORCELOCAL_FLAGS $FORCEDIR_FLAGS $NODELETIONLOCAL_FLAGS $NODELETIONDIR_FLAGS"
echo "File ignore flags    : ${EXCLUDE[@]:-None}"
echo "File ignorenot flags : ${INCLUDE[@]:-None}"
echo "File flags           : ${FILE_FLAGS[@]:-None}"
echo "ssh flags            : -sshargs $SSH_ARGS"
echo "remote is            : $REMOTE"
echo "local is             : $LOCAL"
echo "====================================================================="
$UNISON \
    ${DEFAULT_FLAGS[@]} \
    "${IGNORE_FLAGS[@]}" \
    "${EXCLUDE[@]:-}" \
    ${INCLUDE[@]:-} \
    ${FILE_FLAGS[@]:-} \
    $ADDITIONAL_FLAGS $FORCELOCAL_FLAGS $FORCEDIR_FLAGS \
    -sshargs "$SSH_ARGS" \
    "$LOCAL" "$REMOTE" \
