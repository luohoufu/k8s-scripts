#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

check_path=$cert_dir/sync

if [ -f $check_path ]; then
    echo "Do you want run $0 again? [Y]/n"
    read confirm
    if [[ "${confirm}" =~ ^[nN]$ ]]; then
        exit 0
    fi
fi

master_ip=`hostname -i`
bash $basepath/kubernetes/certs/make-ca-certs.sh "$master_ip" "IP:$master_ip,IP:172.16.0.1,DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.dev"

bash $basepath/etcd/make-ca-certs.sh