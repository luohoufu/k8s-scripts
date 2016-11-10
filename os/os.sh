#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)

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
echo "------------------------------------[ps -ef|grep iptables]------------------------------------"
echo `ps -ef|grep iptables`
echo 
echo
echo "------------------------------------[ps -ef|grep firewalld]------------------------------------"
echo `ps -ef|grep firewalld`
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
echo "------------------------------------[ls /ssl]------------------------------------"
echo `ls /ssl`
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

# rebooting system
echo "You must reboot system,Do You Want Reboot System Now? [Y]/n"
read confirm
if [[ ! "${confirm}" =~ ^[nN]$ ]]; then
    echo "Rebooting Now......"
    shutdown -r now
fi