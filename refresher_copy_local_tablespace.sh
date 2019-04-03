#!/bin/sh
## Purpose: RSYNC and import Tablespaces from source schema to target
## Usage ./copy_tablespace.sh <source_schema> <target_schema> <source_port> <target_host> <target_port> <target_user>
## Parameters passed by TeamCity build
## Initial version optimized to SYSTEST schema migration
##
## Author Igor Matrosov materosava@materosava.eu Materosava AB

source_schema=$1
target_schema=$2
socket=$3
user=$4
schemadir=$5
create_schema=$6

echo "tables locked for export, export in progress..."
echo "Export of $source_schema DB to $target_schema using $user account... Monkey business!"


CONN="/usr/local/bin/mysql --socket=$socket -u$user --skip-column_names -e"

# Recreate schema and discard tablespaces
$CONN "drop database if exists $target_schema; create schema $target_schema; use $target_schema; source $create_schema;"


TABLES=$($CONN "select distinct table_name from information_schema.tables where table_schema='$target_schema';")

for t in $TABLES
do
echo "Discarding $t tablespace from $schema database for import..."
$CONN "SET FOREIGN_KEY_CHECKS=0; ALTER TABLE $target_schema.$t DISCARD TABLESPACE;"
done


rsync -a -P $schemadir/$source_schema/*.{ibd,cfg} $schemadir/$target_schema/
#scp -c arcfour /mysql/data/schemadata/$schema/*.{ibd,cfg} root@$target_host:/mysql/data/schemadata/$schema/
#chown mysql:mysql /mysql/data/schemadata/$target_schema/*
echo "All tablespaces of $source_schema schema copied to $target_schema ..."
echo "Starting import of $source_schema tablespaces into $target_schema..."
for t in $TABLES
do
echo "Importing $t tablespace to $target_schema database ..."
$CONN "ALTER TABLE $target_schema.$t IMPORT TABLESPACE;"
done

rm -f $schemadir/$target_schema/*.cfg

for t in $TABLES
do
echo "Analyzing $t tablespace in $target_schema database ..."
$CONN "ANALYZE TABLE $target_schema.$t;"
done

