#!/bin/sh
## Purpose: RSYNC and import Tablespaces from source schema to target
## Usage ./refresher_recreate_schema.sh <schema> <target_host> <target_socket> <target_user> <create_schema>
## Parameters passed by TeamCity build
##
## Author Igor Matrosov materosava@materosava.eu Materosava AB
schema=$1
target_host=$2
target_socket=$3
target_user=$4
create_schema=$5

echo "refresher_recreate_schema.sh: schema=$schema, target_host=$target_host, target_socket=$target_socket, target_user=$target_user, create_schema=$create_schema" 
echo "refresher_recreate_schema.sh: Export of $schema DB to $target_host on $target_socket using $target_user account..." 
echo "refresher_recreate_schema.sh: Recreating schema and discarding tablespaces for import..."

# Set Connection

CONN="/usr/bin/mysql --socket=$target_socket -u$target_user --skip-column_names -e" 

# Recreate schema

# Forsibly drop schemadir to avoid "ERROR 1010 (HY000) at line 1: Error dropping database (can't rmdir... "
#datadir=$($CONN "select @@datadir;")
#rm -rf $datadir$schema


if $($CONN "SET SQL_LOG_BIN=0; DROP DATABASE IF EXISTS $schema; CREATE SCHEMA $schema; USE $schema; SOURCE $create_schema;"); then

# Discard tablespaces
TABLES=$($CONN"SELECT DISTINCT TABLE_NAME FROM information_schema.tables WHERE table_schema='$schema';")

for t in $TABLES
do
echo "refresher_recreate_schema.sh: Discarding $t tablespace from $schema database for import..."
$CONN "STOP SLAVE; SET SQL_LOG_BIN=0; set FOREIGN_KEY_CHECKS=0; ALTER TABLE $schema.$t DISCARD TABLESPACE;"
done
echo "refresher_recreate_schema.sh: Schema recreated, tablespaces discarded, ready to import data..."

else 
# Forsibly drop schemadir to avoid "ERROR 1010 (HY000) at line 1: Error dropping database (can't rmdir... "
echo "refresher_recreate_schema.sh: Schema $schema  recreation failed, trying to remove schema dir and recreate schema ..."
datadir=$($CONN "select @@datadir;")
rm -rf $datadir$schema
if $($CONN "SET SQL_LOG_BIN=0; CREATE SCHEMA $schema; USE $schema; SOURCE $create_schema;"); then

	echo "refresher_recreate_schema.sh: SCHEMA $schema FORCIBLY RECREATED, PLEASE IGNORE ==ERROR 1010 (HY000) at line 1:== MESSAGE, BUT CHECK LAST VERIFCATION STATUS"
	# Discard tablespaces
	TABLES=$($CONN"SELECT DISTINCT TABLE_NAME FROM information_schema.tables WHERE table_schema='$schema';")
	for t in $TABLES
	do
	echo "refresher_recreate_schema.sh: Discarding $t tablespace from $schema database for import..."
	$CONN "STOP SLAVE; SET SQL_LOG_BIN=0; set FOREIGN_KEY_CHECKS=0; ALTER TABLE $schema.$t DISCARD TABLESPACE;"
	done
	echo "refresher_recreate_schema.sh: Schema recreated, tablespaces discarded, ready to import data..."
else
echo "$?"
echo "refresher_recreate_schema.sh: Schema $schema  recreation failed, please verify MySQL instance health at $target_host ..."
rm -rf /tmp/$source_instance.REFRESHER.LOCK
exit 451
fi
fi
