# MySQL 数据同步到 ElasticSearch 的最佳实践

## 引言

当出现一些复杂的数据查询工作时，MySQL 往往无法满足快速搜索的要求。   
因此，需要将 MySQL 中的数据，异构到其他的存储系统。   
这里就以 ElasticSearch 为数据异构的对象。  

## 准备工作

### 基于 Docker 创建 MySQL 容器

切换国内 `Docker` 镜像源 `vim /etc/docker/daemon.json`

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

### 基于 Docker 创建 ElasticSearch 容器

```
docker run --name=elasticsearch \
-e ES_JAVA_OPTS="-Xms512m -Xmx512m" \
-p 9200:9200 \
-p 9300:9300 \
-d elasticsearch:6.4.0

// 设置内存大小
sudo sysctl -w vm.max_map_count=262144
```

创建 goods 索引

```
curl -XPUT 'http://127.0.0.1:9200/goods'
```

### 基于 Docker 创建 Logstash 容器

```
docker run --name logstash \ 
-p 5044:5044 \
-p 5045:5045 \
-v /docker/logstash/logstash.yml:/usr/share/logstash/config/logstash.yml \
-v /docker/logstash/conf.d/:/usr/share/logstash/conf.d/ \ 
-d logstash:6.4.0
```

## 创建数据同步配置文件

在 `/docker/logstash/conf.d/` 目录下创建 `jdbc.conf` 文件。

```
input {
    stdin {
    }

    jdbc {
        # 连接的数据库地址和哪一个数据库，指定编码格式，禁用SSL协议，设定自动重连
        jdbc_connection_string => "jdbc:mysql://127.0.0.1:3306/test?characterEncoding=UTF-8&useSSL=false&autoReconnect=true"
        jdbc_user => "root"
        jdbc_password => "1234"

        # 下载连接数据库的驱动包，建议使用绝对地址
        jdbc_driver_library => "./mysql-connector-java-5.1.42.jar"

        # jdbc mysql 数据驱动
        jdbc_driver_class => "com.mysql.jdbc.Driver"
        jdbc_paging_enabled => "true"
        jdbc_page_size => "50000"
        codec => plain { charset => "UTF-8"}

        # 使用其它字段追踪，而不是用时间，这里如果是用时间追踪比如：数据的更新时间或创建时间等和时间有关的这里一定不能是true, 切记切记切记，我是用update_time来追踪的
        # use_column_value => true  

        # 追踪的字段
        tracking_column => update_time
        record_last_run => true

        # 上一个sql_last_value值的存放文件路径, 必须要在文件中指定字段的初始值  这里说是必须指定初始值, 我没指定默认是 1970-01-01 08：00：00
        # 这里的lastrun文件夹和.logstash_jdbc_last_run是自己创建的
        last_run_metadata_path => "./.logstash_jdbc_last_run"

        # 设置时区
        jdbc_default_timezone => "Asia/Shanghai"

        # statement => SELECT * FROM goods  WHERE update_time > :last_sql_value
        # 这里要说明一下如果直接写sql语句，前面这种写法肯定不对的，加上引号也试过也不对，所以我直接写在jdbc.sql文件中
        statement_filepath => "./jdbc.sql"

        # 是否清除 last_run_metadata_path 的记录,如果为真那么每次都相当于从头开始查询所有的数据库记录
        clean_run => false

        # 这是控制定时的，重复执行导入任务的时间间隔，第一位是分钟 不设置就是1分钟执行一次
        schedule => "* * * * *"
        type => "std"
    }
}

filter {
    json {
        source => "message"
        remove_field => ["message"]
    }
}

output {
    elasticsearch {
        # 要导入到的Elasticsearch所在的主机
        hosts => "127.0.0.1:9200"

        # 要导入到的Elasticsearch的索引的名称
        index => "goods"

        # 类型名称（类似数据库表名）
        document_type => "spu"

        # 主键名称（类似数据库主键）
        document_id => "%{id}"
    }

    stdout {
        # JSON格式输出
        codec => json_lines
    }
}
```

在 `/docker/logstash/conf.d/` 目录下创建 `jdbc.sql` 文件。

```
select id, name, create_time, update_time from goods where update_time > :sql_last_value
```

## 验证数据

执行搜索，如果出现数据，则意味着同步数据完成。

```
curl http://127.0.0.1:9200/goods/_search?pretty
```
