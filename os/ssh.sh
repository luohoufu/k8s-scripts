#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

echo "gernerate ssh files and copy to all nodes,please wait......"
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -q -t rsa -N "" -f ~/.ssh/id_rsa
fi

#ssh with all nodes
export PATH=$PATH:$basepath/tools

k8s_node_username=`cat $basepath/config.json |jq '.k8s.username'|sed 's/\"//g'`
k8s_node_passwd=`cat $basepath/config.json |jq '.k8s.passwd'|sed 's/\"//g'`

k8s_node_names=`cat $basepath/config.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`
k8s_node_ips=`cat $basepath/config.json |jq '.k8s.nodes[].ip'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))
arr_k8s_node_ips=($(echo $k8s_node_ips))

master_flag=0
ip_falg=0
for ((i=0;i<${#arr_k8s_node_ips[@]};i++));do
    if echo ${arr_k8s_node_names[$i]}|grep -q "master"; then
        continue
    fi
    expect $basepath/os/expect/expect_ssh_node.sh $k8s_node_username ${arr_k8s_node_names[$i]} $k8s_node_passwd > /dev/null 2>&1
    expect $basepath/os/expect/expect_ssh_ip.sh $k8s_node_username ${arr_k8s_node_ips[$i]} $k8s_node_passwd > /dev/null 2>&1
done

echo "......done"