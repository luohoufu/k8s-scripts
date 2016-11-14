#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

# check run user
if [[ ! `id -u` -eq 0 ]]; then
    echo "Please run this shell by root user!"
    exit 1;
fi

if ! grep -q "master" /etc/hostname ; then
    echo "ERROR: This shell must run on master node!"
    exit 1
fi

rsa_path=/root/.ssh/id_rsa
host_path=/root/.ssh/known_hosts
check_path=/tmp/sync
exe_dir=/usr/bin

if [ -f $check_path ]; then
    echo "Do you want run $0 again? [Y]/n"
    read confirm
    if [[ "${confirm}" =~ ^[nN]$ ]]; then
        exit 0
    fi
fi

echo "sync execute files to all nodes,please wait......"
if [ ! -f $rsa_path ]; then
    if [ ! -d ${rsa_path%/*} ]; then
        mkdir -p ${rsa_path%/*}
    fi
    ssh-keygen -q -t rsa -N "" -f $rsa_path
fi
#ssh with all nodes
export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
k8s_registry_hostname=`jq -r '.docker.registry.ip' $json`
# each node sync
k8s_node_username=`jq -r '.host.uname' $json`
k8s_node_passwd=`jq -r '.host.passwd' $json`

k8s_node_names=(`jq -r '.k8s.nodes[].name' $json`)

for ((i=0;i<${#k8s_node_names[@]};i++));do
    k8s_node_hostname=${k8s_node_names[$i]}
    if echo $k8s_node_hostname|grep -q "master"; then
        if [ -f $host_path ]; then
            if ! grep -wq "$k8s_registry_hostname" $host_path; then
                expect $basepath/os/expect/expect_ssh.sh $k8s_registry_hostname $k8s_node_username $k8s_node_passwd > /dev/null 2>&1
            fi
        fi
        for f in docker docker-containerd docker-containerd-ctr docker-containerd-shim dockerd docker-proxy docker-runc etcd etcdctl flanneld kube-apiserver kube-controller-manager kubectl kube-dns kube-scheduler kubelet kube-proxy mk-docker-opts.sh registry; do
            if [ ! -f $exe_dir/$f ];then
                scp -r $k8s_node_username@$k8s_registry_hostname:$exe_dir/$f $exe_dir > /dev/null 2>&1
            fi
         done
        continue
    fi
    
    for f in docker docker-containerd docker-containerd-ctr docker-containerd-shim dockerd docker-proxy docker-runc etcd etcdctl flanneld kubelet kube-proxy mk-docker-opts.sh; do
        if [ -f $exe_dir/$f ];then
            scp -r $exe_dir/$f $k8s_node_username@$k8s_node_hostname:$exe_dir > /dev/null 2>&1
        fi
    done
done

# gernerate check_path
if [ ! -f $check_path ]; then
    touch $check_path
fi

echo "......done"