#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


SCRIPT_NAME="update-backup-mirror-by-modification-time.sh"
VERSION_NUMBER="1.02"

# Implemented methods are: rsync, rdiff-backup
#
# WARNING: rdiff-backup does not detect moved files. If you reorganise your drive,
#          you may want to purge old data immediately (see REMOVE_OLDER_THAN below),
#          or your destination directory may get much bigger than usual.

BACKUP_METHOD="rdiff-backup"


declare -r BOOLEAN_TRUE=0
declare -r BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2015 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "For backup purposes, sometimes you just want to copy all files across"
  echo "to another disk at regular intervals. There is often no need for"
  echo "encryption or compression. However, you normally don't want to copy"
  echo "all files every time around, but only those which have changed."
  echo
  echo "Assuming that you can trust your filesystem's timestamps, this script can"
  echo "get you started in little time. You can easily switch between"
  echo "rdiff-backup and rsync (see this script's source code), until you are"
  echo "sure which method you want."
  echo
  echo "Syntax:"
  echo "  ./$SCRIPT_NAME src dest  # The src directory must exist."
  echo
  echo "You probably want to run this script with \"background.sh\", so that you get a"
  echo "visual indication when the transfer is complete."
  echo
}


str_ends_with ()
{
  # $1 = string
  # $2 = suffix

  case "$1" in
   *$2) return 0;;
   *)   return 1;;
  esac
}


add_to_comma_separated_list ()
{
  local NEW_ELEMENT="$1"
  local MSG_VAR_NAME="$2"

  if [[ ${!MSG_VAR_NAME} = "" ]]; then
    eval "$MSG_VAR_NAME+=\"$NEW_ELEMENT\""
  else
    eval "$MSG_VAR_NAME+=\",$NEW_ELEMENT\""
  fi
}


