# 安装proxysql 
~~~ bash
cat <<EOF | tee /etc/yum.repos.d/proxysql.repo
[proxysql_repo]
name= ProxySQL YUM repository
baseurl=https://repo.proxysql.com/ProxySQL/proxysql-2.0.x/centos/\$releasever
gpgcheck=1
gpgkey=https://repo.proxysql.com/ProxySQL/repo_pub_key
EOF

yum -y install proxysql
systemctl start proxysql
systemctl enable proxysql

egrep -v "^#|^$" /etc/proxysql.cnf
~~~

# 安装mariadb 
~~~ bash
cat <<EOF > /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
yum -y install MariaDB-server
systemctl start mariadb
systemctl enable mariadb
~~~

# 配置 
~~~ bash
# 登陆
mysql -uadmin -padmin -h 127.0.0.1 -P6032 --prompt='Admin> '

# 创建后端节点
insert into mysql_servers(hostgroup_id,hostname,port,weight,comment) values(1,'test-proxy.c7lb4duituqq.ap-east-1.rds.amazonaws.com',3306,1,'write');
insert into mysql_servers(hostgroup_id,hostname,port,weight,comment) values(2,'test-proxy-readonly.c7lb4duituqq.ap-east-1.rds.amazonaws.com',3306,1,'read');
load mysql servers to runtime;
save mysql servers to disk;

# 后端主库创建用户
GRANT SELECT ON *.* TO 'monitor'@'172.16.%.%' IDENTIFIED BY 'monitorTe5bD4p_0tM';
#grant all on *.* to 'proxysql'@'172.16.%.%' identified by 'proxysqlTe5bD4p_0tM';
grant all on `%`.* to 'proxysql'@'172.16.%.%' identified by 'proxysqlTe5bD4p_0tM';



grant select ,insert,update,delete,execute on *.*  to aaonlie@'%' identified by 'oI81j^5EM52ktY23O75DEi3P';

flush privileges;

# proxysql中添加用户
insert into mysql_users(username,password,default_hostgroup,transaction_persistent) values('proxysql','proxysqlTe5bD4p_0tM',1,1);

# 设置监控用户
set mysql-monitor_username='monitor';
set mysql-monitor_password='monitorTe5bD4p_0tM';
load mysql variables to runtime;
save mysql variables to disk;


# 将所有的读操作分离到读节点，因为select.*for uodate需要申请写锁，因此分离到写节点
#insert into mysql_query_rules(rule_id,active,match_digest,destination_hostgroup,apply)values(1,1,'^SELECT.*FOR UPDATE$',1,1);
#insert into mysql_query_rules(rule_id,active,match_digest,destination_hostgroup,apply)values(2,1,'^SELECT',2,1);
insert into mysql_query_rules(rule_id,active,match_digest,destination_hostgroup,apply) VALUES (1,1,'^SELECT.*FOR UPDATE$',1,1), (2,1,'^SELECT',2,1);
# update mysql_query_rules set destination_hostgroup=2 where rule_id=2;

load mysql users to runtime;
save mysql users to disk;
load mysql query rules to runtime;
load admin variables to runtime;
save mysql query rules to disk;
save admin variables to disk;



# 开启ProxySQL的Web统计功能
update global_variables set variable_value='true' where variable_name='admin-web_enabled';
LOAD ADMIN VARIABLES TO RUNTIME;
SAVE ADMIN VARIABLES TO DISK;

select * from global_variables where variable_name LIKE 'admin-web%' or variable_name LIKE 'admin-stats%';


# 清空stats_mysql_query_digest
SELECT 1 FROM stats_mysql_query_digest_reset LIMIT 1;
# 读写分离测试
SELECT @@server_id;  
start transaction;select @@server_id;commit;select @@server_id;

# 查看读写分离效果
mysql -uproxysql -pproxysqlTe5bD4p_0tM -P6033 -h172.16.0.8 -e 'select * from test.t1;'
select hostgroup,username,digest_text,count_star from stats_mysql_query_digest;
select * from mysql_server_connect_log;

# 查询后端节点
select * from mysql_servers;
SELECT * FROM mysql_users;
SELECT * FROM mysql_query_rules;





# 查询监控信息
select * from mysql_server_connect_log;
select * from mysql_server_ping_log;
select * from mysql_server_read_only_log;
select * from mysql_server_replication_lag_log;
SELECT * FROM mysql_replication_hostgroups;

# 禁用节点，将status设置成OFFLINE_SOFT
select hostgroup_id,hostname,status from mysql_servers;
~~~


