#!/bin/sh

node=$1
username=$2

ssh -i /home/$username/.ssh/id_rsa -o StrictHostKeyChecking=no -tt $username@$node
