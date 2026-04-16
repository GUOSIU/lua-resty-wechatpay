
-- 私钥和证书
-- https://wechatpay-api.gitbook.io/wechatpay-api-v3/ren-zheng/zheng-shu#sheng-ming-suo-shi-yong-de-zheng-shu
-- 商户签名使用商户私钥，证书序列号包含在请求HTTP头部的Authorization的serial_no
-- 微信支付签名使用微信支付平台私钥，证书序列号包含在应答HTTP头部的Wechatpay-Serial
-- 商户上送敏感信息时使用微信支付平台公钥加密，证书序列号包含在请求HTTP头部的Wechatpay-Serial

local ngx       = ngx
local os        = os
local coroutine = coroutine

local __ = {}

__.types = {
    WechatPayConf = {
        { "mch_id"              , "服务商商户号"    },
        { "mch_serial_no"       , "商户证书序列号"  },
        { "mch_private_key"     , "商户证书私钥"    },
        { "api_v3_key"          , "APIv3密钥"       },
        { "sys_serial_no"       , "平台证书序列号"  },
        { "sys_public_key"      , "平台证书公钥"    },
    }
}

local CONF_DEFAULT  -- 默认配置
local CONF_INITED   --> boolean

-- 根据环境变量初始化配置
local function init_conf()

    if CONF_DEFAULT then return end
    if CONF_INITED  then return end

    CONF_INITED = true

    local conf = {}

    for _, f in ipairs(__.types.WechatPayConf) do
        local key = f[1]
        local val = os.getenv("wechatpay_" .. key)
        if not val then return end
        conf[key] = val
    end

    CONF_DEFAULT = conf

end

init_conf()

__.get__ = {
    "获取配置",
    res = "@WechatPayConf",
}
__.get = function()

    local map = ngx.ctx[__]  --> map<@WechatPayConf>

    if map then
        local co = coroutine.running()
        local conf = map[co]
        if conf then return conf end
    end

    return CONF_DEFAULT

end

__.set__ = {
    "设置配置",
    req = "@WechatPayConf",
    res = "boolean",
}
__.set = function(conf, in_ctx)

    if in_ctx then
        --- map : map<@WechatPayConf>
        local map = ngx.ctx[__]
        if not map then
            map = {}
            ngx.ctx[__] = map
        end

        local co = coroutine.running()
        map[co] = conf

    else
        CONF_DEFAULT = conf
    end

    return true

end

return __
