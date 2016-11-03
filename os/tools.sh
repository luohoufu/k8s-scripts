#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}

for cmd in vim git wget strace telnet traceroute iptables expect; do
    if ! command_exists ${cmd}; then
        yum -y install $cmd
    fi
done

