#!/bin/sh
## Purpose: script stops replication, flushes tables for export with TTS and starts child job to RSYNC and import tablespaces into remote MySQL instance
## Usage ./refresher_main.sh <source_instance> <schema> <source_user> <source_socket> <target_host> <target_socket> <target_user> <ssh_interface> <source_type>
##
##
## Author Igor Matrosov materosava@materosava.eu Materosava AB
source_instance=$1
schema=$2
source_user=$3
source_socket=$4
target_host=$5
target_socket=$6
target_user=$7
ssh_interface=$8
source_type=$9
target_type=${10}

echo "refresher_main.sh: source_instance=$source_instance, schema=$schema, source_user=$source_user, source_socket=$source_socket, target_host=$target_host, target_socket=$target_socket, target_user=$target_user, ssh_interface=$ssh_interface source_type=$source_type target_type=$target_type"

working_dir=$(eval echo ~$source_user)

ssh_key=$(eval echo ~$target_user)/.ssh/id_rsa

echo "refresher_main.sh: Working directory is $working_dir"
echo "refresher_main.sh: SSH identity key $ssh_key"


# Locking to avoid double run
if mkdir /tmp/$source_instance.REFRESHER.LOCK; then
echo "refresher_main.sh: source_instance=$source_instance, schema=$schema, source_user=$source_user, source_socket=$source_socket, target_host=$target_host, target_socket=$target_socket, target_user=$target_user, ssh_interface=$ssh_interface source_type=$source_type target_type=$target_type" > /tmp/$source_instance.REFRESHER.LOCK/lock_details.lock
chown -R $source_user /tmp/$source_instance.REFRESHER.LOCK
echo "refresher_main.sh: Migration of $source_instance is in progress... Monkey business!"
else
  echo "refresher_main.sh: Migration of $schema seems to be in progress... If you are sure it is not - check LOCK directory /tmp/$source_instance.REFRESHER.LOCK exists and remove it"
  exit 3
fi


#Set DB Connection to check replication (column names enabled)
CONN="/usr/bin/mysql -u$source_user --socket=$source_socket $schema -e"

# Verify replication status before running schema migration and stop replication or set master read-only for the migration
# For the slave instance
if [ "$source_type" = "slave" ] || [ "$source_type" = "debug" ]; then
Slave_Info=$($CONN 'SHOW SLAVE STATUS\G')


Last_IO_Errno=$($CONN 'SHOW SLAVE STATUS\G' |grep "Last_IO_Errno: " | awk -F':' '{print $2}'|tr -d ' ')
Last_SQL_Errno=$($CONN 'SHOW SLAVE STATUS\G' |grep "Last_SQL_Errno: " | awk -F':' '{print $2}'|tr -d ' ')


if [ "$Last_IO_Errno" != 0 ] || [ "$Last_SQL_Errno" != 0 ]; then
        echo "SLAVE is not running proper!"
        echo "Last_IO_Errno = $Last_IO_Errno"
        echo "Last_SQL_Errno = $Last_SQL_Errno"
        exit 1
else
$CONN 'STOP SLAVE;'

echo "refresher_main.sh: Get the master binary log position to start replication after refresh:"
master_bin_file=$($CONN 'SHOW SLAVE STATUS\G' |grep "\sMaster_Log_File: " | awk -F':' '{print $2}'|tr -d ' ')
master_bin_position=$($CONN 'SHOW SLAVE STATUS\G' |grep "Read_Master_Log_Pos: " | awk -F':' '{print $2}'|tr -d ' ')
echo "refresher_main.sh: Replication stoped for schema migration at $master_bin_file, $master_bin_position; use this position to setup replication on target instance..."
#Echo below to pass build variables to TeamCity
echo "##teamcity[setParameter name='Master_Log_File' value='$master_bin_file']"
echo "##teamcity[setParameter name='Read_Master_Log_Pos' value='$master_bin_position']"

fi
# For the master instance
elif [ "$source_type" = "master" ]; then

$CONN 'SET GLOBAL read_only=1;'
echo "refresher_main.sh: Get the master binary log position to start replication after refresh:"
master_bin_file=$($CONN 'SHOW MASTER STATUS\G' |grep "File: " | awk -F':' '{print $2}'|tr -d ' ')
master_bin_position=$($CONN 'SHOW MASTER STATUS\G' |grep "Position: " | awk -F':' '{print $2}'|tr -d ' ')
echo "refresher_main.sh: Master set to read-only for schema migration at $master_bin_file, $master_bin_position; use this position to setup replication on target instance..."
#Echo below to pass build variables to TeamCity
echo "##teamcity[setParameter name='Master_Log_File' value='$master_bin_file']"
echo "##teamcity[setParameter name='Read_Master_Log_Pos' value='$master_bin_position']"

