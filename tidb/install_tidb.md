# 一 服务器初始化
~~~ bash
#!/bin/bash


if [[ "$(whoami)" != "root" ]]; then
	echo "please run this script as root ." >&2
	exit 1
fi


#yum update
yum_update(){
	yum update -y
}
#configure yum source
yum_config(){
  yum install wget epel-release -y
  cd /etc/yum.repos.d/ && mkdir bak && mv -f *.repo bak/
  wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
  wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
  yum clean all && yum makecache
  yum -y install iotop iftop net-tools lrzsz gcc gcc-c++ make cmake libxml2-devel openssl-devel curl curl-devel unzip sudo ntp libaio-devel wget vim ncurses-devel autoconf automake zlib-devel  python-devel bash-completion htop 
}
#firewalld
iptables_config(){
  systemctl stop firewalld.service
  systemctl disable firewalld.service
  yum install iptables-services -y
  systemctl enable iptables
  systemctl start iptables
  iptables -F
  service iptables save
}
# ntp
ntp_config(){
  #检测及安装 NTP 服务
  sudo systemctl status ntpd.service
  ntpstat

  sudo yum install ntp ntpdate && \
  sudo systemctl start ntpd.service && \
  sudo systemctl enable ntpd.service

  sudo systemctl stop ntpd.service && \
  sudo ntpdate pool.ntp.org && \
  sudo systemctl start ntpd.service
}
#system config
system_config(){
  sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
  timedatectl set-local-rtc 1 && timedatectl set-timezone Asia/Shanghai
  yum -y install chrony && systemctl start chronyd.service && systemctl enable chronyd.service
}
ulimit_config(){
  echo "ulimit -SHn 102400" >> /etc/rc.local
  cat >> /etc/security/limits.conf << EOF
  *           soft   nofile       102400
  *           hard   nofile       102400
  *           soft   nproc        102400
  *           hard   nproc        102400
  *           soft  memlock      unlimited 
  *           hard  memlock      unlimited
EOF

}

#set sysctl
sysctl_config(){
  cp /etc/sysctl.conf /etc/sysctl.conf.bak
  cat > /etc/sysctl.conf << EOF
  net.ipv4.ip_forward = 0
  net.ipv4.conf.default.rp_filter = 1
  net.ipv4.conf.default.accept_source_route = 0
  kernel.sysrq = 0
  kernel.core_uses_pid = 1
  net.ipv4.tcp_syncookies = 1
  kernel.msgmnb = 65536
  kernel.msgmax = 65536
  kernel.shmmax = 68719476736
  kernel.shmall = 4294967296
  net.ipv4.tcp_max_tw_buckets = 6000
  net.ipv4.tcp_sack = 1
  net.ipv4.tcp_window_scaling = 1
  net.ipv4.tcp_rmem = 4096 87380 4194304
  net.ipv4.tcp_wmem = 4096 16384 4194304
  net.core.wmem_default = 8388608
  net.core.rmem_default = 8388608
  net.core.rmem_max = 16777216
  net.core.wmem_max = 16777216
  net.core.netdev_max_backlog = 262144
  net.ipv4.tcp_max_orphans = 3276800
  net.ipv4.tcp_max_syn_backlog = 262144
  net.ipv4.tcp_timestamps = 0
  net.ipv4.tcp_synack_retries = 1
  net.ipv4.tcp_syn_retries = 1
  net.ipv4.tcp_tw_recycle = 1
  net.ipv4.tcp_tw_reuse = 1
  net.ipv4.tcp_mem = 94500000 915000000 927000000
  net.ipv4.tcp_fin_timeout = 1
  net.ipv4.tcp_keepalive_time = 30
  net.ipv4.ip_local_port_range = 1024 65000
EOF
  /sbin/sysctl -p
  echo "sysctl set OK!!"
}
#install docker
install_docker() {
	yum install -y yum-utils device-mapper-persistent-data lvm2
	 yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
	 yum-config-manager --enable docker-ce-edge
	yum-config-manager --enable docker-ce-test
	yum-config-manager --disable docker-ce-edge
	yum install docker-ce -y
	systemctl start docker
	systemctl enable docker
	echo "docker install succeed!!"
}
#install_docker_compace
install_docker_compace() {
#curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
mv ./docker-compose /usr/local/bin/
chmod +x /usr/local/bin/docker-compose 
docker-compose --version
echo "docker-compose install succeed!!"
}

main(){
  yum_update
  yum_config
  iptables_config
  system_config
  ulimit_config
  sysctl_config
  #install_docker
  #install_docker_compace

}
main
~~~


