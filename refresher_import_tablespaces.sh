#!/bin/sh
## Purpose: Import Tablespaces copied from source schema to target
## Usage ./refresher_import_tablespaces.sh <source_instance> <schema> <source_user> <source_socket> <target_host> <target_socket> <target_user>
## Parameters passed by TeamCity build
##
## Author Igor Matrosov materosava@materosava.eu Materosava AB


schema=$1
target_host=$2
target_socket=$3
target_user=$4


echo "refresher_import_tablespaces.sh: Import of $schema tablespaces into $target_host in progress..."
# Get instance data directory
target_dir=$(/usr/bin/mysql -u$target_user --socket=$target_socket $schema --skip-column_names -e 'select @@datadir;')

# Set MySQL connection
CONN="/usr/bin/mysql --socket=$target_socket -u$target_user --skip-column_names -e"

# Import new tablespaces
TABLES=$($CONN"select distinct table_name from information_schema.tables where table_schema='$schema';")


for t in $TABLES
do
echo "refresher_import_tablespaces.sh: Importing $t tablespace to $schema database ..."
$CONN "SET SQL_LOG_BIN=0; SET FOREIGN_KEY_CHECKS=0; ALTER TABLE $schema.$t IMPORT TABLESPACE;"
done

rm -f $target_dir/$schema/*.cfg

for t in $TABLES
do
echo "refresher_import_tablespaces.sh: Analyzing $t tablespace in $schema database ..."
$CONN "ANALYZE TABLE $schema.$t;"
done
echo "refresher_import_tablespaces.sh: Import of $schema complete!"



