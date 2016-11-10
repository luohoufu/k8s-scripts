#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

if grep -q "=disabled" /etc/selinux/config ; then
    exit 0
fi

echo "setting selinux to disabled,please wait......"
sed -i "s/=enforcing/=disabled/g" /etc/selinux/config
setenforce 0
echo "......done"
