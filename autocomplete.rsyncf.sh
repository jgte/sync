#!/bin/bash -ue

${SHELL_STARTUP_DEBUG:-true} && echo ">>>>> $BASH_SOURCE" || true

function _rsyncf.sh_() {
  latest="${COMP_WORDS[$COMP_CWORD]}"
  COMPREPLY=($(compgen -W "$(rsyncf.sh list)" -- $latest))
}

complete -F _rsyncf.sh_ rsyncf.sh || echo "WARNING: $BASH_SOURCE failed"

${SHELL_STARTUP_DEBUG:-true} && echo "<<<<< $BASH_SOURCE" || true
