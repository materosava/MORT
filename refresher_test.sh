#!/bin/sh
## Purpose: RSYNC and import Tablespaces from source schema to target
## Usage ./refresher_test.sh <target_user> <target_socket> <target_schema> <target_replication>
## Parameters passed by TeamCity build
##
## Author Igor Matrosov materosava@materosava.eu Materosava AB

target_user=$1
target_socket=$2
target_schema=$3
target_replication=$4



ps -ef | grep mysql
#Set DB Connection to check replication (column names enabled)
CONN="/usr/bin/mysql -u$target_user --socket=$target_socket $target_schema -e"
#CONN="/usr/bin/mysql -u$target_user --socket=$target_socket -e"


$CONN 'SHOW DATABASES;'

if [ "$target_replication" = "master" ]; then

$CONN 'SHOW MASTER STATUS; SHOW PROCESSLIST;'

elif [ "$target_replication" = "slave" ]; then

$CONN 'SHOW SLAVE STATUS\G SHOW PROCESSLIST; \! pwd'

fi
working_dir=$(eval echo ~$target_user)
echo "$working_dir"
pwd
echo "$HOME"
df -h
which mysql

#Remove locks left after failed bilds

##rm -rf /tmp/*.REFRESHER.LOCK/

#Kill zomby refresher
##kill -9 $(ps aux | grep 'refresher_' | awk '{print $2}')

