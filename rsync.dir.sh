#!/bin/bash -u
#
# rsync.<dir>.sh
#
# This script synchronizes the current directory with that specified in the filename
# of this script. Alternative, it is convinient to use a link pointing to the main
# script which (usually) resides in the ~/bin dir and renaming this link appropriately.
#
# <dir> , specified in the name of the script/link is always relative to
# $HOME. Subdirectories are specified with ':', for example:
#
# rsync.cloud:Dropbox.sh
#
# To specify unidirection sync, use in the argument list the keywords:
#
#   '--not-local2dir' or '--not-dir2local'
#
# All input arguments are passed as additional rsync arguments (except
# the keywords above).
#
# https://github.com/jgte/bash

# ------------- dynamic parameters -------------

LOCAL="$(cd $(dirname $0); pwd)"

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
SCRIPT_ARGS="--not-dir2local --not-local2dir --not-local2remote --not-remote2local --no-confirmation --no-feedback"

# ------------- given arguments -------------

ARGS=$@

# ------------- additonal flags -------------

ADDITIONAL_FLAGS=$ARGS
for i in $SCRIPT_ARGS
do
    ADDITIONAL_FLAGS=${ADDITIONAL_FLAGS//$i/}
done

# ------------- dir -------------

DIR=`basename "$0"`
DIR=${DIR#rsync.}
DIR=${DIR%.sh}
DIR=${DIR//\:/\/}
DIR=$HOME/$DIR

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
            DIR=${i/--remote-dir=/}
            ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS//--remote-dir=$DIR/}"
            ARGS="$ARGS --remote-dir=$DIR"
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
ensure_file "$LOCAL/rsync.include"
if [[ "${@/--delete}" == "$@" ]]
then
  if [ -e "$LOCAL/rsync.include" ] && grep -q '.git*' "$LOCAL/rsync.include"
  then
    echo "NOTICE: to sync .git, need the --delete flag, otherwise .git dirs are ignored."
    grep -v '.git' "$LOCAL/rsync.include" > /tmp/rsync.include.$$ || true
    mv -f /tmp/rsync.include.$$ "$LOCAL/rsync.include"
  fi
else
  if [ -e "$LOCAL/rsync.include" ] && ! grep -q '.git*' "$LOCAL/rsync.include"
  then
    echo "NOTICE: not ignoring .git, since the --delete flag was given."
    echo '.git*' >> "$LOCAL/rsync.include"
    GITSYNC=true
  fi
fi

# ------------- resolve git versions -------------

if $GITSYNC
then
  for d in $(find "$LOCAL" -type d -name .git)
  do
    GITDIRLOCAL=$(dirname $d)
    GITDIRSINK=${GITDIRLOCAL/$LOCAL/$DIRSINK}
    GITVERSINK=$( git -C $GITDIRSINK  log --pretty=format:"%at" 2> /dev/null | head -n1)
    GITVERLOCAL=$(git -C $GITDIRLOCAL log --pretty=format:"%at" 2> /dev/null | head -n1)
    if [ ! -z "$GITVERSINK" ] && [ ! -z "$GITVERLOCAL" ] && [ $GITVERLOCAL -lt $GITVERSINK ]
    then
        echo "WARNING: date of git repo at source is lower than at sink:"
        echo "source: $($DATE -d @$GITVERLOCAL) $GITDIRLOCAL/$i"
        echo "sink  : $($DATE -d @$GITVERSINK) $GITDIRSINK/$i"
        echo "Skip synching '$i'"
        EXCLUDE+=" --exclude=${GITDIRLOCAL/$LOCAL}"
    # else
    #   echo "source: $($DATE -d @$GITVERLOCAL) $GITDIRLOCAL/$i"
    #   echo "sink  : $($DATE -d @$GITVERSINK) $GITDIRSINK/$i"
    fi
  done
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

# ------------- resolve argument conflicts -------------

#need to remove sparse if inplace if given
if [[ ! "${ADDITIONAL_FLAGS//--inplace/}" == "$ADDITIONAL_FLAGS" ]]
then
    DEFAULT_FLAGS="${DEFAULT_FLAGS//--sparse/}"
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Removed --sparse because --inplace was given."
fi

# ------------- feedback -------------

if [[ "${ARGS//--no-feedback/}" == "$ARGS" ]]
then
    ADDITIONAL_FLAGS="$ADDITIONAL_FLAGS --progress --human-readable"
    echo "Additional flags are $ADDITIONAL_FLAGS"
    echo "local is $LOCAL"
    echo "dir is $DIR"
    [[ ! "${ARGS//--not-local2dir/}" == "$ARGS" ]] && echo "Not synching local to dir"
    [[ ! "${ARGS//--not-dir2local/}" == "$ARGS" ]] && echo "Not synching dir to local"
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

# ------------- local to dir -------------

if [[ "${ARGS//--not-local2dir/}" == "$ARGS" ]] && [[ "${ARGS//--not-local2remote/}" == "$ARGS" ]]
then
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Synching local -> dir"
    rsync --log-file="$LOCAL/$LOG" $DEFAULT_FLAGS $ADDITIONAL_FLAGS $INCLUDE $EXCLUDE "$LOCAL/" "$DIR/"
fi

# ------------- dir to local -------------

if [[ "${ARGS//--not-dir2local/}" == "$ARGS" ]] && [[ "${ARGS//--not-remote2local/}" == "$ARGS" ]]
then
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Synching dir -> local"
    rsync --log-file="$LOCAL/$LOG" $DEFAULT_FLAGS $ADDITIONAL_FLAGS $INCLUDE $EXCLUDE "$DIR/" "$LOCAL/"
fi