## 1.1 关闭swap分区
~~~ bash
echo "vm.swappiness = 0">> /etc/sysctl.conf
swapoff -a && swapon -a
sysctl -p
~~~

## 1.2 检测和关闭透明大页
- ## 执行以下命令查看透明大页的开启状态。如果返回 [always] madvise never 则表示处于启用状态：
> cat /sys/kernel/mm/transparent_hugepage/enabled

- ## 执行 grubby 命令查看默认内核版本：
> grubby --default-kernel

- ## 执行 grubby --update-kernel 命令修改内核配置，--update-kernel 后换成你查到的内核版本
> grubby --args="transparent_hugepage=never" --update-kernel /boot/vmlinuz-3.10.0-1160.el7.x86_64

- ## 执行 grubby --info 命令查看修改后的默认内核配置
> grubby --info /boot/vmlinuz-3.10.0-1160.el7.x86_64

- ## 执行 reboot 命令进行重启或者修改当前的内核配置：
~~~
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
~~~
- ## 查看重启或者修改后已生效的默认内核配置。如果输出 always madvise [never] 表示透明大页处于禁用状态。
> cat /sys/kernel/mm/transparent_hugepage/enabled

# 二 在 TiKV 部署目标机器上添加数据盘 EXT4 文件系统挂载参数(卷名等参数自行修改)

1.1 查看数据盘
fdisk -l 

1.2 创建分区 
parted -s -a optimal /dev/nvme1n1 mklabel gpt -- mkpart primary ext4 1 -1

1.3 格式化文件系统
mkfs.ext4 /dev/nvme1n1p1

1.4 查看数据盘分区 UUID
lsblk -f

1.5 编辑 /etc/fstab 文件，添加 nodelalloc 挂载参数
UUID=c51eb23b-195c-4061-92a9-3fad812cc12f /data1 ext4 defaults,nodelalloc,noatime 0 2

1.6 挂载数据盘
mkdir /data1 && \
mount -a

1.7 执行以下命令，如果文件系统为 ext4，并且挂载参数中包含 nodelalloc，则表示已生效
mount -t ext4


# 三 配置中控机与其他服务器互信
## 3.1  中控机创建普通用户并生成密钥
useradd tidb
su - tidb
ssh-keygen

## 3.2 修改sshd服务的连接数限制
~~~ bash
sudo sed -i 's/#MaxSessions 10/MaxSessions 20/' /etc/ssh/sshd_config
sudo systemctl restart sshd
~~~

## 3.3 所有服务器上创建同样的用户，配置中控机与其他所有服务器互信
~~~ bash
useradd tidb
echo 'tidb ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
su - tidb
mkdir -pv /home/tidb/.ssh
echo "中控机的公钥" > /home/tidb/.ssh/authorized_keys
chmod 700 /home/tidb/.ssh
chmod 600 /home/tidb/.ssh/authorized_keys
~~~ 


# 四 中控机器下载安装tiup
~~~ bash
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
source ~/.bash_profile
~~~

## 4.1 安装tiup的cluster组件
tiup cluster

## 4.2 确认是否安装
which tiup

## 4.3 更新TiUP cluster 组件至最新版本
tiup update --self && tiup update cluster

## 4.4 验证当前 TiUP cluster 版本信息
tiup --binary cluster

## 4.5 配置集群配置文件 topo.yaml
<https://github.com/pingcap/docs-cn/tree/release-4.0/config-templates>
## 4.6 创建配置文件
~~~ bash
cat <<'EOF' > ~/.tiup/topo.yaml

# # Global variables are applied to all deployments and used as the default value of

# # the deployments if a specific deployment value is missing.
global:
  user: "tidb"
  ssh_port: 11618

monitored:
  node_exporter_port: 9100
  blackbox_exporter_port: 9115
  deploy_dir: "/tidb-deploy/monitored-9100"
  data_dir: "/tidb-data/monitored-9100"
  log_dir: "/tidb-deploy/monitored-9100/log"

server_configs:
  tidb:
    log.slow-threshold: 500
    binlog.enable: false
    binlog.ignore-error: false
    new_collations_enabled_on_first_bootstrap: true
    alter-primary-key: true

  tikv:
