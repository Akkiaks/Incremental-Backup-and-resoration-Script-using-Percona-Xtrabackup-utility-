#!/bin/bash

INNOBACKUPEX=innobackupex-1.5.1
INNOBACKUPEXFULL=/usr/bin/$INNOBACKUPEX
USEROPTIONS="--user=root "
USERPASSWD="--password=akki"
CUSTOMPARAMS="--slave-info --safe-slave-backup"
TMPFILE="/tmp/innobackupex-runner.$$.tmp"
MYCNF=/etc/my.cnf
MYSQL=/usr/bin/mysql
MYSQLADMIN=/usr/bin/mysqladmin
LOGSDIR=/mnt/log/percona/backup # Backups base directory
BACKUPDIR=/mnt/percona/backups # Backups base directory
S3BACKUPS=/mnt/percona/s3backups # Compressed S3 Backups base
S3BUCKET="s3://mysqldiff_backup"
S3BUCKETBACKUPPATH=$S3BUCKET
FULLBACKUPDIR=$BACKUPDIR/full # Full backups directory
DIFFBACKUPDIR=$BACKUPDIR/diff # Differential backups directory
FULLBACKUPLIFE=82800 # 23 Hours.Lifetime of the latest full backup in seconds
KEEP=1 # Number of full backups (and its differentials) to keep
MEMORY=2048M
# Grab start time
STARTED_AT=`date +%s`
S3DELDATE=$(date --date='10 days ago' +%Y-%m-%d)
S3DELBUCKET="mysqldiff_backup"

#create required directories for the script
#rm -rf $S3BACKUPS/*
mkdir -p $LOGSDIR
mkdir -p $BACKUPDIR
mkdir -p $S3BACKUPS

# Display error message and exit
error()
{
        echo "$1" 1>&2
        exit 1
}

# Check options before proceeding
if [ ! -x $INNOBACKUPEXFULL ]; then
        error "$INNOBACKUPEXFULL does not exist."
fi

if [ ! -d $BACKUPDIR ]; then
        error "Backup destination folder: $BACKUPDIR does not exist."
fi

if [ -z "`$MYSQLADMIN $USEROPTIONS $USERPASSWD  status | grep 'Uptime'`" ] ; then
        error "HALTED: MySQL does not appear to be running."
fi

if ! `echo 'exit' | $MYSQL -s $USEROPTIONS $USERPASSWD` ; then
        error "HALTED: Supplied mysql username or password appears to be incorrect."
fi

# Some info output
echo "----------------------------"
echo
echo "$0: MySQL backup script"
echo "started: `date`"
echo


# Create full and incr backup directories if they not exist.
mkdir -p $FULLBACKUPDIR
mkdir -p $DIFFBACKUPDIR

# Find latest full backup
LATEST_FULL=`find $FULLBACKUPDIR -mindepth 1 -maxdepth 1 -type d -printf "%P\n" | sort -nr | head -1`
# Get latest backup last modification time
LATEST_FULL_CREATED_AT=`stat -c %Y $FULLBACKUPDIR/$LATEST_FULL`

# Run an differential backup if latest full is still valid. Otherwise, run a new full one.
if [ "$LATEST_FULL" -a `expr $LATEST_FULL_CREATED_AT + $FULLBACKUPLIFE + 5` -ge $STARTED_AT ] ; then
        # Create incremental backups dir if not exists.
        TMPDIFFDIR=$DIFFBACKUPDIR/$LATEST_FULL
        mkdir -p $TMPDIFFDIR
        DIFFBASEDIR=$FULLBACKUPDIR/$LATEST_FULL
        echo "Running new differential backup using $DIFFBASEDIR as base."
        $INNOBACKUPEXFULL --defaults-file=$MYCNF $USEROPTIONS  $USERPASSWD --use-memory=$MEMORY --incremental $CUSTOMPARAMS $TMPDIFFDIR --incremental-basedir $DIFFBASEDIR > $TMPFILE 2>&1
        BACKUPTYPE='diff'
        mkdir -p $S3BACKUPS/$LATEST_FULL
else
        echo "Running new full backup."
        $INNOBACKUPEXFULL --defaults-file=$MYCNF $USEROPTIONS $USERPASSWD $CUSTOMPARAMS $FULLBACKUPDIR > $TMPFILE 2>&1
        BACKUPTYPE='full'
fi

if [ -z "`tail -1 $TMPFILE | grep 'completed OK!'`" ] ; then
        echo "$INNOBACKUPEX failed:"; echo
        echo "---------- ERROR OUTPUT from $INNOBACKUPEX ----------"
        cat $TMPFILE
        mv $TMPFILE $LOGSDIR/$BACKUPTYPE-$STARTED_AT"-detail".log
        exit 1
fi

THISBACKUP=`awk -- "/Backup created in directory/ { split( \\\$0, p, \"'\" ) ; print p[2] }" $TMPFILE`
if [ "$BACKUPTYPE" == "full" ] ; then
LATEST_FULL=`basename $THISBACKUP`
mkdir -p $S3BACKUPS/$LATEST_FULL
fi

tar -zcf $S3BACKUPS/$LATEST_FULL/$BACKUPTYPE-`basename $THISBACKUP`.tar.gz $THISBACKUP
md5sum $S3BACKUPS/$LATEST_FULL/$BACKUPTYPE-`basename $THISBACKUP`.tar.gz > $S3BACKUPS/$LATEST_FULL/$BACKUPTYPE-`basename $THISBACKUP`.tar.gz.md5.txt
LOGNAME=`date -u --date="1970-01-01 $STARTED_AT sec" +"%m-%d-%Y_%H-%M-%S"`
mv $TMPFILE $LOGSDIR/$BACKUPTYPE-$LOGNAME"-detail".log

echo "Databases backed up successfully to: $THISBACKUP"
echo "S3 backup created at: $S3BACKUPS/$LATEST_FULL/$BACKUPTYPE-`basename $THISBACKUP`.tar.gz"
echo "Logs at $LOGSDIR/$BACKUPTYPE-$LOGNAME-detail.log"
echo
echo "Moving Backup and md5 to S3"
echo "s3cmd sync $S3BACKUPS/$LATEST_FULL/ $S3BUCKETBACKUPPATH/$LATEST_FULL/"
s3cmd sync $S3BACKUPS/$LATEST_FULL/ $S3BUCKETBACKUPPATH/$LATEST_FULL/

# Cleanup
echo "Cleanup. Keeping only $KEEP full backups and its differentials."
AGE=$(($FULLBACKUPLIFE * $KEEP / 60))
find $FULLBACKUPDIR -maxdepth 1 -type d -mmin +$AGE -execdir echo "removing: "$FULLBACKUPDIR/{} \; -execdir rm -rf $FULLBACKUPDIR/{} \; -execdir echo "removing: "$DIFFBACKUPDIR/{} \; -execdir rm -rf $DIFFBACKUPDIR/{} \;
find $S3BACKUPS -maxdepth 1 -type d -mmin +$AGE -execdir echo "removing: "$S3BACKUPS/{} \; -execdir rm -rf $S3BACKUPS/{} \;
s3cmd ls s3://$S3DELBUCKET/ | grep s3 | sed "s/.*s3:\/\/$S3DELBUCKET\//s3:\/\/$S3DELBUCKET\//" | grep $S3DELDATE | xargs s3cmd --recursive del

echo
echo "completed: `date`"
