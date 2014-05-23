#!/bin/sh
INNOBACKUPEX=innobackupex-1.5.1
INNOBACKUPEXFULL=/usr/bin/$INNOBACKUPEX
DATADIR=/var/lib/mysql/
TMPFILE="/tmp/innobackupex-restore.$$.tmp"
MYCNF=/etc/my.cnf
BACKUPDIR=/mnt/work/percona/restores # Backups base directory
FULLBACKUPDIR=$BACKUPDIR/full # Full backups directory
DIFFBACKUPDIR=$BACKUPDIR/diff # Differential backups directory
TMPMYSQLBACKUPDIR=/mnt/work/percona/tmpmysqlbackups
MEMORY=6068M # Amount of memory to use when preparing the backup

error()
{
        echo "$1" 1>&2
        exit 1
}

check_innobackupex_error()
{
 if [ -z "`tail -1 $TMPFILE | grep 'completed OK!'`" ] ; then
    echo "$INNOBACKUPEX failed:"; echo
    echo "---------- ERROR OUTPUT from $INNOBACKUPEX ----------"
    cat $TMPFILE
    rm -f $TMPFILE
    exit 1
  fi
}

# Check options before proceeding
if [ ! -x $INNOBACKUPEXFULL ]; then
  error "$INNOBACKUPEXFULL does not exist."
fi

if [ ! -d $BACKUPDIR ]; then
  error "Backup destination folder: $BACKUPDIR does not exist."
fi

if [ $# != 1 ] ; then
  error "Usage: $0 /absolute/path/to/backup/to/restore"
fi

if [ ! -d $1 ]; then
  error "Backup to restore: $1 does not exist."
fi
# Create tmp mysql backup directories if it not exist.
mkdir -p $TMPMYSQLBACKUPDIR

# Some info output
echo "----------------------------"
echo
echo "$0: MySQL backup script"
echo "started: `date`"
echo

PARENT_DIR=`dirname $1`

if [ $PARENT_DIR = $FULLBACKUPDIR ]; then
  FULLBACKUP=$1
  echo "Restore `basename $FULLBACKUP`"
  echo
else
  if [ `dirname $PARENT_DIR` = $DIFFBACKUPDIR ]; then
    DIFF=`basename $1`
    FULL=`basename $PARENT_DIR`
    FULLBACKUP=$FULLBACKUPDIR/$FULL

    if [ ! -d $FULLBACKUP ]; then
      error "Full backup: $FULLBACKUP does not exist."
    fi

    echo "Restore $FULL up to differential $DIFF"
    echo
#    $INNOBACKUPEXFULL --defaults-file=$MYCNF --apply-log --redo-only --use-memory=$MEMORY $FULLBACKUP > $TMPFILE 2>&1
    $INNOBACKUPEXFULL --defaults-file=$MYCNF --apply-log --redo-only $FULLBACKUP > $TMPFILE 2>&1
    check_innobackupex_error

    echo "Applying $DIFF to full ..."
    echo
    $INNOBACKUPEXFULL --defaults-file=$MYCNF --apply-log --redo-only $FULLBACKUP --incremental-dir=$PARENT_DIR/$DIFF > $TMPFILE 2>&1
    check_innobackupex_error

  else
    error "unknown backup type"
  fi
fi

echo "Preparing ..."
#$INNOBACKUPEXFULL --defaults-file=$MYCNF --apply-log --use-memory=$MEMORY $FULLBACKUP > $TMPFILE 2>&1
$INNOBACKUPEXFULL --defaults-file=$MYCNF --apply-log $FULLBACKUP > $TMPFILE 2>&1
check_innobackupex_error

echo
echo "Temporarily moving existing $DATADIR to $TMPMYSQLBACKUPDIR ..."
rm -rf $TMPMYSQLBACKUPDIR/*
mv $DATADIR/* $TMPMYSQLBACKUPDIR/


echo
echo "Restoring ..."
$INNOBACKUPEXFULL --defaults-file=$MYCNF --copy-back $FULLBACKUP > $TMPFILE 2>&1
check_innobackupex_error

rm -f $TMPFILE

echo "Setting files ownership in mysql data $DATADIR."
chown -R mysql:mysql $DATADIR

echo "Backup restored successfully. You are able to start mysql now."
echo
echo "completed: `date`"