fi


# Set DB_EXPORT_DATE for refresher verification
DB_EXPORT_DATE=$(date +"%Y-%m-%d_%H:%M:%S")


#Set DB Connection to get table listing (column names disabled)
CONN="/usr/bin/mysql -u$source_user --socket=$source_socket $schema --skip-column_names -e"

# Get TABLES list to flush for export:

tables=$($CONN "SET SESSION group_concat_max_len = 10240; SELECT GROUP_CONCAT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '$schema';")

# Export schema DDL with mysqldump

epoch=$(date +%s)
create_schema="/tmp/$schema-DDL-$epoch.sql"


echo "refresher_main.sh: Start mysqldump to import schema structure to the target host..."
/usr/bin/mysqldump --socket=$source_socket -u $source_user --no-data $schema | ssh -i $ssh_key -o StrictHostKeyChecking=no $target_user@$target_host "cat > $create_schema"

# Perform "TABLE LOCK FOR EXPORT" and trigger TTS import to target host:

$CONN "use '$schema'; flush tables $tables for export; \! $working_dir/scripts/refresher_copy_tablespace.sh $source_socket $source_user $source_instance $schema $target_host $target_socket $target_user $create_schema $ssh_interface $target_type"

# Trigger import on target host
echo "refresher_main.sh: All tablespaces of $schema schema copied to $target_host target server..."
echo "refresher_main.sh: export complete, all tables unlocked"
echo "refresher_main.sh: Starting import of $schema tablespaces into $target_host MySQL instance..."

#ssh -b $ssh_interface -i $ssh_key/.ssh/id_rsa $target_user@$target_host sudo ./scripts/refresher_import_tablespaces.sh $schema $target_host $target_socket $target_user 
ssh -i $ssh_key -o StrictHostKeyChecking=no $target_user@$target_host sudo ./scripts/refresher_import_tablespaces.sh $schema $target_host $target_socket $target_user 


# Enable replication back or release master for updates
#Set DB Connection to check replication (column names enabled)
CONN="/usr/bin/mysql -u$source_user --socket=$source_socket $schema -e"

if [ "$source_type" = "slave" ] || [ "$source_type" = "debug" ]; then
$CONN 'START SLAVE;'

sleep 10

Slave_Info=$($CONN 'SHOW SLAVE STATUS\G')


Slave_IO_Running=$($CONN "SHOW SLAVE STATUS\G" |grep "Slave_IO_Running: " | awk -F':' '{print $2}'|tr -d ' ')
Slave_SQL_Running=$($CONN "SHOW SLAVE STATUS\G" |grep "Slave_SQL_Running: " | awk -F':' '{print $2}'|tr -d ' ')


if [ "$Slave_IO_Running" != "Yes" ] || [ "$Slave_SQL_Running" != "Yes" ]; then
        echo "refresher_main.sh: WARNING!!!! SLAVE on $source_instance could not start! Please verify replication status of $source_instance"
        echo "Slave_IO_Running = $Slave_IO_Running"
        echo "Slave_SQL_Running = $Slave_SQL_Running"
        
else

echo "refresher_main.sh: Replication of $source_instance started..."
fi
elif [ "$source_type" = "master" ]; then

$CONN 'SET GLOBAL read_only=0;'
echo "refresher_main.sh: Master set writable"
fi

# Set VERIFICATION_TIME for refresher verification and update 'refresher' table on target
VERIFICATION_TIME=$(date +"%Y-%m-%d_%H:%M:%S")

#ssh -b $ssh_interface -i $ssh_key/.ssh/id_rsa $target_user@$target_host sudo ./scripts/refresher_verify.sh $schema $target_host $target_socket $target_user $DB_EXPORT_DATE $VERIFICATION_TIME
if ssh -i $ssh_key -o StrictHostKeyChecking=no $target_user@$target_host sudo ./scripts/refresher_verify.sh $schema $target_host $target_socket $target_user $DB_EXPORT_DATE $VERIFICATION_TIME; then
echo "refresher_main.sh: Success!!!"
rm -rf /tmp/$source_instance.REFRESHER.LOCK
exit 0

else 
echo "refresher_main.sh: Schema verification failed, import is not successful. Examine the logs for the reason, fix and restart MÖRT for the $schema schema..."
rm -rf /tmp/$source_instance.REFRESHER.LOCK
exit 911
fi
