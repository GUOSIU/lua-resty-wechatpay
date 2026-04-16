
local ngx               = ngx
local type              = type
local table             = table

local wechatpay         = require "resty.wechatpay"

local RSA               = require "resty.rsa"
local SHA256            = require "resty.sha256"
local Cipher            = require "resty.openssl.cipher"
local X509              = require "resty.openssl.x509"
local http              = require "resty.http"
local cjson             = require "cjson.safe"

local to_hex            = require "resty.string".to_hex
local random_bytes      = require "resty.random".bytes

local __ = { ver = "v24.10.17" }

local HTTP_ERR = {
    [400] = "协议或者参数非法",
    [401] = "签名验证失败",
    [403] = "权限异常",
    [404] = "请求的资源不存在",
    [429] = "请求超过频率限制",
    [500] = "系统错误",
    [502] = "服务下线，暂时不可用",
    [503] = "服务不可用，过载保护",
}

local NONE_VALID_URL = {
    ["/v3/certificates"] = true,
}

__.get_jsapi_package__ = {
    "获取Jsapi微信支付包",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/apis/chapter4_1_4.shtml
    req = {
        { "appid"       , "应用ID"              },
        { "appkey?"     , "商户证书私钥"        },
        { "prepay_id"   , "预支付交易会话标识"  },
    },
    res = {
        { "appId"       , "应用ID"              },
        { "timeStamp"   , "时间戳"              },
        { "nonceStr"    , "随机字符串"          },
        { "package"     , "订单详情扩展字符串"  },
        { "signType"    , "签名方式"            },
        { "paySign"     , "签名"                },
    }
}
__.get_jsapi_package = function(t)

    local  conf = wechatpay.conf.get()
    if not conf then return nil, "相关配置尚未定义" end

    local appid     = t.appid
    local timeStamp = "" .. ngx.time()
    local nonceStr  = to_hex(random_bytes(16))-- 取得随机码
    local package   = "prepay_id=" .. t.prepay_id

    local str = table.concat {
        appid       , "\n",
        timeStamp   , "\n",
        nonceStr    , "\n",
        package     , "\n",
    }

    local rsa, err = RSA:new {
        private_key = t.appkey or conf.mch_private_key, -- 商户证书私钥
        algorithm   = "SHA256",
    }
    if not rsa then return nil, err end

    local  sign, err = rsa:sign(str)
    if not sign then return nil, err end

    local paySign = ngx.encode_base64(sign)

    return {
        appId       = appid,
        timeStamp   = timeStamp,
        nonceStr    = nonceStr,
        package     = package,
        signType    = "RSA",
        paySign     = paySign,
    }

end

-- 签名生成
-- https://wechatpay-api.gitbook.io/wechatpay-api-v3/qian-ming-zhi-nan-1/qian-ming-sheng-cheng
local function get_authorization(req)

    local  conf = wechatpay.conf.get()
    if not conf then return nil, "相关配置尚未定义" end

    local timestamp = ngx.time()
    local nonce_str = to_hex(random_bytes(16))-- 取得随机码

    local str = table.concat {
        req.body and "POST" or "GET", "\n",
        req.url, "\n",
        timestamp, "\n",
        nonce_str, "\n",
        req.body or "", "\n",  -- 【坑】最后一行必须是换行
    }

    local rsa, err = RSA:new {
        private_key = conf.mch_private_key, -- 商户证书私钥
        -- key_type = RSA.KEY_TYPE.PKCS8,
        algorithm   = "SHA256",
    }
    if not rsa then return nil, err end

    local  sign, err = rsa:sign(str)
    if not sign then return nil, err end

    local signature = ngx.encode_base64(sign)

    local mchid     = conf.mch_id         -- 服务商商户号
    local serial_no = conf.mch_serial_no  -- 商户证书序列号

    return table.concat {
        "WECHATPAY2-SHA256-RSA2048", " ",  -- 只有一个空格
        "mchid"     , "=", '"', mchid     , '"', ",",   -- 服务商商户号
        "serial_no" , "=", '"', serial_no , '"', ",",   -- 商户证书序列号
        "nonce_str" , "=", '"', nonce_str , '"', ",",   -- 请求随机串
        "timestamp" , "=", '"', timestamp , '"', ",",   -- 时间戳
        "signature" , "=", '"', signature , '"',        -- 签名值
    }

