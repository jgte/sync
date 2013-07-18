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

# ------------- Finding where I am ------------- 

DIR=`dirname $0`
DIR=`cd $DIR; pwd`

#default flags
DEFAULT_FLAGS="--progress --human-readable --recursive --update --times --omit-dir-times --links --sparse  --fuzzy --partial --log-file=$HOME/bin/rsync.log --no-perms --no-group --chmod=ugo=rwX --compress --modify-window=2"

# ------------- additonal flags ------------- 

ADDITIONAL_FLAGS=${@//--not-local2remote/}
ADDITIONAL_FLAGS=${ADDITIONAL_FLAGS//--not-remote2local/}

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

# ------------- dirs ------------- 

#editing the remote dir
DIR_REMOTE=${DIR/\/home\/$USER\//\/home\/$USER_REMOTE\/}
DIR_REMOTE=${DIR/\/Users\/$USER\//\/Users\/$USER_REMOTE\/}

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

if [ -e "$DIR/rsync.exclude" ]
then
    EXCLUDE="--exclude-from=$DIR/rsync.exclude"
    echo -e "Using exclude file $DIR/rsync.exclude:\n`cat $DIR/rsync.exclude`\n"
else
    EXCLUDE=""
    echo "Not using any exclude file."
fi

# ------------- argument file ------------- 

if [ -e "$DIR/rsync.arguments" ]
then
    if [ `cat $DIR/rsync.arguments | wc -l` -gt 1 ]
    then
        echo "ERROR: file $DIR/rsync.arguments cannot have more than one line."
        exit 3
    fi
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS `cat $DIR/rsync.arguments`"
    echo "Using arguments file $DIR/rsync.arguments"
else
    echo "Not using any arguments file."
fi

# ------------- singularities ------------- 

case "$COMPUTER_REMOTE" in
    "portable" )
        #portable is always at PORTABLE_MOUNT_POINT
        PORTABLE_MOUNT_POINT=/media/portable/portable/docs
        DIR_REMOTE=$PORTABLE_MOUNT_POINT/${DIR//\/home\//}
        #portable is always connected locally
        USER_REMOTE=$USER
        COMPUTER_REMOTE=localhost
    ;;
    "jgte-mac.no-ip.org" )
        #inverse translation of "tud14231"
        DIR_REMOTE=${DIR_REMOTE/\/home\//\/Users\/}
    ;;
    * )
        #do nothing
    ;;
esac

case "`hostname`" in
    "tud14231" )
        #inverse translation of "jgte-mac.no-ip.org"
        DIR_REMOTE=${DIR_REMOTE/\/Users\//\/home\/}
    ;;
    * )
        #do nothing
    ;;
esac

# ------------- feedback ------------- 

echo "Additional flags are $ADDITIONAL_FLAGS"
echo "Remote computer is $COMPUTER_REMOTE"
echo "Remote user is $USER_REMOTE; local user is $USER"
echo "Remote dir is $DIR_REMOTE; local dir is $DIR"

# ------------- local to remote ------------- 

if [[ "${@//--not-local2remote/}" == "$@" ]]
then
    echo "Synching local -> remote"
    if [ -z "$RSH" ]
    then
        rsync $DEFAULT_FLAGS $ADDITIONAL_FLAGS $EXCLUDE $DIR/ $USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/ | grep -v 'files...'
    else
        rsync --rsh="$RSH" $DEFAULT_FLAGS $ADDITIONAL_FLAGS $EXCLUDE $DIR/ $USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/ | grep -v 'files...'
    fi
fi

# ------------- remote to local ------------- 

if [[ "${@//--not-remote2local/}" == "$@" ]]
then
    echo "Synching remote -> local"
    if [ -z "$RSH" ]
    then
        rsync $DEFAULT_FLAGS $ADDITIONAL_FLAGS $EXCLUDE $USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/ $DIR/ | grep -v 'files...'
    else
        rsync --rsh="$RSH" $DEFAULT_FLAGS $ADDITIONAL_FLAGS $EXCLUDE $USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/ $DIR/ | grep -v 'files...'
    fi
fi