is_dir_empty ()
{
  shopt -s nullglob
  shopt -s dotglob  # Include hidden files.
  local -a FILES=( "$1"/* )

  if [ ${#FILES[@]} -eq 0 ]; then
    return $BOOLEAN_TRUE
  else
    if false; then
      echo "Files found: ${FILES[@]}"
    fi
    return $BOOLEAN_FALSE
  fi
}


# rsync is OK, but I think that rdiff-backup is better.

rsync_method ()
{
  local SRC_DIR="$1"
  local DEST_DIR="$2"

  local SRC_DIR_QUOTED
  local DEST_DIR_QUOTED

  printf -v SRC_DIR_QUOTED  "%q" "$SRC_DIR"
  printf -v DEST_DIR_QUOTED "%q" "$DEST_DIR"

  local ARGS=""

  ARGS+=" --no-inc-recursive"  # Uses more memory and is somewhat slower, but improves progress indication.
                               # Otherwise, rsync is almost all the time stuck at a 99% completion rate.
  ARGS+=" --archive"  #  A quick way of saying you want recursion and want to preserve almost everything.
  ARGS+=" --delete --delete-excluded --force"
  ARGS+=" --human-readable"  # Display "60M" instead of "60,000,000" and so on.

  if [[ $OSTYPE = "cygwin" ]]; then
    # After years and years of using Cygwin, as of Jan 2016 I am still getting errors
    # due to rsync failing at setting file permissions and file group membership. This is an example error message:
    #   rsync: chgrp "/cygdrive/c/blah/blah" failed: Permission denied (13)
    # I am just disabling them. If you manage to get your Cygwin to work properly in this respect,
    # you may want to keep these options enabled.
    ARGS+=" --no-perms --no-group"
  fi

  # Unfortunately, there seems to be no way to display the estimated remaining time for the whole transfer.

  local PROGRESS_ARGS=""

  # Instead of making a quiet pause at the beginning, display a file scanning progress indication.
  # That is message "building file list..." and the increasing file count.
  # If you are copying a large number of files and are logging to a file, the log file will be pretty big,
  # as rsync (as of version 3.1.0) seems to refresh the file count in 100 increments. See below for more
  # information about refreshing the progress indication too often.
  add_to_comma_separated_list "flist2" PROGRESS_ARGS

  # Display a global progress indication.
  # If you are copying a large number of files and are logging to a file, the log file will
  # grow very quickly, as rsync (as of version 3.1.0) seems to refresh the accumulated statistics
  # once for every single file. I suspect the console's speed may end up limiting rsync's performance
  # in such scenarios. I have reported this issue, see the following mailing list message:
  #   "Progress indication refreshes too often with --info=progress2"
  #   Wed Jun 11 04:50:26 MDT 2014
  #   https://lists.samba.org/archive/rsync/2014-June/029494.html
  add_to_comma_separated_list "progress2" PROGRESS_ARGS

  # Warn if files are skipped. Not sure if we need this.
  add_to_comma_separated_list "skip1" PROGRESS_ARGS

  # Warn if symbolic links are unsafe. Not sure if we need this.
  add_to_comma_separated_list "symsafe1" PROGRESS_ARGS

  # We want to see how much data there is (the "total size" value).
  # Unfortunately, there is no way to suppress the other useless stats.
  add_to_comma_separated_list "stats1" PROGRESS_ARGS


  ARGS+=" --info=$PROGRESS_ARGS"

  local CMD="rsync  $ARGS --  $SRC_DIR_QUOTED  $DEST_DIR_QUOTED"

  echo "$CMD"
  eval "$CMD"
}


# rdiff_backup can keep old files around for a certain amount of time.
# This way, you can recover accidentally-deleted files from a recent backup.

rdiff_backup_method ()
{
  local SRC_DIR="$1"
  local DEST_DIR="$2"

  local SRC_DIR_QUOTED
  local DEST_DIR_QUOTED

  printf -v SRC_DIR_QUOTED  "%q" "$SRC_DIR"
  printf -v DEST_DIR_QUOTED "%q" "$DEST_DIR"

  # When backing up across different operating systems, it may be impractical to map all users and groups
  # correctly. Sometimes you just want to ignore users and groups altogether. Disabling the backing up
  # of ACLs also prevents unnecessary warnings in this scenario.
  local DISABLE_ACLS=true

  # If you have been backing up with rsync, and then want to switch to the rdiff-backup method,
  # the first time you run rdiff-backup the destination directory will not contain the rdiff-backup
  # metadata directory. In this case, we should not try to run a --remove-older-than command,
  # because it will always fail.
  local RDIFF_METADATA_DIRNAME="rdiff-backup-data"

  if test -d "$DEST_DIR" && test -d "$DEST_DIR/$RDIFF_METADATA_DIRNAME"; then
    local REMOVE_OLDER_THAN="3M"  # 3M means 3 months.

    local CMD1="rdiff-backup  --force --remove-older-than \"$REMOVE_OLDER_THAN\"  $DEST_DIR_QUOTED"

    echo "$CMD1"
    eval "$CMD1"
  fi

  # We need "--force" in case the previous backup was interrupted (for example, if rdiff-backup was stopped
  # with Ctrl+C), which can happen rather often if your backups are large. Otherwise, you get this error message:
  #   Fatal Error: It appears that a previous rdiff-backup session with process
  #   id xxx is still running.  If two different rdiff-backup processes write
  #   the same repository simultaneously, data corruption will probably
  #   result.  To proceed with regress anyway, rerun rdiff-backup with the
  #   --force option.
  local CMD2="rdiff-backup  --force"

  # Unfortunately, rdiff-backup prints no nice progress indication for the casual user.
  if true; then
    # The default verbosity level is 3.
    # With level 4 you get information about ACL support.
    # With level 5 you start seeing the transferred files, but that makes the backup process too verbose.
    CMD2+=" --verbosity 4"
  fi

  if $DISABLE_ACLS; then
    CMD2+=" --no-acls"
  fi

  # Say we are backing up under Linux from a Linux filesystem to a Windows network drive mounted
  # with "mount -t cifs". If a file in the Linux filesystem is a symlink to another file (even if the target
  # file falls under the same set being backed-up), then the complete backup operation will fail
  # with error "[Errno 95] Operation not supported".
  CMD2+=" --exclude-symbolic-links"

  # Print some statistics at the end.
  if true; then
    CMD2+=" --print-statistics"
  fi

  CMD2+="  $SRC_DIR_QUOTED  $DEST_DIR_QUOTED"

  echo "$CMD2"
  eval "$CMD2"

  if ! test -d "$DEST_DIR/$RDIFF_METADATA_DIRNAME"; then
    abort "After running rdiff-backup, the following expected directory was not found: \"$DEST_DIR/$RDIFF_METADATA_DIRNAME\"."
  fi

  # Verification takes time, so you can disable it if you like.
  if true; then
    local CMD3="rdiff-backup --verify"

    if $DISABLE_ACLS; then
      CMD3+=" --no-acls"
    fi

    CMD3+="  $DEST_DIR_QUOTED"

    echo "$CMD3"
    eval "$CMD3"
  fi
}


# ------- Entry point -------

if [ $# -eq 0 ]; then
  display_help
  exit 0
fi

if [ $# -ne 2 ]; then
  abort "Invalid number of command-line arguments. Run this script without arguments for help."
fi

SRC_DIR="$1"
DEST_DIR="$2"

# In rsync, "src/" means just the contents of src, and "src" means the src itself.
# However, rdiff-backup makes no such distinction.
# For consistency, make all methods behave the same, so that the user
# can switch methods without modifying the paths.

if [[ $SRC_DIR = "/" ]]; then
  abort "The source directory cannot be the root directory."
fi

if [[ $DEST_DIR = "/" ]]; then
  abort "The destination directory cannot be the root directory."
fi

if ! test -d "$SRC_DIR"; then
  abort "The source directory \"$SRC_DIR\" does not exit."
fi

SRC_DIR_ABS="$(readlink --verbose  --canonicalize-existing  "$SRC_DIR")"


# Sanity check: Make sure that the source directory is not empty.
# This can easily happen if you have an empty directory intended to act
# as a mountpoint for a network drive, but you forget to mount the network drive
# before running this script. An empty source directory would mark all files
# in the backup as "deleted", which is a rather unlikely operation for a backup.

if is_dir_empty "$SRC_DIR_ABS"; then
  abort "The source directory has no files, which is unexpected."
fi


# Tool 'readlink' should have removed the trailing slash.
# Note that, for rsync, a trailing will be appended.

if str_ends_with "SRC_DIR_ABS" "/"; then
  abort "The destination directory ends with a slash, which is unexpected after canonicalising it."
fi

case "$BACKUP_METHOD" in
  rsync) rsync_method "$SRC_DIR_ABS/" "$DEST_DIR";;
  rdiff-backup) rdiff_backup_method "$SRC_DIR_ABS" "$DEST_DIR";;
  *) abort "Unknown method \"$BACKUP_METHOD\".";;
esac

echo
echo "Backup mirror updated successfully."
