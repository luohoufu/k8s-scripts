#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}

if command_exists expect ; then
    exit 0
fi

echo "install system utils tools,please wait......"
for cmd in vim git wget strace telnet traceroute iptables expect; do
    if ! command_exists ${cmd}; then
        yum -y install $cmd > /dev/null 2>&1
    fi
done
echo "......done"
