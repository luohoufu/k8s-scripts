#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

if grep -q "aliyun"  /etc/yum.repos.d/CentOS-Base.repo ; then
    exit 0
fi

echo "setting aliyun repo and update,please wait......"

mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo > /dev/null 2>&1
yum clean all > /dev/null 2>&1
yum makecache > /dev/null 2>&1
yum -y update > /dev/null 2>&1

echo "......done"
