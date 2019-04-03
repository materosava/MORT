#!/bin/sh
## Purpose: RSYNC and import Tablespaces from source schema to target
## Usage ./refresher_copy_tablespace.sh <source_instance> <schema> <target_host> <target_socket> <target_user> <create_schema>
## Parameters passed by TeamCity build
##
## Author Igor Matrosov materosava@materosava.eu Materosava AB

source_socket=$1 
source_user=$2
source_instance=$3
schema=$4
target_host=$5
target_socket=$6
target_user=$7
create_schema=$8
ssh_interface=$9
target_type=${10}

working_dir=$(eval echo ~$target_user)
ssh_key=$(eval echo ~$target_user)/.ssh/id_rsa
source_dir=$(/usr/bin/mysql -u$source_user --socket=$source_socket $schema --skip-column_names -e 'select @@datadir;')
target_dir=$(ssh -i $ssh_key -o StrictHostKeyChecking=no $target_user@$target_host "/usr/bin/mysql -u$target_user --socket=$target_socket $schema --skip-column_names -e 'select @@datadir;'")

# Prepare target to copy tablespaces of schema 

if ssh -i $ssh_key -o StrictHostKeyChecking=no $target_user@$target_host sudo $working_dir/scripts/refresher_recreate_schema.sh $schema $target_host $target_socket $target_user $create_schema; then
echo "refresher_copy_tablespace.sh: Schema $schema successfully recreated, starting tablespaces synchronization..."
else 
echo "refresher_copy_tablespace.sh: Schema $schema  recreation failed, please verify MySQL instance health at $target_host ..."
rm -rf /tmp/$source_instance.REFRESHER.LOCK
exit 451
fi

# RSYNC tablespaces to target server as root
#rsync -a -P /mysql_$source_instance/datadir/schemadata/$schema/*.{ibd,cfg} $target_user@$target_host:/mysql/data/schemadata/$schema/
# method to rsync by non-root user, visudo to add line "rsyncuser ALL= NOPASSWD:/usr/bin/rsync"

if [ "$target_type" = "cluster" ]; then

echo "refresher_copy_tablespace.sh: Start RSYNC of tablespaces with bandwidth limit of 50MB/sec to protect bloody RedHat cluster from fencing with a command:"
echo "refresher_copy_tablespace.sh: rsync --bwlimit=50000 -a -P -e "ssh -i $ssh_key" --rsync-path="sudo rsync" $source_dir/$schema/*.{ibd,cfg} $target_user@$target_host:$target_dir/$schema/"
rsync --bwlimit=50000 -a -P -e "ssh -i $ssh_key" --rsync-path="sudo rsync" $source_dir/$schema/*.{ibd,cfg} $target_user@$target_host:$target_dir/$schema/

else

echo "refresher_copy_tablespace.sh: Start RSYNC of tablespaces at full speed available with the command:"
echo "refresher_copy_tablespace.sh: rsync -a -P -e "ssh -i $ssh_key" --rsync-path="sudo rsync" $source_dir/$schema/*.{ibd,cfg} $target_user@$target_host:$target_dir/$schema/"
echo "refresher_copy_tablespace.sh: If target is a bloody RedHat cluster it will most likely fence and die - check paramter target_type set to <cluster>"
rsync -a -P -e "ssh -i $ssh_key" --rsync-path="sudo rsync" $source_dir/$schema/*.{ibd,cfg} $target_user@$target_host:$target_dir/$schema/
fi

echo "refresher_copy_tablespace.sh: RSYNC of $schema tablespaces complete!"