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

DATE=$(which gdate 2> /dev/null || which date)
function is_file_older
{
  [ $( $DATE +%s -r "$1" ) -ge $( $DATE +%s --date="$2" ) ] && return 0 || return 1
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
#        for this reason, --update is added to RSYNC_ARGS whenever --not-local2remote or --not-remote2local are used
# DEFAULT_FLAGS+=" --update"
DEFAULT_FLAGS+=" --exclude=.DS_Store"
DEFAULT_FLAGS+=" --exclude=._*"
DEFAULT_FLAGS+=" --exclude=.~*"
DEFAULT_FLAGS+=" --exclude=*.o"
DEFAULT_FLAGS+=" --exclude=*.a"
DEFAULT_FLAGS+=" --exclude=*.exe"
DEFAULT_FLAGS+=" --exclude=.swo"
DEFAULT_FLAGS+=" --exclude=.swp"
DEFAULT_FLAGS+=" --exclude=screenlog.*"
DEFAULT_FLAGS+=" --exclude=.gmt*"
DEFAULT_FLAGS+=" --exclude=nohup.out"
DEFAULT_FLAGS+=" --exclude=.Trash*"
DEFAULT_FLAGS+=" --exclude=\$RECYCLE.BIN"
DEFAULT_FLAGS+=" --exclude=lost+found"
DEFAULT_FLAGS+=" --exclude=.Spotlight*"
DEFAULT_FLAGS+=" --exclude=.fseventsd*"
DEFAULT_FLAGS+=" --exclude=.DocumentRevisions*"
DEFAULT_FLAGS+=" --exclude=.sync"
DEFAULT_FLAGS+=" --exclude=.TemporaryItems"
DEFAULT_FLAGS+=" --exclude=.SyncArchive"
DEFAULT_FLAGS+=" --exclude=.SyncID"
DEFAULT_FLAGS+=" --exclude=.SyncIgnore"
DEFAULT_FLAGS+=" --exclude=.dropbox*"
DEFAULT_FLAGS+=" --exclude=.unison*"
DEFAULT_FLAGS+=" --exclude=Thumbs.db"
DEFAULT_FLAGS+=" --exclude=Icon*"
DEFAULT_FLAGS+=" --exclude=*~"
DEFAULT_FLAGS+=" --exclude=*.!sync"
DEFAULT_FLAGS+=" --exclude=.journal*"
DEFAULT_FLAGS+=" --exclude=.HFS+*"
DEFAULT_FLAGS+=" --exclude=.fuse_hidden*"
DEFAULT_FLAGS+=" --exclude=*.run.xml"
DEFAULT_FLAGS+=" --exclude=*.swp"
DEFAULT_FLAGS+=" --exclude=*-blx.bib"
DEFAULT_FLAGS+=" --exclude=*.aux"
DEFAULT_FLAGS+=" --exclude=*.bbl"
DEFAULT_FLAGS+=" --exclude=*.blg"
DEFAULT_FLAGS+=" --exclude=*.fdb_latexmk"
DEFAULT_FLAGS+=" --exclude=*.fls"
DEFAULT_FLAGS+=" --exclude=*.synctex.gz"
DEFAULT_FLAGS+=" --exclude=*.lof"
DEFAULT_FLAGS+=" --exclude=*.lot"
DEFAULT_FLAGS+=" --exclude=*.toc"
DEFAULT_FLAGS+=" --exclude=*.log"
DEFAULT_FLAGS+=" --exclude=*.nav"
DEFAULT_FLAGS+=" --exclude=*.out"
DEFAULT_FLAGS+=" --exclude=*.snm"
DEFAULT_FLAGS+=" --exclude=*.vrb"
DEFAULT_FLAGS+=" --exclude=*conflicted*"
DEFAULT_FLAGS+=" --exclude=*to-delete*"


#script-specific arguments
SCRIPT_ARGS_ALL="--not-dir2local --no-d2l --not-local2dir --no-l2d --not-local2remote --no-l2r --not-remote2local --no-r2l --no-confirmation --no-feedback --backup-deleted --no-default-flags --no-exclude-file --no-include-file --no-arguments-file --be-verbose --no-git-check"

# ------------- given arguments -------------

SCRIPT_ARGS="$@"

# ------------- resolve arguments with many names -------------

function remote2local()
{
  [[ "${SCRIPT_ARGS//--not-remote2local}" == "$SCRIPT_ARGS" ]] && \
  [[ "${SCRIPT_ARGS//--not-dir2local}"    == "$SCRIPT_ARGS" ]] && \
  [[ "${SCRIPT_ARGS//--no-r2l}"           == "$SCRIPT_ARGS" ]] && \
  [[ "${SCRIPT_ARGS//--no-d2l}"           == "$SCRIPT_ARGS" ]] && \
  return 0 || \
  return 1
}

function local2remote()
{
  [[ "${SCRIPT_ARGS//--not-local2remote}" == "$SCRIPT_ARGS" ]] && \
  [[ "${SCRIPT_ARGS//--not-local2dir}"    == "$SCRIPT_ARGS" ]] && \
  [[ "${SCRIPT_ARGS//--no-l2r}"           == "$SCRIPT_ARGS" ]] && \
  [[ "${SCRIPT_ARGS//--no-l2d}"           == "$SCRIPT_ARGS" ]] && \
  return 0 || \
  return 1
}

function show-feedback()
{
  [[ "${SCRIPT_ARGS//--no-feedback/}" == "$SCRIPT_ARGS" ]] && return 0 || return 1
}

function be-verbose()
{
  [[ "${SCRIPT_ARGS//--be-verbose/}" == "$SCRIPT_ARGS" ]] && return 1 || return 0
}

# ------------- additonal flags -------------

RSYNC_ARGS="$@"

# ------------- remote dir name -------------

function strip_file_accessories(){
  local OUT=$(basename $1)
  OUT=${OUT%.sh*}
  OUT=${OUT#*rsync.}
  echo $OUT
}

DIR_REMOTE_FILE=$(strip_file_accessories $0)
DIR_REMOTE=$HOME/${DIR_REMOTE_FILE//\:/\/}

# ------------- handle files with rsync options -------------

#resolve existing rsync.*{exclude|include|arguments} file
function get-rsync-file()
{
  local TYPE=$1
  for i in \
    "$DIR_SOURCE/rsync.$(basename $DIR_REMOTE_FILE).$1" \
    "$DIR_SOURCE/rsync.$(basename $DIR_REMOTE).$1" \
    "$DIR_SOURCE/rsync.$1"
  do
    # echo "get-rsync-file: $i" 1>&2
    if [ -e "$i" ]
    then
      echo "$i"
      return
    fi
  done
  echo ""
}
#return the name of a rsync.*{exclude|include|arguments} file
function set-rsync-file()
{
  local TYPE=$1
  echo "$DIR_SOURCE/rsync.$(basename $DIR_REMOTE_FILE).$1"
}

# ------------- arguments file -------------

ARGUMENTS_FILE="$(get-rsync-file arguments)"
if [ ! -z "$ARGUMENTS_FILE" ] && \
  [[ "${SCRIPT_ARGS//--no-arguments-file/}" == "$SCRIPT_ARGS" ]]
then
  if [ $(cat "$ARGUMENTS_FILE" | wc -l) -gt 1 ]
  then
    echo "ERROR: file $DIR_SOURCE/rsync.arguments cannot have more than one line."
    exit 3
  fi
  RSYNC_ARGS="$RSYNC_ARGS $(cat "$ARGUMENTS_FILE")"
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
#NOTICE: SCRIPT_ARGS will be augmented with all the SCRIPT_ARGS_ALL that are present in RSYNC_ARGS;
#        in turn, RSYNC_ARGS will be cleaned of those arguments.
#        if SCRIPT_ARGS_ALL options are passed in the command line, then they are already
#        in SCRIPT_ARGS (SCRIPT_ARGS=$@) and there will be duplicates. This is no problem.
#        The point of this loop is to pass the SCRIPT_ARGS_ALL collected from
#        rsync.arguments to SCRIPT_ARGS (and to clean RSYNC_ARGS of them).
for i in $SCRIPT_ARGS_ALL
do
  if [[ ! "${RSYNC_ARGS//$i/}" == "$RSYNC_ARGS" ]]
  then
    #remove this argument from the rsync list of arguments
    RSYNC_ARGS=${RSYNC_ARGS//$i/}
    SCRIPT_ARGS="$SCRIPT_ARGS $i"
  fi
done

# ------------- --<name>= options -------------

for arg in --remote-dir= #--remote-user= --remote-computer= --pre-run=
do
  if [[ ! "${RSYNC_ARGS/$arg}" == "$RSYNC_ARGS" ]]
  then
    for i in $RSYNC_ARGS
    do
      if [[ ! "${i/$arg}" == "$i" ]]
      then
        #xargs trimms the values
        V="$(echo ${i/$arg} | xargs)"
        #distribute value where it's supposed to go
        case $arg in
          # --remote-user=)         USER_REMOTE=$V ;;
          # --remote-computer=) COMPUTER_REMOTE=$V ;;
          --remote-dir=)           DIR_REMOTE=$V ;;
          --pre-run=)
            #execute the requested command
            echo "executing pre-run command '$V':"
            $V || exit $?
          ;;
        esac
        #trim additional flags
        RSYNC_ARGS="${RSYNC_ARGS//$arg$V/}"
        #append to args
        SCRIPT_ARGS="$SCRIPT_ARGS $arg$V"
        break
      fi
    done
  fi
done

# ------------- it's now safe to use variables instead of functions -------------

show-feedback && SHOW_FEEDBACK=true || SHOW_FEEDBACK=false
be-verbose    && BE_VERBOSE=true    || BE_VERBOSE=false
remote2local  && REMOTE2LOCAL=true  || REMOTE2LOCAL=false
local2remote  && LOCAL2REMOTE=true  || LOCAL2REMOTE=false

# ------------- include .git dirs when --delete is given -------------

function ensure_file()
{
  [ -e "$1" ] || touch "$1"
}

GITSYNC=false
#make sure rsync.include exists
INCLUDE_FILE="$(get-rsync-file include)"
[ -z "$INCLUDE_FILE" ] && INCLUDE_FILE="$(set-rsync-file include)"
ensure_file "$INCLUDE_FILE"
#NOTICE: git checkind needs --delete and not --no-git-check
if [[ "${RSYNC_ARGS/--delete}" == "$RSYNC_ARGS" ]] || \
   [[ ! "${SCRIPT_ARGS/--no-git-check}" == "$SCRIPT_ARGS" ]]
then
  if grep -q '.git*' "$INCLUDE_FILE"
  then
    $SHOW_FEEDBACK && echo "NOTICE: to sync .git, need the --delete flag, otherwise .git dirs are ignored."
    grep -v '.git' "$INCLUDE_FILE" > /tmp/rsync.include.$$ || true
    mv -fv /tmp/rsync.include.$$ "$INCLUDE_FILE"
  fi
else
  GITSYNC=true
  if ! grep -q '.git*' "$INCLUDE_FILE"
  then
    $SHOW_FEEDBACK && echo "NOTICE: not ignoring .git, since the --delete flag was given."
    echo '.git*' >> "$INCLUDE_FILE"
  fi
fi

# ------------- resolve git versions -------------


if $GITSYNC
then
  GITLIST_FILE="$DIR_SOURCE/rsync.$(basename $DIR_REMOTE_FILE).git-list"
  if [ -e "$GITLIST_FILE" ] && is_file_older "$GITLIST_FILE" "1 week ago"
  then
    echo "Reading list of git repositories from $GITLIST_FILE"
  else
    echo "Updating list of git repositories to $GITLIST_FILE"
    find "$DIR_SOURCE" -type d -name .git -print0 > "$GITLIST_FILE"
  fi
  $SHOW_FEEDBACK && echo "Checking git versions..."
  while IFS='' read -r -d '' d; do
    $SHOW_FEEDBACK && echo "Checking git version at $d"
    GITDIRLOCAL="$(dirname "$d")"
    GITDIRSINK="${GITDIRLOCAL/$DIR_SOURCE/$DIR_REMOTE}"
    GITVERLOCAL=$(git -C "$GITDIRLOCAL" log --pretty=format:"%at" 2>&1 | head -n1)
    GITVERSINK=$( git -C "$GITDIRSINK"  log --pretty=format:"%at" 2>&1 | head -n1)
    echo "$GITVERLOCAL" | grep -q fatal && echo "failed git log on $GITDIRLOCAL" && continue
    echo "$GITVERSINK"  | grep -q fatal && echo "failed git log on $GITDIRSINK"  && continue
    if [ ! -z "$GITVERSINK" ] && [ ! -z "$GITVERLOCAL" ] && [ $GITVERLOCAL -lt $GITVERSINK ]
    then
      echo "WARNING: date of git repo at source is lower than at sink:"
      echo "source: $($DATE -d @$GITVERLOCAL) $GITDIRLOCAL"
      echo "sink  : $($DATE -d @$GITVERSINK) $GITDIRSINK"
      echo "Skip synching '$i'"
      EXCLUDE+=" --exclude=${GITDIRLOCAL/"$DIR_SOURCE"}"
    # else
    #   echo "source: $($DATE -d @$GITVERLOCAL) $GITDIRLOCAL/$i"
    #   echo "sink  : $($DATE -d @$GITVERSINK) $GITDIRSINK/$i"
    fi
  done < "$GITLIST_FILE"
fi

# ------------- exclude file -------------

EXCLUDE_FILE="$(get-rsync-file exclude)"
if [ ! -z "$EXCLUDE_FILE" ] && \
  [[ "${SCRIPT_ARGS//--no-exclude-file/}" == "$SCRIPT_ARGS" ]]
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
  [[ "${SCRIPT_ARGS//--no-include-file/}" == "$SCRIPT_ARGS" ]]
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

if [[ ! "${SCRIPT_ARGS//--backup-deleted/}" == "$SCRIPT_ARGS" ]]
then
  RSYNC_ARGS+=" --delete --backup --backup-dir=backup/$( $DATE "+%Y-%m-%d") --exclude=backup.????-??-??"
fi

# ------------- get rid of default flags -------------

[[ "${SCRIPT_ARGS//--no-default-flags/}" == "$SCRIPT_ARGS" ]] || DEFAULT_FLAGS=

# ------------- resolve argument conflicts -------------

#need to remove sparse if inplace if given
if [[ ! "${RSYNC_ARGS//--inplace/}" == "$RSYNC_ARGS" ]]
then
  DEFAULT_FLAGS="${DEFAULT_FLAGS//--sparse/}"
  $SHOW_FEEDBACK && echo "Removed --sparse because --inplace was given."
fi

# ------------- update flag -------------

if $REMOTE2LOCAL || $LOCAL2REMOTE; then
  [[ "${RSYNC_ARGS//--update/}" == "$RSYNC_ARGS" ]] && RSYNC_ARGS+=" --update"
fi

# ------------- feedback -------------

if $SHOW_FEEDBACK
then
  $BE_VERBOSE \
    && RSYNC_ARGS="$RSYNC_ARGS --progress --human-readable" \
    || RSYNC_ARGS="$RSYNC_ARGS --itemize-changes"
  $BE_VERBOSE && echo "Default flags     : $DEFAULT_FLAGS"
  echo "Additional flags  : $RSYNC_ARGS"
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
  RSYNC_ARGS="$RSYNC_ARGS --itemize-changes"
fi

# ------------- user in the loop? -------------

if [[ "${SCRIPT_ARGS//--no-confirmation/}" == "$SCRIPT_ARGS" ]]
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
    $INCLUDE $DEFAULT_FLAGS $RSYNC_ARGS $EXCLUDE \
    "$DIR_SOURCE/" "$DIR_REMOTE/"
fi

# ------------- remote to local -------------

if $REMOTE2LOCAL
then
  $SHOW_FEEDBACK && echo "Synching $DIR_REMOTE -> $DIR_SOURCE"
  $ECHO rsync --log-file="$DIR_SOURCE/$LOG" \
    $INCLUDE $DEFAULT_FLAGS $RSYNC_ARGS $EXCLUDE \
    "$DIR_REMOTE/" "$DIR_SOURCE/"
fi
