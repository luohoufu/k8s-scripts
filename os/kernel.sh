#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

if [ $(uname -r |cut -c1) -eq 4 ]; then
    exit 0
fi
echo "setting upgrade linux kernel,please wait......"
if [ ! -f $basepath/RPM-GPG-KEY-elrepo.org ] ; then
    wget --no-check-certificate https://www.elrepo.org/RPM-GPG-KEY-elrepo.org > /dev/null 2>&1
fi
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm > /dev/null 2>&1
yum --enablerepo=elrepo-kernel -y install kernel-ml-devel kernel-ml > /dev/null 2>&1
grub2-set-default 0
rm -rf $basepath/RPM-GPG-KEY-elrepo.org
echo "......done"