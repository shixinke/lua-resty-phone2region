local phone2region = require 'lib.resty.phone2region.location'
local location = phone2region:new()
local tab, err = location:memory_search('15867172046')
if tab then
    ngx.say(tab.city)
else
    ngx.say(err)
end