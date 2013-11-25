#!/bin/bash -u
#
# unison.<dir>.sh
#
# This script synchronizes the current directory with that specified in the filename
# of this script. Alternative, it is convinient to use a link pointing to the main
# script which (usually) resides in the ~/bin dir and renaming this link appropriately.
#
# <dir> , specified in the name of the script/link is always relative to
# $HOME. Subdirectories are specified with ':', for example:
#
# unison.cloud:Dropbox.sh
#
# All input arguments are passed as additional unison arguments.
#
# https://github.com/jgte/bash

# ------------- Finding where I am -------------

LOCAL=`dirname $0`
LOCAL=`cd $LOCAL; pwd`

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

# ------------- dir -------------

DIR=`basename "$0"`
DIR=${DIR#unison.}
DIR=${DIR%.sh}
DIR=${DIR//\:/\/}
DIR=$HOME/$DIR

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

# ------------- feedback -------------

echo "Additional flags are  ${ADDITIONAL_FLAGS:+"${ADDITIONAL_FLAGS[@]}"}"
echo "local is $LOCAL"
echo "dir is $DIR"
echo "Exclude commands are ${EXCLUDE:+"${EXCLUDE[@]}"}"

# ------------- syncing -------------

unison "${DEFAULT_FLAGS[@]}" ${EXCLUDE:+"${EXCLUDE[@]}"} ${ADDITIONAL_FLAGS:+"${ADDITIONAL_FLAGS[@]}"} "$DIR" "$LOCAL"
