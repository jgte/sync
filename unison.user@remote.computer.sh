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

# ------------- Finding where I am ------------- 

DIR=`dirname $0`
DIR=`cd $DIR; pwd`

#default flags
DEFAULT_FLAGS="-auto -times -dontchmod -perms 0"
ADDITIONAL_FLAGS="$@"

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
DIR_REMOTE=${DIR/\/home\/$USER\//\/home\/$USER_REMOTE\/}
DIR_REMOTE=${DIR/\/Users\/$USER\//\/Users\/$USER_REMOTE\/}

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

EXCLUDE=
if [ -e "$DIR/unison.ignore" ]
then
    while read i
    do
        EXCLUDE=(${EXCLUDE[@]} -ignore "$i")
    done < "$DIR/unison.ignore"
    echo "Using exclude file $DIR/unison.ignore: ${EXCLUDE[@]}"
else
    echo "Not using any exclude file."
fi

# ------------- argument file ------------- 

if [ -e "$DIR/unison.arguments" ]
then
    if [ `cat $DIR/unison.arguments | wc -l` -gt 1 ]
    then
        echo "ERROR: file $DIR/unison.arguments cannot have more than one line."
        exit 3
    fi
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS `cat $DIR/unison.arguments`"
    echo "Using arguments file $DIR/unison.arguments"
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
        #adding non-default location of unison because of brew
        DEFAULT_FLAGS="$DEFAULT_FLAGS -servercmd /usr/local/bin/unison"
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
echo "Exclude commands are ${EXCLUDE[@]}"

# ------------- syncing ------------- 

E="${EXCLUDE[@]}"
if [ -z "$E" ]
then
    unison -sshargs "$SSH_ARGS" $DEFAULT_FLAGS $ADDITIONAL_FLAGS "$DIR" "ssh://$USER_REMOTE@$COMPUTER_REMOTE/$DIR_REMOTE"
else
    unison "${EXCLUDE[@]}" -sshargs "$SSH_ARGS" $DEFAULT_FLAGS $ADDITIONAL_FLAGS "$DIR" "ssh://$USER_REMOTE@$COMPUTER_REMOTE/$DIR_REMOTE"
fi
