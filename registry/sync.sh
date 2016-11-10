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

host_path=/root/.ssh/known_hosts
check_path=/tmp/sync
usr_bin=/usr/bin

if [ -f $check_path ]; then
    echo "Do you want run $0 again? [Y]/n"
    read confirm
    if [[ "${confirm}" =~ ^[nN]$ ]]; then
        exit 0
    fi
fi

echo "sync execute files to all nodes,please wait......"

#ssh with all nodes
export PATH=$PATH:$basepath/tools

k8s_registry_hostname=`cat $basepath/config/k8s.json |jq '.docker.registry.ip'|sed 's/\"//g'`

# each node sync
k8s_node_username=`cat $basepath/config/k8s.json |jq '.k8s.username'|sed 's/\"//g'`
k8s_node_passwd=`cat $basepath/config/k8s.json |jq '.k8s.passwd'|sed 's/\"//g'`

k8s_node_names=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))

for ((i=0;i<${#arr_k8s_node_names[@]};i++));do
    k8s_node_hostname=${arr_k8s_node_names[$i]}
    if echo $k8s_node_hostname|grep -q "master"; then
        if [ -f $host_path ]; then
            if ! grep -wq "$k8s_registry_hostname" $host_path; then
                expect $basepath/os/expect/expect_ssh.sh $k8s_registry_hostname $k8s_node_username $k8s_node_passwd > /dev/null 2>&1
            fi
        fi
        for f in docker docker-containerd docker-containerd-ctr docker-containerd-shim dockerd docker-proxy docker-runc etcd etcdctl flanneld kube-apiserver kube-controller-manager kubectl kube-dns kube-scheduler kubelet kube-proxy mk-docker-opts.sh; do
            if [ ! -f $usr_bin/$f ];then
                scp -r $k8s_node_username@$k8s_registry_hostname:$usr_bin/$f $usr_bin > /dev/null 2>&1
            fi
         done
        continue
    fi
    
    for f in docker docker-containerd docker-containerd-ctr docker-containerd-shim dockerd docker-proxy docker-runc etcd etcdctl flanneld kubelet kube-proxy mk-docker-opts.sh; do
        if [ -f $usr_bin/$f ];then
            scp -r $usr_bin/$f $k8s_node_username@$k8s_node_hostname:$usr_bin > /dev/null 2>&1
        fi
    done
done

# gernerate check_path
if [ ! -f $check_path ]; then
    touch $check_path
fi

echo "......done"