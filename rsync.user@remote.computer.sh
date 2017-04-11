#!/bin/bash -u

# This script connects to the computer specified in the filename and synchronizes
# the current directory with the corresponding remote current directory.
#
# The remote computer name and the user on that computer is identified in the
# filename of this script as:
#
#   rsync.<username>@<remote computer>.sh
#
# If there is no '@' character, then the current username is used.
#
# The current directory is synchronized with the remote directory, relative to $HOME
# (this cannot be changed):
#
#   <username>@<remote computer>:$PWD
#
# To specify unidirection sync, use in the argument list the keywords:
#
#   '--not-local2remote' or '--not-remote2local'
#
# All input arguments are passed as additional rsync arguments (except
# the keywords above).
#
# https://github.com/jgte/bash

function machine_is
{
  OS=`uname -v`
  [[ ! "${OS//$1/}" == "$OS" ]] && return 0 || return 1
}

# ------------- dynamic parameters -------------

LOCAL=$(cd $(dirname $0); pwd)

#can't get this thing to work with paths with blanks, dunno why
if [[ ! "$LOCAL" == "${LOCAL// /}" ]]
then
    echo "ERROR: cannot handle paths with blanks."
    exit 3
fi

LOG=`basename "$0"`.log
LOG=${LOG// /_}

# ------------- static parameters -------------

#default flags
DEFAULT_FLAGS=" --recursive --update --times --omit-dir-times --links --sparse  --fuzzy --partial --no-perms --no-group --chmod=ugo=rwX --modify-window=1"
DEFAULT_FLAGS+=" --exclude=.DS_Store"
DEFAULT_FLAGS+=" --exclude=._*"
DEFAULT_FLAGS+=" --exclude=*.o"
DEFAULT_FLAGS+=" --exclude=*.a"
DEFAULT_FLAGS+=" --exclude=*.exe"
DEFAULT_FLAGS+=" --exclude=.swo"
DEFAULT_FLAGS+=" --exclude=.swp"
DEFAULT_FLAGS+=" --exclude=screenlog.*"
DEFAULT_FLAGS+=" --exclude=.gmt*"
DEFAULT_FLAGS+=" --exclude=.Trash*"
DEFAULT_FLAGS+=" --exclude=lost+found"
DEFAULT_FLAGS+=" --exclude=.Spotlight*"
DEFAULT_FLAGS+=" --exclude=.fseventsd*"
DEFAULT_FLAGS+=" --exclude=.DocumentRevisions*"
DEFAULT_FLAGS+=" --exclude=.sync"
DEFAULT_FLAGS+=" --exclude=.SyncArchive"
DEFAULT_FLAGS+=" --exclude=.SyncID"
DEFAULT_FLAGS+=" --exclude=.SyncIgnore"
DEFAULT_FLAGS+=" --exclude=.dropbox*"
DEFAULT_FLAGS+=" --exclude=.unison*"
DEFAULT_FLAGS+=" --exclude=$LOG"
DEFAULT_FLAGS+=" --exclude=.git"
DEFAULT_FLAGS+=" --exclude=.svn"
DEFAULT_FLAGS+=" --exclude=Thumbs.db"
DEFAULT_FLAGS+=" --exclude=Icon"
DEFAULT_FLAGS+=" --exclude=*~"
DEFAULT_FLAGS+=" --exclude=*.!sync"

#script-specific arguments
SCRIPT_ARGS="--not-dir2local --not-local2dir --not-local2remote --not-remote2local --no-confirmation --no-feedback --backup-deleted"

# ------------- given arguments -------------

ARGS=$@

# ------------- additonal flags -------------

ADDITIONAL_FLAGS=$ARGS
for i in $SCRIPT_ARGS
do
    ADDITIONAL_FLAGS=${ADDITIONAL_FLAGS//$i/}
done
ADDITIONAL_FLAGS=${ADDITIONAL_FLAGS//--remote-dir=.*/}

# ------------- remote computer name -------------

COMPUTER_REMOTE=`basename $0`
COMPUTER_REMOTE=${COMPUTER_REMOTE%.sh*}
COMPUTER_REMOTE=${COMPUTER_REMOTE#*rsync.}

# ------------- remote username -------------

#strip user form the remote computer name
USER_REMOTE=${COMPUTER_REMOTE%@*}
#handling user in the computer name
if [ "$USER_REMOTE" == "$COMPUTER_REMOTE" ]
then
    #if the user is the same of the computer, then no user was given
    USER_REMOTE=${USER:-unknown}
else
    #if there's a user, then remove it form the computer name
    COMPUTER_REMOTE=${COMPUTER_REMOTE#*@}
fi
# ------------- local username -------------

#this is useful when run from crontab and the USER_REMOTE is set
USER=${USER:-$USER_REMOTE}

# ------------- argument file -------------

if [ -e "$LOCAL/rsync.arguments" ]
then
    if [ `cat "$LOCAL/rsync.arguments" | wc -l` -gt 1 ]
    then
        echo "ERROR: file $LOCAL/rsync.arguments cannot have more than one line."
        exit 3
    fi
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS `cat "$LOCAL/rsync.arguments"`"
    #need to clean script-specific arguments, otherwise they contaminate the rsync call
    for i in $SCRIPT_ARGS
    do
        if [[ ! "${ADDITIONAL_FLAGS//$i/}" == "$ADDITIONAL_FLAGS" ]]
        then
            ADDITIONAL_FLAGS=${ADDITIONAL_FLAGS//$i/}
            ARGS="$ARGS $i"
        fi
    done
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Using arguments file $LOCAL/rsync.arguments: `cat "$LOCAL/rsync.arguments"`"
else
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Not using any arguments file."
fi

# ------------- dirs -------------

if [[ ! "${ADDITIONAL_FLAGS//--remote-dir=/}" == "$ADDITIONAL_FLAGS" ]]
then
    for i in $ADDITIONAL_FLAGS
    do
        if [[ ! "${i//--remote-dir=/}" == "$i" ]]
        then
            #xargs trimmes the DIR_REMOTE value
            DIR_REMOTE="$(echo ${i/--remote-dir=/} | xargs)"
            ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS//--remote-dir=$DIR_REMOTE/}"
            ARGS="$ARGS --remote-dir=$DIR_REMOTE"
            break
        fi
    done
else
    #editing the remote dir (no need to escape the / character of the replacing string, apparently)
    DIR_REMOTE="${LOCAL/\/home\/$USER\///home/$USER_REMOTE/}"
    DIR_REMOTE="${LOCAL/\/Users\/$USER\///Users/$USER_REMOTE/}"
fi

# # ------------- pre-run comman -------------

if [[ ! "${ADDITIONAL_FLAGS//--pre-run=/}" == "$ARGS" ]]
then
    for i in "$ADDITIONAL_FLAGS"
    do
        if [[ ! "${i//--pre-run=/}" == "$i" ]]
        then
            if [[ "${i//\'/}" == "$i" ]]
            then
                echo "ERROR: the command --pre-run='command' must use single quotes explicitly."
                exit 3
            fi
            #xargs trimmes the PRE_RUN_COM value
            PRE_RUN_COM="$(echo ${i/--pre-run=/} | xargs)"
            ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS//--pre-run=\'$PRE_RUN_COM\'/}"
            ARGS="$ARGS --pre-run=$PRE_RUN_COM"
            #execute the requested command
            echo "executing pre-run command '$PRE_RUN_COM':"
            $PRE_RUN_COM || exit $?
            break
            exit
        fi
    done
fi

# ------------- keyfile -------------

SSH_KEY_FILE=$HOME/.ssh/$USER_REMOTE@${COMPUTER_REMOTE%%.*}
[[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Looking for key file $SSH_KEY_FILE"
if [ ! -e "$SSH_KEY_FILE" ]
then
    SSH_KEY_FILE=none
    RSH=
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Not using a keyfile (file $SSH_KEY_FILE does not exist)."
else
    RSH="ssh -i $SSH_KEY_FILE"
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Using keyfile $SSH_KEY_FILE"
fi

# ------------- exclude file -------------

if [ -e "$LOCAL/rsync.exclude" ]
then
    EXCLUDE="--exclude-from=$LOCAL/rsync.exclude"
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo -e "Using exclude file $LOCAL/rsync.exclude:\n`cat "$LOCAL/rsync.exclude"`\n"
else
    EXCLUDE=""
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Not using any exclude file."
fi

# ------------- include file -------------

if [ -e "$LOCAL/rsync.include" ]
then
    INCLUDE="--include-from=$LOCAL/rsync.include"
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo -e "Using include file $LOCAL/rsync.include:\n`cat "$LOCAL/rsync.include"`\n"
else
    INCLUDE=""
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Not using any include file."
fi

# ------------- backup deleted files -------------

if [[ ! "${ARGS//--backup-deleted/}" == "$ARGS" ]]
then
    DATE=
    machine_is Darwin && DATE=$(date "+%Y-%m-%d")
    if [ -z "$DATE" ]
    then
        echo "BUG TRAP: need implementation of date for this machine"
        exit 3
    fi
    ADDITIONAL_FLAGS+=" --delete --backup --backup-dir=backup.$DATE --exclude=backup.????-??-??"
fi

# ------------- resolve argument conflicts -------------

#need to remove sparse if inplace if given
if [[ ! "${ADDITIONAL_FLAGS//--inplace/}" == "$ADDITIONAL_FLAGS" ]]
then
    DEFAULT_FLAGS="${DEFAULT_FLAGS//--sparse/}"
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Removed --sparse because --inplace was given."
fi

# ------------- singularities -------------

if [[ "${ARGS//--remote-dir=.*/}" == "$ARGS" ]]
then
    # translation origin: USER_REMOTE is used here because it was already replaced above
    case "`hostname`" in
        "tud14231"|"imac"|"csr-875717.csr.utexas.edu")
            #inverse translation of Darwin homes
            FROM="/Users/$USER_REMOTE"
        ;;
        "srv227" )
            FROM="/home/nfs/$USER_REMOTE"
        ;;
        "login1"|"login2"|"login3")
            FROM="/home1/00767/$USER_REMOTE"
        ;;
        "login1.corral.tacc.utexas.edu")
            FROM="/home/utexas/csr/$USER_REMOTE"
        ;;
        * )
            FROM="/home/$USER_REMOTE"
        ;;
    esac
    # translation destiny
    case "$COMPUTER_REMOTE" in
        "jgte-mac.no-ip.org"|"holanda.no-ip.org:20022"|"holanda.no-ip.org:20024"|"holanda.no-ip.org:20029"|"csr-875717.csr.utexas.edu" )
            #translation of Darwin homes
            TO="/Users/$USER_REMOTE"
        ;;
        "linux-bastion.tudelft.nl" )
            TO="/home/nfs/$USER_REMOTE"
        ;;
        "ls5.tacc.utexas.edu"|"login3.ls5.tacc.utexas.edu")
            which ls5.sh &> /dev/null && ls5.sh token
            TO="/home1/00767/$USER_REMOTE"
        ;;
        "corral.tacc.utexas.edu")
            TO="/home/utexas/csr/$USER_REMOTE"
        ;;
        * )
            TO="/home/$USER_REMOTE"
        ;;
    esac
    # echo FROM=$FROM
    # echo TO=$TO
    # echo "DIR_REMOTE=$DIR_REMOTE (before translating)"
    #translate
    DIR_REMOTE="${DIR_REMOTE/$FROM/$TO}"
    # echo "DIR_REMOTE=$DIR_REMOTE (after translating)"

