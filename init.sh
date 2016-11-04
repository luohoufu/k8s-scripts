 #!/usr/bin/env bash
 # -*- bash -*-

set -e -o pipefail -o errtrace -o functrace
# runtime env
basepath=$(cd `dirname $0`; pwd)
command_exists() {
     command -v "$@" > /dev/null 2>&1
}
# check run user
if [[ ! `id -u` -eq 0 ]]; then
     echo "Please run this shell by root user!"
     exit 1;
 fi
# add execute permission
 for f in $basepath/tools/*;do
    if test -f $f; then
        chmod +x $f
    fi
 done
# add execute permission for shell
find . -name '*.sh' -exec chmod +x {} \;
# dowload tool
if ! command_exists wget; then
    yum -y install wget > /dev/null 2>&1
fi
# net tool
if ! command_exists ifconfig; then
    yum -y install net-tools > /dev/null 2>&1
fi
# ntp tool
if ! command_exists ntpd; then
    yum -y install ntp > /dev/null 2>&1
fi
# ssh folder
if [ ! -d /root/.ssh ]; then
    mkdir -p /root/.ssh
fi
# ssl folder
if [ ! -d /ssl ]; then
    mkdir -p /ssl
fi
#check config
export PATH=$PATH:$basepath/tools

k8s_node_names=`cat $basepath/config/config.json |jq '.k8s.nodes[].name'|sed 's/\"//g'`
k8s_node_ips=`cat $basepath/config/config.json |jq '.k8s.nodes[].ip'|sed 's/\"//g'`

arr_k8s_node_names=($(echo $k8s_node_names))
arr_k8s_node_ips=($(echo $k8s_node_ips))

master_flag=0
ip_falg=0
for ((i=0;i<${#arr_k8s_node_ips[@]};i++));do
    if echo ${arr_k8s_node_names[$i]}|grep -q "master"; then
        master_flag=$(($master_flag+1))
    fi
    if ip a |grep -q ${arr_k8s_node_ips[$i]}; then
        ip_falg=$(($ip_falg+1))
    fi
done
if [ $master_flag -ne 1 ]; then
    echo "ERROR: You must set only one node name with content master,Please modify $basepath/config/config.json!"
    exit 1
fi
if [ $ip_falg -ne 1 ]; then
    echo "ERROR: You ip not in cluster,,Please modify $basepath/config/config.json!"
    exit 1
fi

# execute shell file
for s in repo tools selinux hostname hosts iface ntpd kernel vim fix; do
    bash $basepath/os/$s.sh
done 

# firewall & iptables
if [ $(ps -ef |grep "firewalld" |grep -v "grep" |wc -l) -gt 0 ]; then
    echo "setting disable firewalld......"
    systemctl stop firewalld
    systemctl disable firewalld
    echo "......done"
fi
if [ $(ps -ef |grep "iptables" |grep -v "grep" |wc -l) -gt 0 ]; then
    echo "setting disable iptables-services......"
    systemctl stop iptables
    systemctl disable iptables
    echo "......done"
fi

# setting execute files
if [[ -d "$basepath/usr/bin"  &&  ! -f /usr/bin/etcd ]] ; then
    echo "setting execute file......"
    scp -r $basepath/usr/bin/* /usr/bin
    echo "......done"
fi

# rebooting system
echo "You must reboot system,Do You Want Reboot System Now? [Y]/n"
read confirm
if [[ ! "${confirm}" =~ ^[nN]$ ]]; then
    echo "Rebooting Now......"
    shutdown -r now
fi
