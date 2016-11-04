# k8s-scripts for centos 7.2

## 测试环境
* [CentOS 7.2 x86_64镜像](http://centos.ustc.edu.cn/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1511.iso)
* 虚拟机 Oracle VM VirtualBox 5.1.8
  - [Windows x86/amd64](http://download.virtualbox.org/virtualbox/5.1.8/VirtualBox-5.1.8-111374-Win.exe)
  - [Linux x86_64](https://www.virtualbox.org/wiki/Linux_Downloads) 
* 采用3台虚拟机，1台master,2台node
* 采用脚本（配置和systemd服务生成）+可执行文件方式搭建k8s环境
* 机器信息通过config/*.json进行配置

## 网络环境
* 采用桥接网卡，虚拟机与HOSTS在同一局域网，并能相互访问，关于虚拟机网络设置如下：  
    **1. NAT 网络地址转换模式(NAT,Network Address Translation)**  
    虚拟机访问网络，是通过主机转换的，真实的主机不能访问虚拟机。  
    **2. Bridged Adapter 桥接模式**   
    分配独立的IP地址，可以相互访问。(建议使用这种，这样可以保证虚拟机有独立的IP，满足arm开发)  
    **3. Internal 内部网络模式**   
    **4. Host-only Adapter 主机模式**   
    主机模式，这个模式比较复杂，可以说前面几种模式所实现的功能，在这种模式下，通过虚拟机及网卡的设置都可以实现。

## 脚本执行顺序
1. 系统配置
2. 系统补丁
3. 安装ETCD集群
4. 安装FLANNEL
5. 安装DOCKER
6. 安装K8S MASTER服务
7. 安装K8S NODE服务

## 依赖工具
* ssl文件生成  
**cfssl**
go get -u github.com/cloudflare/cfssl/cmd/...  
* json操作  
**jq**
https://github.com/stedolan/jq/releases
http://stedolan.github.io/jq/download/linux64/jq