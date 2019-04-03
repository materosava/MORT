#!/bin/sh
## Purpose: Get active ECOM leg odd or even for TeamCity jobs
## Usage ./extract-odd-or-even.sh <internal_www>
## Parameters passed by TeamCity build
## Initial version optimized to SRV11294 to SYSTEST schema migration
##
## Author Igor Matrosov materosava@materosava.eu Materosava AB


internal_www=$1
OddOrEven=$(curl -s http://$internal_www.hm.com/josh/support/version/all | grep leg | cut -d '>' -f 4 | sed 's/<\/span//')
echo "##teamcity[setParameter name='oddOrEven' value='$OddOrEven']"
