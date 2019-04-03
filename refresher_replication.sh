#!/bin/sh
## Purpose: Set replication position and start replication on slaves or cascade masters
## Usage ./refresher_replication.sh <target_socket> <target_user>
##
## Author Igor Matrosov materosava@materosava.eu Materosava AB



target_socket=$1
target_user=$2
master_bin_file=$3
master_bin_position=$4
slave_command=$5

# Set MySQL connection
CONN="/usr/bin/mysql --socket=$target_socket -u$target_user -e"

echo "refresher_replication.sh: $target_socket, $target_user, $master_bin_file, $master_bin_position, $slave_command"


if [ "${slave_command,,}" = "stop" ]; then
$CONN 'STOP SLAVE;'
Master_Log_File=$($CONN 'SHOW SLAVE STATUS\G' |grep "\sMaster_Log_File: " | awk -F':' '{print $2}'|tr -d ' ')
Read_Master_Log_Pos=$($CONN 'SHOW SLAVE STATUS\G' |grep "Read_Master_Log_Pos: " | awk -F':' '{print $2}'|tr -d ' ')
echo "refresher_replication.sh: Replication stopped at  '$Master_Log_File' '$Read_Master_Log_Pos'"

elif [ "${slave_command,,}" = "start" ]; then

$CONN "CHANGE MASTER TO MASTER_LOG_FILE = '$master_bin_file', MASTER_LOG_POS = $master_bin_position; START SLAVE;"
sleep 5
$CONN "SHOW SLAVE STATUS;"
Slave_Info=$($CONN 'SHOW SLAVE STATUS\G')

echo "$Slave_Info"

elif [ "${slave_command,,}" = "reset_master" ]; then

$CONN "RESET MASTER;"
sleep 5
$CONN "SHOW MASTER STATUS;"
Master_Info=$($CONN 'SHOW MASTER STATUS\G')

echo "$Master_Info"

fi