# server.grpc-concurrency: 4
# raftstore.apply-pool-size: 2
# raftstore.store-pool-size: 2
# rocksdb.max-sub-compactions: 1
# storage.block-cache.capacity: "16GB"
# readpool.unified.max-thread-count: 12
    readpool.coprocessor.use-unified-pool: true
    coprocessor.split-region-on-table: true
    readpool.storage.use-unified-pool: true
    readpool.unified.max-thread-count: 10
    server.grpc-concurrency: 6
    storage.block-cache.capacity: 14G
  pd:
    schedule.leader-schedule-limit: 4
    schedule.region-schedule-limit: 2048
    schedule.replica-schedule-limit: 64
    schedule.enable-cross-table-merge: true
  tiflash:
    # Maximum memory usage for processing a single query. Zero means unlimited.
    profiles.default.max_memory_usage: 0
    # Maximum memory usage for processing all concurrently running queries on the server. Zero means unlimited.
    profiles.default.max_memory_usage_for_all_queries: 0

pd_servers:
  - host: 172.16.0.165
    ssh_port: 22
    name: "pd-1"
    client_port: 2379
    peer_port: 2380
    deploy_dir: "/pd-data/deploy/pd-2379"
    data_dir: "/pd-data/data/pd-2379"
    log_dir: "/pd-data/deploy/pd-2379/log"
  - host: 172.16.0.250
    ssh_port: 22
    name: "pd-2"
    client_port: 2379
    peer_port: 2380
    deploy_dir: "/pd-data/deploy/pd-2379"
    data_dir: "/pd-data/data/pd-2379"
    log_dir: "/pd-data/deploy/pd-2379/log"
  - host: 172.16.0.202
    ssh_port: 22
    name: "pd-3"
    client_port: 2379
    peer_port: 2380
    deploy_dir: "/pd-data/deploy/pd-2379"
    data_dir: "/pd-data/data/pd-2379"
    log_dir: "/pd-data/deploy/pd-2379/log"

tidb_servers:
  - host: 172.16.0.161
    ssh_port: 22
    port: 4000
    status_port: 10080
    deploy_dir: "/tidb-data/deploy/tidb-4000"
    log_dir: "/tidb-data/deploy/tidb-4000/log"
  - host: 172.16.0.197
    ssh_port: 22
    port: 4000
    status_port: 10080
    deploy_dir: "/tidb-data/deploy/tidb-4000"
    log_dir: "/tidb-data/deploy/tidb-4000/log"
  - host: 172.16.0.187
    ssh_port: 22
    port: 4000
    status_port: 10080
    deploy_dir: "/tidb-data/deploy/tidb-4000"
    log_dir: "/tidb-data/deploy/tidb-4000/log"

tikv_servers:
  - host: 172.16.0.38
    ssh_port: 22
    port: 20160
    status_port: 20180
    deploy_dir: "/tikv-data/deploy/tikv-20160"
    data_dir: "/tikv-data/data/tikv-20160"
    log_dir: "/tikv-data/deploy/tikv-20160/log"
  - host: 172.16.0.234
    ssh_port: 22
    port: 20160
    status_port: 20180
    deploy_dir: "/tikv-data/deploy/tikv-20160"
    data_dir: "/tikv-data/data/tikv-20160"
    log_dir: "/tikv-data/deploy/tikv-20160/log"
  - host: 172.16.0.81
    ssh_port: 22
    port: 20160
    status_port: 20180
    deploy_dir: "/tikv-data/deploy/tikv-20160"
    data_dir: "/tikv-data/data/tikv-20160"
    log_dir: "/tikv-data/deploy/tikv-20160/log"

tiflash_servers:
  - host: 172.16.0.66
    ssh_port: 22
    #tcp_port: 9000
    #http_port: 8123
    #flash_service_port: 3930
    #flash_proxy_port: 20170
    #flash_proxy_status_port: 20292
    #metrics_port: 8234
    deploy_dir: "/flash-data/deploy/tiflash-9000"
    ## The `data_dir` will be overwritten if you define `storage.main.dir` configurations in the `config` section.
    data_dir: "/flash-data/data/tiflash-9000"
    log_dir: "/flash-data/deploy/tiflash-9000/log"
  - host: 172.16.0.88
    ssh_port: 22
    #tcp_port: 9000
    #http_port: 8123
    #flash_service_port: 3930
    #flash_proxy_port: 20170
    #flash_proxy_status_port: 20292
    #metrics_port: 8234
    deploy_dir: "/flash-data/deploy/tiflash-9000"
    ## The `data_dir` will be overwritten if you define `storage.main.dir` configurations in the `config` section.
    data_dir: "/flash-data/data/tiflash-9000"
    log_dir: "/flash-data/deploy/tiflash-9000/log"


monitoring_servers:
  - host: 172.16.0.207
    ssh_port: 22
    port: 9090
    deploy_dir: "/tidb-deploy/prometheus-9090"
    data_dir: "/tidb-data/prometheus-9090"
    log_dir: "/tidb-deploy/prometheus-9090/log"