end

local PUBKEYS = {}  --> map<string>

-- 取得平台证书公钥
local function get_cert_pubkey(serial_no)

    local conf = wechatpay.conf.get()
    if conf and conf.sys_serial_no == serial_no then
        return conf.sys_public_key
    end

    local public_key = PUBKEYS[serial_no]

    if public_key then return public_key end

    local  certs, err = wechatpay.certificate.list()
    if not certs then return nil, err end

    for _, c in ipairs(certs) do
        PUBKEYS[c.serial_no] = c.public_key
    end

    public_key = PUBKEYS[serial_no]
    if not public_key then return nil, "证书序列号不存在" end

    return public_key

end

-- 验证签名
local function valid_signature(res)
-- @res : { headers: map<string>, body?: string }
-- @return  : ok?: boolean, err?: string

    local  serial_no = res.headers["Wechatpay-Serial"]
    if not serial_no then return true end

    local public_key, err = get_cert_pubkey(serial_no)
    if not public_key then return nil, err end

    local rsa, err = RSA:new {
        public_key = public_key, -- 平台证书公钥
        key_type   = RSA.KEY_TYPE.PKCS8,
        algorithm  = "SHA256",
    }
    if not rsa then return nil, err end

    local data = table.concat {
        res.headers["Wechatpay-Timestamp"], "\n",   -- 应答时间戳\n
        res.headers["Wechatpay-Nonce"], "\n",       -- 应答随机串\n
        res.body or "", "\n",                       -- 应答报文主体\n
    }

    local sign = res.headers["Wechatpay-Signature"]
          sign = ngx.decode_base64(sign)

    local  ok, err = rsa:verify(data, sign)
    if not ok then return nil, err end

    return true

end

-- 微信支付API v3 接口规则
-- https://wechatpay-api.gitbook.io/wechatpay-api-v3/wei-xin-zhi-fu-api-v3-jie-kou-gui-fan

-- http请求
__.request = function(req)
-- @req     : { url, body?, args? : table, boundary, multipart }
-- @return  : res?: any, err?: string, code?: string | number

    local  conf = wechatpay.conf.get()
    if not conf then return nil, "相关配置尚未定义" end

    if req.args then
        req.url = req.url .. "?" .. ngx.encode_args(req.args)
    end

    local  authorization, err = get_authorization(req)
    if not authorization then return nil, err end

    req.body = req.multipart or req.body

    local headers = {
        ["Content-Type"]    = req.boundary and ( "multipart/form-data;boundary=" .. req.boundary )
                           or req.body     and "application/json" or nil,
        ["Accept"]          = "application/json",
        ["Accept-Language"] = "zh-CN",
        ["Authorization"]   = authorization,
        ["Wechatpay-Serial"]= conf.sys_serial_no,   -- 平台证书序列号
    }

    local url = "https://api.mch.weixin.qq.com" .. req.url

    local httpc = http.new()

    local res, err = httpc:request_uri(url, {
        method  = req.body and "POST" or "GET",
        body    = req.body,
        headers = headers,
    })
    if not res then return nil, err, -1 end

    if not NONE_VALID_URL[req.url] then
        local ok, err = valid_signature(res)  -- 验证签名
        if not ok then return nil, err end
    end

    -- 处理成功，无返回Body
    if res.status == 202 or res.status == 204 then return {} end

    local obj = res.body and cjson.decode(res.body)

    if type(obj) ~= "table" then
        if res.status == 200 then
            return nil, "JSON解析失败", -2
        else
            return nil, HTTP_ERR[res.status] or
               ( "请求失败 (" .. res.status .. ")" ), -3
        end
    end

    if res.status ~= 200 then
        local code = obj.code    or -4
        local err  = obj.message or HTTP_ERR[res.status] or
                          ( "请求失败 (" .. res.status .. ")" )
        return nil, err, code
    else
        return obj
    end

