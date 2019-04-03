#!/bin/sh
## Purpose: Get active RH Cluster Master node
## Usage ./refresher_cluster.sh <cluster_sg> 
## Parameters passed by TeamCity build
## 
## Author Igor Matrosov materosava@materosava.eu Materosava AB


cluster_sg=$1

owner=$(clustat -s $cluster_sg | grep $cluster_sg | awk -F' ' '{print $2}')
echo "$owner"
echo "##teamcity[setParameter name='ServiceOwner' value='$owner']"
