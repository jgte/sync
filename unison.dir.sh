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

function machine_is
{
  OS=`uname -v`
  [[ ! "${OS//$1/}" == "$OS" ]] && return 0 || return 1
}

function file_ends_with_newline() {
    if machine_is Darwin
    then
        [[ "$(tail -n1 "$1")" == "" ]]
    else
        [[ "$(tail -c1 "$1")" == "" ]]
    fi
}

# ------------- Finding where I am -------------

LOCAL=$(cd $(dirname $0); pwd)

#default flags
DEFAULT_FLAGS=(-auto)
DEFAULT_FLAGS+=(-times)
DEFAULT_FLAGS+=(-fastcheck true)
DEFAULT_FLAGS+=(-perms 0)
DEFAULT_FLAGS+=(-rsrc false)
DEFAULT_FLAGS+=(-dontchmod)
DEFAULT_FLAGS+=(-prefer newer)

#default files to ignore
IGNORE_FLAGS=(-ignore 'Name .DS_Store')
IGNORE_FLAGS+=(-ignore 'Name ._*')
IGNORE_FLAGS+=(-ignore 'Name *.o')
IGNORE_FLAGS+=(-ignore 'Name *.a')
IGNORE_FLAGS+=(-ignore 'Name *.exe')
IGNORE_FLAGS+=(-ignore 'Name .swo')
IGNORE_FLAGS+=(-ignore 'Name .swp')
IGNORE_FLAGS+=(-ignore 'Name screenlog.*')
IGNORE_FLAGS+=(-ignore 'Name .gmt*')
IGNORE_FLAGS+=(-ignore 'Path lost+found')
IGNORE_FLAGS+=(-ignore 'Path .Spotlight*')
IGNORE_FLAGS+=(-ignore 'Path .fseventsd*')
IGNORE_FLAGS+=(-ignore 'Path .DocumentRevisions*')
IGNORE_FLAGS+=(-ignore 'Path .Trash*')
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
IGNORE_FLAGS+=(-ignore 'Name .journal*')
IGNORE_FLAGS+=(-ignore 'Path .TemporaryItems')
IGNORE_FLAGS+=(-ignore 'Name .HFS+*')

# ------------- dir -------------

DIR=`basename "$0"`
DIR=${DIR#unison.}
DIR=${DIR%.sh}
DIR=${DIR//\:/\/}
DIR=$HOME/$DIR

# ------------- exclude file -------------

FILE_NOW="$LOCAL/unison.ignore"
if [ -e "$FILE_NOW" ]
then
    file_ends_with_newline "$FILE_NOW" || {
        echo "ERROR: file $FILE_NOW needs to end with a newline."
        exit 3
    }
    while read i
    do
        EXCLUDE+=(-ignore "$i")
    done < "$FILE_NOW"
    echo "Using exclude file $FILE_NOW: ${EXCLUDE[@]}"
else
    echo "Not using any exclude file."
fi

# ------------- include file -------------

FILE_NOW="$LOCAL/unison.ignorenot"
if [ -e "$FILE_NOW" ]
then
    file_ends_with_newline "$FILE_NOW" || {
        echo "ERROR: file $FILE_NOW needs to end with a newline."
        exit 3
    }
    while read i
    do
        INCLUDE+=(-ignorenot "$i")
    done < "$FILE_NOW"
    echo "Using include file $FILE_NOW: ${INCLUDE[@]}"
else
    echo "Not using any include file."
fi

# ------------- argument file -------------

FILE_NOW="$LOCAL/unison.arguments"
if [ -e "$FILE_NOW" ]
then
    file_ends_with_newline "$FILE_NOW" || {
        echo "ERROR: file $FILE_NOW needs to end with a newline."
        exit 3
    }
    while read i
    do
        echo $i
        FILE_FLAGS+=($i)
    done < "$FILE_NOW"
    echo "Using arguments file $FILE_NOW"
else
    FILE_FLAGS=
    echo "Not using any arguments file."
fi

# ------------- more arguments in the command line -------------

ADDITIONAL_FLAGS="$@"

# ------------- dirs -------------

if [[ ! "${ADDITIONAL_FLAGS//--remote-dir=/}" == "${ADDITIONAL_FLAGS}" ]]
then
    for i in $ADDITIONAL_FLAGS
    do
        echo $i
        if [[ ! "${i//--remote-dir=/}" == "$i" ]]
        then
            DIR="${i/--remote-dir=/}"
            echo $DIR
            ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS//--remote-dir=$DIR/}"
            break
        fi
    done
else
    #editing the remote dir
    DIR="${DIR/\/home\/$USER\//\/home\/$USER\/}"
    DIR="${DIR/"/Users/$USER/"/"/Users/$USER/"}"
fi

# ------------- force flags -------------

if [[ ! "${ADDITIONAL_FLAGS/-force-here/}" == "$ADDITIONAL_FLAGS" ]]; then
    FORCELOCAL_FLAGS="-force $LOCAL"
      FORCEDIR_FLAGS=
    ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS/-force-here/}"
elif [[ ! "${ADDITIONAL_FLAGS/-force-there/}" == "$ADDITIONAL_FLAGS" ]]; then
    FORCELOCAL_FLAGS=
      FORCEDIR_FLAGS="-force $DIR"
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
      NODELETIONDIR_FLAGS="-nodeletion $DIR"
    ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS/-nodeletion-there/}"
