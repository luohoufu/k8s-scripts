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
# you need docker pull images manual

# check manual with kubectl get rc,svc,po --namespace=kube-system
if [ $(kubectl get po | grep nginx |wc -l) -eq 0 ]; then
    kubectl create -f  $basepath/kubernetes/add-on/nginx/nginx.yaml
    #kubectl delete deploy,svc k8s-nginx
fi
