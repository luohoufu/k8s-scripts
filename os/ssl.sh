#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

if [ -f /ssl/synced ]; then
    exit 0
fi

echo "gernerate ssl files and copy to all nodes,please wait......"
if [ ! -d /ssl ]; then
    mkdir -p /ssl
fi

export PATH=$PATH:$basepath/tools

#ssl with all nodes
if [ ! -f /ssl/ca.pem ]; then
    cfssl gencert -initca "$basepath/config/ca-csr.json" | cfssljson -bare /ssl/ca > /dev/null 2>&1
fi

for f in etcd flanneld apiserver; do
    if [ ! -f /ssl/$f.pem ]; then
        cfssl gencert -ca /ssl/ca.pem -ca-key /ssl/ca-key.pem -config "$basepath/config/ca-config.json" "$basepath/config/req-csr.json" | cfssljson -bare /ssl/$f > /dev/null 2>&1
    fi
done

k8s_node_username=`cat $basepath/config/k8s.json |jq '.k8s.username'|sed 's/\"//g'`
k8s_node_names=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))

for ((i=0;i<${#arr_k8s_node_names[@]};i++));do
    k8s_node_hostname=${arr_k8s_node_names[$i]}
    if echo $k8s_node_hostname|grep -q "master"; then
        continue
    fi
    scp -r /ssl $k8s_node_username@$k8s_node_hostname:/
    touch /ssl/synced
done

echo "......done"