fi


# # ------------- pinging remote host -------------

# if [[ "${ARGS//--no-feedback/}" == "$ARGS" ]]
# then
#     ping -c 1 $COMPUTER_REMOTE || exit 3
# else
#     ping -c 1 $COMPUTER_REMOTE > /dev/null || exit 3
# fi

# ------------- feedback -------------

if [[ "${ARGS//--no-feedback/}" == "$ARGS" ]]
then
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --progress --human-readable"
    echo "Additional flags are $ADDITIONAL_FLAGS"
    echo "Remote computer is $COMPUTER_REMOTE; remote user is $USER_REMOTE; local user is $USER"
    echo "Remote dir is $DIR_REMOTE; local dir is $LOCAL"
    [[ ! "${ARGS//--not-local2dir/}" == "$ARGS" ]] && echo "Not synching local to dir"
    [[ ! "${ARGS//--not-dir2local/}" == "$ARGS" ]] && echo "Not synching dir to local"
else
    #at least show me the changes
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --itemize-changes"
fi

if [[ "${ARGS//--no-confirmation/}" == "$ARGS" ]]
then
    echo "Continue [Y/n] ?"
    read ANSWER
    if [ "$ANSWER" == "N" ] || [ "$ANSWER" == "n" ]
    then
        exit
    fi
