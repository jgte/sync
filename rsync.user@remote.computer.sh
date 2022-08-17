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
# From the current directory to <dir>:
#   '--not-local2dir'
#   '--not-local2remote'
#   '--no-l2d'
#   '--no-l2r'
#
# From <dir> to the current directory:
#   '--not-dir2local'
#   '--not-remote2local'
#   '--no-d2l'
#   '--no-r2l'
#
# All input arguments are passed as additional rsync arguments (except
# the keywords above).
#
# https://github.com/jgte/bash
#
#https://stackoverflow.com/questions/4493525/rsync-what-means-the-f-on-rsync-logs
# YXcstpoguax  path/to/file
# |||||||||||
# ||||||||||╰- x: The extended attribute information changed
# |||||||||╰-- a: The ACL information changed
# ||||||||╰--- u: The u slot is reserved for future use
# |||||||╰---- g: Group is different
# ||||||╰----- o: Owner is different
# |||||╰------ p: Permission are different
# ||||╰------- t: Modification time is different
# |||╰-------- s: Size is different
# ||╰--------- c: Different checksum (for regular files), or
# ||              changed value (for symlinks, devices, and special files)
# |╰---------- the file type:
# |            f: for a file,
# |            d: for a directory,
# |            L: for a symlink,
# |            D: for a device,
# |            S: for a special file (e.g. named sockets and fifos)
# ╰----------- the type of update being done::
#              <: file is being transferred to the remote host (sent)
#              >: file is being transferred to the local host (received)
#              c: local change/creation for the item, such as:
#                 - the creation of a directory
#                 - the changing of a symlink,
#                 - etc.
#              h: the item is a hard link to another item (requires
#                 --hard-links).
#              .: the item is not being updated (though it might have
#                 attributes that are being modified)
#              *: means that the rest of the itemized-output area contains
#                 a message (e.g. "deleting")

function machine_is
{
  OS=`uname -v`
  [[ ! "${OS//$1/}" == "$OS" ]] && return 0 || return 1
}

# ------------- dynamic parameters -------------

DIR_SOURCE=$(cd $(dirname $0); pwd)

#can't get this thing to work with paths with blanks, dunno why
if [[ ! "$DIR_SOURCE" == "${DIR_SOURCE// /}" ]]
then
  echo "ERROR: cannot handle paths with blanks."
  exit 3
fi

if [[ ! "${@/debug/}" == "$@" ]] || [[ ! "${@/echo/}" == "$@" ]]
then
  ECHO=echo
else
  ECHO=
fi

