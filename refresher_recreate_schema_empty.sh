#!/bin/sh
## Purpose: RSYNC and import Tablespaces from source schema to target
## Usage ./refresher_recreate_schema_empty.sh <schema> <target_host> <target_socket> <target_user> <create_schema>
## Parameters passed by TeamCity build
## Initial version optimized to SRV11294 to SYSTEST schema migration
##
## Author Igor "I-pop" Matrosov igor.matrosov@hm.com 

schema=$1
target_host=$2
target_socket=$3
target_user=$4
create_schema=$5

echo "refresher_recreate_schema_empty.sh: schema=$schema, target_host=$target_host, target_socket=$target_socket, target_user=$target_user, create_schema=$create_schema" 
echo "refresher_recreate_schema_empty.sh: Export of $schema DB to $target_host on $target_socket using $target_user account..." 


# Set Connection

CONN="/usr/bin/mysql --socket=$target_socket -u$target_user --skip-column_names -e" 

# Recreate schema

# Forsibly drop schemadir to avoid "ERROR 1010 (HY000) at line 1: Error dropping database (can't rmdir... "
#datadir=$($CONN "select @@datadir;")
#rm -rf $datadir$schema


if $($CONN "SET SQL_LOG_BIN=0; DROP DATABASE IF EXISTS $schema; CREATE SCHEMA $schema; USE $schema; SOURCE $create_schema;"); then

echo "refresher_recreate_schema_empty.sh: Schema recreated start verification..."

else 
# Forsibly drop schemadir to avoid "ERROR 1010 (HY000) at line 1: Error dropping database (can't rmdir... "
echo "refresher_recreate_schema_empty.sh: Schema $schema  recreation failed, trying to remove schema dir and recreate schema ..."
datadir=$($CONN "select @@datadir;")
rm -rf $datadir$schema
if $($CONN "SET SQL_LOG_BIN=0; CREATE SCHEMA $schema; USE $schema; SOURCE $create_schema;"); then

	echo "refresher_recreate_schema_empty.sh: SCHEMA $schema FORCIBLY RECREATED, PLEASE IGNORE ==ERROR 1010 (HY000) at line 1:== MESSAGE, BUT CHECK LAST VERIFCATION STATUS"
	
	echo "refresher_recreate_schema_empty.sh: Schema recreated start verification..."
else
echo "$?"
echo "refresher_recreate_schema_empty.sh: Schema $schema  recreation failed, please verify MySQL instance health at $target_host ..."

exit 451
fi
fi
