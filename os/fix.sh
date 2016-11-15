#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

# setting core fix
if grep -wq "ip6tables" /etc/sysctl.conf ; then
    exit 0
fi
echo "setting ip6 bridge,please wait......"
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-arptables = 1" >> /etc/sysctl.conf
echo "......done"

if grep -wq "655350" /etc/security/limits.conf ; then
echo "* soft nofile 655350" >> /etc/security/limits.conf
echo "* hard nofile 655350" >> /etc/security/limits.conf
echo "* soft nproc 655350" >> /etc/security/limits.conf
echo "* hard nproc 655350" >> /etc/security/limits.conf
fi