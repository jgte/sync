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
    [[ "$(tail -c1 "$1")" == "" ]]
    # if machine_is Darwin
    # then
    #     [[ "$(tail -n1 "$1")" == "" ]]
    # else
    #     [[ "$(tail -c1 "$1")" == "" ]]
    # fi
}

# ------------- unison executable -------------

UNISON="$(which unison)"
if [ -z "$UNISON" ]
then
    for i in / /usr /usr/local $HOME
    do
        for j in bin sbin
        do
            [ -e "$i$j/unison" ] && UNISON="$i$j/unison"
            [ ! -z "$UNISON" ] && break
        done
        [ ! -z "$UNISON" ] && break
    done
fi
if [ -z "$UNISON" ]
then
    echo ERROR: cannot find unison binary
    exit 3
fi

# ------------- Finding where I am -------------

LOCAL=$(cd $(dirname $0); pwd)

#default flags
DEFAULT_FLAGS=(-auto)
DEFAULT_FLAGS+=(-times)
DEFAULT_FLAGS+=(-fastcheck true)
# DEFAULT_FLAGS+=(-perms 0)
# DEFAULT_FLAGS+=(-dontchmod)
DEFAULT_FLAGS+=(-rsrc false)
DEFAULT_FLAGS+=(-prefer newer)
DEFAULT_FLAGS+=(-links false)

#default files to ignore
IGNORE_FLAGS=()
IGNORE_FLAGS+=(-ignore 'Name *-blx.bib')
IGNORE_FLAGS+=(-ignore 'Name *.!sync')
IGNORE_FLAGS+=(-ignore 'Name *.a')
IGNORE_FLAGS+=(-ignore 'Name *.aux')
IGNORE_FLAGS+=(-ignore 'Name *.bbl')
IGNORE_FLAGS+=(-ignore 'Name *.blg')
IGNORE_FLAGS+=(-ignore 'Path *cache*')
IGNORE_FLAGS+=(-ignore 'Name *.exe')
IGNORE_FLAGS+=(-ignore 'Name *.fdb_latexmk')
IGNORE_FLAGS+=(-ignore 'Name *.fls')
IGNORE_FLAGS+=(-ignore 'Name *.lof')
IGNORE_FLAGS+=(-ignore 'Name *.log')
IGNORE_FLAGS+=(-ignore 'Name .*.log')
IGNORE_FLAGS+=(-ignore 'Name *.lot')
IGNORE_FLAGS+=(-ignore 'Name *.nav')
IGNORE_FLAGS+=(-ignore 'Name *.o')
IGNORE_FLAGS+=(-ignore 'Name *.out')
IGNORE_FLAGS+=(-ignore 'Name *.run.xml')
IGNORE_FLAGS+=(-ignore 'Name *.snm')
IGNORE_FLAGS+=(-ignore 'Name *.swp')
IGNORE_FLAGS+=(-ignore 'Name *.synctex.gz')
IGNORE_FLAGS+=(-ignore 'Name *.toc')
IGNORE_FLAGS+=(-ignore 'Name *.vrb')
IGNORE_FLAGS+=(-ignore 'Path __pycache__')
IGNORE_FLAGS+=(-ignore 'Name *conflicted*')
IGNORE_FLAGS+=(-ignore 'Name *to-delete*')
IGNORE_FLAGS+=(-ignore 'Name *~')
IGNORE_FLAGS+=(-ignore 'Name .*.swp')
IGNORE_FLAGS+=(-ignore 'Name ._*')
IGNORE_FLAGS+=(-ignore 'Path .DocumentRevisions*')
IGNORE_FLAGS+=(-ignore 'Name .dropbox*')
IGNORE_FLAGS+=(-ignore 'Name .DS_Store')
IGNORE_FLAGS+=(-ignore 'Path .fseventsd*')
IGNORE_FLAGS+=(-ignore 'Name .fuse_hidden*')
IGNORE_FLAGS+=(-ignore 'Name .gmt*')
IGNORE_FLAGS+=(-ignore 'Name .HFS+*')
IGNORE_FLAGS+=(-ignore 'Name .journal*')
IGNORE_FLAGS+=(-ignore 'Name .metadata*')
IGNORE_FLAGS+=(-ignore 'Path .Spotlight*')
IGNORE_FLAGS+=(-ignore 'Name .swo')
IGNORE_FLAGS+=(-ignore 'Name .swp')
IGNORE_FLAGS+=(-ignore 'Name .sync*')
IGNORE_FLAGS+=(-ignore 'Path .sync')
IGNORE_FLAGS+=(-ignore 'Name .SyncArchive')
IGNORE_FLAGS+=(-ignore 'Name .SyncID')
IGNORE_FLAGS+=(-ignore 'Name .SyncIgnore')
IGNORE_FLAGS+=(-ignore 'Name ._Sync*')
IGNORE_FLAGS+=(-ignore 'Path .TemporaryItems')
IGNORE_FLAGS+=(-ignore 'Path .Trash*')
IGNORE_FLAGS+=(-ignore 'Name .unison*')
IGNORE_FLAGS+=(-ignore 'Name .~*')
IGNORE_FLAGS+=(-ignore 'Path $RECYCLE.BIN')
IGNORE_FLAGS+=(-ignore 'Name Icon*')
IGNORE_FLAGS+=(-ignore 'Path lost+found')
IGNORE_FLAGS+=(-ignore 'Name nohup.out')
IGNORE_FLAGS+=(-ignore 'Name screenlog.*')
IGNORE_FLAGS+=(-ignore 'Name Thumbs.db')
IGNORE_FLAGS+=(-ignore 'Path *to-delete*')
IGNORE_FLAGS+=(-ignore 'Path .dropbox*')
IGNORE_FLAGS+=(-ignore 'Path .unison')
IGNORE_FLAGS+=(-ignore 'Path .stfolder')

