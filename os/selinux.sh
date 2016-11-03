#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}


if ! grep -wq "=disabled" /etc/selinux/config ; then
    sed -i "s/=enforcing/=disabled/g" /etc/selinux/config
    setenforce 0
fi
