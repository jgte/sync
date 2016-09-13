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
DEFAULT_FLAGS=(-auto)
DEFAULT_FLAGS+=(-times)
DEFAULT_FLAGS+=(-fastcheck true)
DEFAULT_FLAGS+=(-perms 0)
DEFAULT_FLAGS+=(-dontchmod)
DEFAULT_FLAGS+=(-prefer newer)

IGNORE_FLAGS=(-ignore 'Name .DS_Store')
IGNORE_FLAGS+=(-ignore 'Name ._*')
IGNORE_FLAGS+=(-ignore 'Name *.o')
IGNORE_FLAGS+=(-ignore 'Name *.a')
IGNORE_FLAGS+=(-ignore 'Name *.exe')
IGNORE_FLAGS+=(-ignore 'Name .swo')
IGNORE_FLAGS+=(-ignore 'Name .swp')
IGNORE_FLAGS+=(-ignore 'Name screenlog.*')
IGNORE_FLAGS+=(-ignore 'Name .gmt*')
IGNORE_FLAGS+=(-ignore 'Path .Trash*')
IGNORE_FLAGS+=(-ignore 'Path lost+found')
IGNORE_FLAGS+=(-ignore 'Path .Spotlight*')
IGNORE_FLAGS+=(-ignore 'Path .fseventsd*')
IGNORE_FLAGS+=(-ignore 'Path .DocumentRevisions*')
IGNORE_FLAGS+=(-ignore 'Path .sync')
IGNORE_FLAGS+=(-ignore 'Name .SyncArchive')
IGNORE_FLAGS+=(-ignore 'Name .SyncID')
IGNORE_FLAGS+=(-ignore 'Name .SyncIgnore')
IGNORE_FLAGS+=(-ignore 'Name .dropbox*')
IGNORE_FLAGS+=(-ignore 'Path .dropbox*')
IGNORE_FLAGS+=(-ignore 'Name .unison*')
IGNORE_FLAGS+=(-ignore 'Path .unison')
IGNORE_FLAGS+=(-ignore 'Name .git')
IGNORE_FLAGS+=(-ignore 'Name .svn')
IGNORE_FLAGS+=(-ignore 'Name Thumbs.db')
IGNORE_FLAGS+=(-ignore 'Name Icon')
IGNORE_FLAGS+=(-ignore 'Name *~')
IGNORE_FLAGS+=(-ignore 'Name *.!sync')

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

# ------------- include file -------------

if [ -e "$LOCAL/unison.ignorenot" ]
then
    while read i
    do
        INCLUDE+=(-ignorenot "$i")
    done < "$LOCAL/unison.ignorenot"
    echo "Using include file $LOCAL/unison.ignorenot: ${INCLUDE[@]}"
else
    echo "Not using any include file."
fi

# ------------- argument file -------------

if [ -e "$LOCAL/unison.arguments" ]
then
    while read i
    do
        FILE_FLAGS+=($i)
    done < $LOCAL/unison.arguments
    echo "Using arguments file $LOCAL/unison.arguments"
else
    echo "Not using any arguments file."
fi

# ------------- more arguments in the command line -------------

ADDITIONAL_FLAGS="$@"

# ------------- dirs -------------

if [[ ! "${ADDITIONAL_FLAGS//--remote-dir=/}" == "${ADDITIONAL_FLAGS}" ]]
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

# ------------- singularities -------------

if [[ "${ADDITIONAL_FLAGS//--remote-dir=.*/}" == "$ADDITIONAL_FLAGS" ]]
then
    # translation origin
    case "`hostname`" in
        "tud14231"|"imac"|"csr-875717.csr.utexas.edu")
            #inverse translation of Darwin homes
            FROM="/Users/$USER"
        ;;
        "srv227" )
            FROM="/home/nfs/$USER"
        ;;
        "login1"|"login2"|"login3")
            FROM="/home1/00767/$USER"
        ;;
        * )
            FROM="$HOME"
        ;;
    esac
    # translation destiny
    case "$COMPUTER_REMOTE" in
        "jgte-mac.no-ip.org"|"csr-875717.csr.utexas.edu" )
            #translation of Darwin homes
            TO="/Users/$USER_REMOTE"
            #adding non-default location of unison because of brew
            DEFAULT_FLAGS+=(-servercmd /usr/local/bin/unison)
        ;;
        "linux-bastion.tudelft.nl" )
            TO="/home/nfs/$USER_REMOTE"
        ;;
        "login1.ls5.tacc.utexas.edu"|"login2.ls5.tacc.utexas.edu"|"login3.ls5.tacc.utexas.edu")
            TO="/home1/00767/$USER_REMOTE"
        ;;
        * )
            TO="/home/$USER_REMOTE"
        ;;
    esac
    #translate
    DIR_REMOTE="${DIR_REMOTE/$FROM/$TO}"

fi

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

#need to fix freaky blank messing up the unison call below
ADDITIONAL_FLAGS="$(echo $ADDITIONAL_FLAGS |  sed 's/ *$//' | sed 's/^ *//')"

# ------------- pinging remote host -------------

# ping -c 1 $COMPUTER_REMOTE || (
#     echo "Continue anyway [Y/n]?"
#     read ANSWER
#     [ "$ANSWER" == "n" ] || [ "$ANSWER" == "N" ] && exit 3
# )

# ------------- feedback -------------

echo "====================================================================="
echo "Default flags        : ${DEFAULT_FLAGS[@]}"
echo "Default ignore flags : ${IGNORE_FLAGS[@]}"
echo "Command-line flags   : $ADDITIONAL_FLAGS $FORCELOCAL_FLAGS $FORCEDIR_FLAGS $NODELETIONLOCAL_FLAGS $NODELETIONDIR_FLAGS"
echo "File ignore flags    : ${EXCLUDE:+"${EXCLUDE[@]}"}"
echo "File ignorenot flags : ${INCLUDE:+"${INCLUDE[@]}"}"
echo "File flags           : ${FILE_FLAGS:+"${FILE_FLAGS[@]}"}"
echo "ssh flags            : -sshargs $SSH_ARGS"
echo "remote is            : $REMOTE"
echo "local is             : $LOCAL"
echo "====================================================================="

# ------------- syncing -------------

unison \
    ${DEFAULT_FLAGS[@]} "${IGNORE_FLAGS[@]}" \
    ${INCLUDE:+"${INCLUDE[@]}"} \
    ${EXCLUDE:+"${EXCLUDE[@]}"} \
    ${FILE_FLAGS:+"${FILE_FLAGS[@]}"} \
    $ADDITIONAL_FLAGS $FORCELOCAL_FLAGS $FORCEDIR_FLAGS \
    -sshargs "$SSH_ARGS" \
    "$LOCAL" "$REMOTE" \
