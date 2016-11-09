#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ../..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools

service_cluster_ip_range=`cat $basepath/config/k8s.json |jq '.k8s.svciprange'|sed 's/\"//g'`
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


cert_dir=`cat $basepath/config/k8s.json |jq '.cert.dir'|sed 's/\"//g'`

ca=$cert_dir/ca.pem
cert=$cert_dir/client.pem
certkey=$cert_dir/client-key.pem
certcsr=$cert_dir/client.csr
conf=/etc/kubernetes/kubecfg

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
- name: dev
  cluster:
    certificate-authority: ${ca}
    server: https://${k8s_master}:6443
contexts:
- context:
    cluster: dev
    user: kubelet
  name: service-account-context
current-context: service-account-context    
EOF

#setting alias
if ! grep -q "kubectl" /root/.bashrc ; then
    sed -i "/alias etcdctl/a\alias kubectl='kubectl --kubeconfig=$conf'" /root/.bashrc
fi