LOG=`basename "$0"`.log
LOG=${LOG// /_}

# ------------- static parameters -------------

#default flags
DEFAULT_FLAGS=" --recursive --times --omit-dir-times --links --no-group"
#this makes sense between different machines
DEFAULT_FLAGS+=" --no-perms --chmod=ugo=rwX"
#skip files that are newer on the receiver
#NOTICE: this can be dangerous when mirroring, since touching a file at destination will prevent it from being updated
#        for this reason, --update is added to ADDITIONAL_FLAGS whenever --not-local2remote or --not-remote2local are used
# DEFAULT_FLAGS+=" --update"
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
DEFAULT_FLAGS+=" --exclude=Icon*"
DEFAULT_FLAGS+=" --exclude=.*.swp"
DEFAULT_FLAGS+=" --exclude=*/__pycache__/*"

#script-specific arguments
SCRIPT_ARGS="--not-dir2local --no-d2l --not-local2dir --no-l2d --not-local2remote --no-l2r --not-remote2local --no-r2l --no-confirmation --no-feedback --backup-deleted --no-default-flags --no-exclude-file --no-include-file --no-arguments-file --be-verbose"

# ------------- given arguments -------------

ARGS="$@"

# ------------- resolve arguments with many names -------------

function remote2local()
{
  [[ "${ARGS//--not-remote2local}" == "$ARGS" ]] && \
  [[ "${ARGS//--not-dir2local}"    == "$ARGS" ]] && \
  [[ "${ARGS//--no-r2l}"           == "$ARGS" ]] && \
  [[ "${ARGS//--no-d2l}"           == "$ARGS" ]] && \
  return 0 || \
  return 1
}

function local2remote()
{
  [[ "${ARGS//--not-local2remote}" == "$ARGS" ]] && \
  [[ "${ARGS//--not-local2dir}"    == "$ARGS" ]] && \
  [[ "${ARGS//--no-l2r}"           == "$ARGS" ]] && \
  [[ "${ARGS//--no-l2d}"           == "$ARGS" ]] && \
  return 0 || \
  return 1
}

function show-feedback()
{
  [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && return 0 || return 1
}

function be-verbose()
{
  [[ "${ARGS//--be-verbose/}" == "$ARGS" ]] && return 1 || return 0
}

# ------------- additonal flags -------------

ADDITIONAL_FLAGS="$@"

# ------------- remote computer name -------------

function strip_file_accessories(){
  local OUT=$(basename $1)
  OUT=${OUT%.sh*}
  OUT=${OUT#*rsync.}
  echo $OUT
}

function computer_remote(){
  local COMPUTER_REMOTE=$(strip_file_accessories $1)
  COMPUTER_REMOTE=${COMPUTER_REMOTE#*@}
  echo $COMPUTER_REMOTE
}

#NOTICE: the COMPUTER_REMOTE_FILE (ans USER_REMOTE_FILE, below) variables are needed in order to ensure rsync.*{exclude|include|arguments} in the form of (e.g.) rsync.teixeira@aristarchos.lr.tudelft.nl.{exclude|include|arguments} work properly.

COMPUTER_REMOTE=$(computer_remote $0)
COMPUTER_REMOTE_FILE=$COMPUTER_REMOTE

# ------------- remote username -------------

function user_remote(){
  local DEBUG_HERE=false
  $DEBUG_HERE && echo "0:$1" 1>&2
  #get remote computer
  local USER_REMOTE=$(strip_file_accessories $1)
  $DEBUG_HERE && echo "1:$USER_REMOTE" 1>&2
  #check if the @ character is there
  if [[ ! "${USER_REMOTE/\@}" == "$USER_REMOTE" ]]
  then
    #get user form the remote computer name
    USER_REMOTE=${USER_REMOTE%@*}
    $DEBUG_HERE && echo "2:$USER_REMOTE" 1>&2
  else
    #if no user was given, use the current one, default to 'unknown_user'
    USER_REMOTE=${USER:-unknown_user}
    $DEBUG_HERE && echo "3.1:$USER_REMOTE" 1>&2
  fi
  echo $USER_REMOTE
}

USER_REMOTE=$(user_remote $0)
USER_REMOTE_FILE=$USER_REMOTE

# ------------- local username -------------

#this is useful when run from crontab and the USER_REMOTE is set
USER=${USER:-$USER_REMOTE}

# ------------- handle files with rsync options -------------

#resolve existing rsync.*{exclude|include|arguments} file
function get-rsync-file()
{
  local TYPE=$1
  for i in \
    "$DIR_SOURCE/rsync.$USER_REMOTE_FILE@$COMPUTER_REMOTE_FILE.$1" \
    "$DIR_SOURCE/rsync.$COMPUTER_REMOTE_FILE.$1" \
    "$DIR_SOURCE/rsync.$USER_REMOTE@$COMPUTER_REMOTE.$1" \
    "$DIR_SOURCE/rsync.$COMPUTER_REMOTE.$1" \
    "$DIR_SOURCE/rsync.$1"
  do
    if [ -e "$i" ]
    then
      echo "$i"
      return
    fi
  done
  echo ""
}

# ------------- arguments file -------------

ARGUMENTS_FILE="$(get-rsync-file arguments)"
if [ ! -z "$ARGUMENTS_FILE" ] && \
  [[ "${ARGS//--no-arguments-file/}" == "$ARGS" ]]
then
  if [ $(cat "$ARGUMENTS_FILE" | grep -v '#' | grep -v '^ *$' | wc -l) -gt 1 ]
  then
    echo "ERROR: file $DIR_SOURCE/rsync.arguments cannot have more than one line."
    exit 3
  fi
  ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS $(cat "$ARGUMENTS_FILE" | grep -v '#' | grep -v '^ *$')"
  if show-feedback
  then
    echo "====================================================================="
    echo "File arguments    : $(cat $ARGUMENTS_FILE)"
  fi
else
  if show-feedback
  then
    echo "====================================================================="
    echo "File arguments    : none"
  fi
fi

# ------------- clean script-specific arguments -------------

#NOTICE: this does not clean command in the form --<arg>=<something>,
#        such as --remote-dir=...; those need to handled below.
#NOTICE: ARGS will be augments with all the SCRIPT_ARGS in ADDITIONAL_FLAGS;
#        if SCRIPT_ARGS options are passed in the command line, then they are already
#        in ARGS (ARGS=$@) and there will be duplicates. This is no problem.
#        The point of this loop is to pass the SCRIPT_ARGS collected from
#        rsync.arguments to ARGS (and to clean ADDITIONAL_FLAGS of them).
for i in $SCRIPT_ARGS
do
  if [[ ! "${ADDITIONAL_FLAGS//$i/}" == "$ADDITIONAL_FLAGS" ]]
  then
    ADDITIONAL_FLAGS=${ADDITIONAL_FLAGS//$i/}
    ARGS="$ARGS $i"
  fi
done

# ------------- --<name>= options -------------

for arg in --remote-dir= --remote-user= --remote-computer= --pre-run=
do
  if [[ ! "${ADDITIONAL_FLAGS//$arg}" == "$ADDITIONAL_FLAGS" ]]
  then
    for i in $ADDITIONAL_FLAGS
    do
      if [[ ! "${i//$arg}" == "$i" ]]
      then
        #xargs trimms the values
        V="$(echo ${i/$arg} | xargs)"
        #distribute value where it's supposed to go
        case $arg in
          --remote-user=)         USER_REMOTE=$V ;;
          --remote-computer=) COMPUTER_REMOTE=$V ;;
          --remote-dir=)           DIR_REMOTE=$V ;;
          --pre-run=)
            #execute the requested command
            echo "executing pre-run command '$V':"
            $V || exit $?
          ;;
        esac
        #trim additional flags
        ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS//$arg$V/}"
        #append to args
        ARGS="$ARGS $arg$V"
        break
      fi
    done
  fi
done

# ------------- if remote dir is not given explicitly, defaul to user's home -------------

if [ -z "${DIR_REMOTE-}" ]
then
  #editing the remote dir (no need to escape the / character of the replacing string, apparently)
  DIR_REMOTE="${DIR_SOURCE/\/home\/$USER\///home/$USER_REMOTE/}"
  DIR_REMOTE="${DIR_SOURCE/\/Users\/$USER\///Users/$USER_REMOTE/}"
fi

# ------------- it's now safe to use variables instead of functions -------------

show-feedback && SHOW_FEEDBACK=true || SHOW_FEEDBACK=false
be-verbose    && BE_VERBOSE=true    || BE_VERBOSE=false
remote2local  && REMOTE2LOCAL=true  || REMOTE2LOCAL=false
local2remote  && LOCAL2REMOTE=true  || LOCAL2REMOTE=false

# ------------- keyfile -------------

SSH_KEY_FILE=$HOME/.ssh/$USER_REMOTE@${COMPUTER_REMOTE%%.*}
$SHOW_FEEDBACK && echo "Looking for key file $SSH_KEY_FILE"
if [ ! -e "$SSH_KEY_FILE" ]
then
  SSH_KEY_FILE=none
  $SHOW_FEEDBACK && echo "Not using a keyfile (file $SSH_KEY_FILE does not exist)."
else
  [ -z "${SSH_AUTH_SOCK:-}" ] && eval $(ssh-agent -s)
  ssh-add -t 60 $SSH_KEY_FILE
  $SHOW_FEEDBACK && echo "Using keyfile $SSH_KEY_FILE"
fi

# ------------- include .git dirs when --delete is given -------------

function ensure_file()
{
  [ -e "$1" ] || touch "$1"
}

#make sure rsync.include exists
ensure_file "$DIR_SOURCE/rsync.include"
if [[ "${ARGS/--delete}" == "$ARGS" ]]
then
  if [ -e "$DIR_SOURCE/rsync.include" ] && grep -q '.git*' "$DIR_SOURCE/rsync.include"
  then
    echo "NOTICE: to sync .git, need the --delete flag, otherwise .git dirs are ignored."
    grep -v '.git' "$DIR_SOURCE/rsync.include" > /tmp/rsync.include.$$ || true
    mv -f /tmp/rsync.include.$$ "$DIR_SOURCE/rsync.include"
  fi
else
  if [ -e "$DIR_SOURCE/rsync.include" ] && ! grep -q '.git*' "$DIR_SOURCE/rsync.include"
  then
    echo "NOTICE: not ignoring .git, since the --delete flag was given."
    echo '.git*' >> "$DIR_SOURCE/rsync.include"
  fi
fi

# ------------- exclude file -------------

EXCLUDE_FILE="$(get-rsync-file exclude)"
if [ ! -z "$EXCLUDE_FILE" ] && \
  [[ "${ARGS//--no-exclude-file/}" == "$ARGS" ]]
then
  EXCLUDE="--exclude-from=$EXCLUDE_FILE"
  if $SHOW_FEEDBACK
  then
    echo -n "Exclude file      : $EXCLUDE_FILE"
    $BE_VERBOSE \
      && echo -e ":\n$(cat "$EXCLUDE_FILE")" \
      || echo " ($(printf '%d' $(cat "$EXCLUDE_FILE" | wc -l)) lines)"
  fi
else
  EXCLUDE=""
  $SHOW_FEEDBACK && echo "Exclude file      : none"
fi

# ------------- include file -------------

INCLUDE_FILE="$(get-rsync-file include)"
if [ ! -z "$INCLUDE_FILE" ] && \
  [[ "${ARGS//--no-include-file/}" == "$ARGS" ]]
then
  INCLUDE="--include-from=$INCLUDE_FILE"
  if $SHOW_FEEDBACK
  then
    echo -n "Include file      : $INCLUDE_FILE"
    $BE_VERBOSE \
      && echo -e ":\n$(cat "$INCLUDE_FILE")" \
      || echo " ($(printf '%d' $(cat "$INCLUDE_FILE" | wc -l)) lines)"
  fi
else
  INCLUDE=""
  $SHOW_FEEDBACK && echo "Include file      : none"
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
  ADDITIONAL_FLAGS+=" --delete --backup --backup-dir=backup/$DATE --exclude=backup.????-??-??"
fi

# ------------- get rid of default flags -------------

[[ "${ARGS//--no-default-flags/}" == "$ARGS" ]] || DEFAULT_FLAGS=

# ------------- resolve argument conflicts -------------

#need to remove sparse if inplace if given
if [[ ! "${ADDITIONAL_FLAGS//--inplace/}" == "$ADDITIONAL_FLAGS" ]]
then
  DEFAULT_FLAGS="${DEFAULT_FLAGS//--sparse/}"
  $SHOW_FEEDBACK && echo "Removed --sparse because --inplace was given."
fi

# ------------- singularities -------------

if [[ "${ARGS//--remote-dir=.*/}" == "$ARGS" ]]
then
  # translation origin: USER_REMOTE is used here because it was already replaced above
  case "`hostname -f`" in
    "tud14231"|"TUD500415")
      #inverse translation of Darwin homes
      FROM="/Users/$USER_REMOTE"
    ;;
    "srv227.tudelft.net" )
      FROM="/home/nfs/$USER_REMOTE"
    ;;
    "corral.tacc.utexas.edu"|"wrangler.tacc.utexas.edu")
      FROM="/home/utexas/csr/$USER_REMOTE"
    ;;
    *.tacc.utexas.edu)
      FROM="/home1/00767/$USER_REMOTE"
    ;;
    *)
      FROM="/home/$USER_REMOTE"
    ;;
  esac
  # translation destiny
  case "$COMPUTER_REMOTE" in
    "jgte-mac.no-ip.org"|"holanda.no-ip.org:20022"|"holanda.no-ip.org:20024"|"holanda.no-ip.org:20029"|"TUD500415" )
      #translation of Darwin homes
      TO="/Users/$USER_REMOTE"
    ;;
    "linux-bastion.tudelft.nl" )
      TO="/home/nfs/$USER_REMOTE"
    ;;
    "corral.tacc.utexas.edu"|"wrangler.tacc.utexas.edu")
      which tacc.sh &> /dev/null && ECHO+=" tacc.sh "
      [ -e $HOME/bin/tacc.sh ] && ECHO+=" $HOME/bin/tacc.sh "
      TO="/home/$USER_REMOTE"
    ;;
    *.tacc.utexas.edu)
      which tacc.sh &> /dev/null && ECHO+=" tacc.sh "
      [ -e $HOME/bin/tacc.sh ] && ECHO+=" $HOME/bin/tacc.sh "
      TO="/home1/00767/$USER_REMOTE"
    ;;
    *)
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