fi

# ------------- local to remote -------------

if [[ "${ARGS//--not-local2remote/}" == "$ARGS" ]] && [[ "${ARGS//--not-local2dir/}" == "$ARGS" ]]
then
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Synching local -> remote"
    if [ -z "$RSH" ]
    then
        rsync --log-file="$LOCAL/$LOG" \
            $DEFAULT_FLAGS $ADDITIONAL_FLAGS $INCLUDE $EXCLUDE \
            $LOCAL/ $USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/ | grep -v 'files...'
    else
        rsync --log-file="$LOCAL/$LOG" --rsh="$RSH" \
            $DEFAULT_FLAGS $ADDITIONAL_FLAGS $INCLUDE $EXCLUDE \
            $LOCAL/ $USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/ | grep -v 'files...'
    fi
fi

# ------------- remote to local -------------

if [[ "${ARGS//--not-remote2local/}" == "$ARGS" ]] && [[ "${ARGS//--not-dir2local/}" == "$ARGS" ]]
then
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Synching remote -> local"
    if [ -z "$RSH" ]
    then
        rsync --log-file="$LOCAL/$LOG" \
            $DEFAULT_FLAGS $ADDITIONAL_FLAGS $INCLUDE $EXCLUDE \
            $USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/ "$LOCAL/" | grep -v 'files...'
    else
        rsync --log-file="$LOCAL/$LOG" --rsh="$RSH" \
            $DEFAULT_FLAGS $ADDITIONAL_FLAGS $INCLUDE $EXCLUDE \
            $USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/ "$LOCAL/" | grep -v 'files...'
    fi
fi


