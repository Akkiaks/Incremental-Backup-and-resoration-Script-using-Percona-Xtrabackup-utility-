Incremental-Backup-and-resoration-Script-using-Percona-Xtrabackup-utility-
==========================================================================

To take Mysql Database incremental Backup using Percona Xtrabackup utility


If you are planning to take your Mysql Database backup then you are in correct direcory 

1. you have percona-xtrabackup.x86_64             2.0.1-446.rhel5              installed

2. Shecdule your backup script in crontab hourly it will take full backup at every  day and incremental after every hour .

3 * * * * /mnt/backups/Incremental_backup_Script.sh > /mnt/backups/percona_output_$(date +\%d_\%H:\%M).txt 2>&1
