#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

if [ $(uname -r |cut -c1) -lt 4 ]; then
    echo "setting upgrade linux kernel,please wait......"
    if [ ! -f $basepath/RPM-GPG-KEY-elrepo.org ] ; then
        wget --no-check-certificate https://www.elrepo.org/RPM-GPG-KEY-elrepo.org > /dev/null 2>&1
    fi
    rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
    yum --enablerepo=elrepo-kernel install kernel-ml-devel kernel-ml -y > /dev/null 2>&1
    grub2-set-default 0
    rm -rf $basepath/RPM-GPG-KEY-elrepo.org
    echo "......done"
fi