#!/bin/bash -u

# This script synchronizes the current directory with that specified in the filename
# of this script. Alternative, it is convinient to use a link pointing to the main
# script which (usually) resides in the ~/bin dir and renaming this link appropriately.
#
# rsync.<dir>.sh
#
# <dir> , specified in the name of the script/link is always relative to
# $HOME. Subdirectories are specified with ':', for example:
#
# rsync.cloud:Dropbox.sh
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

DIR_SOURCE="$(cd $(dirname $0); pwd)"
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
DEFAULT_FLAGS=" --recursive --times --omit-dir-times --links --no-group --modify-window=1"
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

#script-specific arguments
SCRIPT_ARGS="--not-dir2local --no-d2l --not-local2dir --no-l2d --not-local2remote --no-l2r --not-remote2local --no-r2l --no-confirmation --no-feedback --backup-deleted --no-default-flags"

# ------------- given arguments -------------

ARGS=$@

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

# ------------- additonal flags -------------

ADDITIONAL_FLAGS=$ARGS
for i in $SCRIPT_ARGS
do
    ADDITIONAL_FLAGS=${ADDITIONAL_FLAGS//$i/}
done

# ------------- dir -------------

function strip_file_accessories(){
    local OUT=$(basename $1)
    OUT=${OUT%.sh*}
    OUT=${OUT#*rsync.}
    echo $OUT
}

DIR_REMOTE=$(strip_file_accessories $0)
DIR_REMOTE=$HOME/${DIR_REMOTE//\:/\/}

# ------------- argument file -------------

if [ -e "$DIR_SOURCE/rsync.arguments" ]
then
    if [ `cat "$DIR_SOURCE/rsync.arguments" | wc -l` -gt 1 ]
    then
        echo "ERROR: file $DIR_SOURCE/rsync.arguments cannot have more than one line."
        exit 3
    fi
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS `cat "$DIR_SOURCE/rsync.arguments"`"
    #need to clean script-specific arguments, otherwise they contaminate the rsync call
    for i in $SCRIPT_ARGS
    do
        if [[ ! "${ADDITIONAL_FLAGS//$i/}" == "$ADDITIONAL_FLAGS" ]]
        then
            ADDITIONAL_FLAGS=${ADDITIONAL_FLAGS//$i/}
            ARGS="$ARGS $i"
        fi
    done
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Using arguments file $DIR_SOURCE/rsync.arguments: `cat "$DIR_SOURCE/rsync.arguments"`"
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
fi

# ------------- include .git dirs when --delete is given -------------

function ensure_file()
{
  [ -e "$1" ] || touch "$1"
}

GITSYNC=false
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
    GITSYNC=true
  fi
fi

# ------------- resolve git versions -------------

if $GITSYNC
then
  for d in $(find "$DIR_SOURCE" -type d -name .git)
  do
    echo "Checking git version at $d"
    GITDIRLOCAL=$(dirname $d)
    GITDIRSINK=${GITDIRLOCAL/$DIR_SOURCE/$DIR_REMOTE}
    GITVERSINK=$( git -C $GITDIRSINK  log --pretty=format:"%at" 2> /dev/null | head -n1)
    GITVERLOCAL=$(git -C $GITDIRLOCAL log --pretty=format:"%at" 2> /dev/null | head -n1)
    if [ ! -z "$GITVERSINK" ] && [ ! -z "$GITVERLOCAL" ] && [ $GITVERLOCAL -lt $GITVERSINK ]
    then
        echo "WARNING: date of git repo at source is lower than at sink:"
        echo "source: $($DATE -d @$GITVERLOCAL) $GITDIRLOCAL/$i"
        echo "sink  : $($DATE -d @$GITVERSINK) $GITDIRSINK/$i"
        echo "Skip synching '$i'"
        EXCLUDE+=" --exclude=${GITDIRLOCAL/$DIR_SOURCE}"
    # else
    #   echo "source: $($DATE -d @$GITVERLOCAL) $GITDIRLOCAL/$i"
    #   echo "sink  : $($DATE -d @$GITVERSINK) $GITDIRSINK/$i"
    fi
  done
fi

# ------------- exclude file -------------

if [ -e "$DIR_SOURCE/rsync.exclude" ]
then
    EXCLUDE="--exclude-from=$DIR_SOURCE/rsync.exclude"
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo -e "Using exclude file $DIR_SOURCE/rsync.exclude:\n`cat "$DIR_SOURCE/rsync.exclude"`\n"
else
    EXCLUDE=""
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Not using any exclude file."
fi

# ------------- include file -------------

if [ -e "$DIR_SOURCE/rsync.include" ]
then
    INCLUDE="--include-from=$DIR_SOURCE/rsync.include"
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo -e "Using include file $DIR_SOURCE/rsync.include:\n`cat "$DIR_SOURCE/rsync.include"`\n"
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

# ------------- get rid of default flags -------------

[[ "${ARGS//--no-default-flags/}" == "$ARGS" ]] || DEFAULT_FLAGS=

# ------------- resolve argument conflicts -------------

#need to remove sparse if inplace if given
if [[ ! "${ADDITIONAL_FLAGS//--inplace/}" == "$ADDITIONAL_FLAGS" ]]
then
    DEFAULT_FLAGS="${DEFAULT_FLAGS//--sparse/}"
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Removed --sparse because --inplace was given."
fi

# ------------- update flag -------------

if [ remote2local ] || [ local2remote ]; then
    [[ "${ADDITIONAL_FLAGS//--update/}" == "$ADDITIONAL_FLAGS" ]] && ADDITIONAL_FLAGS+=" --update"
fi

# ------------- feedback -------------

if [[ "${ARGS//--no-feedback/}" == "$ARGS" ]]
then
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --progress --human-readable"
    echo "Default    flags are $DEFAULT_FLAGS"
    echo "Additional flags are $ADDITIONAL_FLAGS"
    echo "Remote dir is $DIR_REMOTE; local dir is $DIR_SOURCE"
    ! local2remote && echo "Not synching local to remote"
    ! remote2local && echo "Not synching remote to local"
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

if local2remote
then
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Synching local -> remote"
    $ECHO rsync --log-file="$DIR_SOURCE/$LOG" \
      $INCLUDE $DEFAULT_FLAGS $ADDITIONAL_FLAGS $EXCLUDE \
      "$DIR_SOURCE/" "$DIR_REMOTE/"
fi

# ------------- remote to local -------------

if remote2local
then
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Synching dir -> local"
    $ECHO rsync --log-file="$DIR_SOURCE/$LOG" \
        $INCLUDE $DEFAULT_FLAGS $ADDITIONAL_FLAGS $EXCLUDE \
        "$DIR_REMOTE/" "$DIR_SOURCE/"
fi
