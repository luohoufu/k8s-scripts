 #!/usr/bin/env bash
 # -*- bash -*-

set -e -o pipefail -o errtrace -o functrace
# runtime env
basepath=$(cd `dirname $0`; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
data=`jq -r '.docker.registry.data' $json`
fsdriver=`jq -r '.docker.registry.fsdriver' $json`

echo $data
echo $fsdriver

etcd_ip=`hostname -i`
etcd_name=`jq -r ".etcd.nodes[]| select(.ip == \"$etcd_ip\")|.name" $json`

etcd_node_names=`jq -r '.etcd.nodes[].name' $json`
etcd_node_ips=`jq -r '.etcd.nodes[].ip' $json`

etcd_cluster=`echo $etcd_node_names $etcd_node_ips|awk '{for (i = 1; i < NF/2; i++) printf("%s=https://%s:2380,",$i,$(i+NF/2));printf("%s=https://%s:2380",$i,$(i+NF/2))}'`
etcd_endpoints=`echo $etcd_node_ips|awk '{for (i = 1; i < NF; i++) printf("https://%s:2379,",$i);printf("https://%s:2379",$NF)}'`

echo $etcd_name
echo $etcd_ip
echo $etcd_cluster
echo $etcd_endpoints

certdir=`jq -r '.cert.dir' $json`

echo $certdir


flannel_iface=`jq -r '.flannel.iface' $json`
flannel_key=`jq -r '.flannel.key' $json`
flannel_value=`jq -r '.flannel.value' $json`

etcd_node=`jq -r '.etcd.nodes[0].ip' $json`

echo $flannel_iface
echo $flannel_key
echo $flannel_value
echo $etcd_node

k8s_node_names=`jq -r '.k8s.nodes[].name' $json`

echo $k8s_node_names
arr_k8s_node_names=($(echo $k8s_node_names))
echo ${#arr_k8s_node_names[@]}

a_k8s_node_names=($(echo `jq -r '.k8s.nodes[].name' $json`))
echo ${#a_k8s_node_names[@]}


b_k8s_node_names=(`jq -r '.k8s.nodes[].name' $json`)
echo ${#b_k8s_node_names[@]}


host_ip=$(ip a | grep -Po '(?<=inet ).*(?=\/)'|awk '{if($1!~/^10.0|^192|^172|^127|^0/) print $1}')
echo $host_ip