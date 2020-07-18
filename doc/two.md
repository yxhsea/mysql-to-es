## ElasticSearch 的最佳实践

### 引言

对于需要在海量数据中进行搜索的需求，我们大多数的情况都会使用搜索引擎。
那我们今天要介绍的就是 ElasticSearch，文中会简称 ES。

###  简单介绍

### 开发流程

我们在使用 ES 时，也和 MySQL 一样需要创建数据库、数据表，还有定义字段。
但是在 ES 中是定义索引 (Index)、映射关系 (Mapping)。

接下来，我们先定义一个索引和映射关系。
这里我以创建一个 `product` 索引为例。

```
// 创建索引并定义属性
PUT http://127.0.0.1/product
 
{
 "settings": {
     "number_of_shards": 1,
     "number_of_replicas": 1
 },
 "mappings": {
     "properties": {
         "product_id": {
             "type": "integer"
         },
         "name" : {
             "type": "text"
         },
         "sku": {
             "type": "text"
         },
         "price": {
             "type": "double"
         },
         "sales": {
             "type": "integer"
         },
         "date_modified": {
             "type": "date",
             "format": "yyyy-MM-dd HH:mm:ss || yyyy-MM-dd || epoch_millis"
         }
     }
 }
}
```

创建好索引之后，我们就从 MySQL 数据库将数据同步到 ES。
同步的方案：
1、可以直接在存储入 MySQL 之后，就直接写入 ES。
2、通过 Logstash 定时，从 MySQL 数据库中拉取数据同步到 ES。
3、可以通过第三方中间件（例如：），拉取 MySQL 数据库的 binlog 日志，之后中间件将数据同步到 ES。

创建好索引和添加数据之后，在业务的发展过程中，可能会增加字段。
这里增加一个 `description` 字段。

```
// 增加映射字段
// http://127.0.0.1:9200/product/_mapping
{
	"properties": {
		"description": {
			"type": "text"
		}
	}
}   
```

业务发展到中后时期的时候，可能发现字段越来越多了，这个时候想要删除一些字段。
但是，在 ES 中的 Mapping 中是不能直接删除字段的，只能重新创建。
很多情况，我们还是不建议去删除字段，因为这会增加很多不必要的成本以及带来的风险。
如果，为了节省存储空间，Boss 一定要删除字段。那就按照下面的方法，也是可以实现的。

```
1、创建一个新的索引
2、创建新的映射关系 mapping
3、将原索引的数据到入到新索引
4、新索引创建原索引一致的别名
5、删除原索引
```

5、从 MySQL 同步数据到 ES

6、更新 ES 中的数据

7、删除 ES 中的数据
