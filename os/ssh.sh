#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

check_path=/root/.ssh/sync

if [ -f $check_path ]; then
    echo "Do you want run again? [Y]/n"
    read confirm
    if [[ "${confirm}" =~ ^[nN]$ ]]; then
        exit 0
    fi
fi

echo "gernerate ssh files and copy to all nodes,please wait......"
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -q -t rsa -N "" -f /root/.ssh/id_rsa
fi

#ssh with all nodes
export PATH=$PATH:$basepath/tools

k8s_node_username=`cat $basepath/config/k8s.json |jq '.k8s.username'|sed 's/\"//g'`
k8s_node_passwd=`cat $basepath/config/k8s.json |jq '.k8s.passwd'|sed 's/\"//g'`

k8s_node_names=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))

for ((i=0;i<${#arr_k8s_node_names[@]};i++));do
    k8s_node_hostname=${arr_k8s_node_names[$i]}
    if echo $k8s_node_hostname|grep -q "master"; then
        continue
    fi
    if [ -f /root/.ssh/known_hosts ]; then
        if grep -wq "$k8s_node_hostname" /root/.ssh/known_hosts; then
            continue
        fi
    fi
    expect $basepath/os/expect/expect_ssh.sh $k8s_node_hostname $k8s_node_username $k8s_node_passwd > /dev/null 2>&1
done

# gernerate check_path
if [ ! -f $check_path ]; then
    touch $check_path
fi

echo "......done"