#  rule表相关字段意义
show create table mysql_query_rules；
rule_id：规则的id。规则是按照rule_id的顺序进行处理的。
active：只有该字段值为1的规则才会加载到runtime数据结构，所以只有这些规则才会被查询处理模块处理。
username：用户名筛选，当设置为非NULL值时，只有匹配的用户建立的连接发出的查询才会被匹配。
schemaname：schema筛选，当设置为非NULL值时，只有当连接使用schemaname作为默认schema时，该连接发出的查询才会被匹配。(在MariaDB/MySQL中，schemaname等价于databasename)。
flagIN,flagOUT：这些字段允许我们创建"链式规则"(chains of rules)，一个规则接一个规则。
apply：当匹配到该规则时，立即应用该规则。
client_addr：通过源地址进行匹配。
proxy_addr：当流入的查询是在本地某地址上时，将匹配。
proxy_port：当流入的查询是在本地某端口上时，将匹配。
digest：通过digest进行匹配，digest的值在stats_mysql_query_digest.digest中。
match_digest：通过正则表达式匹配digest。
match_pattern：通过正则表达式匹配查询语句的文本内容。
negate_match_pattern：设置为1时，表示未被match_digest或match_pattern匹配的才算被成功匹配。也就是说，相当于在这两个匹配动作前加了NOT操作符进行取反。
re_modifiers：RE正则引擎的修饰符列表，多个修饰符使用逗号分隔。指定了CASELESS后，将忽略大小写。指定了GLOBAL后，将替换全局(而不是第一个被匹配到的内容)。为了向后兼容，默认只启用了CASELESS修饰符。
replace_pattern：将匹配到的内容替换为此字段值。它使用的是RE2正则引擎的Replace。注意，这是可选的，当未设置该字段，查询处理器将不会重写语句，只会缓存、路由以及设置其它参数。
destination_hostgroup：将匹配到的查询路由到该主机组。但注意，如果用户的transaction_persistent=1(见mysql_users表)，且该用户建立的连接开启了一个事务，则这个事务内的所有语句都将路由到同一主机组，无视匹配规则。
cache_ttl：查询结果缓存的时间长度(单位毫秒)。注意，在ProxySQL 1.1中，cache_ttl的单位是秒。
reconnect：目前不使用该功能。
timeout：被匹配或被重写的查询执行的最大超时时长(单位毫秒)。如果一个查询执行的时间太久(超过了这个值)，该查询将自动被杀掉。如果未设置该值，将使用全局变量mysql-default_query_timeout的值。
retries：当在执行查询时探测到故障后，重新执行查询的最大次数。如果未指定，则使用全局变量mysql-query_retries_on_failure的值。
delay：延迟执行该查询的毫秒数。本质上是一个限流机制和QoS，使得可以将优先级让位于其它查询。这个值会写入到mysql-default_query_delay全局变量中，所以它会应用于所有的查询。将来的版本中将会提供一个更高级的限流机制。
mirror_flagOUT和mirror_hostgroup：mirroring相关的设置，目前mirroring正处于实验阶段，所以不解释。
error_msg：查询将被阻塞，然后向客户端返回error_msg指定的信息。
sticky_conn：当前还未实现该功能。
multiplex：如果设置为0，将禁用multiplexing。如果设置为1，则启用或重新启用multiplexing，除非有其它条件(如用户变量或事务)阻止启用。如果设置为2，则只对当前查询不禁用multiplexing。默认值为NULL，表示不会修改multiplexing的策略。
log：查询将记录日志。
apply：当设置为1后，当匹配到该规则后，将立即应用该规则，不会再评估其它的规则(注意：应用之后，将不会评估mysql_query_rules_fast_routing中的规则)。
comment：注释说明字段，例如描述规则的意义。



main库：
内存配置数据库，表里存放后端db实例、用户验证、路由规则等信息。表名以 runtime_开头的表示proxysql当前运行的配置内容，不能通过dml语句修改，只能修改对应的不以 runtime_ 开头的（在内存）里的表，然后LOAD使其生效， SAVE使其存到硬盘以供下次重启加载。
disk库：
是持久化到硬盘的配置库，对应/var/lib/proxysql/proxysql.db文件，也就是sqlite的数据文件。
stats库：
是proxysql运行抓取的统计信息库，包括到后端各命令的执行次数、流量、processlist、查询种类汇总/执行时间等等。
monitor库：
存储monitor模块收集的信息，主要是对后端db的健康、延迟检查。
