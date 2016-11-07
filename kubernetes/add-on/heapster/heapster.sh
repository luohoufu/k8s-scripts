#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ../../..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

#
# check run user
#
if [ ! `id -u` -eq 0 ]; then
    echo "Please run this shell by root user!!!"
    exit 1;
fi

export PATH=$PATH:$basepath/tools

registry_ip=`cat $basepath/config/k8s.json |jq '.docker.registry.ip'|sed 's/\"//g'`
registry_port=`cat $basepath/config/k8s.json |jq '.docker.registry.port'|sed 's/\"//g'`
registry_url=$registry_ip + ":" + $registry_port

k8s_node_username=`cat $basepath/config/k8s.json |jq '.k8s.username'|sed 's/\"//g'`
k8s_node_passwd=`cat $basepath/config/k8s.json |jq '.k8s.passwd'|sed 's/\"//g'`

k8s_node_names=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`
k8s_node_ips=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].ip'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))
arr_k8s_node_ips=($(echo $k8s_node_ips))

for ((i=0;i<${#arr_k8s_node_names[@]};i++));do
    k8s_node_hostname=${arr_k8s_node_names[$i]}
    if echo $k8s_node_hostname|grep -q "master"; then
        k8s_master=${arr_k8s_node_ips[$i]}
    fi
done

# setting apiserver ip address
sed -i "s/registy_url/$registry_url/g" $bashpath/kubernetes/add-on/dashboard/heapster-controller.yaml

if [ $(docker images|grep "heapster"|wc -l) -eq 0 ]; then
    docker pull $registry_url/google_containers/heapster:v1.1.0
fi
if [ $(docker images|grep "resizer"|wc -l) -eq 0 ]; then
    docker pull $registry_url//google_containers/addon-resizer:v1.0
fi

if [ $(kubectl get po --namespace=kube-system| grep heapster |wc -l) -eq 0 ]; then
    kubectl create -f $basepath/heapster-controller.yaml
    kubectl create -f $basepath/heapster-service.yaml
    #kubectl delete rc kubernetes-heapster-v1.1.0 --namespace=kube-system
    #kubectl delete services kubernetes-heapster --namespace=kube-system
fi
