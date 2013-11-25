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

# ------------- Finding where I am -------------

LOCAL=$(cd $(dirname $0); pwd)

#default flags
DEFAULT_FLAGS=(-auto -times -dontchmod -perms 0)
DEFAULT_FLAGS+=(-ignore 'Name .DS_Store')
DEFAULT_FLAGS+=(-ignore 'Name ._*')
DEFAULT_FLAGS+=(-ignore 'Path .Trash*')
DEFAULT_FLAGS+=(-ignore 'Name .SyncArchive')
DEFAULT_FLAGS+=(-ignore 'Name .SyncID')
DEFAULT_FLAGS+=(-ignore 'Name .SyncIgnore')
DEFAULT_FLAGS+=(-ignore 'Name .dropbox*')
DEFAULT_FLAGS+=(-ignore 'Path .dropbox*')
DEFAULT_FLAGS+=(-ignore 'Name .unison*')
DEFAULT_FLAGS+=(-ignore 'Path .unison*')
DEFAULT_FLAGS+=(-ignore 'Name Thumbs.db')
DEFAULT_FLAGS+=(-ignore 'Name *~')
DEFAULT_FLAGS+=(-ignore 'Name *.!sync')

ADDITIONAL_FLAGS=($@)

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

# ------------- dirs -------------

#editing the remote dir
DIR_REMOTE=${LOCAL/\/home\/$USER\//\/home\/$USER_REMOTE\/}
DIR_REMOTE=${LOCAL/\/Users\/$USER\//\/Users\/$USER_REMOTE\/}

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

if [ -e "$LOCAL/unison.ignore" ]
then
    while read i
    do
        EXCLUDE+=(-ignore "$i")
    done < "$LOCAL/unison.ignore"
    echo "Using exclude file $LOCAL/unison.ignore: ${EXCLUDE[@]}"
else
    echo "Not using any exclude file."
fi

# ------------- argument file -------------

if [ -e "$LOCAL/unison.arguments" ]
then
    if [ `cat $LOCAL/unison.arguments | wc -l` -gt 1 ]
    then
        echo "ERROR: file $LOCAL/unison.arguments cannot have more than one line."
        exit 3
    fi
    for i in `cat $LOCAL/unison.arguments`
    do
        ADDITIONAL_FLAGS+=($i)
    done
    echo "Using arguments file $LOCAL/unison.arguments"
else
    echo "Not using any arguments file."
fi
# ------------- singularities -------------

case "`hostname`" in
    "tud14231" )
        #inverse translation of "jgte-mac.no-ip.org"
        DIR_REMOTE=${DIR_REMOTE/\/Users\//\/home\/}
    ;;
    * )
        #do nothing
    ;;
esac

case "$COMPUTER_REMOTE" in
    "portable" )
        #portable is always at PORTABLE_MOUNT_POINT
        PORTABLE_MOUNT_POINT=/media/portable/portable
        DIR_REMOTE=$PORTABLE_MOUNT_POINT/${LOCAL//\/home\//}
        #portable is always connected locally
        USER_REMOTE=$USER
        COMPUTER_REMOTE=localhost
    ;;
    "jgte-mac.no-ip.org" )
        #inverse translation of "tud14231"
        DIR_REMOTE=${DIR_REMOTE/\/home\//\/Users\/}
        #adding non-default location of unison because of brew
        DEFAULT_FLAGS+=(-servercmd /usr/local/bin/unison)
    ;;
    "linux-bastion.tudelft.nl" )
      DIR_REMOTE=${DIR_REMOTE/\/home\//\/home\/nfs\/}
    ;;
    * )
        #do nothing
    ;;
esac

# ------------- pinging remote host -------------

# ping -c 1 $COMPUTER_REMOTE || (
#     echo "Continue anyway [Y/n]?"
#     read ANSWER
#     [ "$ANSWER" == "n" ] || [ "$ANSWER" == "N" ] && exit 3
# )

# ------------- feedback -------------

echo "Additional flags are  ${ADDITIONAL_FLAGS:+"${ADDITIONAL_FLAGS[@]}"}"
echo "Remote computer is $COMPUTER_REMOTE; Remote user is $USER_REMOTE; local user is $USER"
echo "Remote dir is $DIR_REMOTE; local dir is $LOCAL"
echo "Exclude commands are ${EXCLUDE:+"${EXCLUDE[@]}"}"

# ------------- syncing -------------

unison "$LOCAL" "ssh://$USER_REMOTE@$COMPUTER_REMOTE/$DIR_REMOTE" -sshargs "$SSH_ARGS" "${DEFAULT_FLAGS[@]}" ${EXCLUDE:+"${EXCLUDE[@]}"} ${ADDITIONAL_FLAGS:+"${ADDITIONAL_FLAGS[@]}"}
