# mysql-to-es

## 基于 Docker 创建 MySQL 数据库

切换 Docker 镜像源 `vim /etc/docker/daemon.json`

```
{
  "registry-mirrors" : [
    "http://ovfftd6p.mirror.aliyuncs.com",
    "http://registry.docker-cn.com",
    "http://docker.mirrors.ustc.edu.cn",
    "http://hub-mirror.c.163.com"
  ],
  "insecure-registries" : [
    "registry.docker-cn.com",
    "docker.mirrors.ustc.edu.cn"
  ],
  "debug" : true,
  "experimental" : true
}
```

创建 MySQL 容器

```
docker run --name mysql \
--privileged=true \
-p 3306:3306 \
-v /home/ubuntu/docker/data:/var/lib/mysql \
-e MYSQL_ROOT_PASSWORD=1234 \
-d mysql:5.7
```

创建数据库

```
create database `test`
```

创建数据表

```
CREATE TABLE `goods`  (
  `id` int(0) NOT NULL,
  `name` varchar(255) NOT NULL,
  `create_time` datetime(0) NOT NULL,
  `update_time` datetime(0) NOT NULL,
  PRIMARY KEY (`id`)
);
```

插入测试数据

```
insert into goods values (1, 'test1', '2020-07-13 00:00:00', '2020-07-13 00:00:00');
insert into goods values (2, 'test2', '2020-07-15 00:00:00', '2020-07-15 00:00:00');
```

## 基于 Docker 创建 ElasticSearch 服务

```
docker run -e ES_JAVA_OPTS="-Xms512m -Xmx512m" --name=elasticsearch -d -p 9200:9200 -p 9300:9300 elasticsearch:6.4.0

sudo sysctl -w vm.max_map_count=262144
```

## 基于 Docker 创建 logstash 服务

```
docker run -it -d -p 5044:5044 \
-p 5045:5045 \
--name logstash \
--net somenetwork \
-v /docker/logstash/logstash.yml:/usr/share/logstash/config/logstash.yml \
-v /docker/logstash/conf.d/:/usr/share/logstash/conf.d/ \ 
logstash:6.4.0
```

https://www.cnblogs.com/killer21/p/12170031.html

https://www.cnblogs.com/wang-yaz/p/10231852.html

## 测试效果

创建 goods 索引

```
curl -XPUT 'http://127.0.0.1:9200/goods'
```

搜索数据

```
curl http://127.0.0.1:9200/goods/_search?pretty
```
