#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

if ip a |grep -q "eth0" ; then
    exit 0
fi

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
host_name=`hostname`
node_ip=`jq -r ".k8s.nodes[]| select(.ip == \"$host_name\")|.name" $json`

echo "setting iface,please wait......"

iface=`ip a |grep $node_ip|awk '{print $NF}'`
mac=`nmcli device show $iface| grep 'HWADDR'|awk '{print $2}'`

face=/etc/sysconfig/network-scripts/ifcfg-eth0
rule=/etc/udev/rules.d/70-persistent-net.rules

if [ -f /etc/sysconfig/network-scripts/ifcfg-$iface ]; then
    mv /etc/sysconfig/network-scripts/ifcfg-$iface $face
fi

if [ -f $face ]; then
    if ! grep -wq "eth0" $face ; then
        sed -i "s/$iface/eth0/g" $face
    fi
fi

if ! grep -wq 'net' /etc/default/grub ; then
    sed -i 's/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0 ipv6.disable=1 selinux=0 /' /etc/default/grub
fi

if [ ! -f $rule ]; then
    echo 'SUBSYSTEM=="net",ACTION=="add",DRIVERS=="?*",ATTR{address}=="$mac",ATTR{type}=="1" ,KERNEL=="eth*",NAME="eth0"' > $rule

    sed -i "s%\$mac%"$mac"%g" $rule
    grub2-mkconfig -o /boot/grub2/grub.cfg > /dev/null 2>&1
    grub2-set-default 0
fi

echo "......done"
