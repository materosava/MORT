#!/bin/sh
## Purpose: script stops replication, flushes tables for export with TTS and starts child job to RSYNC and import tablespaces into remote MySQL instance
## Usage ./refresher_schema_only.sh <source_instance> <schema> <source_user> <source_socket> <target_host> <target_socket> <target_user> <ssh_interface> <source_type>
##
## Initial version optimized to SRV11294 to SYSTEST schema migration
##
## Author Igor "I-pop" Matrosov igor.matrosov@hm.com

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

echo "refresher_schema_only.sh: source_instance=$source_instance, schema=$schema, source_user=$source_user, source_socket=$source_socket, target_host=$target_host, target_socket=$target_socket, target_user=$target_user, ssh_interface=$ssh_interface source_type=$source_type target_type=$target_type"

working_dir=$(eval echo ~$source_user)

ssh_key=$(eval echo ~$target_user)/.ssh/id_rsa

echo "refresher_schema_only.sh: Working directory is $working_dir"
echo "refresher_schema_only.sh: SSH identity key $ssh_key"

# Active leg for HMCOM Database detection performed by "Extract odd or even" TeamCity build step
# For manual execution detect active HMCOM DB leg in "http://tellus-internal-www/josh/support/version/all" service page


# Set DB_EXPORT_DATE for refresher verification
DB_EXPORT_DATE=$(date +"%Y-%m-%d_%H:%M:%S")


#Set DB Connection to get table listing (column names disabled)
CONN="/usr/bin/mysql -u$source_user --socket=$source_socket $schema --skip-column_names -e"

# Get TABLES list to flush for export:

tables=$($CONN "SET SESSION group_concat_max_len = 10240; SELECT GROUP_CONCAT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '$schema';")

# Export schema DDL with mysqldump

epoch=$(date +%s)
create_schema="/tmp/$schema-DDL-$epoch.sql"


echo "refresher_schema_only.sh: Start mysqldump to import schema structure to the target host..."
/usr/bin/mysqldump --socket=$source_socket -u $source_user --no-data $schema | ssh -i $ssh_key -o StrictHostKeyChecking=no $target_user@$target_host "cat > $create_schema"

# Import schema to target

if ssh -i $ssh_key -o StrictHostKeyChecking=no $target_user@$target_host sudo $working_dir/scripts/refresher_recreate_schema_empty.sh $schema $target_host $target_socket $target_user $create_schema; then
echo "refresher_schema_only.sh: Schema $schema successfully recreated, start verification..."
else 
echo "refresher_schema_only.sh: Schema $schema  recreation failed, please verify MySQL instance health at $target_host ..."

exit 451
fi


# Set VERIFICATION_TIME for refresher verification and update 'refresher' table on target
VERIFICATION_TIME=$(date +"%Y-%m-%d_%H:%M:%S")

#ssh -b $ssh_interface -i $ssh_key/.ssh/id_rsa $target_user@$target_host sudo ./scripts/refresher_verify.sh $schema $target_host $target_socket $target_user $DB_EXPORT_DATE $VERIFICATION_TIME
if ssh -i $ssh_key -o StrictHostKeyChecking=no $target_user@$target_host sudo ./scripts/refresher_verify.sh $schema $target_host $target_socket $target_user $DB_EXPORT_DATE $VERIFICATION_TIME; then
echo "refresher_schema_only.sh: Success!!!"

exit 0

else 
echo "refresher_schema_only.sh: Schema verification failed, import is not successful. Examine the logs for the reason, fix and restart MÖRT for the $schema schema..."

exit 911
fi
