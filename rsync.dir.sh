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
SCRIPT_ARGS="--not-dir2local --not-local2dir --no-confirmation --no-feedback"

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
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Using arguments file $LOCAL/rsync.arguments: `cat $LOCAL/rsync.arguments`"
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

if [[ "${ARGS//--not-local2dir/}" == "$ARGS" ]]
then
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Synching local -> dir"
    rsync --log-file="$LOCAL/$LOG" $DEFAULT_FLAGS $ADDITIONAL_FLAGS $INCLUDE $EXCLUDE "$LOCAL/" "$DIR/"
fi

# ------------- dir to local -------------

if [[ "${ARGS//--not-dir2local/}" == "$ARGS" ]]
then
    [[ "${ARGS//--no-feedback/}" == "$ARGS" ]] && echo "Synching dir -> local"
    rsync --log-file="$LOCAL/$LOG" $DEFAULT_FLAGS $ADDITIONAL_FLAGS $INCLUDE $EXCLUDE "$DIR/" "$LOCAL/"
fi
