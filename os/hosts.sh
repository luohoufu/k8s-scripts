#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}

if [[ ! "${confirm}" =~ ^[nN]$ ]]; then
    echo "setting hostname,please wait......"
    hostnamectl set-hostname $hostname
    if [[ ! ${grep -wq "$hostname" /etc/hosts} ]]; then
        echo "$hostip    $hostname" >> /etc/hosts
    fi
    echo "......done"
fi