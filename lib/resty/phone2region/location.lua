--[[
-- @description : It is a phone location library for openresty
-- @author : shixinke <ishixinke@qq.com>
-- @website : www.shixinke.com
-- @date : 2018-02-06
--]]
local _M = {
    _version = '0.01'
}

local shdict = ngx.shared
local math = math
local tonumber = tonumber
local first_index_offset = 4
local index_block_length = 9
local index_step_length = 4
local strlen = string.len
local io_open = io.open
local str_byte = string.byte
local str_char = string.char
local substr = string.sub
local str_match = string.match
local str_gsub = string.gsub
local ngx_var = ngx.var
local math_floor = math.floor
local ngx_null = ngx.null
local isp_tab = {"移动", "联通", "电信", "电信虚拟运营商", "联通虚拟运营商", "移动虚拟运营商" }

local mt = {
    __index = _M
}

--[[
-- @description : left shift int number　
-- @param number num : number
-- @param number displacement : displacement
--]]
local function int_lshift(num, displacement)
    if not num or type(num) ~= 'number' then
        return nil, 'not a number'
    end
    return (num * 2 ^ displacement) % 2 ^ 32
end


local function merge2long(num1, num2, num3, num4)
    local long_num = 0
    if type(num1) ~= 'number' or type(num2) ~= 'number' or type(num2) ~= 'number' or type(num2) ~= 'number' then
        return long_num, 'parameters expected number, get '..type(num1)..'....'
    end
    long_num = long_num + int_lshift(num1, 24)
    long_num = long_num + int_lshift(num2, 16)
    long_num = long_num + int_lshift(num3, 8)
    long_num = long_num + num4
    if long_num >= 0 then
        return long_num
    else
        return long_num + math.pow(2, 32)
    end
end

local function substr2long(str, offset)
    return merge2long(str_byte(substr(str, offset + 3, offset + 3), 1), str_byte(substr(str, offset+2, offset+2), 1), str_byte(substr(str, offset+1, offset+1), 1), str_byte(substr(str, offset, offset), 1))
end


local function is_empty_string(str)
    if not str or str == '' or str == ngx_null then
        return true
    end
    return false
end

local function check_phone(phone)
    if is_empty_string(phone) then
        return false
    end
    local ok, phone_num = pcall(tonumber, phone)
    if not ok then
        return false
    end
    return true
end

