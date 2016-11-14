#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
host_ip=$(ip a | grep -Po '(?<=inet ).*(?=\/)'|awk '{if($1!~/^10.0|^192|^172|^127|^0/) print $1}')
host_name=`jq -r ".k8s.nodes[]| select(.ip == \"$host_ip\")|.name" $json`

if grep -wq "$host_name"  /etc/hostname ; then
    exit 0
fi
echo "setting hostname,please wait......"
hostnamectl set-hostname $host_name
echo "......done"