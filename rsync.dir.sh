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

# ------------- Finding where I am ------------- 

LOCAL=`dirname $0`
LOCAL=`cd $LOCAL; pwd`

#default flags
DEFAULT_FLAGS="--progress --human-readable --recursive --update --times --omit-dir-times --links --sparse  --fuzzy --partial --log-file=$LOCAL/rsync.log --no-perms --no-group --chmod=ugo=rwX --modify-window=1"

# ------------- additonal flags ------------- 

ADDITIONAL_FLAGS=${@//--not-dir2local/}
ADDITIONAL_FLAGS=${ADDITIONAL_FLAGS//--not-local2dir/}

# ------------- dir ------------- 

DIR=`basename "$0"`
DIR=${DIR#rsync.}
DIR=${DIR%.sh}
DIR=${DIR//\:/\/}
DIR=$HOME/$DIR

# ------------- exclude file ------------- 

if [ -e "$LOCAL/rsync.exclude" ]
then
    EXCLUDE="--exclude-from=$LOCAL/rsync.exclude"
    echo -e "Using exclude file $LOCAL/rsync.exclude:\n`cat $LOCAL/rsync.exclude`\n"
else
    EXCLUDE=""
    echo "Not using any exclude file."
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
    echo "Using arguments file $LOCAL/rsync.arguments"
else
    echo "Not using any arguments file."
fi

# ------------- feedback -------------

echo "Additional flags are $ADDITIONAL_FLAGS"
echo "local is $LOCAL"
echo "dir is $DIR"

if [[ ! "${@//--not-local2dir/}" == "$@" ]]
then
  echo "Not synching local to dir"
fi
if [[ ! "${@//--not-dir2local/}" == "$@" ]]
then
  echo "Not synching dir to local"
fi

echo "Continue [Y/n] ?"
read ANSWER
if [ "$ANSWER" == "N" ] || [ "$ANSWER" == "n" ]
then
  exit
fi

# ------------- local to dir -------------

if [[ "${@//--not-local2dir/}" == "$@" ]]
then
    echo "Synching local -> dir"
    rsync $DEFAULT_FLAGS $ADDITIONAL_FLAGS $EXCLUDE "$LOCAL/" "$DIR/"
fi

# ------------- dir to local -------------

if [[ "${@//--not-dir2local/}" == "$@" ]]
then
    echo "Synching dir -> local"
    rsync $DEFAULT_FLAGS $ADDITIONAL_FLAGS $EXCLUDE "$DIR/" "$LOCAL/"
fi
