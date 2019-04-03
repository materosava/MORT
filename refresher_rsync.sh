#!/bin/sh
## Purpose: Grant user privilege to sudo RSYNC for tablespace copy
## Usage ./refresher_rsync.sh <target_user>
## Parameters passed by TeamCity build
##
## Author Igor Matrosov materosava@materosava.eu Materosava AB

username=$1
grep -qF "$username ALL= NOPASSWD:/usr/bin/rsync" /etc/sudoers || echo "$username ALL= NOPASSWD:/usr/bin/rsync" | tee --append /etc/sudoers

cat /etc/sudoers | grep "$username"