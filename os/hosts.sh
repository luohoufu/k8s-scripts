#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools

k8s_node_names=`cat $basepath/config.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`
k8s_node_ips=`cat $basepath/config.json |jq '.k8s.nodes[].ip'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))
arr_k8s_node_ips=($(echo $k8s_node_ips))

if ! grep -wq "${arr_k8s_node_names[$i]}"  /etc/hosts ; then
    echo "setting hosts,please wait......"
    echo "#add by user" >> /etc/hosts
    for ((i=0;i<${#arr_k8s_node_ips[@]};i++));do
        echo "${arr_k8s_node_ips[$i]}    ${arr_k8s_node_names[$i]}" >> /etc/hosts
    done
    echo "......done"
fi