local function format_region(str, isp)
    if is_empty_string(str) then
        return nil, 'not found'
    end
    local info = {province = '', city = '', zipcode = '',  telephone_prefix = '', isp = ''}
    local arr = {}
    str_gsub(str,'[^|]+',function ( field )
        arr[#arr + 1] = field
    end)
    info.province = arr[1] or ''
    info.city = arr[2] or ''
    info.zipcode = arr[3] or ''
    info.telephone_prefix = arr[4] or ''
    info.isp = (isp and isp_tab[isp]) and isp_tab[isp] or '未知'
    return info
end

local function substring(str, offset, length)
    offset = offset + 1
    local end_index = offset + length
    return substr(str, offset, end_index)
end


function _M.new(opts)
    opts = opts or {}
    local dict = opts.dict and shdict[opts.dict] or shdict.ip_data
    local file = opts.file or 'lib/resty/phone2region/data/phone.dat'
    local root = opts.root or ngx_var.root or ngx_var.document_root
    if substr(file, 1, 1) ~= '/' then
        file = root..'/'..file
    end
    return setmetatable({
        mode = opts.mode or 'memory',
        file = file,
        dict = dict,
        first = nil,
        last = nil,
        capacity = 0,
        content = nil,
        fd = nil
    }, mt)
end

function _M.verion(self)
    if self.version then
        return self.verion
    end
    if self.content then
        return substr(self.content, 0, first_index_offset)
    end
end

function _M.memory_search(self, phone)
    if check_phone(phone) ~= true then
        return nil, 'Not a legal phone number'
    end
    local content, err = self:get_dict_content()
    if not content then
        return nil, err
    end
    if self.capacity == 0 then
        self.capacity = strlen(content)
    end
    local phone_prefix = tonumber(substr(phone, 1, 7))
    local first_index = substring(self.content, 4, 4)
    if not self.first then
        self.first = substr2long(first_index, 1)
    end
    if not self.last then
        self.last = (self.capacity - self.first) / index_block_length
    end
    local heads = 0
    local tails = self.last
    local ptr = 0
    local times = 0
    local isp = 0
    while ( heads <= tails ) do
        times = times + 1
        local mid = math_floor((tails - heads) / 2)
        local tmp = heads + mid
        local offset = self.first + (tmp * index_block_length)
        local buff = substring(self.content, offset, index_step_length)
        local ok,  tmp_idx = pcall(substr2long, buff, 1)
        if not ok then
            self:close()
            return nil, 'parse data file failed'
        end

        if tmp_idx < phone_prefix then
            heads = tmp
        else
            if tmp_idx > phone_prefix then
                tails = tmp
            else
                offset =  self.first + (tmp * index_block_length + index_step_length)
                buff = substring(self.content, offset, 5)
                ptr = substr2long(buff, 1)
                isp = str_byte(substr(buff, 5, 5), 1)
                break
            end
        end
    end

    if ptr == 0 then
        return nil, 'not found'
    end
    local row = str_match(self.content, '[^\\0]+', ptr)
    return format_region(row, isp)
end



function _M.bin_search(self, phone, multi)
    if check_phone(phone) ~= true then
        return nil, 'not a legal phone number'
    end
    self.mode = 'binary'
    if self.capacity == 0 then
        self.capacity = self:filesize(true)
    end
    if self.fd == nil then
        local fd, err = io_open(self.file, 'r')
        if not fd then
            return nil, err
        end
        self.fd = fd
    end
    local phone_prefix = tonumber(substr(phone, 1, 7))
    self.fd:seek("set", 4)
    local first_index = self.fd:read(4)
    if not self.first then
        self.first = substr2long(first_index, 1)
    end
    if not self.last then
        self.last = (self.capacity - self.first) / index_block_length
    end
    local heads = 0
    local tails = self.last
    local ptr = 0
    local times = 0
    local isp = 0
    while ( heads <= tails ) do
        times = times + 1
        local mid = math_floor((tails - heads) / 2)
        local tmp = heads + mid
        self.fd:seek('set', self.first + (tmp * index_block_length))
        local buff = self.fd:read(index_step_length)
        local ok,  tmp_idx = pcall(substr2long, buff, 1)
        if not ok then
            self:close()
            return nil, 'parse data file failed'
        end

        if tmp_idx < phone_prefix then
            heads = tmp
        else
            if tmp_idx > phone_prefix then
                tails = tmp
            else
                self.fd:seek('set', self.first + (tmp * index_block_length + index_step_length))
                buff = self.fd:read(5)
                ptr = substr2long(buff, 1)
                isp = str_byte(substr(buff, 5, 5), 1)
                break
            end
        end
    end

    if ptr == 0 then
        self:close()
        return nil, 'not found'
    end
    self.fd:seek('set', ptr)
    local row = ""
    local ch = self.fd:read(1)
    while (ch ~= str_char("0")) do
        row = row .. ch
        ch = self.fd:read(1)
    end
    if not multi then
        self:close()
    end
    return format_region(row, isp)

end

function _M.search(self, phone, multi)
    if check_phone(phone) ~= true then
        return nil, 'the IP is invalid'
    end
    if self.mode == 'memory' then
        return self:memory_search(phone)
    elseif self.mode == 'binary' then
        return self:bin_search(phone, multi)
    end
end

function _M.loadfile(self)
    if self.content ~= nil then
        return self.content
    end
    local path = self.file
    if not path then
        return nil, 'the file path is nil'
    end
    local fd, err = io_open(path)
    if fd == nil then
        return nil, err
    end
    self.content = fd:read('*a')
    fd:close()
    return self.content
end

function _M.get_dict_content(self)
    local content = self.content
    local err
    if content == nil then
        if self.dict then
            content = self.dict:get('phone_region_data')
        end
        if not content then
            content, err = self:loadfile()
            if content and self.dict then
                self.dict:set('phone_region_data', content)
            end
        end
        self.content = content
        self.capacity = strlen(content)
    end

    return content, err
end

function _M.filesize(self, keep)
    if self.capacity > 0 then
        return self.capcity
    end
    if self.content ~= nil then
        return strlen(self.content)
    end
    local err
    if self.mode == 'memory' then
        self.content, err = self:get_dict_content()
        if self.content ~= nil then
            return strlen(self.content)
        else
            return 0, err
        end
    else
        if self.fd == nil then
            self.fd = io_open(self.file)
        end
        if not self.fd then
            return 0, '文件不存在'
        end
        self.capacity = self.fd:seek('end')
        if not keep then
            self.fd:close()
        end
        return self.capacity
    end
end


function _M.close(self)
    if self.fd then
        self.fd:close()
    end
end

return _M
