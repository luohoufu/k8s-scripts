#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

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
    ssh-keygen -q -t rsa -N "" -f $rsa_path
fi

#ssh with all nodes
export PATH=$PATH:$basepath/tools

k8s_registry_hostname="10.37.116.11"
k8s_registry_username="root"
k8s_registry_passwd="hello@1234"

src_dir=/root/ftp/security/usr/bin/*
dest_dir=/usr/bin

# each node sync
k8s_node_username=`cat $basepath/config/k8s.json |jq '.k8s.username'|sed 's/\"//g'`
k8s_node_passwd=`cat $basepath/config/k8s.json |jq '.k8s.passwd'|sed 's/\"//g'`

k8s_node_names=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))

for ((i=0;i<${#arr_k8s_node_names[@]};i++));do
    k8s_node_hostname=${arr_k8s_node_names[$i]}
    if echo $k8s_node_hostname|grep -q "master"; then
        if [ -f $host_path ]; then
            if grep -wq "$k8s_registry_hostname" $host_path; then
                continue
            fi
        fi
        expect $basepath/os/expect/expect_ssh.sh $k8s_registry_hostname $k8s_registry_username $k8s_registry_passwd > /dev/null 2>&1
        scp -r $k8s_registry_username@$k8s_registry_hostname:$src_dir $dest_dir
    fi
    
    for f in docker docker-containerd docker-containerd-ctr docker-containerd-shim dockerd docker-proxy docker-runc etcd etcdctl flanneld hyperkube kube-apiserver kube-controller-manager kubectl kube-dns kubelet kubemark kube-proxy kube-scheduler mk-docker-opts.sh; do
        scp -r $dest_dir/$f $k8s_node_username@$k8s_node_hostname:$dest_dir
    done
done