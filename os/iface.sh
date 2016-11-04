#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

if ip a |grep -q "eth0" ; then
    exit 0
fi

export PATH=$PATH:$basepath/tools

k8s_node_names=`cat $basepath/config.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`
k8s_node_ips=`cat $basepath/config.json |jq '.k8s.nodes[].ip'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))
arr_k8s_node_ips=($(echo $k8s_node_ips))

echo "setting iface,please wait......"
for ((i=0;i<${#arr_k8s_node_ips[@]};i++));do
    if ip a |grep -q ${arr_k8s_node_ips[$i]}; then
        iface=`ip a |grep ${arr_k8s_node_ips[$i]}|awk '{print $NF}'`
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
    fi
done
echo "......done"