# if $SHOW_FEEDBACK
# then
#     ping -c 1 $COMPUTER_REMOTE || exit 3
# else
#     ping -c 1 $COMPUTER_REMOTE > /dev/null || exit 3
# fi

# ------------- update flag -------------

if $REMOTE2LOCAL || $LOCAL2REMOTE; then
  [[ "${ADDITIONAL_FLAGS//--update/}" == "$ADDITIONAL_FLAGS" ]] && ADDITIONAL_FLAGS+=" --update"
fi

# ------------- feedback -------------

if $SHOW_FEEDBACK
then
  $BE_VERBOSE \
    && ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --progress --human-readable" \
    || ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --itemize-changes"
  $BE_VERBOSE && echo "Default flags     : $DEFAULT_FLAGS"
  echo "Additional flags  : $ADDITIONAL_FLAGS"
  echo "Remote dir        : $DIR_REMOTE"
  echo "Local dir         : $DIR_SOURCE"
  if $LOCAL2REMOTE && $REMOTE2LOCAL
  then
    echo "Directional sync  : local -> remote -> local"
  elif $LOCAL2REMOTE
  then
    echo "Directional sync  : local -> remote"
  elif $REMOTE2LOCAL
  then
    echo "Directional sync  : remote -> local"
  else
    echo "Directional sync  : none (pointless to have both --not-local2remote and --not-remote2local)"
  fi
  echo "====================================================================="
else
  #at least show me the changes
  ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --itemize-changes"
fi

# ------------- user in the loop? -------------

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

if $LOCAL2REMOTE
then
  $SHOW_FEEDBACK && echo "Synching $DIR_SOURCE -> $DIR_REMOTE"
  $ECHO rsync --log-file="$DIR_SOURCE/$LOG" \
    "$INCLUDE" $DEFAULT_FLAGS $ADDITIONAL_FLAGS "$EXCLUDE" \
    "$DIR_SOURCE/" "$USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/"
fi

# ------------- remote to local -------------

if $REMOTE2LOCAL
then
  $SHOW_FEEDBACK && echo "Synching $DIR_REMOTE -> $DIR_SOURCE"
  $ECHO rsync --log-file="$DIR_SOURCE/$LOG" \
    "$INCLUDE" $DEFAULT_FLAGS $ADDITIONAL_FLAGS $EXCLUDE \
    "$USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/" "$DIR_SOURCE/"
fi
