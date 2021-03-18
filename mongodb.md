# mongodb分片集群（primary、secondary、arbiter）
## 配置yum源
~~~ bash
cat << 'EOF' > /etc/yum.repos.d/mongodb-org.repo
[mongodb-org-4.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/4.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.2.asc
EOF
~~~ 
## 安装最新版
> sudo yum install -y mongodb-org
## 安装指定版本
> sudo yum install -y mongodb-org-4.4.4 mongodb-org-server-4.4.4 mongodb-org-shell-4.4.4 mongodb-org-mongos-4.4.4 mongodb-org-tools-4.4.4

## 防止意外升级
~~~ bash
cat << 'EOF' >> /etc/yum.conf 
exclude=mongodb-org,mongodb-org-server,mongodb-org-shell,mongodb-org-mongos,mongodb-org-tools
EOF
~~~
## 修改绑定ip,开启rs集群配置
~~~ bash
cat <<EOF > /etc/mongodb.conf
replication:
    oplogSizeMB: 1024
    replSetName: rs0
EOF
~~~
## 登入mongo shell 配置集群
~~~ bash
mongo ip:port
use admin
cfg={ _id:"rs0", members:[ {_id:0,host:'192.168.27.40:27017',priority:2}, {_id:1,host:'192.168.27.41:27017',priority:1},   
{_id:2,host:'192.168.27.42:27017',arbiterOnly:true}] }; 
rs.initiate(cfg)
~~~
## 查看集群状态
> rs.status()

## secondary 默认不能读写，需在主库设置
>  rs.secondaryOk()
> 
## 常用操作
~~~ bash
# 显示所有存在的数据库
show dbs;
# 进入数据库
use test;
# 显示当前所在数据库
db;
显示当前数据库所有集合
show collections;
# 向当前数据库,students集合中插入一个学生文档
db.students.insert({"name":"lucy","age":18,"sex":"女"});
# 向当前数据库,students集合中插入多个学生文档
db.students.insert([{"name":"jack","age":16,"sex":"男"},{"name":"alex","age":23,"sex":"男"}]);
# 查询当前数据库,students集合中所有的文档
db.students.find();
# 查询当前数据库,students集合中符合条件的文档
db.students.find({"sex":"男"});
# 模糊查询
db.students.find({"name":/jack/});
# 查询当前数据库,students集合中所有的文档的总数
db.students.find().count();
# 根据字段排序，1正序  -1倒序
db.students.find().sort({"age":1});
# 部分字段更新,默认只修改一条记录
db.students.update({"name":"lucy"}, {$set:{"name":"lily"}});
# 部分字段更新,修改多条记录
db.students.updateMany({"sex":"男"}, {$set:{"sex":"男生"}});
# 删除符合条件的文档
db.students.remove({"name":"lily"});
# 删除当前集合
db.students.drop();
# 删除当前数据库
db.dropDatabase();
# 查看正在执行的操作
db.currentOp()
# 查看当前的oplog时间窗口预计值
rs.printReplicationInfo()
~~~
