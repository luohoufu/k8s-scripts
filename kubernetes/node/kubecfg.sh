#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ../..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
cert_dir=`jq -r '.cert.dir' $json`
conf=`jq -r '.k8s.cfg' $json`
k8s_master_ip=`jq -r '.k8s.nodes[]| select(.type == "master")|.ip' $json` 

ca=$cert_dir/ca.pem
cert=$cert_dir/client.pem
certkey=$cert_dir/client-key.pem

# if you want use base64 data,that not need mount volumes to docker
#ca_base64=`cat $ca |base64|awk '{printf("%s"),$0}'`
#cert_base64=`cat $cert |base64|awk '{printf("%s"),$0}'`
#certkey_base64=`cat $certkey |base64|awk '{printf("%s"),$0}'`

# check confdir
if [ ! -d "${conf%/*}" ]; then
     mkdir -p ${conf%/*}
fi

cat <<EOF >$conf
apiVersion: v1
kind: Config
users:
- name: kubelet
  user:
    client-certificate: ${cert}
    client-key: ${certkey}
clusters:
- name: local
  cluster:
    certificate-authority: ${ca}
    server: https://${k8s_master_ip}:6443
contexts:
- context:
    cluster: local
    user: kubelet
  name: service-account-context
current-context: service-account-context    
EOF

# setting alias
if ! grep -q "kubectl" /root/.bashrc ; then
    sed -i "/alias etcdctl/a\alias kubectl='kubectl --kubeconfig=$conf'" /root/.bashrc
fi

# check conf
if [ -f $conf ];then
    echo "kubecfg generate success!"
fi