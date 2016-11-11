#!/usr/bin/env bash
 # -*- bash -*-

set -e -o pipefail -o errtrace -o functrace
# runtime env
basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}
# check run user
if [[ ! `id -u` -eq 0 ]]; then
    echo "Please run this shell by root user!"
    exit 1;
fi

# update trust cat
update-ca-trust force-enable
update-ca-trust extract

# add execute permission
 for f in $basepath/tools/*;do
    if test -f $f; then
        chmod +x $f
    fi
 done

# add execute permission for shell
find . -name '*.sh' -exec chmod +x {} \;

# dowload tool
if ! command_exists wget; then
    yum -y install wget > /dev/null 2>&1
fi
# net tool
if ! command_exists ifconfig; then
    yum -y install net-tools > /dev/null 2>&1
fi
# ntp tool
if ! command_exists ntpd; then
    yum -y install ntp > /dev/null 2>&1
fi

export PATH=$PATH:$basepath/tools

ssh_dir=/root/.ssh
cert_dir=`cat $basepath/config/k8s.json |jq '.cert.dir'|sed 's/\"//g'`

# ssh folder
if [ ! -d $ssh_dir ]; then
    mkdir -p $ssh_dir
fi

# ssl folder
if [ ! -d $cert_dir ]; then
    mkdir -p $cert_dir
fi

#check config
k8s_node_names=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`
k8s_node_ips=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].ip'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))
arr_k8s_node_ips=($(echo $k8s_node_ips))

master_flag=0
ip_falg=0
for ((i=0;i<${#arr_k8s_node_ips[@]};i++));do
    if echo ${arr_k8s_node_names[$i]}|grep -q "master"; then
        master_flag=$(($master_flag+1))
    fi
    if ip a |grep -q ${arr_k8s_node_ips[$i]}; then
        ip_falg=$(($ip_falg+1))
    fi
done
if [ $master_flag -ne 1 ]; then
    echo "ERROR: You must set only one node name with content master,Please setting $basepath/config/k8s.json first!"
    exit 1
fi
if [ $ip_falg -ne 1 ]; then
    echo "ERROR: You ip not in cluster,Please setting $basepath/config/k8s.json first!"
    exit 1
fi

# setting sshd
sshd_conf=/etc/ssh/sshd_config
if [ -f $sshd_conf ]; then
    if grep -q "GSSAPIAuthentication yes" $sshd_conf ; then
        sed -i "s/GSSAPIAuthentication yes/GSSAPIAuthentication no/g" $sshd_conf
    fi
fi

# check firewall & iptables
if [ $(ps -ef |grep "firewalld" |grep -v "grep" |wc -l) -gt 0 ]; then
    echo "setting disable firewalld......"
    systemctl stop firewalld > /dev/null 2>&1
    systemctl disable firewalld > /dev/null 2>&1
    echo "......done"
fi
if [ $(ps -ef |grep "iptables" |grep -v "grep\|kube" |wc -l) -gt 0 ]; then
    echo "setting disable iptables-services......"
    systemctl stop iptables > /dev/null 2>&1
    systemctl disable iptables > /dev/null 2>&1
    echo "......done"
fi