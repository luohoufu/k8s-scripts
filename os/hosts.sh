#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
master_node_name=(`jq -r '.k8s.nodes[0].name' $json`)
k8s_node_names=(`jq -r '.k8s.nodes[].name' $json`)
k8s_node_ips=(`jq -r '.k8s.nodes[].ip' $json`)

if grep -wq "$master_node_name"  /etc/hosts ; then
    exit 0
fi

echo "setting hosts,please wait......"
echo "#add by user" >> /etc/hosts
for ((i=0;i<${#k8s_node_names[@]};i++));do
    echo "${k8s_node_ips[$i]}    ${k8s_node_names[$i]}" >> /etc/hosts
done
echo "......done"

