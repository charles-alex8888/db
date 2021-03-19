# mysql5.7安装
## 1. 查看当前有没有安装mysql
> rpm -qa | grep -i mysql 
## 2. 配置yum源
~~~ bash
wget http://repo.mysql.com/mysql57-community-release-el7-8.noarch.rpm
rpm -ivh mysql57-community-release-el7-8.noarch.rpm
~~~
## 3. 安装mysql
~~~ bash
yum -y install mysql-server
systemctl start mysqld
~~~
## 4. 获取临时密码登陆mysql,修改root密码
~~~ bash
cat /var/log/mysqld.log | grep password
alter user 'root'@'localhost' identified by '<your_password>';
ALTER USER 'root'@'localhost' PASSWORD EXPIRE NEVER;
flush privileges;
~~~