grafana_servers:
  - host: 172.16.0.207
    port: 3000
    deploy_dir: /tidb-deploy/grafana-3000

alertmanager_servers:
  - host: 172.16.0.207
    ssh_port: 22
    web_port: 9093
    cluster_port: 9094
    deploy_dir: "/tidb-deploy/alertmanager-9093"
    data_dir: "/tidb-data/alertmanager-9093"
    log_dir: "/tidb-deploy/alertmanager-9093/log"
EOF
~~~

## 4.7 执行部署命令
    tiup cluster deploy <cluster-name> v4.0.0 topology.yaml --user tidb [-p] [-i /home/tidb/.ssh/gcp_rsa]
## 4.8 启动
    tiup cluster start <cluter-name>
## 4.9 查看集群情况
    tiup cluster list
## 4.10 检查部署的 TiDB 集群情况
    tiup cluster display <cluter-name>


# 五 访问集群
## 1. 访问数据库
    mysql -h ip -P 4000 -u root
## 2. 访问grafana
    http://ip:3000  
    默认用户密码都是admin
## 3. 访问tidb的dashboard
    http://ip:2379/dashboard
    默认用户名root

# 六 集群伸缩
## 6.1 扩展
tiup cluster scale-out <cluster-name> <file_path>
## 6.1.1 tidb
~~~ bash
tidb_servers:
  - host: 172.16.0.171
    ssh_port: 11618
    port: 4000
    status_port: 10080
    deploy_dir: "/tidb-data/deploy/tidb-4000"
    log_dir: "/tidb-data/deploy/tidb-4000/log"
~~~
## 6.1.2
~~~ bash
tikv_servers:
  - host: 172.16.0.101
    ssh_port: 11618
    port: 20160
    status_port: 20180
    deploy_dir: "/tikv-data/deploy/tikv-20160"
    data_dir: "/tikv-data/data/tikv-20160"
    log_dir: "/tikv-data/deploy/tikv-20160/log"
~~~
## 6.2 缩减
tiup cluster scale-in <cluster-name> -N ip:port --force

# 七 为tidb配置负载均衡
## 7.1 安装haproxy
~~~ bash
yum -y install epel-release gcc systemd-devel
yum -y install haproxy
which haproxy
~~~ 
### 
## 7.2 编辑配置文件 方法1
~~~ bash
cat << 'EOF' > /etc/haproxy/haproxy.cfg
global
    #工作目录
    chroot /usr/local/haproxy
    #日志文件，使用rsyslog服务中local5日志设备（/var/log/local5），等级info
    log 127.0.0.1 local5 info
    #守护进程运行
    daemon
        pidfile /data/haproxy/haproxy.pid
        user tidb
    group tidb

defaults
    log    global
    mode    http
    #日志格式
    option    httplog
    #日志中不记录负载均衡的心跳检测记录
    option    dontlognull
    #连接超时（毫秒）
    timeout connect 30000
    #客户端超时（毫秒）
    timeout client  3000000
    #服务器超时（毫秒）
    timeout server  3000000

#监控界面
listen  admin_stats
    #监控界面的访问的IP和端口
    bind  0.0.0.0:8888
    #访问协议
    mode        http
    #URI相对地址
    stats uri   /dbs
    #统计报告格式
    stats realm     Global\ statistics
    #登陆帐户信息
    stats auth  admin:abc123456
#数据库负载均衡
listen  proxy-mysql
    #访问的IP和���口
    bind  0.0.0.0:3306
    #网络协议
    mode  tcp
    #负载均衡算法（轮询算法）
    #轮询算法：roundrobin
    #权重算法：static-rr
    #最少连接算法：leastconn
    #请求源IP算法：source
    balance  roundrobin
    #日志格式
    option  tcplog
    #在MySQL中创建一个没有权限的haproxy用户，密码为空。Haproxy使用这个账户对MySQL数据库心跳检测
    option  mysql-check user haproxy
    server  tidb_1 172.16.0.57:4000 check weight 1 maxconn 10000 inter 600 fall 5
    server  tidb_2 172.16.0.4:4000 check weight 1 maxconn 10000 inter 600 fall 5
    server  tidb_3 172.16.0.121:4000 check weight 1 maxconn 10000 inter 600 fall 5
    server  tidb_4 172.16.0.171:4000 check weight 1 maxconn 10000 inter 600 fall 5
    #使用keepalive检测死链
    option  tcpka