# ------------- dir -------------

DIRNAME=`basename "$0"`
DIRNAME=${DIRNAME#unison.}
DIRNAME=${DIRNAME%.sh}
DIR=${DIRNAME//\:/\/}
DIR=$HOME/$DIR

# ------------- exclude file -------------

EXCLUDE=()
for FILE_NOW in "$LOCAL/unison.ignore" "$LOCAL/unison.$DIRNAME.ignore"
do
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
        echo "Not using exclude file $(basename $FILE_NOW)."
    fi
done

# ------------- include file -------------

INCLUDE=()
for FILE_NOW in "$LOCAL/unison.ignorenot" "$LOCAL/unison.$DIRNAME.ignorenot"
do
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
        echo "Not using include file $(basename $FILE_NOW)."
    fi
done

# ------------- argument file -------------

FILE_FLAGS=()
for FILE_NOW in "$LOCAL/unison.arguments" "$LOCAL/unison.$DIRNAME.arguments"
do
    if [ -e "$FILE_NOW" ]
    then
        file_ends_with_newline "$FILE_NOW" || {
            echo "ERROR: file $FILE_NOW needs to end with a newline."
            exit 3
        }
        while read -r i
        do
            echo "Added to FILE_FLAGS the argument '$i'"
            FILE_FLAGS+=("$i")
        done <<< "$(xargs < "$FILE_NOW" printf '%s\n')"
        echo "Using arguments file $FILE_NOW"
    else
        echo "Not using arguments file $(basename $FILE_NOW)."
    fi
done

# ------------- more arguments in the command line -------------

ADDITIONAL_FLAGS="$@"

# ------------- debug -------------

if [[ ! "${ADDITIONAL_FLAGS/-debug/}" == "$ADDITIONAL_FLAGS" ]]; then
    UNISON="echo $UNISON"
    ADDITIONAL_FLAGS="${ADDITIONAL_FLAGS/-debug/}"
fi

# ------------- dirs -------------

if [ ${#FILE_FLAGS[@]} -gt 0 ] && [[ ! "${FILE_FLAGS[@]//--remote-dir=/}" == "${FILE_FLAGS[@]}" ]]
then
    count=0
    for ((i = 0 ; i < ${#FILE_FLAGS[@]} ; i++))
    do
        echo "FILE_FLAGS[$i]=${FILE_FLAGS[$i]}"
        if [[ ! "${FILE_FLAGS[$i]//--remote-dir=/}" == "${FILE_FLAGS[$i]}" ]]
        then
            DIR="${FILE_FLAGS[$i]/--remote-dir=/}"
            echo "DIR=$DIR"
            FILE_FLAGS[$i]=""
            break
        fi
    done
elif [[ ! "${ADDITIONAL_FLAGS//--remote-dir=/}" == "${ADDITIONAL_FLAGS}" ]]
then
    for i in $ADDITIONAL_FLAGS
    do
        if [[ ! "${i//--remote-dir=/}" == "$i" ]]
        then
            DIR="${i/--remote-dir=/}"
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
elif [[ ! "${ADDITIONAL_FLAGS/-nodeletion-there/}" == "$ADDITIONAL_FLAGS" ]]; then
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

    #get dir list
    [ "$(basename $DIR)" == "dir_list" ]  && DIR_LIST_FILE=$LOCAL/unison.dir_list
    [ "$(basename $DIR)" == "recursive" ] && DIR_LIST_FILE=$(TMP=/tmp/unison.recursive.$RANDOM && find $LOCAL -type d -maxdepth 1 > $TMP 2>/dev/null && echo $TMP)

    #sanity
    if [ ! -e "$DIR_LIST_FILE" ]
    then
        echo "ERROR: need file with list of directories to sync: $DIR_LIST_FILE"
        exit 3
    fi

    #loop over list of directories
    for line in $(cat $DIR_LIST_FILE); do

        line=${line%%\#*}
        if [[ ! "${line/\ /}" == "$line" ]]; then
            line=($line)
            subdir=${line[0]}
            for ((i = 1 ; i < ${#line[@]} ; i++)); do
               case ${line[i]} in
                -ignorenot)
                    INCLUDE+=(-ignorenot "${line[i+1]} ${line[i+2]}")
                    i=$(( i+2 ))
                ;;
                -ignore)
                    EXCLUDE+=(-ignore "${line[i+1]} ${line[i+2]}")
                    i=$(( i+2 ))
                ;;
                *)
                    ADDITIONAL_FLAGS+=" ${line[i]}"
                ;;
                esac
            done
        else
            subdir=$line
        fi

        # ------------- sanity -------------

        SKIP=false

        #check for full comment lines
        [ -z "$line" ] && SKIP=true
        #check for non-existing directories
        [ ! -d "$HOME/$subdir"  ] && echo "ERROR: cannot find $HOME/$subdir"  && SKIP=true
        [ ! -d "$LOCAL/$subdir" ] && echo "ERROR: cannot find $LOCAL/$subdir" && SKIP=true
        #skip self-pointing dirs
        [ ! -z "$(readlink  $HOME/$subdir)" ] && [ "$(cd $(readlink  $HOME/$subdir); pwd)" == "$(cd $LOCAL/$subdir; pwd)" ] && echo "ERROR: $HOME/$subdir  points to $LOCAL/$subdir" && SKIP=true
        [ ! -z "$(readlink $LOCAL/$subdir)" ] && [ "$(cd $(readlink $LOCAL/$subdir); pwd)" == "$(cd  $HOME/$subdir; pwd)" ] && echo "ERROR: $LOCAL/$subdir points to  $HOME/$subdir" && SKIP=true

        $SKIP && continue

        # ------------- force/nodeletion flags -------------

        [ ! -z      "$FORCELOCAL_FLAGS" ] &&      FORCELOCAL_FLAGS="-force $LOCAL/$subdir"
        [ ! -z        "$FORCEDIR_FLAGS" ] &&        FORCEDIR_FLAGS="-force $HOME/$subdir"
        [ ! -z "$NODELETIONLOCAL_FLAGS" ] && NODELETIONLOCAL_FLAGS="-nodeletion $LOCAL/$subdir"
        [ ! -z   "$NODELETIONDIR_FLAGS" ] &&   NODELETIONDIR_FLAGS="-nodeletion $HOME/$subdir" && echo "4:NODELETIONDIR_FLAGS=$NODELETIONDIR_FLAGS"

        # ------------- batch mode -------------

        echo "====================================================================="
        echo "Default flags        : ${DEFAULT_FLAGS[@]} "
        echo "Default ignore flags : ${IGNORE_FLAGS[@]}"
        echo "File ignore flags    : ${EXCLUDE:+"${EXCLUDE[@]}"}"
        echo "File ignorenot flags : ${INCLUDE:+"${INCLUDE[@]}"}"
        echo "File flags           : ${FILE_FLAGS:+"${FILE_FLAGS[@]}"}"
        echo "Command-line flags   : $ADDITIONAL_FLAGS $FORCELOCAL_FLAGS $FORCEDIR_FLAGS $NODELETIONLOCAL_FLAGS $NODELETIONDIR_FLAGS"
        echo "dir is               : $HOME/$subdir"
        echo "local is             : $LOCAL/$subdir"
        echo "====================================================================="
        $UNISON \
            ${DEFAULT_FLAGS[@]} \
            "${IGNORE_FLAGS[@]}" \
            ${EXCLUDE:+"${EXCLUDE[@]}"} \
            ${INCLUDE:+"${INCLUDE[@]}"} \
            ${FILE_FLAGS:+"${FILE_FLAGS[@]}"} \
            "$ADDITIONAL_FLAGS" $FORCELOCAL_FLAGS $FORCEDIR_FLAGS $NODELETIONLOCAL_FLAGS $NODELETIONDIR_FLAGS \
            "$HOME/$subdir" "$LOCAL/$subdir"  || exit $?

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
    echo "File ignore flags    : ${EXCLUDE[@]:-None}"
    echo "File ignorenot flags : ${INCLUDE[@]:-None}"
    echo "File flags           : ${FILE_FLAGS[@]:-None}"
    echo "dir is               : $DIR"
    echo "local is             : $LOCAL"
    echo "====================================================================="
    $UNISON \
        ${DEFAULT_FLAGS[@]} \
        "${IGNORE_FLAGS[@]}" \
        "${EXCLUDE[@]:-}" \
        ${INCLUDE[@]:-} \
        ${FILE_FLAGS[@]:-} \
        $ADDITIONAL_FLAGS $FORCELOCAL_FLAGS $FORCEDIR_FLAGS \
        "$DIR" "$LOCAL"

fi
