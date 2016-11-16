#!/usr/bin/env bash
# -*- bash -*-

set -e -o pipefail -o errtrace -o functrace

basepath=$(cd `dirname $0`;cd ..; pwd)
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

# check run user
if [[ ! `id -u` -eq 0 ]]; then
    echo "Please run this shell by root user!"
    exit 1;
fi

export PATH=$PATH:$basepath/tools
json=$basepath/config/k8s.json
ver=`jq -r '.proxy.ver' $json`
opdir=`jq -r '.proxy.opdir' $json`
ngx_dir=/usr/local/nginx
cfg=$opdir/nginx/conf/nginx.conf

# Create etcd.conf, etcd.service
user=nginx
name=nginx
data=/data/logs
exefile=/usr/bin/nginx
service=/usr/lib/systemd/system/nginx.service

# check user
if ! grep -q $user /etc/passwd; then
    useradd -c "$name user" -d $data -M -r -s /sbin/nologin $user
fi

# check env
for p in patch pert bc gcc; then
    if ! command_exists patch; then
        yum -y install $p > /dev/null 2>&1
    fi
done

if ! command_exists ${exefile##*/}; then
    yum -y install readline-devel pcre-devel openssl-devel > /dev/null 2>&1
fi

# check workdir
if [ ! -d "$data" ]; then
    mkdir -p $data
    for p in $data $opdir; do
        chown -R $user:$user $p
    done
fi

echo "openresty install start......"
tmpdir=$(mktemp -d -t openresty.XXXXXX)
trap 'rm -rf "${tmpdir}"' EXIT
cd "${tmpdir}"

if [ -f ~/openresty-$ver.tar.gz ]; then
    ln -s ~/openresty-$ver.tar.gz .
else
    curl -L -O https://openresty.org/download/openresty-$ver.tar.gz > /dev/null 2>&1
fi

tar xzf openresty-$ver.tar.gz > /dev/null 2>&1
cd openresty-$ver

# for security i remove the openresty head tag
sed -i "s/${ver%.*}\"/2.0.0\"/" bundle/nginx-no_pool.patch
sed -i "s/openresty/ApiServer/" bundle/nginx-no_pool.patch
sed -i 's#"openresty/" NGINX_VERSION ".1"#"ApiServer/2.0.0"#' bundle/nginx-${ver%.*}/src/core/nginx.h
sed -i "s/openresty/ApiServer/" bundle/nginx-${ver%.*}/src/http/ngx_http_header_filter_module.c
sed -i "s/>nginx</>ApiServer</" bundle/nginx-${ver%.*}/src/http/ngx_http_special_response.c

# complie and install
cpucore=`cat /proc/cpuinfo |grep "processor"|wc -l`
./configure --prefix=$opdir -j$cpucore --with-http_stub_status_module > /dev/null 2>&1
gmake -j$cpucore > /dev/null 2>&1
gmake install > /dev/null 2>&1

# remove default html
rm -rvf $opdir/nginx/html/* > /dev/null 2>&1

# setting path
if [ ! -d $ngx_dir ]; then
    ln -s $opdir/nginx $ngx_dir
fi
fi [ ! -f $exefile ]; then
    ln -s $ngx_dir/sbin/nginx $exefile
fi

# setting lua 
scp -r $basepath/proxy/lua $ngx_dir

# setting html
cat <<EOF >$ngx_dir/html/index.json
{"code":1,"message":"Welcome to ApiServer!","data":{}}    
EOF

cat <<EOF >$ngx_dir/html/50x.json
{"code":111,"message":"ApiServer Internal Error!","data":{}}
EOF

cat <<EOF >$ngx_dir/html/404.json
{"code":0,"message":"Page not found！","data":{}}  
EOF

# setting permission
for p in html logs;do
    chown -R nginx:nginx $ngx_dir/$p
done

affinity="worker_cpu_affinity "
for((i=1;i<=$cpucore;i++));do
    printf -v cpubit "%04d " `echo "obase=2;$i" | bc`
    if [ $i -eq $cpucore ]; then
        printf -v cpubit "%04d" `echo "obase=2;$i" | bc`
    fi
    affinity=$affinity$cpubit
done

# setting conf
cat <<EOF >$ngx_dir/conf/nginx.conf
user nginx nginx
worker_processes  $cpucore;
$affinity

# [ debug | info | notice | warn | error | crit ]   
error_log  /data/logs/main.error.log crit;

pid        /var/run/nginx.pid;

#Specifies the value for maximum file descriptors that can be opened by this process. 
worker_rlimit_nofile 65535;

events {
    use epoll;
    worker_connections  10240;
    multi_accept on;
}
 
http {
    include       mime.types;
    default_type  application/json;
    charset_types application/json;
    charset UTF-8;

 
    access_log off;
    error_log /data/logs/http.log crit;

    #隐藏nginx 版本号
    server_tokens off;
    #开启高效文件传输模式
    sendfile  on;
    #防止网络阻塞
    tcp_nopush  on;
    tcp_nodelay on;
    #长链接超时时间
    keepalive_timeout 30s 30s;

    gzip  on;
    gzip_min_length 1k;
    gzip_buffers 4 16k;
    gzip_http_version 1.0;
    gzip_comp_level 4;
    gzip_types text/plain text/xml application/json;
    gzip_vary on;
    gzip_disable "MSIE [1-6].";

    client_body_buffer_size 8m;
    #上传文件大小限制
    client_max_body_size 20m;
    #设定请求缓冲
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
    client_header_timeout 60;
    client_body_timeout 60;
    send_timeout        60;
    reset_timedout_connection on;

    limit_conn_zone $binary_remote_addr zone=addr:5m;
    limit_conn addr 1000;

    #lua模块路径，多个之间”;”分隔，其中”;;”表示默认搜索路径，默认到/opt/openresty/nginx下找
    include blocksip.conf;
    lua_package_path "$opdir/lualib/?.lua;;";
    lua_package_cpath "$opdir/lualib/?.so;;";
    lua_shared_dict global  20m;
    lua_shared_dict process  20m;
    init_by_lua_file  lua/initialize.lua;
 
    server {
        listen 80 reuseport;
        server_name  _;
        root html;
        index index.json;

        location /reload {
            allow 127.0.0.1;
            deny all;
            content_by_lua 'DispatchReload()';
        }
 
        location /process {
            internal;

            content_by_lua_file lua/process.lua;
            access_log off;
            error_log /data/logs/api.process.error.log;
        }

        location /upload {
            internal;

            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Max-Age 86400;
            add_header Access-Control-Allow-Methods GET,POST,PUT,OPTIONS;
            add_header Access-Control-Allow-Headers x-forwarded-with,content-type;

            proxy_pass $dispatch;
            access_log off;
            error_log /data/logs/api.upload.error.log;
        }
 
        location /proxy {
            internal;     
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_http_version 1.1;

            proxy_connect_timeout 2s;
            proxy_send_timeout  5s;
            proxy_read_timeout  10s;
            proxy_buffer_size 4k;
            proxy_buffers 4 32k;
            proxy_busy_buffers_size 64k;
            proxy_temp_file_write_size 64k;
            proxy_set_header Accept-Encoding '';

            proxy_pass $dispatch;
            access_log off;
            error_log /data/logs/api.proxy.error.log;
        }
 
        location / {
            index index.json;
            if (-f $request_filename) {
                break;
            }
            set $dispatch $1;
            if ($request_method = OPTIONS) {
                add_header Access-Control-Allow-Origin *;
                add_header Access-Control-Max-Age 86400;
                add_header Access-Control-Allow-Methods GET,POST,PUT,OPTIONS;
                add_header Access-Control-Allow-Headers x-forwarded-with,content-type;
                return 200;
            }
            lua_need_request_body on;
            content_by_lua_file lua/gateway.lua;
            access_log off;
            error_log /data/logs/api.index.error.log;
        }
 
        #全局安全
        location ~ /\. {
            deny all;
        }
 
        #错误页面
        error_page              404 =200 /404.json;
        error_page  500 502 503 504 =200 /50x.json;
        location = /50x.json{
            root html;
        }

        access_log  off;
        error_log /data/logs/server.error.log;
    }
}                              
EOF

echo "openresty install complete......"

$name -v > /dev/null 2>&1
if [[ $? -eq 0 ]];then
    echo "$name install success!"
else
    echo "$name install error!"
fi

if ! grep -q "vim" /root/.bashrc ; then
    sed -i "/alias mv/a\alias vi='vim'" /root/.bashrc
fi
if ! grep -q "curl" /root/.bashrc ; then
    sed -i "/alias vi/a\alias reload='curl localhost/reload'" /root/.bashrc
fi