EOF
~~~
## 7.3 编辑配置文件 方法二
~~~ bash
cat << 'EOF' > /etc/haproxy/haproxy.cfg
global                                     # 全局配置。
    log         127.0.0.1 local2            # 定义全局的 syslog 服务器，最多可以定义两个。
    chroot      /var/lib/haproxy            # 更改当前目录并为启动进程设置超级用户权限，从而提高安全性。
    pidfile     /var/run/haproxy.pid        # 将 HAProxy 进程的 PID 写入 pidfile。
    maxconn     4000                        # 每个 HAProxy 进程所接受的最大并发连接数。
    user        haproxy                     # 同 UID 参数。
    group       haproxy                     # 同 GID 参数，建议使用专用用户组。
    nbproc      40                          # 在后台运行时创建的进程数。在启动多个进程转发请求时，确保该值足够大，保证 HAProxy 不会成为瓶颈。
    daemon                                  # 让 HAProxy 以守护进程的方式工作于后台，等同于命令行参数“-D”的功能。当然，也可以在命令行中用“-db”参数将其禁用。
    stats socket /var/lib/haproxy/stats     # 统计信息保存位置。

    defaults                                   # 默认配置。
    log global                              # 日志继承全局配置段的设置。
    retries 2                               # 向上游服务器尝试连接的最大次数，超过此值便认为后端服务器不可用。
    timeout connect  2s                     # HAProxy 与后端服务器连接超时时间。如果在同一个局域网内，可设置成较短的时间。
    timeout client 30000s                   # 客户端与 HAProxy 连接后，数据传输完毕，即非活动连接的超时时间。
    timeout server 30000s                   # 服务器端非活动连接的超时时间。

    listen admin_stats                         # frontend 和 backend 的组合体，此监控组的名称可按需进行自定义。
    bind 0.0.0.0:8080                       # 监听端口。
    mode http                               # 监控运行的模式，此处为 `http` 模式。
    option httplog                          # 开始启用记录 HTTP 请求的日志功能。
    maxconn 10                              # 最大并发连接数。
    stats refresh 30s                       # 每隔 30 秒自动刷新监控页面。
    stats uri /haproxy                      # 监控页面的 URL。
    stats realm HAProxy                     # 监控页面的提示信息。
    stats auth <user>:<password>    # 监控页面的用户和密码，可设置多个用户名。
    stats hide-version                      # 隐藏监控页面上的 HAProxy 版本信息。
    stats  admin if TRUE                    # 手工启用或禁用后端服务器（HAProxy 1.4.9 及之后版本开始支持）。

    listen tidb-cluster                        # 配置 database 负载均衡。
    bind 0.0.0.0:3390                       # 浮动 IP 和 监听端口。
    mode tcp                                # HAProxy 要使用第 4 层的传输层。
    balance leastconn                       # 连接数最少的服务器优先接收连接。`leastconn` 建议用于长会话服务，例如 LDAP、SQL、TSE 等，而不是短会话协议，如 HTTP。该算法是动态的，对于启动慢的服务器，服务器权重会在运行中作调整。
    server tidb-1 <backend-ip1>:4000 check inter 2000 rise 2 fall 3       # 检测 4000 端口，检测频率为每 2000 毫秒一次。如果 2 次检测为成功，则认为服务器可用；如果 3 次检测为失败，则认为服务器不可用。
    server tidb-2 <backend-ip2>:4000 check inter 2000 rise 2 fall 3
EOF
~~~ 
## 7.4 启动
> haproxy -D -f /etc/haproxy/haproxy.cfg
# 八 其他命令
~~~ bash
# 在线修改配置文件
tiup cluster edit-config <cluster-name>
# 滚动重启
tiup cluster reload <cluster-name>  -R pd/tikv/tidb
# 重启某个节点
tiup cluster restart  <cluster-name>  -N ip:port
# 修改集群名
tiup cluster rename <old-name> <new-name>
~~~ 


# 其他参数设置
~~~ bash
innodb_lock_wait_timeout=60
interactive_timeout=300
wait_timeout=300
sql_mode ='NO_ENGINE_SUBSTITUTION,PIPES_AS_CONCAT'
transaction_isolation ='READ-COMMITTED'

去掉主键开关，会话级
set tidb_allow_remove_auto_inc=1;

GC查询和设置保留一天

select VARIABLE_NAME, VARIABLE_VALUE from mysql.tidb where VARIABLE_NAME like "tikv_gc%";
update mysql.tidb set VARIABLE_VALUE="24h" where VARIABLE_NAME="tikv_gc_life_time";
~~~