end

__.aes_256_gcm_decrypt__ = {
    "AES-256-GCM解密",
    req = {
        { "associated_data" , "附加数据包"                  },
        { "nonce"           , "随机串初始化向量"            },
        { "ciphertext"      , "Base64编码后的密文"          },
    },
    res = "string",
}
__.aes_256_gcm_decrypt = function(t)

    local  conf = wechatpay.conf.get()
    if not conf then return nil, "相关配置尚未定义" end

    local key = conf.api_v3_key
    local iv  = t.nonce
    local aad = t.associated_data

    -- 加密的数据后16位是tag数据，也就是要拆成两部分作为参数传入
    local ciphertext = ngx.decode_base64(t.ciphertext)
    local encrypted  = ciphertext:sub(1, -17)
    local tag        = ciphertext:sub(-16)

    local cipher, err = Cipher.new("aes-256-gcm")
    if not cipher then return nil, err end

    local decrypted, err = cipher:decrypt(key, iv, encrypted, false, aad, tag)
    if not decrypted then return nil, err end

    return decrypted

end

-- 敏感信息加密
-- https://pay.weixin.qq.com/docs/partner/development/interface-rules/sensitive-data-encryption.html
__.encrypt = function(str)

    if type(str) ~= "string" then return nil end

    local  conf = wechatpay.conf.get()
    if not conf then return nil, "相关配置尚未定义" end

    local  rsa, err = RSA:new {
        public_key  = conf.sys_public_key,  -- 平台证书公钥
        key_type    = RSA.KEY_TYPE.PKCS8,
        padding     = RSA.PADDING.RSA_PKCS1_OAEP_PADDING,
    }
    if not rsa then return nil, err end

    local  res = rsa:encrypt(str)
    if not res then return nil end

    return ngx.encode_base64(res)

end

-- 通过证书取得公钥
__.get_public_key = function(cert)
-- @cert    : string
-- @return  : string

    local x509, err = X509.new(cert)
    if not x509 then return nil, err end

    local pubkey = x509:get_pubkey()

    return pubkey:to_PEM()

end

local function sha256_hex(data)
-- @data    : string
-- @return  : string

    if type(data) ~= "string" then return end

    local  sha256 = SHA256:new()
    if not sha256 then return end

    local  ok = sha256:update(data)
    if not ok then return end

    local  bin = sha256:final()
    if not bin then return end

    return to_hex(bin)

end

-- 图片上传
-- https://pay.weixin.qq.com/wiki/doc/apiv3/wxpay/tool/chapter3_1.shtml
__.upload = function(req)
-- @req     : { file_name?, file_data?, name?, data? }
-- @return  : res?: any, err?: string, code?: string | number

    if type(req) ~= "table" then return nil, "请求参数不能为空" end

    local url = "/v3/merchant/media/upload"

    local file_name = req.file_name or req.name or "file.jpg"
    local file_data = req.file_data or req.data

    if type(file_name) ~= "string" or file_name == "" then
        return nil, "文件名称不能为空"
    end

    if type(file_data) ~= "string" or file_data == "" then
        return nil, "文件内容不能为空"
    end

    local body = cjson.encode {
        filename = file_name,
        sha256   = sha256_hex(file_data)
    }

    local boundary = to_hex(random_bytes(16)) -- 取得随机码

    local multipart = table.concat({
        '--' .. boundary,
        'Content-Disposition: form-data; name="meta";',
        'Content-Type: application/json',
        '',
        body,
        '--' .. boundary,
        'Content-Disposition: form-data; name="file"; filename="'.. file_name ..'";',
        'Content-Type: image/jpg',
        '',
        file_data,
        '--' .. boundary .. '--'
    },"\r\n")

    return __.request {
            url         = url
        ,   body        = body
        ,   multipart   = multipart
        ,   boundary    = boundary
    }

end

return __
