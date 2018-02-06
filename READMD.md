# lua-resty-iplocation

根据手机号查询所在区域的工具函数(手机数据来源于[https://github.com/lovedboy/phone](https://github.com/lovedboy/phone))

# Overview

        lua_package_path "/the/path/to/lua-resty-phone2region/?.lua;;";
        lua_shared_dict phone_data 10m;
        server {
            listen       80;
            server_name  localhost;
            set $root /the/path/to/lua-resty-phone2region;
            charset utf-8;
        
            location /memory/phone {
                default_type text/html;
                content_by_lua_block {
                    local phone2region = require 'lib.resty.phone2region.location'
                    local location = phone2region:new({dict = 'phone_data', root = '/the/path/to/lua-resty-phone2region'})
                    local tab, err = location:memory_search('15868185878')
                    if tab then
                        ngx.say(tab.city)
                    else
                        ngx.say(err)
                    end
                }
            }
        
            location /file/phone {
                default_type text/html;
                content_by_lua_block {
                    local phone2region = require 'lib.resty.phone2region.location'
                    local location = phone2region:new({root = '/the/path/to/lua-resty-phone2region'})
                    local tab, err = location:bin_search('15868185878')
                    if tab then
                        ngx.say(tab.city)
                    else
                        ngx.say(err)
                    end
                }
            }
        
            location /phone {
                default_type text/html;
                content_by_lua_block {
                    local phone2region = require 'lib.resty.phone2region.location'
                    local location = phone2region:new({dict = 'phone_data', root = '/the/path/to/lua-resty-phone2region', mode = 'memory'})
                    local tab, err = location:search('15868185878')
                    if tab then
                        ngx.say(tab.city)
                    else
                        ngx.say(err)
                    end
                }
            }
        }


# Methods

## new

用法:phone2region_obj, err = phone2region:new({file = 'the/path/to/the/data/file', dict = 'shared dict name'})

功能：初始化iplocation模块

参数：是一个table，里面有两个元素
     
   file：数据文件所在路径

   dict:共享字典的名称(默认为ip_data，注：字典的大小建议为5m，因为文件存到内存中所占内存大约为4多M),
   
   mode:查询方式(支持内存(memory)查找,文件(binary))

## search

用法:ip_tab,err = phone2region_obj:search(ip, multi)

功能：通过手机号查询其所在区域(根据初始中的mode来判断它是采用内存查找还是文件查找)

参数：
     
   phone:查询的手机号

   multi:是否多次查找(多次查询不会关闭文件流，但需要手动调用close方法关闭文件流)
   
返回数据说明：
   
如果查询成功，则得到一个table数据，其结构如下：
   
       {
           province = "浙江",
       	　 city = "杭州",
       	　　zipcode = 330100,
       	   telephone_prefix = 0571,
       	　 isp = "电信",
       }
   
字段说明：
   
  
 
   province：省级行政区名称(不带行政区行政单位名称)
   
   city:城市名称
   
   zipcode:邮政编码
   
   telephone_prefix = 电话区号
   
   isp:网络提供商
   

## memory_search

用法:ip_tab,err = phone2region_obj:memory_search(ip)

功能：通过从内存数据中查找数据(如果没有对应的字典，则从数据文件中查找)

参数：

　　phone:查询的手机号


返回值与search方法相同

## bin_search

用法:ip_tab,err = phone2region_obj:bin_search(ip)

功能：通过二进制文件查找

参数：

　　phone:查询的手机号

　　multi:是否多次查找(多次查询不会关闭文件流，但需要手动调用close方法关闭文件流)

返回值与search方法相同


## loadfile

用法：content, err = phone2region_obj:loadfile()

功能：加载数据文件并返回数据文件中的数据(内部使用)

## close

用法：phone2region_obj:close()

功能：关闭文件流



# TODO

数据文件进一步加工(返回更多的字段)

# contact

也请各位同学反馈bug

E-mail:ishixinke@qq.com

website:[www.shixinke.com](http://www.shixinke.com "诗心客的博客")
