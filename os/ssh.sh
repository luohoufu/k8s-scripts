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
    if [ ! -d ${rsa_path%/*} ]; then
        mkdir -p ${rsa_path%/*}
    fi
    ssh-keygen -q -t rsa -N "" -f $rsa_path
fi

#ssh with all nodes
export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
k8s_node_username=`jq -r '.host.uname' $json`
k8s_node_passwd=`jq -r '.host.passwd' $json`
k8s_node_names=(`jq -r '.k8s.nodes[]| select(.type == "node")|.ip' $json`)

for ((i=0;i<${#k8s_node_names[@]};i++));do
    k8s_node_hostname=${k8s_node_names[$i]}
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