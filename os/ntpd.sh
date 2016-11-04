#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}

# setting ntp config
if [ ! -f /etc/ntp.conf ]; then
    echo "ERROR: You not install ntp service,please install it!"
    exit 1
fi
if grep -q "aliyun" /etc/ntp.conf ; then
    exit 0
fi
echo "setting aliyun ntp server and update,please wait......"
sed -i "s/0.centos.pool.ntp.org/time1.aliyun.com/" /etc/ntp.conf
sed -i "s/1.centos.pool.ntp.org/time2.aliyun.com/" /etc/ntp.conf
sed -i "s/2.centos.pool.ntp.org/time3.aliyun.com/" /etc/ntp.conf
sed -i "s/3.centos.pool.ntp.org/time4.aliyun.com/" /etc/ntp.conf
timedatectl set-timezone Asia/Shanghai
if command_exists ntpd; then
    systemctl start ntpd  > /dev/null 2>&1
    systemctl enable ntpd  > /dev/null 2>&1
    ntpq -p > /dev/null 2>&1
fi
echo "......done"
    
