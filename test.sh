 #!/usr/bin/env bash
 # -*- bash -*-

set -e -o pipefail -o errtrace -o functrace
# runtime env
basepath=$(cd `dirname $0`; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}
# shell runtime env
export PATH=$PATH:$basepath/tools


etcd_node_names=`cat $basepath/config/k8s.json |jq '.etcd.nodes[].name'`
etcd_node_ips=`cat $basepath/config/k8s.json |jq '.etcd.nodes[].ip'`

etcd_endpoints=`echo $etcd_node_names $etcd_node_ips|sed 's/\"//g'|awk  '{for (i = 1; i < NF/2; i++) printf("%s=https://%s:2380,",$i,$(i+NF/2));printf("%s=https://%s:2380",$i,$(i+NF/2))}'` 
echo $etcd_endpoints

flannel_key=`cat $basepath/config/k8s.json |jq '.flannel.key'`
flannel_value=`cat $basepath/config/k8s.json |jq '.flannel.value'`

echo $flannel_key
echo $flannel_value


k8s_node_names=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`
k8s_node_ips=`cat $basepath/config/k8s.json |jq '.k8s.nodes[].ip'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))
for ((i=0;i<${#arr_k8s_node_names[@]};i++));do
   echo ${arr_k8s_node_names[$i]}
done
