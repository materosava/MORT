#!/bin/sh
## Purpose: update schema refresh verification table 'refresher' on target schema
## Usage ./refresher_verify.sh <schema> <target_host> <target_socket> <target_user> <DB_EXPORT_DATE> <VERIFICATION_TIME>
## Parameters passed by TeamCity build
##
## Author Igor Matrosov materosava@materosava.eu Materosava AB


schema=$1 
target_host=$2
target_socket=$3
target_user=$4
DB_EXPORT_DATE=$5
VERIFICATION_TIME=$6

CONN="/usr/bin/mysql --socket=$target_socket -u $target_user --skip-column_names -e"

tablescount=$($CONN "select count(*) from information_schema.tables where table_schema='$schema';")

if [ "$tablescount" -le 1 ]; then
echo "refresher_verify.sh: ERROR - schema $schema has $tablescount tables, import was not successfull, please examine the logs for the failing steps"
exit 451

else
echo "refresher_verify.sh: SUCCESS - schema $schema has $tablescount tables imported, creating 'refresher' table for the schema import time verification"
$CONN "SET sql_log_bin=0; CREATE TABLE IF NOT EXISTS $schema.refresher (export_time datetime default null, verification_time datetime default null) engine = innodb; INSERT INTO $schema.refresher (export_time, verification_time) values (\"$DB_EXPORT_DATE\",\"$VERIFICATION_TIME\"); SET sql_log_bin=1;"

fi

exit 0