else
    NODELETIONLOCAL_FLAGS=
      NODELETIONDIR_FLAGS=
fi

# ------------- syncing -------------

if [ "$(basename $DIR)" == "dir_list" ] || [ "$(basename $DIR)" == "recursive" ]
then

    #sanity
    if [ "$(basename $DIR)" == "dir_list" ] && [ ! -e "$LOCAL/unison.dir_list" ]
    then
        echo "ERROR: need file with list of directories to sync: $LOCAL/unison.dir_list"
        exit 3
    fi

    #get dir list
    [ "$(basename $DIR)" == "dir_list" ]  && DIR_LIST=$(cat $LOCAL/unison.dir_list | grep -v ^#)
    [ "$(basename $DIR)" == "recursive" ] && DIR_LIST=$(find $LOCAL -type d -maxdepth 1)

    #loop over list of directories
    for i in $DIR_LIST
    do
        [ ! -d "$HOME/$i"  ] && echo "ERROR: cannot find $HOME/$i"
        [ ! -d "$LOCAL/$i" ] && echo "ERROR: cannot find $LOCAL/$i"
        ( [ ! -d "$LOCAL/$i" ] || [ ! -d "$HOME/$i" ] ) && continue

        # ------------- force/nodeletion flags -------------

        [ ! -z      "$FORCELOCAL_FLAGS" ] &&      FORCELOCAL_FLAGS="-force $LOCAL/$i"
        [ ! -z        "$FORCEDIR_FLAGS" ] &&        FORCEDIR_FLAGS="-force $HOME/$i"
        [ ! -z "$NODELETIONLOCAL_FLAGS" ] && NODELETIONLOCAL_FLAGS="-nodeletion $LOCAL/$i"
        [ ! -z   "$NODELETIONDIR_FLAGS" ] &&   NODELETIONDIR_FLAGS="-nodeletion $HOME/$i"

        # ------------- batch mode -------------

        echo "====================================================================="
        echo "Default flags        : ${DEFAULT_FLAGS[@]}"
        echo "Default ignore flags : ${IGNORE_FLAGS[@]}"
        echo "Command-line flags   : $ADDITIONAL_FLAGS $FORCELOCAL_FLAGS $FORCEDIR_FLAGS $NODELETIONLOCAL_FLAGS $NODELETIONDIR_FLAGS"
        echo "File ignore flags    : ${EXCLUDE:+"${EXCLUDE[@]}"}"
        echo "File ignorenot flags : ${INCLUDE:+"${INCLUDE[@]}"}"
        echo "File flags           : ${FILE_FLAGS:+"${FILE_FLAGS[@]}"}"
        echo "dir is               : $HOME/$i"
        echo "local is             : $LOCAL/$i"
        echo "====================================================================="
        unison \
            ${DEFAULT_FLAGS[@]} "${IGNORE_FLAGS[@]}" \
            ${EXCLUDE:+"${EXCLUDE[@]}"} \
            ${INCLUDE:+"${INCLUDE[@]}"} \
            ${FILE_FLAGS:+"${FILE_FLAGS[@]}"} \
            $ADDITIONAL_FLAGS $FORCELOCAL_FLAGS $FORCEDIR_FLAGS \
            "$HOME/$i" "$LOCAL/$i"  || exit $?

    done
else

    [ ! -d "$DIR"   ] && echo "ERROR: cannot find $DIR"
    [ ! -d "$LOCAL" ] && echo "ERROR: cannot find $LOCAL"
    ( [ ! -d "$LOCAL" ] || [ ! -d "$DIR" ] ) && exit 3

    # ------------- simple mode -------------

    echo "====================================================================="
    echo "Default flags        : ${DEFAULT_FLAGS[@]}"
    echo "Default ignore flags : ${IGNORE_FLAGS[@]}"
    echo "Command-line flags   : $ADDITIONAL_FLAGS $FORCELOCAL_FLAGS $FORCEDIR_FLAGS $NODELETIONLOCAL_FLAGS $NODELETIONDIR_FLAGS"
    echo "File ignore flags    : ${EXCLUDE:+"${EXCLUDE[@]}"}"
    echo "File ignorenot flags : ${INCLUDE:+"${INCLUDE[@]}"}"
    echo "File flags           : ${FILE_FLAGS:+"${FILE_FLAGS[@]}"}"
    echo "dir is               : $DIR"
    echo "local is             : $LOCAL"
    echo "====================================================================="
    unison \
        ${DEFAULT_FLAGS[@]} "${IGNORE_FLAGS[@]}" \
        ${EXCLUDE:+"${EXCLUDE[@]}"} \
        ${INCLUDE:+"${INCLUDE[@]}"} \
        ${FILE_FLAGS:+"${FILE_FLAGS[@]}"} \
        $ADDITIONAL_FLAGS $FORCELOCAL_FLAGS $FORCEDIR_FLAGS \
        "$DIR" "$LOCAL"

fi


