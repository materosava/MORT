#!/bin/sh
## Purpose: Heartbeat of MySQL instance health for TC Build Radiator
## Usage ./refresher_heartbeat.sh <socket> <user> <schema> <replacation>
## Parameters passed by TeamCity "Template healthcheck" project http://teamcity.hm.com/project.html?projectId=HmComDatabaseMaintenance_TemplateHealthcheck
##
## Author Igor Matrosov materosava@materosava.eu Materosava AB
socket=$1
mysql_user=$2
schema=$3
replication=$4

CONN="mysql -u$mysql_user --socket=$socket $schema --skip-column_names -e"
select1=$($CONN "select 1;")

echo "$select1"		
if [ -z "$select1" ]; then
  echo "MySQL instance is not running on $socket!!!"
  exit 66
fi
echo "Select 1 returns $select1 - instance Running OK"

CONN="mysql -u$mysql_user --socket=$socket $schema -e"

# If socket param contains odd or even 
# then it is ECOM
# then we should check that
#/mysql_odd/datadir/mysql_odd.sock
#/mysql_even/datadir/mysql_even.sock
Master_Port=$($CONN 'SHOW SLAVE STATUS\G' |grep "Master_Port: " | awk -F':' '{print $2}'|tr -d ' ')

if [ $socket == "/mysql_odd/datadir/mysql_odd.sock" ]; then
  if [ $Master_Port != "3307" ]; then
    echo "Master Port for HMCOM ODD is wrong: $Master_Port"
    exit 153 
  fi
elif [ $socket == "/mysql_even/datadir/mysql_even.sock" ]; then
  if [ $Master_Port != "3308" ]; then
    echo "Master Port for HMCOM EVEN is wrong: $Master_Port"
    exit 152
  fi
fi

if [ "$replication" == "slave" ]; then
        
        Slave_Info=$($CONN 'SHOW SLAVE STATUS\G')


        Slave_IO_Running=$($CONN 'SHOW SLAVE STATUS\G' |grep "Slave_IO_Running: " | awk -F':' '{print $2}'|tr -d ' ')
        Slave_SQL_Running=$($CONN 'SHOW SLAVE STATUS\G' |grep "Slave_SQL_Running: " | awk -F':' '{print $2}'|tr -d ' ')
        Seconds_Behind_Master=$($CONN 'SHOW SLAVE STATUS\G' |grep "Seconds_Behind_Master: " | awk -F':' '{print $2}'|tr -d ' ')

        if [ "$Slave_IO_Running" != "Yes" ] || [ "$Slave_SQL_Running" != "Yes" ]; then
                echo "SLAVE is not running proper!"
                echo "Slave_IO_Running = $Slave_IO_Running"
                echo "Slave_SQL_Running = $Slave_SQL_Running"
                exit 77
        fi
		echo "Schema $schema replication is running"
		echo "Replication lag is $Seconds_Behind_Master seconds"
fi

echo "Instance seems to be OK, success!!!"
exit 0
