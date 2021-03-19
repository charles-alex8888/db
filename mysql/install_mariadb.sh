#!/bin/bash
# 配置yum源
cat <<'EOF' > /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
# 安装
yum -y install MariaDB-server
systemctl start mariadb
systemctl enable mariadb
