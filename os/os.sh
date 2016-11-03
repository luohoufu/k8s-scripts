#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

#get summary info
w
date
hostname
hostname -i
uname -r
cat /etc/hosts
ip a show eth0
ifconfig eth0
ps -ef|grep iptables
ps -ef|grep firewalld
uname -a
uname -r
sestatus -v

