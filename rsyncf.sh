#!/bin/bash -u

# TODO: provide a nice description
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
# Addtional arguments specifict to this script are:
#   '--no-confirmation
#   '--no-feedback'
#   '--backup-deleted'
#   '--no-default-flags'
#   '--no-exclude-file'
#   '--no-include-file'
#   '--no-arguments-file'
#   '--be-verbose'
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


# https://stackoverflow.com/a/66082575
# Get values from a .ini file
function iniget() {
    if [[ $# -lt 2 || ! -f $1 ]]; then
        echo "usage: iniget <file> [--list|<section> [key]]"
        return 1
    fi
    local inifile=$1

    if [ "$2" == "--list" ]; then
        for section in $(cat $inifile | grep "^\\s*\[" | sed -e "s#\[##g" | sed -e "s#\]##g"); do
            echo $section
        done
        return 0
    fi

    local section=$2
    local key=
    [ $# -eq 3 ] && key=$3
    # This awk line turns ini sections => [section-name]key=value
    local lines=$(awk '/\[/{prefix=$0; next} $1{print prefix $0}' $inifile)
    #remove blanks and trim out comments
    lines=$(echo "$lines" | sed -e 's/[[:blank:]]*=[[:blank:]]*/=/g' | sed '/^[[:blank:]]*#/d;s/#.*//' )
    while read -r line ; do
      if [[ "$line" = \[$section\]* ]]; then
        local keyval=$(echo "$line" | sed -e "s/^\[$section\]//")
        if [[ -z "$key" ]]; then
          echo "$keyval"
        else
          if [[ "$keyval" = $key=* ]]; then
            keyval=$(echo "$keyval" | sed -e "s/^$key=//")
          fi
        fi
      fi
    done <<<"$lines"
}

function is-included
{
  local i
  for i in "${@:2}"
  do
    # echoerr "checking: $i == $1"
    [ ! "$i" == "$1" ] || return 0
  done
  return 1
}


# ------------- dynamic parameters -------------

DIR_SOURCE=$PWD

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
DEFAULT_FLAGS+=" --exclude=.git"
DEFAULT_FLAGS+=" --exclude=.svn"
DEFAULT_FLAGS+=" --exclude=Thumbs.db"
DEFAULT_FLAGS+=" --exclude=*~"
DEFAULT_FLAGS+=" --exclude=*.!sync"
DEFAULT_FLAGS+=" --exclude=Icon*"
DEFAULT_FLAGS+=" --exclude=*/__pycache__/*"
DEFAULT_FLAGS+=" --exclude=rsyncf.*.log"
DEFAULT_FLAGS+=" --exclude=.fuse_hidden*"
DEFAULT_FLAGS+=" --exclude=rsync.*"
DEFAULT_FLAGS+=" --exclude=unison.*"
DEFAULT_FLAGS+=" --exclude=nohup.out"
DEFAULT_FLAGS+=" --exclude=*.run.xml"
DEFAULT_FLAGS+=" --exclude=*.swp"
DEFAULT_FLAGS+=" --exclude=*-blx.bib"
DEFAULT_FLAGS+=" --exclude=*.aux"
DEFAULT_FLAGS+=" --exclude=*.bbl"
DEFAULT_FLAGS+=" --exclude=*.bib"
DEFAULT_FLAGS+=" --exclude=*.blg"
DEFAULT_FLAGS+=" --exclude=*.fdb_latexmk"
DEFAULT_FLAGS+=" --exclude=*.fls"
DEFAULT_FLAGS+=" --exclude=*.synctex.gz"
DEFAULT_FLAGS+=" --exclude=*.lof"
DEFAULT_FLAGS+=" --exclude=*.lot"
DEFAULT_FLAGS+=" --exclude=*.toc"
DEFAULT_FLAGS+=" --exclude=*.nav"
DEFAULT_FLAGS+=" --exclude=*.out"
DEFAULT_FLAGS+=" --exclude=*.snm"
DEFAULT_FLAGS+=" --exclude=*.vrb"
DEFAULT_FLAGS+=" --exclude=*.sif"
DEFAULT_FLAGS+=" --exclude=.snakemake"
DEFAULT_FLAGS+=" --exclude=gmt.conf"
DEFAULT_FLAGS+=" --exclude=*cache/"
DEFAULT_FLAGS+=" --exclude=*to-delete*"


# #script-specific arguments
# SCRIPT_ARGS="--not-dir2local --no-d2l --not-local2dir --no-l2d --not-local2remote --no-l2r --not-remote2local --no-r2l --no-confirmation --no-feedback --backup-deleted --no-default-flags --no-exclude-file --no-include-file --no-arguments-file --be-verbose"

# ------------- parse input arguments -------------

REMOTE_LIST=$DIR_SOURCE/rsyncf.list
DEFINED_ARGS=()
COMPUTER_REMOTE=localhost
USER_REMOTE=$USER
DIR_REMOTE=
PRE_SYNC=
SSH_KEY_FILE=
LOCAL2REMOTE=true
REMOTE2LOCAL=true
SHOW_FEEDBACK=true
NO_CONFIRMATION=true
BE_VERBOSE=false
BACKUP_DELETE=false
ECHO=
ADDITIONAL_FLAGS=
ROUTINE=false
REMOTES=()
for arg in "$@"
do
  $BE_VERBOSE && echo -e "Parsing input argument '$arg'"
  case "$arg" in
    help) #show this help screen
      echo "\
$(basename $BASH_SOURCE) <remote1> [ <remote2> ... ] [...]

Copies files from/to the current directory. The source/destination of that copy operation is defined in the 'remotes-file'. This script reads the details of remote computer or other local directories (henceforth known simply as 'remotes') from the 'remotes-file') and call rsync to perform the copy operation.

The default 'remotes-file' for this directory is $REMOTE_LIST; if the argument 'remotes-file=' is used and it points to a file in another directory, the files from that directory will be copied.

Multiple remotes (as allowed in the 'remotes-file') can be specified in one command call but be aware that the following input arguments (if any) will only refer to the first remote:
computer-remote=
    user-remote=
     dir-remote=
       pre-sync=
        ssh-key=
Input argument that are passed directly to rsync (all --* arguments that are not relevant to this script) are preserved for all multiple remotes (if that's the case).

NOTICE: include/exclude details do not support blank-separated file/directory names. The current work-around is to define them manually as input arguments.

NOTICE: although no argument is positional, 'verbose' will only show the parsing operations for the input arguments defined after it.

Defaults flags are:
$DEFAULT_FLAGS
"
      grep ') #' $BASH_SOURCE \
      | grep -v grep \
      | grep -v awk \
      | awk -F') #' '{print $1"_:",$2}' \
      | column -t -s'_'
      exit
    ;;
    --list-remotes|list) #show the list of remote locations defined in the remote list file
      iniget $REMOTE_LIST --list
      # awk '/remote:/ {print $2}' $REMOTE_LIST
      exit
    ;;
    --details|details) #shows the details associated with the previously defined remotes
      if [ ${#REMOTES[@]} -eq 0 ]
      then
        echo "ERROR: need a valid remote before the '--show-details' option"
        exit 3
      fi
      for i in ${REMOTES[@]:-}
      do
        echo "=== details for $i ==="
        iniget $REMOTE_LIST $i
      done
      exit
    ;;
    remotes-file=*) #define the file with the list of remotes, defaults to rsyncf.list in the current directory
      REMOTE_LIST=${arg/remotes-file=}
      DIR_SOURCE=$(cd $(dirname ${REMOTE_LIST/\~/$HOME});pwd)
      REMOTE_LIST=$DIR_SOURCE/$(basename $REMOTE_LIST)
      $BE_VERBOSE && echo -e "Set DIR_SOURCE='$DIR_SOURCE'\nSet REMOTE_LIST='$REMOTE_LIST'"
    ;;
    # ------------------ ) #The arguments below may be defined in the remote list file
    computer-remote=*) #define the remote computer address
      COMPUTER_REMOTE=${arg/computer-remote=}
      DEFINED_ARGS+=(computer-remote)
    ;;
    user-remote=*) #define the remote username
      USER_REMOTE=${arg/user-remote=}
      DEFINED_ARGS+=(user-remote)
    ;;
    dir-remote=*) #define the remote directory, defaults to exactly the same directory as in the local computer
      DIR_REMOTE=${arg/dir-remote=}
      DEFINED_ARGS+=(dir-remote)
    ;;
    pre-sync=*) #execute this command before rsync'ing
      PRE_SYNC=${arg/pre-sync=}
      DEFINED_ARGS+=(pre-sync)
    ;;
    ssh-key=*) #define this ssh-key file, can also be defined in the remote list file; defaults to ~/.ssh/$USER_REMOTE@${COMPUTER_REMOTE%%.*}
      SSH_KEY_FILE=${arg/ssh-key=}
      DEFINED_ARGS+=(ssh-key)
    ;;
    # ------------------ ) #The arguments below may be defined in the 'arguments' section in the remote list file
    #NOTICE: the argument parsing below needs to be duplicated below, when parsing arguments defined in the remote list file
    --not-remote2local|--not-dir2local|--no-r2l|--no-d2l) #sync direction remote -> local
      REMOTE2LOCAL=false
    ;;
    --not-local2remote|--not-local2dir|--no-l2r|--no-l2d) #sync direction remote <- local
      LOCAL2REMOTE=false
    ;;
    --no-feedback) #be quiet
      SHOW_FEEDBACK=false
    ;;
    --feedback) #be quiet
      SHOW_FEEDBACK=true
    ;;
    --confirmation) #start syncing immediately, do not as for confirmation
      NO_CONFIRMATION=false
    ;;
    --no-confirmation) #start syncing immediately, do not as for confirmation
      NO_CONFIRMATION=true
    ;;
    --verbose|verbose) #be noisy
      BE_VERBOSE=true
    ;;
    --no-verbose) #be noisy
      BE_VERBOSE=true
    ;;
    --backup-deleted) #backup files that are deleted
      BACKUP_DELETE=true
    ;;
    #NOTICE: the argument parsing above needs to be duplicated below, when parsing arguments defined in the remote list file
    # ------------------ ) #The arguments below may be only be defined as input arguments
    --no-default-flags) #do not set the defaults rsync flags, you'll need to define all relevant flags from scratch
      DEFAULT_FLAGS=
    ;;
    --no-exclude|--no-include|--no-arguments) #ignore this type of arguments defined in the remote list file
      DEFINED_ARGS+=(${arg/--no-})
    ;;
    --no-exclude-file|--no-include-file|--no-arguments-file) #same as above, needed for compatibility with other rsync scripts
      T=${arg/--no-};T=${T/-file}
      DEFINED_ARGS+=($T)
    ;;
    echo|debug) #show which rsync commands would have been issues
      ECHO=echo
    ;;
    --*) #pass this argument directly to rsync
      ADDITIONAL_FLAGS+=" $arg"
    ;;
    all) #call rsync on ALL remotes defined in the relevant remotes-file
      REMOTES=($(iniget $REMOTE_LIST --list))
      $SHOW_FEEDBACK && echo "Will sync ALL remotes"
    ;;
    routine) #call rsync on the remotes that have 'routine = true'
      REMOTES=($(iniget $REMOTE_LIST --list))
      ROUTINE=true
      $SHOW_FEEDBACK && echo "Will sync routine remotes"
    ;;
    *)
      if [ ! -s $REMOTE_LIST ]
      then
        echo "ERROR: cannot find non-empty remotes list file, expecting '$REMOTE_LIST'"
        exit 3
      fi
      if grep -q '['${arg//-/\\-}']' $REMOTE_LIST
      then
        $BE_VERBOSE && echo "Added remote '$arg'"
        REMOTES+=($arg)
      else
        echo "ERROR: cannot handle input argument '$arg'"
        exit 3
      fi
    ;;
  esac
done

# ------------- sanity -------------

if [ ${#REMOTES[@]} -eq 0 ]
then
  echo "ERROR: need one remote, i.e. one of:"
  $BASH_SOURCE --list-remotes
  exit 3
fi

#can't get this thing to work with paths with blanks, dunno why
if [[ ! "$DIR_SOURCE" == "${DIR_SOURCE// /}" ]]
then
  echo "ERROR: cannot handle paths with blanks."
  exit 3
fi

# ------------- loop over all remotes -------------

FIRST=true
for remote in ${REMOTES[@]}
do
  #retrieve details for this remote
  DETAILS=$(iniget $REMOTE_LIST $remote)
  #sanity
  if [ -z "$DETAILS" ]
  then
    echo "WARNING: cannot find remote '$remote' in file $REMOTE_LIST, ignoring..."
    continue
  fi

  #skip routine sync if this remote does not have 'routine = true'
  if $ROUTINE
  then
    if echo "$DETAILS" | grep -q 'routine=true'
    then
      $BE_VERBOSE && echo "Remote to be included in routine sync: '$remote'"
    else
      $BE_VERBOSE && echo "Remote not to be included in routine sync: '$remote'"
      continue
    fi
  fi

  $SHOW_FEEDBACK && echo "====================================================================="
  $SHOW_FEEDBACK && echo $remote
  $SHOW_FEEDBACK && echo "====================================================================="

  $BE_VERBOSE && echo -e "DETAILS:\n$DETAILS"

  #init loop variables
  FILTER_FLAGS=
  MORE_FLAGS=

  #don't init details so that given as input argument work as expected (for the first iteration only!)
  if $FIRST
  then
    FIRST=false
  else
    #clean up details
    for i in computer-remote user-remote dir-remote pre-sync ssh-key
    do
      DEFINED_ARGS=( ${DEFINED_ARGS[@]/$i} )
    done
    #reset details to defaults
    COMPUTER_REMOTE=localhost
    USER_REMOTE=$USER
    DIR_REMOTE=
    PRE_SYNC=
    SSH_KEY_FILE=
  fi

  LOG=rsyncf.$remote.log
  LOG=${LOG// /_}
  MORE_FLAGS+=" --exclude=$LOG"

  #loop over all details and save them to the appropriate variables
  previous_key=
  while read -r line
  do
    #check if key-value are gives
    if echo "$line" | grep -q '='
    then
      #if it is, the define the new key
      key=$(  echo "$line" | awk -F'=' ' {print $1}')
      value=$(echo "$line" | awk -F'=' ' {print $2}')
    else
      #sanity: need to start with a key
      if [ -z "$previous_key" ]
      then
        echo "ERROR: error parsing $REMOTE_LIST entry [$remote]"
        exit 3
      fi
      #if it is not, use the previous key
      key=$previous_key
      value="$line"
    fi
    $BE_VERBOSE && echo "Parsing $key='$value'"
    if is-included $key ${DEFINED_ARGS[@]:-}
    then
      $SHOW_FEEDBACK && echo "Because of input arguments, ignoring value(s) for key $key: $value"
    else
      case $key in
      computer-remote)
        COMPUTER_REMOTE=$value
        $BE_VERBOSE && echo "Set COMPUTER_REMOTE='$value'"
        DEFINED_ARGS+=($key)
      ;;
      user-remote)
        USER_REMOTE=$value
        $BE_VERBOSE && echo "Set USER_REMOTE='$value'"
        DEFINED_ARGS+=($key)
      ;;
      dir-remote)
        DIR_REMOTE=$value
        $BE_VERBOSE && echo "Set DIR_REMOTE='$value'"
        DEFINED_ARGS+=($key)
      ;;
      pre-sync)
        PRE_SYNC="$value"
        $BE_VERBOSE && echo "Set PRE_SYNC='$value'"
        DEFINED_ARGS+=($key)
      ;;
      ssh-key)
        SSH_KEY_FILE="$value"
        $BE_VERBOSE && echo "Set SSH_KEY_FILE='$value'"
        DEFINED_ARGS+=($key)
      ;;
      exclude|include)
        if [[ "${value/ }" == "$value" ]]
        then
          #NOTICE: the quotes are needed to avoid expanding globbers
          for i in "$value"
          do
            [ -z "$i" ] && continue
            FILTER_FLAGS+=" --$key=$i"
            $BE_VERBOSE && echo "To FILTER_FLAGS, appended '--$key=$i'"
          done
        else
          #NOTICE: keep names with blanks in one single line and use single quotes
          if [ "${value:0:1}" == "\"" ]
          then
            FILTER_FLAGS+=" --$key=${value//\\\*/*}"
          else
            #NOTICE: this is needed for those cases when there are multiple values in one line
            for i in ${value//\*/\\*}
            do
              [ -z "$i" ] && continue
              FILTER_FLAGS+=" --$key=${i//\\\*/*}"
              $BE_VERBOSE && echo "To FILTER_FLAGS, appended '--$key=${i//\\\*/*}'"
            done
          fi
        fi
      ;;
      arguments)
        for i in $value
        do
          case "$i" in
            #NOTICE: the argument parsing below needs to be duplicated above, when parsing input arguments
            --not-remote2local|--not-dir2local|--no-r2l|--no-d2l)
              REMOTE2LOCAL=false
            ;;
            --not-local2remote|--not-local2dir|--no-l2r|--no-l2d)
              LOCAL2REMOTE=false
            ;;
            --no-feedback)
              SHOW_FEEDBACK=false
            ;;
            --no-confirmation)
              NO_CONFIRMATION=true
            ;;
            --be-verbose)
              BE_VERBOSE=true
            ;;
            --backup-deleted)
              BACKUP_DELETE=true
            ;;
            #NOTICE: the argument parsing above needs to be duplicated below, when parsing input arguments
            *)
              MORE_FLAGS+=" $i"
              $BE_VERBOSE && echo "To MORE_FLAGS, appended '$i'"
            ;;
          esac
        done
      ;;
      esac
    fi
    previous_key=$key
  done < <(iniget $REMOTE_LIST $remote)

  # ------------- local username -------------

  #this is useful when run from crontab and the USER_REMOTE is set
  USER=${USER:-$USER_REMOTE}

  # ------------- pre sync operations -------------

  if is-included pre-sync ${DEFINED_ARGS[@]:-}
  then
    #execute the requested command
    echo "executing pre-run command '$PRE_SYNC':"
    $PRE_SYNC || exit $?
  fi

  # ------------- if remote dir is not given explicitly, defaul to user's home -------------

  if ! is-included dir-remote ${DEFINED_ARGS[@]:-}
  then
    #editing the remote dir (no need to escape the / character of the replacing string, apparently)
    DIR_REMOTE="${DIR_SOURCE/\/home\/$USER\///home/$USER_REMOTE/}"
    DIR_REMOTE="${DIR_SOURCE/\/Users\/$USER\///Users/$USER_REMOTE/}"
  fi

  # ------------- keyfile -------------

  if ! is-included ssh-key ${DEFINED_ARGS[@]:-}
  then
    SSH_KEY_FILE=$HOME/.ssh/$USER_REMOTE@${COMPUTER_REMOTE%%.*}
  fi

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

  if ! is-included --delete $ADDITIONAL_FLAGS $MORE_FLAGS
  then
    if is-included '--include=.git' $ADDITIONAL_FLAGS $MORE_FLAGS
    then
      echo "NOTICE: to sync .git, need the --delete flag, otherwise .git dirs are ignored."
      #delete the --include=.git entry
      for i in $ADDITIONAL_FLAGS
      do
        #this ensures things like --include=.git* are also deleted
        [[ "${i/--include=.git}" == "$i" ]] || ADDITIONAL_FLAGS=${ADDITIONAL_FLAGS/$i}
      done
      for i in $MORE_FLAGS
      do
        #this ensures things like --include=.git* are also deleted
        [[ "${i/--include=.git}" == "$i" ]] || MORE_FLAGS=${MORE_FLAGS/$i}
      done

    fi
  else
    if ! is-included '--include=.git' $ADDITIONAL_FLAGS $MORE_FLAGS
    then
      echo "NOTICE: not ignoring .git, since the --delete flag was given."
      MORE_FLAGS+=" --include=.git*"
    fi
  fi

  # ------------- backup deleted files -------------

  if $BACKUP_DELETE
  then
    DATE=$(date "+%Y-%m-%d")
    if [ -z "$DATE" ]
    then
      echo "BUG TRAP: could not build data string"
      exit 3
    fi
    MORE_FLAGS+=" --delete --backup --backup-dir=backup/$(date "+%Y-%m-%d") --exclude=backup/????-??-??"
  fi

  # ------------- update flag -------------

  if $REMOTE2LOCAL || $LOCAL2REMOTE; then
    is-included --update $ADDITIONAL_FLAGS $MORE_FLAGS || MORE_FLAGS+=" --update"
  fi

  # ------------- make rsync verbose too -------------

  $BE_VERBOSE \
    && MORE_FLAGS="$MORE_FLAGS --progress --human-readable" \
    || MORE_FLAGS="$MORE_FLAGS --itemize-changes"

  # ------------- feedback -------------

  if $SHOW_FEEDBACK
  then
    #split additional flags
    INCLUDE_LIST=()
    EXCLUDE_LIST=()
    OTHER_LIST=()
    for i in $ADDITIONAL_FLAGS $MORE_FLAGS $FILTER_FLAGS $DEFAULT_FLAGS
    do
      if [[ ! "${i/--include=}" == "$i" ]]
      then
        INCLUDE_LIST+=("${i/--include=}")
      elif [[ ! "${i/--exclude=}" == "$i" ]]
      then
        EXCLUDE_LIST+=("${i/--exclude=}")
      else
        OTHER_LIST+=("$i")
      fi
    done
    echo "Additional flags  : ${OTHER_LIST[@]:-}"
    echo "Include list      : ${INCLUDE_LIST[@]:-}"
    echo "Exclude list      : ${EXCLUDE_LIST[@]:-}"
    echo "Remote address    : $COMPUTER_REMOTE"
    echo "Remote dir        : $DIR_REMOTE"
    echo "Local dir         : $DIR_SOURCE"
    if $LOCAL2REMOTE && $REMOTE2LOCAL
    then
      echo "Bidirectional sync: local -> remote -> local"
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
    MORE_FLAGS="$MORE_FLAGS --itemize-changes"
  fi

  # ------------- user in the loop? -------------

  if ! $NO_CONFIRMATION
  then
    echo "Continue [Y/n] ?"
    read ANSWER
    if [ "$ANSWER" == "N" ] || [ "$ANSWER" == "n" ]
    then
      exit
    fi
  fi

  function remote-name()
  {
    if [ "$COMPUTER_REMOTE" == "localhost" ]
    then
      echo "$DIR_REMOTE/"
    else
      echo "$USER_REMOTE@$COMPUTER_REMOTE:$DIR_REMOTE/"
    fi
  }

  # ------------- sync -------------

  SYNC_LOCATIONS=()
  if $LOCAL2REMOTE
  then
    SYNC_LOCATIONS+=("$DIR_SOURCE/ $(remote-name)")
  fi
  if $REMOTE2LOCAL
  then
    SYNC_LOCATIONS+=("$(remote-name) $DIR_SOURCE/")
  fi

  for ((i = 0 ; i < ${#SYNC_LOCATIONS[@]} ; i++))
  do
    $SHOW_FEEDBACK && echo "Synching ${SYNC_LOCATIONS[i]/ / -> }"
    $ECHO rsync --log-file="$DIR_SOURCE/$LOG" \
      $DEFAULT_FLAGS $MORE_FLAGS $ADDITIONAL_FLAGS $FILTER_FLAGS \
      ${SYNC_LOCATIONS[i]}
  done

done
