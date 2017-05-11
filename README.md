Sync utilities
==============

Introduction
------------

These scripts are useful for synchronizing files within or between different computers. Their usage is not very standard but very simple. In the directory containing the files (or sub-directories) to be synchronized, create a link to one of these scripts. The name of the link contains the 'remote' directory to synchronize with. Furthermore, the scripts `[rsync|unison].dir.sh` are meant for 'remote' directories in the local computer and the scripts `[rsync|unison].user@remote.computer.sh` are meant for remote directories in other computers.

The `[rsync|unison].dir.sh` scripts expect the directory specified in the name of the link to be relative to `$HOME`. The ':' character is used to specify subdirectories. For example, if `rsync.dir.sh` resides in `$HOME/bin/` and you want to backup the contents of `$HOME/projects/` to `$HOME/backup/projects/`, then inside this directory create the link:

`ln -s ~/bin/rsync.dir.sh rsync.backup:projects.sh`

Issuing the command:

`~/projects/rsync.backup:projects.sh`

... will mirror the contents of `$HOME/projects/` and `$HOME/backup/projects/` by doing running `rsync` once in each direction (i.e. `$HOME/projects/` -> `$HOME/backup/projects/` and `HOME/backup/projects/` -> `$HOME/projects/`).

Likewise, the `[rsync|unison].user@remote.computer.sh` looks at the name of the link to determine which computer to connect to. The remote directory on that computer is assumed to be the same relatively to `$HOME` as in the local computer (there are flags to override this, see below). For example, to backup the contents of `$HOME/projects/` to the computer `backup.machine.net`, create the link:

`ln -s ~/bin/rsync.user@remote.computer.sh rsync.backup.machine.net.sh`

If the user name at backup.machine.net differs form the user name at the current computer, then:

`ln -s ~/bin/rsync.user@remote.computer.sh rsync.remoteusername@backup.machine.net.sh`

Issuing the command:

`~/projects/rsync.backup.machine.net.sh`

... will mirror the contents of `$HOME/projects/` in the local computer with the contents of `$HOME/projects/` at `backup.machine.net`, by doing running rsync once in each direction.

The same idea applies to the `unison.[dir|user@remote.computer].sh` scripts, except that unison does the bi-directional synchronization in one step.


Uni-directional synchronization
-------------------------------

(unfinished)


Directories outside home
------------------------

(unfinished)


Parameter files
---------------

(unfinished)

### rsync.arguments

### rsync.exclude

### rsync.include

### unison.arguments

### unison.ignore


