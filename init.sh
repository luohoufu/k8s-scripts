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

# check config
bash $basepath/os/check.sh

echo "System init maybe take half hour,You can have a coffee now!"

# execute shell file
for s in repo tools selinux hostname hosts iface ntpd kernel vim fix; do
    bash $basepath/os/$s.sh
done 

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
