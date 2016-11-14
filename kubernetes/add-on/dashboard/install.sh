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
cert_dir=`jq -r '.cert.dir' $json`
k8s_cfg=`jq -r '.k8s.cfg' $json`
registry_ip=`jq -r '.docker.registry.ip' $json`
registry_port=`jq -r '.docker.registry.port' $json`
registry_url=$registry_ip":"$registry_port
k8s_master_ip=`jq -r '.k8s.nodes[]| select(.type == "master")|.ip' $json` 

name=dashboard
yaml=$basepath/kubernetes/add-on/dashboard/kubernetes-dashboard.yaml

tmpdir=$(mktemp -d -t kubernetes.XXXXXX)
trap 'rm -rf "${tmpdir}"' EXIT
yaml=${tmpdir}/config.yaml
cat $yaml >> $yaml

# setting apiserver ip address
sed -i "s/127.0.0.1/$k8s_master_ip/g" $yaml
sed -i "s/registry_url/$registry_url/g" $yaml
sed -i "s#k8s_cfg#$k8s_cfg#g" $yaml
sed -i "s#cert_dir#$cert_dir#g" $yaml

# you need docker pull images manual

# check manual with kubectl get rc,svc,po --namespace=kube-system
if [ $(kubectl get po --namespace=kube-system| grep $name |wc -l) -eq 0 ]; then
    kubectl create -f  $yaml
    #kubectl -n kube-system delete deploy,svc kubernetes-dashboard
fi
exit