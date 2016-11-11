#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

rsa_path=/root/.ssh/id_rsa
host_path=/root/.ssh/known_hosts
check_path=/root/.ssh/sync

if [ -f $check_path ]; then
    echo "Do you want run $0 again? [Y]/n"
    read confirm
    if [[ "${confirm}" =~ ^[nN]$ ]]; then
        exit 0
    fi
fi

echo "gernerate ssh files and copy to all nodes,please wait......"
if [ ! -f $rsa_path ]; then
    ssh-keygen -q -t rsa -N "" -f $rsa_path
fi

#ssh with all nodes
export PATH=$PATH:$basepath/tools

k8s_node_username=`cat $basepath/config/k8s.json |jq '.host.uname'|sed 's/\"//g'`
k8s_node_passwd=`cat $basepath/config/k8s.json |jq '.host.passwd'|sed 's/\"//g'`

k8s_node_names=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))

for ((i=0;i<${#arr_k8s_node_names[@]};i++));do
    k8s_node_hostname=${arr_k8s_node_names[$i]}
    if echo $k8s_node_hostname|grep -q "master"; then
        continue
    fi
    if [ -f $host_path ]; then
        if grep -wq "$k8s_node_hostname" $host_path; then
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