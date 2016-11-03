#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools

hostname=`cat $basepath/config.json |jq '.master'`
hostip=`cat $basepath/config.json |jq '.masterip'`

echo "NOTE: $0 will read config from config.json"
echo
echo "This script will change hostname: "
echo "    $0 ${ARGHELP}"
echo
echo "Do You Want Setting Now? [Y]/n"
read confirm
if [[ ! "${confirm}" =~ ^[nN]$ ]]; then
    echo "setting hostname,please wait......"
    hostnamectl set-hostname $hostname
    if [[ ! ${grep -wq "$hostname" /etc/hosts} ]]; then
        echo "$hostip    $hostname" >> /etc/hosts
    fi
    echo "......done"
fi