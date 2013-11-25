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

# ------------- dynamic parameters -------------

LOCAL=$(cd $(dirname $0); pwd)

LOG=`basename "$0"`.log
LOG=${LOG// /_}

# ------------- static parameters -------------

#default flags
DEFAULT_FLAGS=" --recursive --update --times --omit-dir-times --links --sparse  --fuzzy --partial --no-perms --no-group --chmod=ugo=rwX --modify-window=1"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=.DS_Store"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=._*"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=.Trash*"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=.SyncArchive"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=.SyncID"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=.SyncIgnore"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=.dropbox*"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=.unison*"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=$LOG"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=Thumbs.db"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=*~"
DEFAULT_FLAGS="$DEFAULT_FLAGS --exclude=*.!sync"

#script-specific arguments
SCRIPT_ARGS="--not-local2remote --not-remote2local --no-confirmation --no-feedback"

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
COMPUTER_REMOTE=${COMPUTER_REMOTE%.sh}
COMPUTER_REMOTE=${COMPUTER_REMOTE#rsync.}

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

# ------------- argument file -------------

if [ -e "$LOCAL/rsync.arguments" ]
then
    if [ `cat $LOCAL/rsync.arguments | wc -l` -gt 1 ]
    then
        echo "ERROR: file $LOCAL/rsync.arguments cannot have more than one line."
        exit 3
    fi
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS `cat $LOCAL/rsync.arguments`"
    #need to clean script-specific arguments, otherwise they contaminate the rsync call
    for i in $SCRIPT_ARGS
    do
        if [[ ! "${ADDITIONAL_FLAGS//$i/}" == "$ADDITIONAL_FLAGS" ]]
        then
            ADDITIONAL_FLAGS=${ADDITIONAL_FLAGS//$i/}
            ARGS="$ARGS $i"
        fi
    done
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Using arguments file $LOCAL/rsync.arguments"
else
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Not using any arguments file."
fi

# ------------- dirs -------------

if [[ ! "${ARGS//--remote-dir=.*/}" == "$ARGS" ]]
then
    for i in $ARGS
    do
        if [[ ! "${i//--remote-dir=.*/}" == "$ARGS" ]]
        then
            DIR_REMOTE=${i/--remote-dir=/}
            break
        fi
    done
else
    #editing the remote dir
    DIR_REMOTE=${LOCAL/\/home\/$USER\//\/home\/$USER_REMOTE\/}
    DIR_REMOTE=${LOCAL/\/Users\/$USER\//\/Users\/$USER_REMOTE\/}
fi

# ------------- keyfile -------------

SSH_KEY_FILE=$HOME/.ssh/$USER_REMOTE@${COMPUTER_REMOTE%%.*}
echo "Looking for key file $SSH_KEY_FILE"
if [ ! -e "$SSH_KEY_FILE" ]
then
    SSH_KEY_FILE=none
    RSH=
    echo "Not using a keyfile (file $SSH_KEY_FILE does not exist)."
else
    RSH="ssh -i $SSH_KEY_FILE"
    echo "Using keyfile $SSH_KEY_FILE"
fi

# ------------- exclude file -------------

if [ -e "$LOCAL/rsync.exclude" ]
then
    EXCLUDE="--exclude-from=$LOCAL/rsync.exclude"
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo -e "Using exclude file $LOCAL/rsync.exclude:\n`cat $LOCAL/rsync.exclude`\n"
else
    EXCLUDE=""
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Not using any exclude file."
fi

# ------------- include file -------------

if [ -e "$LOCAL/rsync.include" ]
then
    INCLUDE="--include-from=$LOCAL/rsync.include"
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo -e "Using include file $LOCAL/rsync.include:\n`cat $LOCAL/rsync.include`\n"
else
    INCLUDE=""
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Not using any include file."
fi

# ------------- resolve argument conflicts -------------

#need to remove sparse if inplace if given
if [[ ! "${ADDITIONAL_FLAGS//--inplace/}" == "$ADDITIONAL_FLAGS" ]]
then
    DEFAULT_FLAGS="${DEFAULT_FLAGS//--sparse/}"
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Removed --sparse because --inplace was given."
fi

# ------------- singularities -------------

case "`hostname`" in
    "tud14231" )
        #inverse translation of "jgte-mac.no-ip.org"
        [[ "${ARGS//--remote-dir=.*/}" == "$ARGS" ]] && DIR_REMOTE=${DIR_REMOTE/\/Users\//\/home\/}
    ;;
    * )
        #do nothing
    ;;
esac

case "$COMPUTER_REMOTE" in
    "portable" )
        #portable is always at PORTABLE_MOUNT_POINT
        PORTABLE_MOUNT_POINT=/media/portable/portable
        [[ "${ARGS//--remote-dir=.*/}" == "$ARGS" ]] && DIR_REMOTE=$PORTABLE_MOUNT_POINT/${LOCAL//\/home\//}
        #portable is always connected locally
        USER_REMOTE=$USER
        COMPUTER_REMOTE=localhost
    ;;
    "jgte-mac.no-ip.org" )
        #inverse translation of "tud14231"
        [[ "${ARGS//--remote-dir=.*/}" == "$ARGS" ]] && DIR_REMOTE=${DIR_REMOTE/\/home\//\/Users\/}
    ;;
    "linux-bastion.tudelft.nl" )
      [[ "${ARGS//--remote-dir=.*/}" == "$ARGS" ]] && DIR_REMOTE=${DIR_REMOTE/\/home\//\/home\/nfs\/}
    ;;
    * )
        #do nothing
    ;;
esac


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

if [[ "${ARGS//--not-local2remote/}" == "$ARGS" ]]
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

if [[ "${ARGS//--not-remote2local/}" == "$ARGS" ]]
then
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Synching remote -> local"
    if [ -z "$RSH" ]
    then
        rsync --log-file="$LOCAL/$LOG" \
            $DEFAULT_FLAGS $ADDITIONAL_FLAGS $INCLUDE $EXCLUDE \
            $USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/ $LOCAL/ | grep -v 'files...'
    else
        rsync --log-file="$LOCAL/$LOG" --rsh="$RSH" \
            $DEFAULT_FLAGS $ADDITIONAL_FLAGS $INCLUDE $EXCLUDE \
            $USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/ $LOCAL/ | grep -v 'files...'
    fi
fi


