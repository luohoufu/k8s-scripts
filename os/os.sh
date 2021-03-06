#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
cert_dir=`jq -r '.cert.dir' $json`

#get summary info
echo "------------------------------------[w]------------------------------------"
echo `w`
echo 
echo
echo "------------------------------------[date]------------------------------------"
echo `date`
echo 
echo
echo "------------------------------------[hostname]------------------------------------"
echo `hostname`
echo
echo
echo "------------------------------------[hostname -i]------------------------------------"
echo `hostname -i`
echo
echo
echo "------------------------------------[uname -r]------------------------------------"
echo `uname -r`
echo
echo
echo "------------------------------------[cat /etc/hosts]------------------------------------"
echo `cat /etc/hosts`
echo
echo "------------------------------------[ip a show eth0]------------------------------------"
echo `ip a show eth0`
echo 
echo
echo "------------------------------------[ps -ef|grep iptables|grep -v grep]------------------------------------"
echo `ps -ef|grep iptables|grep -v grep`
echo 
echo
echo "------------------------------------[ps -ef|grep firewalld|grep -v grep]------------------------------------"
echo `ps -ef|grep firewalld|grep -v grep`
echo
echo
echo "------------------------------------[sestatus -v]------------------------------------"
echo `sestatus -v`
echo
echo
echo "------------------------------------[ls /root/.ssh]------------------------------------"
echo `ls /root/.ssh`
echo
echo
echo "------------------------------------[ls $cert_dir]------------------------------------"
echo `ls $cert_dir`
echo
echo
echo "------------------------------------[ulimit -u]------------------------------------"
echo `ulimit -u`
echo
echo


 # remove unuse linux kernel 
if [[ $(uname -r |cut -c1) -eq 4 && $(rpm -qa | grep kernel|grep -v "4.8"|wc -l) -gt 0 ]]; then
    echo "remove unuse kernel,please wait......"    
    for s in `rpm -qa | grep kernel|grep -v "4.8"`; do
        yum remove -y "$s" > /dev/null 2>&1
    done
    echo "......done"
fi