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

if ! grep -q "master" /etc/hostname ; then
    echo "ERROR: This shell must run on master node!"
    exit 1
fi

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
registry_ip=`jq -r '.docker.registry.ip' $json`
registry_port=`jq -r '.docker.registry.port' $json`
registry_url=$registry_ip":"$registry_port

name=busybox
yaml=$basepath/kubernetes/add-on/busybox/busybox.yaml

# setting apiserver ip address
sed -i "s/registy_url/$registry_url/" $yaml

# you need docker pull images manual

# check manual with kubectl get rc,svc,po --namespace=kube-system
if [ $(kubectl get po | grep $name |wc -l) -eq 0 ]; then
    kubectl create -f  $yaml
fi

# you can use for test
# kubectl exec -i -t busybox sh 
# nslookup k8s-nginx
# nslookup k8s-nginx.default.kube.local
# nslookup k8s-nginx.default.svc.kube.local